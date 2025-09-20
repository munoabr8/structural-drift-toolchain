#!/usr/bin/env bash
# ci/dora/probe_pairs.sh


# CONTRACT-JSON-BEGIN
# {
#   "args": ["[E]"],
#   "env": {},
#   "reads": "events NDJSON file E (default events.ndjson); no network",
#   "writes": "stdout text report; stderr HINT lines; no files",
#   "tools": ["bash","jq","sort","comm","wc","xargs","head"],
#   "exit": { "ok": 0, "shape_error": 1, "missing_tool": 70, "other": "bubbled via set -e" },
#   "emits": [
#     "== totals ==\\nprs=<n> deps=<n> intersect=<n>",
#     "== bad_rows ==\\nbad_pr=<n> bad_deploy=<n>",
#     "== sample_unmatched_pr ==",
#     "== sample_deploy_rows ==",
#     "== sample_pr_rows =="
#   ],
#   "notes": "Shape checks: pr_merged requires .sha 40-hex and .merged_at ending with Z. deployment requires .sha 40-hex, (finished_at||deploy_at) ending with Z, and status success/succeeded."
# }
# CONTRACT-JSON-END


# bash ci/dora/probe_pairs.sh events.ndjson


set -euo pipefail
E="${1:-events.ndjson}"

need(){ command -v jq >/dev/null || { echo "missing:jq" >&2; exit 70; }; }
need

# ----- counts -----
PRS=$(jq -r 'select(.type=="pr_merged")|.sha' "$E" | sort -u | wc -l | xargs)
DEPS=$(jq -r 'select(.type=="deployment")|.sha' "$E" | sort -u | wc -l | xargs)
INT=$(comm -12 \
  <(jq -r 'select(.type=="pr_merged")|.sha' "$E" | sort -u) \
  <(jq -r 'select(.type=="deployment")|.sha' "$E" | sort -u) | wc -l | xargs)

# ----- shape checks -----
# BAD_PR: null-safe (only test when field is a string)
 BAD_PR=$(
jq -s '
  [ .[] | select(.type=="pr_merged")
    | select(
        ((.sha|type)!="string") or
        ((.sha|test("^[0-9a-f]{40}$"))|not) or
        (((.merged_at // "")|type)!="string") or
        (((.merged_at // "")|test("Z$"))|not)
      )
  ] | length' "$E"
)



 # BAD_DEP: null-safe
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



# ----- quick samples -----
echo "== totals ==";      echo "prs=$PRS deps=$DEPS intersect=$INT"
echo "== bad_rows ==";    echo "bad_pr=$BAD_PR bad_deploy=$BAD_DEP"

echo "== sample_unmatched_pr =="
comm -23 \
 <(jq -r 'select(.type=="pr_merged")|.sha' "$E" | sort -u) \
 <(jq -r 'select(.type=="deployment")|.sha' "$E" | sort -u) | head -10

echo "== sample_deploy_rows =="
jq -c 'select(.type=="deployment")|{sha,status,finished_at,deploy_at}' "$E" | head -5

echo "== sample_pr_rows =="
jq -c 'select(.type=="pr_merged")|{pr,sha,merged_at}' "$E" | head -5

# ----- exit hints -----
if (( BAD_PR>0 )); then
  echo "HINT: fix PR rows → 40-hex sha, merged_at ends with Z." >&2
fi
if (( BAD_DEP>0 )); then
  echo "HINT: fix deploy rows → type=deployment, 40-hex sha, finished_at|deploy_at ends with Z, status success/succeeded." >&2
fi

# nonzero exit if shapes are bad
(( BAD_PR==0 && BAD_DEP==0 )) || exit 1
