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
    local data; data="$(api "/repos/${GITHUB_REPOSITORY}/pulls?state=closed&base=${MAIN_BRANCH}&per_page=100&page=${page}")" || die "gh_pr_list_failed"
    local cnt; cnt="$(jq 'length' <<<"$data")"; [[ "$cnt" -eq 0 ]] && break
    # warn on bad PRs, but DO NOT emit them
    local bad; bad="$(jq '[.[] | select(.merged_at==null or (.merge_commit_sha//"")=="" )] | length' <<<"$data")"
    (( bad==0 )) || warn "pr_merged_missing_sha_or_time:count=${bad}"

    jqr --arg since "$SINCE" '
      .[]
      | select(.merged_at!=null and (.merge_commit_sha//"")!="" and .merged_at >= $since)
      | {
          type: "pr_merged",
          repo: .base.repo.full_name,
          pr: .number,
          sha: .merge_commit_sha,
          merged_at: .merged_at
        }
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
#   collect_deploy_runs() {
#   local wf_id="$1" page=1 SINCE; SINCE="$(since_ts)"
#   while :; do
#     local runs; runs="$(api "/repos/${GITHUB_REPOSITORY}/actions/workflows/${wf_id}/runs?per_page=100&page=${page}")" || true
#     local arr;  arr="$(jq -cr '.workflow_runs // []' <<<"$runs")"
#     local n;    n="$(jq 'length' <<<"$arr")"
#     [[ "$n" -eq 0 ]] && break

#     # window by run_started_at (fallback: created_at), main branch, success
#     local filtered
#     filtered="$(jqr --arg b "$MAIN_BRANCH" --arg since "$SINCE" '
#       map(select(
#         (.head_branch == $b)
#         and (.status == "completed")
#         and (.conclusion == "success")
#         and ((.run_started_at // .created_at) >= $since)
#       ))
#     ' <<<"$arr")"

#     echo "batch_total=${n} filtered=$(jq 'length' <<<"$filtered")" >&2

#     # de-dupe by head_sha (keep latest run)
#     jqr '
#       sort_by(.head_sha, (.run_attempt // 1), .run_started_at, .run_number)
#       | group_by(.head_sha)
#       | map(last)
#       | .[]
#       | {
#           type: "deployment",
#           repo: .repository.full_name,
#           sha: .head_sha,
#           status: (.conclusion // "unknown"),
#           finished_at: (.run_completed_at // .updated_at // .created_at)
#         }
#     ' <<<"$filtered"

#     page=$((page+1))
#   done
# }

collect_deployments_api() {
  local page=1 SINCE; SINCE="$(since_ts)"
  local ENV="${DEPLOY_ENV:-prod}"
  while :; do
    local data; data="$(api "/repos/${GITHUB_REPOSITORY}/deployments?environment=${ENV}&per_page=100&page=${page}")" || break
    local n; n="$(jq 'length' <<<"$data")"; [[ "$n" -eq 0 ]] && break

    # For each deployment, fetch latest success status and emit a deployment event
    while read -r dep; do
      local id sha created
      id="$(jq -r '.id' <<<"$dep")"
      sha="$(jq -r '.sha' <<<"$dep")"
      created="$(jq -r '.created_at' <<<"$dep")"
      [[ -z "$sha" || -z "$created" || "$created" < "$SINCE" ]] && continue

      # latest success status (if any)
      local st
      st="$(api "/repos/${GITHUB_REPOSITORY}/deployments/${id}/statuses?per_page=100" \
            | jq -c '[.[] | select(.state=="success")] | sort_by(.created_at) | last // empty')" || true
      [[ -z "$st" || "$st" == "null" ]] && continue

      local fin; fin="$(jq -r '.created_at // .updated_at' <<<"$st")"
      jq -n --arg repo "$GITHUB_REPOSITORY" --arg sha "$sha" --arg fin "$fin" '
        {type:"deployment", repo:$repo, sha:$sha, status:"success", finished_at:$fin}'
    done < <(jq -c '.[]' <<<"$data")

    page=$((page+1))
  done
}





_date(){
  if command -v gdate >/dev/null 2>&1; then gdate "$@"
  else date "$@"
  fi
}

utc_now(){ _date -u +%Y-%m-%dT%H:%M:%SZ; }

since_ts(){  # N days ago in UTC ISO8601
  local days="${WINDOW_DAYS:-14}"
  if _date -u -d '1 day ago' +%s >/dev/null 2>&1; then
    _date -u -d "${days} days ago" +%FT%TZ        # GNU date
  elif _date -u -v-1d +%s >/dev/null 2>&1; then
    _date -u -v-"${days}"d +%FT%TZ                # BSD date
  else
    python3 - <<'PY'                               # Python fallback
import os,datetime
days=int(os.environ.get("WINDOW_DAYS","14"))
print((datetime.datetime.utcnow()-datetime.timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
  fi
}

to_epoch(){  # ISO8601 Z → epoch seconds
  local ts="$1"
  if _date -u -d "$ts" +%s >/dev/null 2>&1; then
    _date -u -d "$ts" +%s                          # GNU
  elif _date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s >/dev/null 2>&1; then
    _date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s  # BSD
  else
    python3 - "$ts" <<'PY'                          # Python
import sys,datetime
ts=sys.argv[1]
dt=datetime.datetime.strptime(ts,"%Y-%m-%dT%H:%M:%SZ")
print(int(dt.replace(tzinfo=datetime.timezone.utc).timestamp()))
PY
  fi
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

  case "${DEPLOY_SOURCE:-deployments}" in
    deployments)
      collect_deployments_api >> "$OUT"
      ;;
    runs)
      local wf_id; wf_id="$(resolve_workflow_id)"
      collect_deploy_runs "$wf_id" >> "$OUT"
      ;;
    *)
      die "bad DEPLOY_SOURCE:${DEPLOY_SOURCE}" 64
      ;;
  esac

  test -s "$OUT" || die "no events in window"
  jq -s 'length>0' "$OUT" >/dev/null

  forward_events "$OUT"
  echo "wrote $(wc -l < "$OUT") events → $OUT" >&2
}

main "$@"
