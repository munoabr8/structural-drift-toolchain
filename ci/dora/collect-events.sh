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

SINCE_ISO="$SINCE"

# Resolve workflow ID by name if provided
wf_id=""
if [[ -n "${DEPLOY_WORKFLOW_ID:-}" ]]; then
  wf_id="$DEPLOY_WORKFLOW_ID"
elif [[ -n "${DEPLOY_WORKFLOW_NAME:-}" && "${DEPLOY_WORKFLOW_NAME}" != "ANY" ]]; then
  wf_json="$(gh api /repos/${GITHUB_REPOSITORY}/actions/workflows)"
  wf_id="$(jq -r --arg n "${DEPLOY_WORKFLOW_NAME}" '.workflows[] | select(.name==$n) | .id' <<<"$wf_json")"
  if [[ -z "$wf_id" || "$wf_id" == "null" ]]; then
    echo "Deploy workflow not found: ${DEPLOY_WORKFLOW_NAME}" >&2
    echo "Available workflows:" >&2
    jq -r '.workflows[].name' <<<"$wf_json" >&2
    exit 1
  fi
fi

page=1
while :; do
  if [[ -n "$wf_id" ]]; then
    runs="$(gh api -X GET "/repos/${GITHUB_REPOSITORY}/actions/workflows/${wf_id}/runs?per_page=100&page=${page}&created>=${SINCE_ISO}")"
  else
    runs="$(gh api -X GET "/repos/${GITHUB_REPOSITORY}/actions/runs?per_page=100&page=${page}&created>=${SINCE_ISO}")"
  fi

  all="$(jq -cr '(.workflow_runs // .runs // [])' <<<"$runs")"
  n_all="$(jq 'length' <<<"$all")"
  [[ "$n_all" -eq 0 ]] && break

  # Optional filters
  filtered="$all"
  if [[ -n "${MAIN_BRANCH:-}" ]]; then
    filtered="$(jq -cr --arg b "$MAIN_BRANCH" 'map(select(.head_branch==$b))' <<<"$filtered")"
  fi
  if [[ -z "$wf_id" && -n "${DEPLOY_WORKFLOW_NAME:-}" && "${DEPLOY_WORKFLOW_NAME}" != "ANY" ]]; then
    filtered="$(jq -cr --arg n "$DEPLOY_WORKFLOW_NAME" 'map(select(.name==$n))' <<<"$filtered")"
  fi
  # Avoid counting this workflow and other obvious non-deploys (extend list if needed)
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



# --- (Optional) forward events to a sink ---
if [[ -n "${EVENT_SINK_URL:-}" ]]; then
  while IFS= read -r line; do
    curl -fsS -H "Content-Type: application/json" -d "$line" "$EVENT_SINK_URL" >/dev/null || true
  done < "$OUT"
fi
