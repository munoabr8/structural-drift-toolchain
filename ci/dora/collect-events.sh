#!/usr/bin/env bash
# ci/dora/collect-events.sh
# Collect DORA events (PR merges + successful deploys) into NDJSON, canonical schema.


# CONTRACT-JSON-BEGIN
# {
#   "args": ["[OUT]"],
#   "env": {
#     "SCHEMA": "events/v1",
#     "WINDOW_DAYS": "14",
#     "MAIN_BRANCH": "main",
#     "DEPLOY_SOURCE": "deployments | runs",
#     "DEPLOY_ENV": "prod (used when DEPLOY_SOURCE=deployments)",
#     "DEPLOY_WORKFLOW_NAME": "required when DEPLOY_SOURCE=runs and ID not provided",
#     "DEPLOY_WORKFLOW_ID": "optional override for runs mode",
#     "GITHUB_REPOSITORY": "owner/name (falls back to REPO or git remote)",
#     "REPO": "owner/name fallback if GITHUB_REPOSITORY unset",
#     "EVENT_SINK_URL": "optional HTTP endpoint; each NDJSON line POSTed",
#     "VERBOSE": "1 enables extra diagnostics to stderr",
#     "GH_TOKEN": "used by gh (or GITHUB_TOKEN)"
#   },
#   "reads": "GitHub REST via `gh api` (repo, branches, pulls, deployments, statuses, workflow runs); local git config for remote URL; the OUT file during de-dupe",
#   "writes": [
#     "OUT NDJSON file (truncated then populated; defaults to events.ndjson)",
#     "stderr status lines (WARN/ERR/info)",
#     "optional POSTs to EVENT_SINK_URL (one per event)"
#   ],
#   "tools": ["bash","gh","jq","git","sed","curl","date|gdate","python3","wc","mktemp"],
#   "exit": {
#     "ok": 0,
#     "bad_source": 64,
#     "workflow_name_missing_or_ambiguous": 66,
#     "missing_tool": 70,
#     "generic_error": 1
#   },
#   "emits": {
#     "pr_merged": {
#       "schema": "events/v1",
#       "fields": ["schema","type","repo","pr","head_sha","merge_commit_sha","sha","base_branch","merged_at"]
#     },
#     "deployment": {
#       "schema": "events/v1",
#       "fields": ["schema","type","repo","sha","status","finished_at"]
#     }
#   },
#   "notes": "DEPLOY_SOURCE=deployments uses Deployments API filtered by DEPLOY_ENV; runs mode requires DEPLOY_WORKFLOW_NAME or ID and emits last successful run per head_sha. WINDOW_DAYS limits both PR merges and deploys. De-dupe key: pr|<merge_commit_sha> and dep|<sha>|<finished_at>. Requires GitHub auth for private/repos and higher rate limits."
# }
# CONTRACT-JSON-END


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

