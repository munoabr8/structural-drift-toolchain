#!/usr/bin/env bash
# ci/dora/probe_pairs.sh
# Diagnose PR↔deploy pairing, event shape, and pair coverage from events.ndjson.

# CONTRACT-JSON-BEGIN
# {
#   "args": ["[E]"],
#   "env": {
#     "BASE_BRANCH": "target prod branch for merges (default: main)",
#     "FALLBACK_HOURS": "hours for time-pairability bootstrap report (default: 168)",
#     "MAX_SHOW": "max rows to sample in sections (default: 10)"
#   },
#   "reads": "events NDJSON file E (default events.ndjson); no network",
#   "writes": "stdout text report; stderr HINT lines; no files",
#   "tools": ["bash","jq","sort","comm","wc","sed","awk","head","xargs","date","mktemp"],
#   "exit": { "ok": 0, "shape_error": 1, "missing_tool": 70, "other": "bubbled via set -e" },
#   "emits": [
#     "== totals ==\\nprs=<n> deps=<n> intersect=<n>",
#     "== coverage ==\\npair_coverage=<0..1>",
#     "== bad_rows ==\\nbad_pr=<n> bad_deploy=<n>",
#     "== merges_not_into_<BASE_BRANCH> ==",
#     "== sample_unmatched_pr ==",
#     "== sample_deploy_rows ==",
#     "== sample_pr_rows ==",
#     "== time_pairability =="
#   ],
#   "notes": "PR key uses merge_commit_sha || sha || head_sha. deployment requires sha, finished_at||deploy_at, and success status."
# }
# CONTRACT-JSON-END

set -euo pipefail
export LC_ALL=C

E="${1:-ci/dora/events.ndjson}"
BASE_BRANCH="${BASE_BRANCH:-main}"
FALLBACK_HOURS="${FALLBACK_HOURS:-168}"
MAX_SHOW="${MAX_SHOW:-10}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "missing:$1" >&2; exit 70; }; }
need jq; need sort; need comm; need wc; need sed; need awk; need head; need xargs; need date

# Validate NDJSON syntactically
jq -e . "$E" >/dev/null || { echo "ERR:invalid_json_lines" >&2; exit 1; }

# Effective PR SHA selector
PR_SHA='(.merge_commit_sha // .sha // .head_sha // "")'
DEP_SHA='.sha'

# ----- counts -----
PRS=$(jq -r "select(.type==\"pr_merged\") | $PR_SHA" "$E" | sed '/^$/d' | sort -u | wc -l | xargs)
DEPS=$(jq -r "select(.type==\"deployment\") | $DEP_SHA" "$E" | sed '/^$/d' | sort -u | wc -l | xargs)
INT=$(comm -12 \
  <(jq -r "select(.type==\"pr_merged\") | $PR_SHA" "$E" | sed '/^$/d' | sort -u) \
  <(jq -r "select(.type==\"deployment\") | $DEP_SHA" "$E" | sed '/^$/d' | sort -u) \
  | wc -l | xargs)

echo "== totals =="
echo "prs=$PRS deps=$DEPS intersect=$INT"

# Coverage metric
COV=$(awk -v i="$INT" -v p="$PRS" 'BEGIN{ if(p==0){print "0.00"} else {printf "%.2f", i/p} }')
echo "== coverage =="
echo "pair_coverage=$COV  # exact sha matches / distinct PR SHAs"

