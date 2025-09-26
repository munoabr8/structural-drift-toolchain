#!/usr/bin/env bash
set -euo pipefail; export LC_ALL=C
die(){ echo "ERR:$*" >&2; exit 2; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing:$1"; }

# Inputs (override via env)
: "${WINDOW_DAYS:=14}"
: "${MAIN_BRANCH:=main}"
: "${REPO:?set REPO like owner/repo}"
: "${DEPLOY_WORKFLOW_ID:?set DEPLOY_WORKFLOW_ID}"


need gh; need jq; need date

log(){ printf '%s %s\n' "[$(date -u +%FT%TZ)]" "$*" >&2; }

owner_repo(){
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
  || git remote -v | awk '/origin.*github/ {print $2}' | sed -E 's#.*github.com[:/]|\.git$##' | head -n1
}

REPO="$(owner_repo)"; [[ -n "$REPO" ]] || die "cannot_resolve_repo"

log "repo=$REPO WIN=$WINDOW_DAYS MAIN=$MAIN_BRANCH DWN='$DEPLOY_WORKFLOW_NAME' DWI='$DEPLOY_WORKFLOW_ID'"

# Resolve workflow id if only name given
if [[ -z "${DEPLOY_WORKFLOW_ID:-}" ]]; then
  if [[ -n "${DEPLOY_WORKFLOW_NAME:-}" ]]; then
    DEPLOY_WORKFLOW_ID="$(gh api "repos/$REPO/actions/workflows" \
      -q --arg n "$DEPLOY_WORKFLOW_NAME" '.workflows[]|select(.name==$n)|.id' | head -n1 || true)"
  fi
fi
if [[ -z "${DEPLOY_WORKFLOW_ID:-}" ]]; then
  log "available workflows:" 
  gh api "repos/$REPO/actions/workflows" -q '.workflows[]|{name,id,path}' | jq -c .
  die "deploy_workflow_unresolved"
fi
log "resolved deploy_workflow_id=$DEPLOY_WORKFLOW_ID"

# Sanity: any successful runs in window?
SINCE="$(date -u -v-"$WINDOW_DAYS"d +%FT%TZ 2>/dev/null || python3 - <<'PY'
import datetime;print((datetime.datetime.utcnow()-datetime.timedelta(days=int(__import__("os").environ.get("WINDOW_DAYS","14")))).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
log "since=$SINCE"

runs_json="$(gh api "repos/$REPO/actions/workflows/$DEPLOY_WORKFLOW_ID/runs?status=success&per_page=100" --paginate)"
count="$(jq '[.workflow_runs[] | select(.updated_at >= "'"$SINCE"'")] | length' <<<"$runs_json")"
log "successful_deploy_runs_in_window=$count"
[[ "$count" -gt 0 ]] || die "no_deploy_runs_in_window"

# Emit 1 sample line in events schema to verify downstream wiring
sha="$(jq -r '[.workflow_runs[]|select(.updated_at >= "'"$SINCE"'")|.head_sha][0] // empty' <<<"$runs_json")"
fin="$(jq -r  '[.workflow_runs[]|select(.updated_at >= "'"$SINCE"'")|.updated_at][0] // empty' <<<"$runs_json")"
[[ -n "$sha" && -n "$fin" ]] || die "deploy_sample_unavailable"
jq -c -n --arg s "events/v1" --arg r "$REPO" --arg sha "$sha" --arg fin "$fin" \
  '{schema:$s,type:"deployment",repo:$r,sha:$sha,status:"success",finished_at:$fin}'