emit(){ local j="$1"; echo "$j"; [[ -n "${EVENT_SINK_URL:-}" ]] && curl -fsS -X POST -H 'Content-Type: application/json' --data "$j" "$EVENT_SINK_URL" >/dev/null || true; }

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

 if [[ "${1:-}" == "--probe" ]]; then
  set -euo pipefail
  WF="${DEPLOY_WORKFLOW_NAME:-Deploy}"
  MAIN_BRANCH="${MAIN_BRANCH:-main}"
  echo "WF=$WF MAIN_BRANCH=$MAIN_BRANCH"
  RUNS_JSON="$(gh run list --workflow "$WF" --branch "$MAIN_BRANCH" -L 50 \
    --json databaseId,createdAt,conclusion 2>/dev/null || echo '[]')"
  printf 'RAW:\n%s\n' "$RUNS_JSON"
  echo "jq:type→" ; jq -r 'type' <<<"$RUNS_JSON" || true
  echo "jq:keys(sample)→" ; jq -r '.[0] | keys? // []' <<<"$RUNS_JSON" || true
  echo "jq:try id→" ; jq -r 'try (.[0].id) catch ""' <<<"$RUNS_JSON" || true
  echo "jq:robust RUN_ID→"
  jq -r '
    if type=="array" and length>0 then
      (map(select(.conclusion=="success")) | sort_by(.createdAt) | (last? // {}))
      | (.databaseId? // .id? // "")
    else empty end
  ' <<<"$RUNS_JSON" || true
  exit 0
fi


# ---------- PR merges (lead-time start) ----------
collect_pr_merges() {
  local page=1 SINCE; SINCE="$(since_ts)"
  while :; do
    local data; data="$(api "/repos/${GITHUB_REPOSITORY}/pulls?state=closed&base=${MAIN_BRANCH}&per_page=100&page=${page}")" || die "gh_pr_list_failed"
    local cnt; cnt="$(jq 'length' <<<"$data")"; [[ "$cnt" -eq 0 ]] && break

    # --- diagnostics (optional) ---
    if [[ "${VERBOSE:-0}" == "1" ]]; then
      {
        echo "== page:$page total:$cnt ==" 
        echo "-- closed_not_merged --"
        jq -r '.[] | select(.merged_at==null) | [.number,.state] | @tsv' <<<"$data"
        echo "-- merged_but_no_merge_commit_sha (likely squash) --"
        jq -r '.[] | select(.merged_at!=null and ((.merge_commit_sha//"")=="" )) | [.number,.merged_at, (.head.sha//"") ] | @tsv' <<<"$data"
      } >&2 || true
    fi

    # warn only when merged but no usable sha at all
    local bad; bad="$(jq '[.[] | select(.merged_at!=null and ((.merge_commit_sha//"")=="" and (.head.sha//"")=="" ))] | length' <<<"$data")"
    (( bad==0 )) || warn "pr_merged_missing_sha_unusable:count=${bad}"

    # emit only valid merged PRs since SINCE; accept squash by falling back to head.sha
    jqr --arg since "$SINCE" --arg s "$SCHEMA" '
      .[]
      | select(.merged_at!=null and .merged_at >= $since)
      | .sha = (.merge_commit_sha // .head.sha)
      | select((.sha // "") != "")
      | {
          schema: $s,
          type: "pr_merged",
          repo: .base.repo.full_name,
          pr: .number,
          head_sha: (.head.sha // null),
          merge_commit_sha: (.merge_commit_sha // null),
          sha: .sha,
          base_branch: .base.ref,
          merged_at: .merged_at
        }
    ' <<<"$data"

    page=$((page+1))
  done
}


# ---------- Resolve deploy workflow id (optional "runs" mode) ----------
resolve_workflow_id() {
  # explicit id wins
  if [[ -n "${DEPLOY_WORKFLOW_ID:-}" ]]; then echo "$DEPLOY_WORKFLOW_ID"; return; fi
  [[ -n "${DEPLOY_WORKFLOW_NAME:-}" ]] || die "deploy_workflow_name_or_id_required" 66
  [[ -n "${GITHUB_REPOSITORY:-}" ]] || die "no_repo" 64

  # fetch safely
  local wf_json
  wf_json="$(api "repos/${GITHUB_REPOSITORY}/actions/workflows" \
              -H 'Accept: application/vnd.github+json' 2>/dev/null || echo '{}')"

  # count with guards
  local cnt
  cnt="$(jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '
      if ( .workflows | type ) == "array" then
        [ .workflows[]? | select((.name // "") == $n or (.path // "" | endswith("/" + ($n|gsub(" "; "_" )|ascii_downcase) + ".yml"))) ] | length
      else 0 end
    ' <<<"$wf_json")"

  (( cnt == 1 )) || die "deploy_workflow_name_ambiguous_or_missing:name=${DEPLOY_WORKFLOW_NAME} count=${cnt}" 66

  # extract id safely
  jq -r --arg n "$DEPLOY_WORKFLOW_NAME" '
    if ( .workflows | type ) == "array" then
      ( .workflows[]? | select((.name // "") == $n) | .id // empty )
    else empty end
  ' <<<"$wf_json"
}




# ---------- Deployments API (recommended) ----------
collect_deployments_api2() {
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

collect_deployments_api() {
  need gh; need jq
  local repo; repo="$(resolve_repo)"
  local env="${DEPLOY_ENV:-prod}"
  local since; since="$(since_ts)"

  # paginate deployments in env, then pick last success per ref/sha occurrence
  api --paginate "repos/$repo/deployments?environment=$env&per_page=100" \
  | jq -r --arg since "$since" '
      .[]?
      | . as $d
      | $d | {id:.id, sha:.sha, ref:.ref}
      ' \
  | while read -r line; do
      id="$(jq -r .id <<<"$line")"; sha="$(jq -r .sha <<<"$line")"
      # statuses for each deployment id, keep the latest success within window
      api "repos/$repo/deployments/$id/statuses?per_page=100" \
      | jq -r --arg since "$since" --arg sha "$sha" '
          .[] | select((.state|ascii_downcase)=="success" and (.updated_at >= $since))
          | {sha:$sha, finished_at:.updated_at}
        ' \
      | jq -c --arg repo "$repo" '
          . | {schema:"events/v1",type:"deployment",repo:$repo,sha:.sha,status:"success",finished_at:.finished_at}
        ' \
      | while read -r ev; do emit "$ev"; done
    done
}


# ---------- Deploy runs mode (optional) ----------
collect_deploy_runs2() {
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



collect_deploy_runs() {
  need gh; need jq
  local repo; repo="$(resolve_repo)"
  local since; since="$(since_ts)"

  local wid=""
  if [[ -n "${DEPLOY_WORKFLOW_ID:-}" ]]; then
    wid="$DEPLOY_WORKFLOW_ID"
  else
    [[ -n "${DEPLOY_WORKFLOW_NAME:-}" ]] || { echo "ERR:workflow_name_missing" >&2; exit 66; }
    wid="$(api "repos/$repo/actions/workflows" \
          -q ".workflows[] | select((.name|ascii_downcase)==(\"$DEPLOY_WORKFLOW_NAME\"|ascii_downcase)) | .id" \
          | head -1)"
    [[ -n "$wid" ]] || { echo "ERR:workflow_name_ambiguous_or_not_found" >&2; exit 66; }
  fi

  # paginate all successful runs; emit one event per run within window
  api --paginate "repos/$repo/actions/workflows/$wid/runs?status=success&per_page=100" \
  | jq -r --arg since "$since" '
      .workflow_runs[]?
      | select(.updated_at >= $since)
      | {sha:.head_sha, finished_at:.updated_at}
    ' \
  | jq -c --arg repo "$repo" '
      . | {schema:"events/v1",type:"deployment",repo:$repo,sha:.sha,status:"success",finished_at:.finished_at}
    ' \
  | while read -r ev; do emit "$ev"; done
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
collect_pr_merges            >> "$OUT"   # your existing PR collector
case "${DEPLOY_SOURCE:-runs}" in
  deployments) collect_deployments_api >> "$OUT" ;;
  runs)        collect_deploy_runs     >> "$OUT" ;;
  *)           echo "ERR:bad_source:$DEPLOY_SOURCE" >&2; exit 64 ;;
esac


  test -s "$OUT" || die "no_events_in_window"
  jq -s 'length>0' "$OUT" >/dev/null

  dedupe_file "$OUT"
  forward_events "$OUT"
  echo "wrote $(wc -l < "$OUT") events → $OUT" >&2
}

main "$@"
