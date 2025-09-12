#!/usr/bin/env bash
# ci/dora/collect-events.sh
# Collect minimal DORA events (PR merges + successful deploys) into NDJSON.

set -euo pipefail
export LC_ALL=C

# ---------- config ----------
OUT="${1:-events.ndjson}"
WINDOW_DAYS="${WINDOW_DAYS:-14}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
DEPLOY_WORKFLOW_NAME="${DEPLOY_WORKFLOW_NAME:-}"   # or set DEPLOY_WORKFLOW_ID
DEPLOY_WORKFLOW_ID="${DEPLOY_WORKFLOW_ID:-}"

# ---------- utils ----------
die()  { echo "ERR:$*" >&2; exit "${2:-1}"; }
warn() { echo "WARN:$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing:$1" 70; }
api()  { gh api "$@" 2>/dev/null; }  # quiet gh wrapper
jqr()  { jq -cr "$@"; }
since_ts() { date -u -d "${WINDOW_DAYS} days ago" +%FT%TZ; }

# ---------- assertions ----------
assert_env() {
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY missing}"
  : "${GH_TOKEN:?GH_TOKEN missing}"
  need gh; need jq; need date
  # rate limit
  rem="$(gh api rate_limit -q '.resources.core.remaining' || echo 0)"
  (( rem>5 )) || die "rate_limit_low:$rem"
  # branch exists
  gh api "repos/${GITHUB_REPOSITORY}/branches/${MAIN_BRANCH}" -q .name >/dev/null \
    || die "main_branch_missing:${MAIN_BRANCH}"
}
# ---------- PR merges (lead-time start) ----------
collect_pr_merges() {
  local page=1 SINCE; SINCE="$(since_ts)"
  while :; do
    data="$(api "/repos/${GITHUB_REPOSITORY}/pulls?state=closed&base=${MAIN_BRANCH}&per_page=100&page=${page}")" || die "gh_pr_list_failed"
    cnt="$(jq 'length' <<<"$data")"; [[ "$cnt" -eq 0 ]] && break
    # assert JSON shape
    bad="$(jq '[ .[] | select(.merged_at==null or (.merge_commit_sha//.head.sha//"")=="" ) ] | length' <<<"$data")"
    (( bad==0 )) || warn "pr_merged_missing_sha_or_time:count=${bad}"

    jqr --arg since "$SINCE" '
      .[] | select(.merged_at != null and .merged_at >= $since)
      | {type:"pr_merged", repo:.base.repo.full_name, pr:.number,
         sha:(.merge_commit_sha // .head.sha // ""),
         merged_at:.merged_at}
    ' <<<"$data"
    page=$((page+1))
  done
}


# ---------- Resolve deploy workflow id ----------
resolve_workflow_id() {
  if [[ -n "$DEPLOY_WORKFLOW_ID" ]]; then echo "$DEPLOY_WORKFLOW_ID"; return; fi
  [[ -n "$DEPLOY_WORKFLOW_NAME" ]] || die "deploy_workflow_name_or_id_required" 66
  wf_json="$(api "/repos/${GITHUB_REPOSITORY}/actions/workflows")"
  # exact name match count
  cnt="$(jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '[.workflows[]|select(.name==$n)]|length' <<<"$wf_json")"
  (( cnt==1 )) || die "deploy_workflow_name_ambiguous_or_missing:name=${DEPLOY_WORKFLOW_NAME} count=${cnt}" 66
  jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '.workflows[]|select(.name==$n)|.id' <<<"$wf_json"
}

# ---------- Fetch successful deploy runs (window, branch) ----------
collect_deploy_runs() {
  local wf_id="$1" page=1 SINCE; SINCE="$(since_ts)"
  while :; do
    local runs; runs="$(api "/repos/${GITHUB_REPOSITORY}/actions/workflows/${wf_id}/runs?per_page=100&page=${page}")" || true
    local arr;  arr="$(jq -cr '.workflow_runs // []' <<<"$runs")"
    local n;    n="$(jq 'length' <<<"$arr")"
    [[ "$n" -eq 0 ]] && break
    # filter window, branch, and success
    local filtered
    filtered="$(jqr --arg b "$MAIN_BRANCH" --arg since "$SINCE" '
      map(select(
        (.head_branch == $b)
        and (.status == "completed")
        and (.conclusion == "success")
        and (.created_at >= $since)
      ))
    ' <<<"$arr")"
    echo "batch_total=${n} filtered=$(jq 'length' <<<"$filtered")" >&2
    # de-dupe by head_sha (keep latest)
    jqr '
      sort_by(.head_sha, (.run_attempt // 1), .run_started_at, .run_number)
      | group_by(.head_sha)
      | map(last)
      | .[]
      | {
          type: "deployment",
          repo: .repository.full_name,
          sha: .head_sha,
          status: (.conclusion // "unknown"),
          finished_at: (.run_completed_at // .updated_at)
        }
    ' <<<"$filtered"
    page=$((page+1))
  done
}

# ---------- optional sink ----------
forward_events() {
  local file="$1"
  [[ -z "${EVENT_SINK_URL:-}" ]] && return 0
  while IFS= read -r line; do
    curl -fsS -H "Content-Type: application/json" -d "$line" "$EVENT_SINK_URL" >/dev/null || true
  done < "$file"
}

# ---------- main ----------
main() {
  assert_env
  : > "$OUT"

  collect_pr_merges >> "$OUT"

  local wf_id; wf_id="$(resolve_workflow_id)"
  collect_deploy_runs "$wf_id" >> "$OUT"

  test -s "$OUT" || die "no events in window"
  jq -s 'length>0' "$OUT" >/dev/null

  forward_events "$OUT"
  echo "wrote $(wc -l < "$OUT") events → $OUT" >&2
}

main "$@"
