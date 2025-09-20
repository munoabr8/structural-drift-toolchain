#!/usr/bin/env bash

# {
#   "schema": "ir/v1",
#   "args": [],
#   "env": {
#     "DEPLOY_WORKFLOW_NAME": "Deploy",
#     "MAIN_BRANCH": "main",
#     "ART": "events-ndjson"
#   },
#   "reads": "",
#   "writes": [
#     "events.ndjson",
#     "artifacts/events.ndjson",
#     "pr.ndjson",
#     "pr_only.ndjson",
#     "raw.ndjson"
#   ],
#   "tools": [
#     "bash",
#     "gh",
#     "jq",
#     "awk",
#     "mktemp"
#   ],
#   "exit": {
#     "0": "success; wrote events.ndjson; stderr: OK:events=<N>",
#     "2": "no events",
#     "3": "no_prs",
#     "4": "no_success_deploys",
#     "5": "no_pr_to_deploy_pairs"
#   },
#   "outputs": [
#     "events.ndjson"
#   ]
# }



# ci/dora/prepare-events.sh
set -euo pipefail

WF="${DEPLOY_WORKFLOW_NAME:-Deploy}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
ART="events-ndjson"

 

# --- fetch artifact (best effort) ---
rm -f artifacts/events.ndjson raw.ndjson events.ndjson

RUNS_JSON="$(gh run list --workflow "$WF" --branch "$MAIN_BRANCH" -L 50 \
  --json databaseId,createdAt,conclusion 2>/dev/null || echo '[]')"

RUN_ID="$(
  jq -r '
    if type=="array" and length>0 then
      ( map(select(.conclusion=="success"))
        | sort_by(.createdAt)
        | (last? // {})
        | (.databaseId? // .id? // empty) )
    else empty end
  ' <<<"$RUNS_JSON"
)"

if [[ -n "${RUN_ID:-}" ]]; then
  mkdir -p artifacts
  gh run download "$RUN_ID" -n "$ART" -D artifacts || true
fi


# --- collect PR merges only ---
bash ci/dora/collect-events.sh pr.ndjson 1>&2
jq -c 'select(.type=="pr_merged")' pr.ndjson > pr_only.ndjson

# --- merge sources into RAW (may contain noise) ---
if [[ -s artifacts/events.ndjson ]]; then cat artifacts/events.ndjson >> raw.ndjson; fi
if [[ -s pr_only.ndjson        ]]; then cat pr_only.ndjson        >> raw.ndjson; fi
[[ -s raw.ndjson ]] || { echo "ERR:no events" >&2; exit 2; }

# --- CLEAN: keep JSON objects only ---
jq -crR 'fromjson? | select(type=="object")' raw.ndjson > events.ndjson

# --- de-dupe by identity keys ---
tmp="$(mktemp)"
jq -s -c '
  def key: .sha // .merge_commit_sha // .head_sha;
  def ttag: if .type=="deployment" then (.finished_at // .deploy_at) else .merged_at end;
  unique_by(.type, (key), (ttag)) | .[]
' events.ndjson > "$tmp"
mv "$tmp" events.ndjson

# --- guards (pure queries; always slurp -s) ---
# 1) PRs exist
jq -se 'any(.[]; (type=="object") and (.type=="pr_merged"))' events.ndjson \
  || { echo "ERR:no_prs" >&2; exit 3; }
# 2) success deploys exist
jq -se 'any(.[]; (type=="object") and (.type=="deployment") and ((.status//"success")=="success"))' events.ndjson \
  || { echo "ERR:no_success_deploys" >&2; exit 4; }
# 3) at least one joinable PR→deploy pair
jq -sr '
  def key: .sha // .merge_commit_sha // .head_sha;
  def mtime: .merged_at // .mergedAt // .time;
  def dtime: .finished_at // .deploy_at // .time;

  . as $all
  | ($all|map(select(.type=="pr_merged")|{k:(key),m:(mtime)})) as $prs
  | ($all|map(select(.type=="deployment" and ((.status//"success")=="success"))|{k:(key),d:(dtime)})) as $deps
  | [ $prs[] as $p
      | $deps[] as $d
      | select($p.k and $d.k and $p.m and $d.d)
      | select($p.k==$d.k)
      | select(( $d.d | fromdateiso8601 ) > ( $p.m | fromdateiso8601 ))
    ] | length
' events.ndjson | awk '{ if ($1<1){print "ERR:no_pr_to_deploy_pairs" > "/dev/stderr"; exit 5} }'

echo "OK:events=$(wc -l < events.ndjson)" >&2
