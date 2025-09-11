#!/usr/bin/env bash
# ci/dora/collect-events.sh
# Collect minimal DORA events from GitHub into events.ndjson
set -euo pipefail

: "${GITHUB_REPOSITORY:?}"
: "${GH_TOKEN:?}"  # used by gh cli

WINDOW_DAYS="${WINDOW_DAYS:-14}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
DEPLOY_WORKFLOW_NAME="${DEPLOY_WORKFLOW_NAME:-}"   # leave empty to disable name filter
DEPLOY_WORKFLOW_ID="${DEPLOY_WORKFLOW_ID:-}"       # optional explicit workflow id
OUT="${1:-events.ndjson}"

SINCE="$(date -u -d "${WINDOW_DAYS} days ago" +%FT%TZ)"
: > "$OUT"

# --- PR merges (lead-time start) ---
page=1
while :; do
  data="$(gh api -X GET \
    "/repos/${GITHUB_REPOSITORY}/pulls?state=closed&base=${MAIN_BRANCH}&per_page=100&page=${page}")"
  cnt="$(jq 'length' <<<"$data")"
  [[ "$cnt" -eq 0 ]] && break
  jq -cr --arg since "$SINCE" '
    .[]
    | select(.merged_at != null and .merged_at >= $since)
    | {
        type: "pr_merged",
        repo: .base.repo.full_name,
        pr: .number,
        sha: .merge_commit_sha,
        merged_at: .merged_at
      }' <<<"$data" >> "$OUT"
  page=$((page+1))
done

# --- Workflow runs (deploys) ---
# Resolve workflow id (prefer ID; else by name; else no filter)
wf_id=""
if [[ -n "$DEPLOY_WORKFLOW_ID" ]]; then
  wf_id="$DEPLOY_WORKFLOW_ID"
elif [[ -n "$DEPLOY_WORKFLOW_NAME" ]]; then
  wf_json="$(gh api /repos/${GITHUB_REPOSITORY}/actions/workflows)"
  wf_id="$(jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '.workflows[] | select(.name==$n) | .id' <<<"$wf_json")"
  if [[ -z "$wf_id" || "$wf_id" == "null" ]]; then
    echo "WARN: Deploy workflow not found: ${DEPLOY_WORKFLOW_NAME}. Using NO name filter." >&2
    DEPLOY_WORKFLOW_NAME=""
    wf_id=""
  fi
fi

page=1
while :; do
  if [[ -n "$wf_id" ]]; then
    runs="$(gh api -X GET "/repos/${GITHUB_REPOSITORY}/actions/workflows/${wf_id}/runs?per_page=100&page=${page}&created>=${SINCE}")"
  else
    runs="$(gh api -X GET "/repos/${GITHUB_REPOSITORY}/actions/runs?per_page=100&page=${page}&created>=${SINCE}")"
  fi

  arr="$(jq -cr '(.workflow_runs // .runs // [])' <<<"$runs")"
  n_all="$(jq 'length' <<<"$arr")"
  [[ "$n_all" -eq 0 ]] && break

  filtered="$arr"
  if [[ -n "$MAIN_BRANCH" ]]; then
    filtered="$(jq -cr --arg b "$MAIN_BRANCH" 'map(select(.head_branch==$b))' <<<"$filtered")"
  fi
  if [[ -z "$wf_id" && -n "$DEPLOY_WORKFLOW_NAME" ]]; then
    filtered="$(jq -cr --arg n "$DEPLOY_WORKFLOW_NAME" 'map(select(.name==$n))' <<<"$filtered")"
  fi
  # Exclude obvious non-deploy markers (extend as needed)
  filtered="$(jq -cr 'map(select(.name != "DORA Basics" and .name != "CI Hours"))' <<<"$filtered")"

  echo "batch_total=${n_all} filtered=$(jq 'length' <<<"$filtered")" >&2

  echo "$filtered" | jq -cr '.[] | {
      type: "deployment",
      repo: .repository.full_name,
      sha: .head_sha,
      status: (.conclusion // "unknown"),
      finished_at: (.run_completed_at // .updated_at)
    }' >> "$OUT"

  page=$((page+1))
done

# --- Optional: forward each event to an external sink ---
if [[ -n "${EVENT_SINK_URL:-}" ]]; then
  while IFS= read -r line; do
    curl -fsS -H "Content-Type: application/json" -d "$line" "$EVENT_SINK_URL" >/dev/null || true
  done < "$OUT"
fi
