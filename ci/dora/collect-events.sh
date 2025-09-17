#!/usr/bin/env bash
# ci/dora/collect-events.sh
# Collect DORA events (PR merges + successful deploys) into NDJSON, canonical schema.

set -euo pipefail
export LC_ALL=C

# ---------- config ----------
OUT="${1:-events.ndjson}"
SCHEMA="${SCHEMA:-events/v1}"
WINDOW_DAYS="${WINDOW_DAYS:-14}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"              # fallback; auto-detected if missing on repo
DEPLOY_WORKFLOW_NAME="${DEPLOY_WORKFLOW_NAME:-}"   # optional if using runs mode
DEPLOY_WORKFLOW_ID="${DEPLOY_WORKFLOW_ID:-}"
DEPLOY_SOURCE="${DEPLOY_SOURCE:-deployments}"  # deployments|runs
DEPLOY_ENV="${DEPLOY_ENV:-prod}"

# ---------- utils ----------
die()  { echo "ERR:$*" >&2; exit "${2:-1}"; }
warn() { echo "WARN:$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing:$1" 70; }
api()  { gh api "$@" 2>/dev/null; }             # quiet gh wrapper
jqr()  { jq -cr "$@"; }

# ---------- repo/branch resolve (robust) ----------
resolve_repo() {
  need gh; need jq
  # Prefer env override, else gh, else git remote
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-${REPO:-}}"
  if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
    GITHUB_REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
    if [[ -z "$GITHUB_REPOSITORY" ]]; then
      need git; need sed
      local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
      [[ -n "$url" ]] && GITHUB_REPOSITORY="$(sed -E 's#(git@|https://)([^/:]+)[:/](.+?)(\.git)?$#\3#; s#/*$##' <<<"$url")"
    fi
  fi
  [[ -n "$GITHUB_REPOSITORY" ]] || die "repo_unresolved"
  api "repos/${GITHUB_REPOSITORY}" -q .id >/dev/null || die "repo_not_found:${GITHUB_REPOSITORY}"

  # Branch: use provided MAIN_BRANCH if it exists, else default_branch
  if ! api "repos/${GITHUB_REPOSITORY}/branches/${MAIN_BRANCH}" -q .name >/dev/null; then
    MAIN_BRANCH="$(api "repos/${GITHUB_REPOSITORY}" -q .default_branch)"
    api "repos/${GITHUB_REPOSITORY}/branches/${MAIN_BRANCH}" -q .name >/dev/null \
      || die "main_branch_missing:${MAIN_BRANCH}"
  fi
}

# ---------- rate limit check ----------
assert_env() {
  need date; need jq; resolve_repo
  local rem; rem="$(api rate_limit -q '.resources.core.remaining' || echo 0)"
  (( rem>5 )) || die "rate_limit_low:${rem}"
}

