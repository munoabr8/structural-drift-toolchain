#!/usr/bin/env bash
# ci/dora/collect-events2.sh


set -euo pipefail
export LC_ALL=C

# ------------ config ------------
OUT="${OUT:-events.ndjson}"
SCHEMA="${SCHEMA:-events/v1}"

# ------------ utils -------------
die(){ echo "ERR:$*" >&2; exit "${2:-2}"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing:$1" 70; }
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
req(){ local v="${!1:-}"; [[ -n "$v" ]] || die "missing:$1"; }
api(){ gh api "$@" 2>/dev/null; }

# ------------ repo resolve -------
resolve_repo() {
  need gh; need jq; need sed; need awk; need git || true
  if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
    GITHUB_REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
    if [[ -z "$GITHUB_REPOSITORY" ]]; then
      local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
      [[ -n "$url" ]] && GITHUB_REPOSITORY="$(sed -E 's#(git@|https://)([^/:]+)[:/](.+)(\.git)?#\3#; s#/*$##' <<<"$url")"
    fi
  fi
  [[ -n "${GITHUB_REPOSITORY:-}" ]] || die "repo_unresolved"
  # sanity (404 means bad slug or no access)
  api "repos/${GITHUB_REPOSITORY}" -q .id >/dev/null || die "repo_not_found:${GITHUB_REPOSITORY}"
}

# ------------ validators ----------
jq_pr='
  .type=="pr_merged"
  and .schema==$s
  and (.pr|type=="number")
  and (.head_sha|test("^[0-9a-f]{40}$"))
  and (.merge_commit_sha|test("^[0-9a-f]{40}$"))
  and (.base_branch|type=="string")
  and (.merged_at|test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$"))
'
jq_dep='
  .type=="deployment"
  and .schema==$s
  and (.sha|test("^[0-9a-f]{40}$"))
  and (.status|IN("success","failure","failed","cancelled","canceled"))
  and (.finished_at|test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$"))
'

# ------------ sink ---------------
append() {
  local json="$1" pred="$2"
  echo "$json" | jq -e . >/dev/null || die "invalid_json"
  echo "$json" | jq -e --arg s "$SCHEMA" "$pred" >/dev/null || die "contract_failed"

  # de-dupe against last 200 lines
  if [[ -f "$OUT" ]]; then
    if jq -e --argjson j "$json" '
      def eqstr(a;b): (a//"")==(b//"");
      inputs as $line
      | ($line|fromjson? // empty) as $x
      | if ($j.type=="deployment")
          then ($x.type=="deployment") and eqstr($x.sha; $j.sha) and eqstr($x.finished_at; $j.finished_at)
          else if ($j.type=="pr_merged")
            then ($x.type=="pr_merged") and ((eqstr($x.merge_commit_sha; $j.merge_commit_sha)) or ($x.pr==$j.pr))
            else false end
        end
      ' < <(tail -n200 "$OUT") >/dev/null; then
      return 0
    fi
  fi

  # simple mkdir lock
  local lock="${OUT}.lockdir"
  for _ in $(seq 1 100); do
    if mkdir "$lock" 2>/dev/null; then
      trap 'rmdir "$lock"' EXIT
      printf '%s\n' "$json" >> "$OUT"
      rmdir "$lock"; trap - EXIT
      return 0
    fi
    sleep 0.1
  done
  die "lock_timeout"
}

# ------------ emitters -----------
emit_deployment(){
  req DEPLOY_SHA; req DEPLOY_STATUS
  local finished="${DEPLOY_FINISHED_AT:-$(ts)}"
  local j
  j=$(jq -c -n --arg s "$SCHEMA" --arg sha "$DEPLOY_SHA" --arg st "$DEPLOY_STATUS" --arg at "$finished" '
        {schema:$s,type:"deployment",sha:$sha,status:($st|ascii_downcase),finished_at:$at}')
  append "$j" "$jq_dep"
}

emit_pr_merged(){
  # Either envs are pre-set, or we resolved them already.
  req PR_NUMBER; req PR_HEAD_SHA; req PR_MERGE_SHA; req PR_BASE; req PR_MERGED_AT
  local j
  j=$(jq -c -n --arg s "$SCHEMA" --arg pr "$PR_NUMBER" \
        --arg head "$PR_HEAD_SHA" --arg merge "$PR_MERGE_SHA" \
        --arg base "$PR_BASE" --arg at "$PR_MERGED_AT" '
        {schema:$s,type:"pr_merged",
         pr:($pr|tonumber),
         head_sha:$head,merge_commit_sha:$merge,
         base_branch:$base,merged_at:$at}')
  append "$j" "$jq_pr"
}

# --------- resolvers -------------
resolve_pr_env_from_api() {
  local n="$1"
  [[ "$n" =~ ^[0-9]+$ ]] || die "bad_pr_number:$n" 64
  local pr; pr="$(api "/repos/$GITHUB_REPOSITORY/pulls/$n")" || die "pr_fetch_failed:$n"
  export PR_NUMBER="$n"
  export PR_HEAD_SHA="$(jq -r '.head.sha' <<<"$pr")"
  export PR_MERGE_SHA="$(jq -r '.merge_commit_sha' <<<"$pr")"
  export PR_BASE="$(jq -r '.base.ref' <<<"$pr")"
  export PR_MERGED_AT="$(jq -r '.merged_at' <<<"$pr")"
  if [[ "${TEST_MODE:-0}" != "1" ]]; then
    [[ "$PR_MERGED_AT" != "null" && -n "$PR_MERGE_SHA" ]] || die "pr_not_merged:$n"
  fi
}

maybe_resolve_pr_from_event() {
  # For Actions: read number from event payload if not given as arg
  if [[ -z "${PR_NUMBER:-}" && -n "${GITHUB_EVENT_PATH:-}" && -f "$GITHUB_EVENT_PATH" ]]; then
    PR_NUMBER="$(jq -r '(.number // .pull_request.number) // empty' "$GITHUB_EVENT_PATH")" || true
    export PR_NUMBER
  fi
}

# -------------- main -------------
resolve_repo

case "${1:-}" in
  pr-merged)
    maybe_resolve_pr_from_event
    if [[ -n "${2:-}" ]]; then
      resolve_pr_env_from_api "$2"
    elif [[ -n "${PR_NUMBER:-}" && -z "${PR_HEAD_SHA:-}" ]]; then
      resolve_pr_env_from_api "$PR_NUMBER"
    fi
    emit_pr_merged
    ;;
  deployment)
    emit_deployment
    ;;
  *)
    die "usage: $0 {pr-merged [PR_NUMBER]|deployment}" 64
    ;;
esac
