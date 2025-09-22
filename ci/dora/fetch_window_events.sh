#!/usr/bin/env bash
# ci/dora/fetch_window_events.sh
# Fetch Deploy artifacts within WINDOW_DAYS and merge their events.ndjson into EVENTS.

set -euo pipefail
export LC_ALL=C

# ---------------- config ----------------
REPO="${REPO:-}"
DEPLOY_WF="${DEPLOY_WF:-Deploy}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
WINDOW_DAYS="${WINDOW_DAYS:-14}"
ARTDIR="${ARTDIR:-artifacts}"
EVENTS="${EVENTS:-ci/dora/events.ndjson}"
ARTNAME="${ARTNAME:-events-ndjson}"   # expected artifact name

# ---------------- deps ------------------
need(){ command -v "$1" >/dev/null 2>&1 || { echo "ERR: missing $1" >&2; exit 70; }; }
need gh; need jq; need python3; need awk; need find

# ============================================================
#                    Q U E R I E S   A P I
# ============================================================

# Resolve repo slug "owner/name"
q_repo() {
  if [[ -n "$REPO" ]]; then printf '%s\n' "$REPO"; return; fi
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true
}

# Compute ISO8601 UTC since-ts for WINDOW_DAYS
q_since_ts() {
  python3 - <<'PY'
from datetime import datetime, timedelta, timezone
import os
d = int(os.getenv("WINDOW_DAYS","14"))
print((datetime.now(timezone.utc)-timedelta(days=d)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
}

# List successful Deploy run IDs since ts
q_list_run_ids_since() {
  local repo="$1" since="$2"
  gh run list --repo "$repo" --workflow "$DEPLOY_WF" --branch "$MAIN_BRANCH" -L 200 \
    --json databaseId,conclusion,createdAt \
  | jq -r --arg since "$since" '
      map(select(.conclusion=="success" and .createdAt >= $since))
      | sort_by(.createdAt) | .[].databaseId'
}

# Does a run have the desired artifact?
q_run_has_artifact() {
  local repo="$1" run_id="$2" name="$3"
  gh api "repos/$repo/actions/runs/$run_id/artifacts" \
    -q '.artifacts[]? | select(.name=="'"$name"'") | .id' 2>/dev/null || true
}

# Download one run’s artifact(s) into dir
q_download_run_artifacts() {
  local repo="$1" run_id="$2" name="$3" dest="$4"
  if [[ -n "$name" ]]; then
    gh run download "$run_id" --repo "$repo" -n "$name" -D "$dest" 2>/dev/null || true
  else
    gh run download "$run_id" --repo "$repo" -D "$dest" 2>/dev/null || true
  fi
}

# ============================================================
#                         L O G I C
# ============================================================

die(){ echo "ERR:$*" >&2; exit "${2:-2}"; }

main() {
  REPO="$(q_repo)"; [[ -n "$REPO" ]] || die "REPO unresolved; set REPO or run inside GH repo" 64
  local since; since="$(q_since_ts)"

  # runs in window
  local ids; ids="$(q_list_run_ids_since "$REPO" "$since")"
  [[ -n "$ids" ]] || die "no successful $DEPLOY_WF runs on $MAIN_BRANCH since $since" 64

  # filter to runs that actually expose the artifact
  local kept=()
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if [[ -n "$(q_run_has_artifact "$REPO" "$id" "$ARTNAME")" ]]; then
      kept+=("$id")
    fi
  done <<<"$ids"

  (( ${#kept[@]} > 0 )) || die "no runs with artifact '$ARTNAME' since $since" 64

  # prepare sinks
  install -d "$(dirname "$EVENTS")" "$ARTDIR"
  : > "$EVENTS"

  # fetch + merge
  local ok=0
  for id in "${kept[@]}"; do
    local dir="$ARTDIR/run-$id"
    rm -rf "$dir"; mkdir -p "$dir"
    q_download_run_artifacts "$REPO" "$id" "$ARTNAME" "$dir"
    local f; f="$(find "$dir" -type f -name 'events.ndjson' -print -quit || true)"
    if [[ -z "$f" ]]; then
      echo "WARN: run $id lists '$ARTNAME' but no events.ndjson after download" >&2
      continue
    fi
    awk 'NF' "$f" >> "$EVENTS"
    ok=$((ok+1))
  done

  [[ -s "$EVENTS" ]] || die "no valid artifacts contained events.ndjson" 65

  jq -s '{pr:map(select(.type=="pr_merged"))|length, dep:map(select(.type=="deployment"))|length}' "$EVENTS"
  echo "OK: merged $ok run(s) into $EVENTS"
}

main "$@"
