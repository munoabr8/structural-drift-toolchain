#!/usr/bin/env bash
# Collect minimal DORA events from GitHub into events.ndjson
set -euo pipefail

: "${GITHUB_REPOSITORY:?}"
: "${GH_TOKEN:?}"
WINDOW_DAYS="${WINDOW_DAYS:-14}"
DEPLOY_WORKFLOW_NAME="${DEPLOY_WORKFLOW_NAME:-Deploy}"   # your deploy workflow name
MAIN_BRANCH="${MAIN_BRANCH:-main}"

SINCE="$(date -u -d "${WINDOW_DAYS} days ago" +%FT%TZ)"
OUT="${1:-events.ndjson}"
: > "$OUT"

# --- PR merges (lead time start) ---
page=1
while :; do
  data="$(gh api -X GET \
    "/repos/${GITHUB_REPOSITORY}/pulls?state=closed&base=${MAIN_BRANCH}&per_page=100&page=${page}")"
  count="$(jq 'length' <<<"$data")"
  [[ "$count" -eq 0 ]] && break
  jq -cr --arg since "$SINCE" '
    .[] | select(.merged_at != null and .merged_at >= $since) |
    {
      type: "pr_merged",
      repo: .base.repo.full_name,
      pr: .number,
      sha: .merge_commit_sha,
      merged_at: .merged_at
    }' <<<"$data" >> "$OUT"
  page=$((page+1))
done

# --- Workflow runs (deploys) ---
# Pull recent runs; filter to your deploy workflow + branch
page=1
while :; do
  runs="$(gh api -X GET \
    "/repos/${GITHUB_REPOSITORY}/actions/runs?per_page=100&page=${page}&created>=${SINCE}")"
  count="$(jq '(.workflow_runs // .runs // []) | length' <<<"$runs")"
  [[ "$count" -eq 0 ]] && break
  jq -cr --arg name "$DEPLOY_WORKFLOW_NAME" --arg branch "$MAIN_BRANCH" '
    (.workflow_runs // .runs // [])
    | map(select(.name == $name and .head_branch == $branch))
    | .[]
    | {
        type: "deployment",
        repo: .repository.full_name,
        sha: .head_sha,
        status: (.conclusion // "unknown"),
        finished_at: (.run_completed_at // .updated_at)
      }' <<<"$runs" >> "$OUT"
  page=$((page+1))
done

# --- (Optional) forward events to a sink ---
if [[ -n "${EVENT_SINK_URL:-}" ]]; then
  while IFS= read -r line; do
    curl -fsS -H "Content-Type: application/json" -d "$line" "$EVENT_SINK_URL" >/dev/null || true
  done < "$OUT"
fi