# ---------- time helpers ----------
_date(){
  if command -v gdate >/dev/null 2>&1; then gdate "$@"; else date "$@"; fi
}
utc_now(){ _date -u +%Y-%m-%dT%H:%M:%SZ; }
since_ts(){  # N days ago in UTC ISO8601
  local days="$WINDOW_DAYS"
  if _date -u -d '1 day ago' +%s >/dev/null 2>&1; then
    _date -u -d "${days} days ago" +%FT%TZ        # GNU
  elif _date -u -v-1d +%s >/dev/null 2>&1; then
    _date -u -v-"${days}"d +%FT%TZ                # BSD
  else
    python3 - <<'PY'
import os,datetime
d=int(os.environ.get("WINDOW_DAYS","14"))
print((datetime.datetime.utcnow()-datetime.timedelta(days=d)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
  fi
}

# ---------- PR merges (lead-time start) ----------
collect_pr_merges() {
  local page=1 SINCE; SINCE="$(since_ts)"
  while :; do
    local data; data="$(api "/repos/${GITHUB_REPOSITORY}/pulls?state=closed&base=${MAIN_BRANCH}&per_page=100&page=${page}")" || die "gh_pr_list_failed"
    local cnt; cnt="$(jq 'length' <<<"$data")"; [[ "$cnt" -eq 0 ]] && break
    local bad; bad="$(jq '[.[] | select(.merged_at==null or (.merge_commit_sha//"")=="" )] | length' <<<"$data")"
    (( bad==0 )) || warn "pr_merged_missing_sha_or_time:count=${bad}"

    jqr --arg since "$SINCE" --arg s "$SCHEMA" '
      .[]
      | select(.merged_at!=null and (.merge_commit_sha//"")!="" and .merged_at >= $since)
      | {
          schema: $s,
          type: "pr_merged",
          repo: .base.repo.full_name,
          pr: .number,
          head_sha: (.head.sha // null),
          merge_commit_sha: .merge_commit_sha,
          base_branch: .base.ref,
          merged_at: .merged_at
        }
    ' <<<"$data"
    page=$((page+1))
  done
}

# ---------- Resolve deploy workflow id (optional "runs" mode) ----------
resolve_workflow_id() {
  if [[ -n "$DEPLOY_WORKFLOW_ID" ]]; then echo "$DEPLOY_WORKFLOW_ID"; return; fi
  [[ -n "$DEPLOY_WORKFLOW_NAME" ]] || die "deploy_workflow_name_or_id_required" 66
  local wf_json; wf_json="$(api "/repos/${GITHUB_REPOSITORY}/actions/workflows")"
  local cnt; cnt="$(jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '[.workflows[]|select(.name==$n)]|length' <<<"$wf_json")"
  (( cnt==1 )) || die "deploy_workflow_name_ambiguous_or_missing:name=${DEPLOY_WORKFLOW_NAME} count=${cnt}" 66
  jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '.workflows[]|select(.name==$n)|.id' <<<"$wf_json"
}

# ---------- Deployments API (recommended) ----------
collect_deployments_api() {
  local page=1 SINCE; SINCE="$(since_ts)"
  while :; do
    local data; data="$(api "/repos/${GITHUB_REPOSITORY}/deployments?environment=${DEPLOY_ENV}&per_page=100&page=${page}")" || break
    local n; n="$(jq 'length' <<<"$data")"; [[ "$n" -eq 0 ]] && break

    while read -r dep; do
      local id sha created
      id="$(jq -r '.id' <<<"$dep")"
      sha="$(jq -r '.sha' <<<"$dep")"
      created="$(jq -r '.created_at' <<<"$dep")"
      [[ -z "$sha" || -z "$created" || "$created" < "$SINCE" ]] && continue

      local st
      st="$(api "/repos/${GITHUB_REPOSITORY}/deployments/${id}/statuses?per_page=100" \
            | jq -c '[.[] | select(.state=="success")] | sort_by(.created_at) | last // empty')" || true
      [[ -z "$st" || "$st" == "null" ]] && continue

      local fin; fin="$(jq -r '.created_at // .updated_at' <<<"$st")"
      jq -n --arg s "$SCHEMA" --arg repo "$GITHUB_REPOSITORY" --arg sha "$sha" --arg fin "$fin" '
        {schema:$s,type:"deployment",repo:$repo,sha:$sha,status:"success",finished_at:$fin}'
    done < <(jq -c '.[]' <<<"$data")

    page=$((page+1))
  done
}

# ---------- Deploy runs mode (optional) ----------
collect_deploy_runs() {
  local wf_id="$1" page=1 SINCE; SINCE="$(since_ts)"
  while :; do
    local runs; runs="$(api "/repos/${GITHUB_REPOSITORY}/actions/workflows/${wf_id}/runs?per_page=100&page=${page}")" || true
    local arr;  arr="$(jq -cr '.workflow_runs // []' <<<"$runs")"
    local n;    n="$(jq 'length' <<<"$arr")"
    [[ "$n" -eq 0 ]] && break

    local filtered
    filtered="$(jqr --arg b "$MAIN_BRANCH" --arg since "$SINCE" '
      map(select(
        (.head_branch == $b)
        and (.status == "completed")
        and (.conclusion == "success")
        and ((.run_started_at // .created_at) >= $since)
      ))
    ' <<<"$arr")"

    jqr --arg s "$SCHEMA" '
      sort_by(.head_sha, (.run_attempt // 1), .run_started_at, .run_number)
      | group_by(.head_sha)
      | map(last)
      | .[]
      | {
          schema: $s,
          type: "deployment",
          repo: .repository.full_name,
          sha: .head_sha,
          status: (.conclusion // "unknown"),
          finished_at: (.run_completed_at // .updated_at // .created_at)
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

# ---------- de-dupe ----------
dedupe_file() {
  local f="$1"
  local tmp
  tmp="$(mktemp)" || die "mktemp_failed"
  jq -s -c '
    def key(x):
      if x.type=="pr_merged"   then "pr|"  + (x.merge_commit_sha//"")
      elif x.type=="deployment" then "dep|" + (x.sha//"") + "|" + (x.finished_at//"")
      else tostring end;
    map(.) | unique_by(key(.)) | .[]
  ' "$f" >"$tmp" && mv "$tmp" "$f"
  rm -f "$tmp" 2>/dev/null || true
}

# ---------- main ----------
main() {
  assert_env
  : > "$OUT"

  collect_pr_merges >> "$OUT"

  case "$DEPLOY_SOURCE" in
    deployments) collect_deployments_api >> "$OUT" ;;
    runs)
      local wf_id; wf_id="$(resolve_workflow_id)"
      collect_deploy_runs "$wf_id" >> "$OUT"
      ;;
    *) die "bad DEPLOY_SOURCE:${DEPLOY_SOURCE}" 64 ;;
  esac

  test -s "$OUT" || die "no_events_in_window"
  jq -s 'length>0' "$OUT" >/dev/null

  dedupe_file "$OUT"
  forward_events "$OUT"
  echo "wrote $(wc -l < "$OUT") events → $OUT" >&2
}

main "$@"
