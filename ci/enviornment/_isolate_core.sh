#!/usr/bin/env bash
# Shared core for environment isolation
set -euo pipefail

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"



snapshot_repo() {
  local ws="$1" mode="${SNAPSHOT_MODE:-head}"
  case "$mode" in
    head)
      git -c core.autocrlf=false archive --format=tar HEAD | tar -C "$ws" -xf -
      ;;
    worktree)
      rsync -a --delete --exclude .git ./ "$ws"/
      ;;
    worktree_tracked)
      # copies tracked files with local edits; excludes junk/untracked
      git ls-files -z | rsync -a --delete --files-from=- --from0 ./ "$ws"/
      ;;
    *)
      echo "ERR: unknown SNAPSHOT_MODE=$mode"; exit 64;;
  esac
}

init_write_marker() {
  local m="${WRITE_MARKER:-.write.marker}"
  : > "$m"; sync -f . 2>/dev/null || true
  WRITE_MARKER="$m"; export WRITE_MARKER

}


assert_writes_confined() {
  local m="${WRITE_MARKER:-.write.marker}"
  [[ -f "$m" ]] || { echo "WARN:no write marker; skipping"; return 0; }

  # emit a list so you can see what's wrong
  local violations
  violations="$(mktemp)"
  # allow only artifacts/ and the three probe files
  find . -type f -newer "$m" \
    ! -path "./artifacts/*" \
    ! -path "./job.log" \
    ! -path "./before.json" \
    ! -path "./after.json" \
    -print >"$violations"

  if [[ -s "$violations" ]]; then
    echo "ERR: unexpected writes"; sed -e 's/^/ - /' "$violations"
    exit 65
  fi
}








probe_env() {
  if [[ -x "$CORE_DIR/probe_env.sh" ]]; then
    "$CORE_DIR/probe_env.sh"
  else
    jq -nc '{schema:"env/probe/v1", tools:{}, path:env.PATH, lock:"no"}'
  fi
}

 
 
scrub_env(){
  local allow="${ALLOWLIST:-PATH HOME WS PWD SHELL SHLVL LC_ALL SOURCE_DATE_EPOCH CI GH_TOKEN TERM _ GITHUB_*}"
  while IFS='=' read -r k _; do
case "$k" in
  GITHUB_*) [[ "$allow" == *GITHUB_* ]] && continue ;;
esac

    [[ " $allow " =~ (^|[[:space:]])"$k"($|[[:space:]]) ]] || unset "$k" 2>/dev/null || true
  done < <(env)
  hash -r
}

# --- reproducibility toggles ---
export LC_ALL=C
export TZ=UTC
: "${SOURCE_DATE_EPOCH:=$(git log -1 --format=%ct 2>/dev/null || date -u +%s)}"
export SOURCE_DATE_EPOCH
 

run_step(){ local cmd="${1:-}"; [[ -n "$cmd" ]] && bash --noprofile --norc -lc "$cmd"; }



assert_min_env() {
  local allow="${ALLOWLIST:-PATH HOME WS PWD SHELL SHLVL LC_ALL SOURCE_DATE_EPOCH CI GH_TOKEN TERM _}"
  local re="^($(printf '%s' "$allow" | tr ' ' '|'))$"
  env | awk -F= '{print $1}' | grep -vE "$re" | grep -q . && { echo "ERR: extra env vars"; exit 66; } || true
}



assert_tools(){ command -v bash jq git >/dev/null || exit 70; }
assert_locale(){ test "${LC_ALL:-}" = "C" || exit 71; }
assert_umask(){ test "$(umask)" = "0022" || exit 72; }
assert_lock(){ jq -e '.lock=="yes"' before.json >/dev/null || echo "WARN:no lockfile"; }
assert_probe_schema(){ jq -e '.schema=="env/probe/v1"' before.json >/dev/null || exit 73; }