# ----- shape checks -----
BAD_PR=$(
jq -s "
  [ .[] | select(.type==\"pr_merged\")
    | {s: $PR_SHA, m:(.merged_at//\"\")}
    | select(
        ((.s|type)!=\"string\") or
        ((.s|test(\"^[0-9a-f]{40}$\"))|not) or
        ((.m|type)!=\"string\") or
        ((.m|test(\"Z$\"))|not)
      )
  ] | length" "$E"
)

BAD_DEP=$(
jq -s '
  [ .[] | select(.type=="deployment")
    | . as $d
    | ($d.status // "success" | tostring | ascii_downcase) as $s
    | ($d.finished_at // $d.deploy_at // "") as $ts
    | select(
        (($d.sha|type)!="string") or
        ((($d.sha)|test("^[0-9a-f]{40}$"))|not) or
        (($ts|type)!="string") or
        (($ts|test("Z$"))|not) or
        (( $s=="success" or $s=="succeeded") | not)
      )
  ] | length' "$E"
)

echo "== bad_rows =="
echo "bad_pr=$BAD_PR bad_deploy=$BAD_DEP"

# ----- merges not into BASE_BRANCH -----
echo "== merges_not_into_${BASE_BRANCH} =="
jq -c --arg b "$BASE_BRANCH" "
  select(.type==\"pr_merged\" and (.base_branch//\"\")!=\$b)
  | {pr,base_branch,sha: $PR_SHA, merged_at}" "$E" | head -n "$MAX_SHOW"

# ----- unmatched PRs by SHA -----
echo "== sample_unmatched_pr =="
comm -23 \
 <(jq -r "select(.type==\"pr_merged\") | $PR_SHA" "$E" | sed '/^$/d' | sort -u) \
 <(jq -r "select(.type==\"deployment\") | $DEP_SHA" "$E" | sed '/^$/d' | sort -u) \
 | head -n "$MAX_SHOW"

# ----- sample rows -----
echo "== sample_deploy_rows =="
jq -c 'select(.type=="deployment")|{sha,status,finished_at,deploy_at}' "$E" | head -n "$MAX_SHOW"

echo "== sample_pr_rows =="
jq -c "select(.type==\"pr_merged\")|{pr,base_branch,sha: $PR_SHA,merged_at}" "$E" | head -n "$MAX_SHOW"

# ----- time-pairability (bootstrap) -----
echo "== time_pairability =="
jq -s --arg b "$BASE_BRANCH" --argjson H "$FALLBACK_HOURS" '
  def toTs($s): if $s and ($s|length>0) then ($s|fromdateiso8601) else null end;

  . as $all
  | ($all | map(select(.type=="deployment" and (.sha|length>0))
                | {sha:.sha, t: toTs((.finished_at//.deploy_at))})) as $dep
  | ($all | map(select(.type=="pr_merged" and (.merged_at|length>0))
                | {pr, base_branch:(.base_branch//""), sha:(.merge_commit_sha//.sha//.head_sha//""), m: toTs(.merged_at)})) as $prs
  | ($prs | map(select(.base_branch==$b))) as $prs_main
  | $prs_main
  | map(. as $p
        | ($dep | map(select(.sha==$p.sha) | .t) | sort) as $dt
        | if ($dt|length)>0 then
            $p + {pair:"exact", t: ($dt[0]), lead: (($dt[0]-$p.m)/3600.0)}
          else
            ($dep | map(select((.t != null) and (.t >= $p.m) and (.t <= ($p.m + ($H*3600)))) ) | sort_by(.t)) as $ft
            | if ($ft|length)>0 then
                $p + {pair:"fallback", t: ($ft[0].t), lead: (($ft[0].t-$p.m)/3600.0)}
              else
                $p + {pair:"none"}
              end
          end)
  | {
      considered: ($prs_main|length),
      exact_pairs: (map(select(.pair=="exact"))|length),
      fallback_pairs: (map(select(.pair=="fallback"))|length),
      none: (map(select(.pair=="none"))|length),
      examples_unpaired: (map(select(.pair=="none"))[:10] | map({pr,sha,merged_at:(.m|todate)}))
    }
' "$E"

# ----- exit hints -----
if (( BAD_PR > 0 )); then
  echo "HINT: fix PR rows → effective sha 40-hex (merge_commit_sha||sha||head_sha), merged_at ends with Z." >&2
fi
if (( BAD_DEP > 0 )); then
  echo "HINT: fix deploy rows → type=deployment, sha 40-hex, finished_at|deploy_at ends with Z, status success/succeeded." >&2
fi
if (( BAD_PR>0 || BAD_DEP>0 )); then
  exit 1
fi
