#!/usr/bin/env bash
#./system/log_exec.sh
# Run a command with start/finish JSON logs; propagate child exit code.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=system/logger.sh
. "$SCRIPT_DIR/logger.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=system/names.sh
. "$SCRIPT_DIR/../system/names.sh"


# ---------- helpers ----------
now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

is_true()     { case "${1:-}" in 1|true|TRUE|yes|YES) return 0;; *) return 1;; esac; }

 

emit_finish_path() {
  local base out_path err_path
  base="$(safe_name "$node")"               # <- use new safe_name
  out_path="${STD_DIR}/${base}.out"
  err_path="${ERR_DIR}/${base}.err"
  mv -f "$stdout_tmp" "$out_path"
  mv -f "$stderr_tmp" "$err_path"
  local sb eb
  sb=$(wc -c <"$out_path" 2>/dev/null || echo 0)
  eb=$(wc -c <"$err_path" 2>/dev/null || echo 0)
  log_json "SUCCESS" "finish $node" \
    "dur_ms=$dur_ms; exit=$code; stdout_path=$out_path; stdout_bytes=$sb; stderr_path=$err_path; stderr_bytes=$eb" \
    "$code"
}

ensure_dirs() { mkdir -p "${STD_DIR}" "${ERR_DIR}"; }

capture_run() {
  stdout_tmp="$(mktemp)"; stderr_tmp="$(mktemp)"
  set +e; "$@" >"$stdout_tmp" 2>"$stderr_tmp"; code=$?; set -e
}

 

 

emit_finish_head() {
  local sh eh
  sh="$(head -c 4096 "$stdout_tmp")"
  eh="$(head -c 4096 "$stderr_tmp")"
  log_json "SUCCESS" "finish $node" "dur_ms=$dur_ms; exit=$code; stdout_head=$(printf %q "$sh"); stderr_head=$(printf %q "$eh")" "$code"
  rm -f "$stdout_tmp" "$stderr_tmp"
}





# ---------- config ----------
STD_DIR="${STD_DIR:-artifacts/stdout}"
ERR_DIR="${ERR_DIR:-artifacts/stderr}"
MODE="${LOG_STD_MODE:-path}"   # path|head


# ---------- cli ----------
usage() { printf 'usage: %s <node-name> -- <cmd> [args...]\n' "$(basename "$0")" >&2; exit 64; }
[[ $# -ge 3 && "$2" == "--" ]] || usage
node="$1"; shift 2

# ---------- run ----------
ensure_dirs
ts_start_ms="$(now_ms)"
log_info "start $node"

capture_run "$@"

ts_end_ms="$(now_ms)"
dur_ms=$(( ts_end_ms - ts_start_ms ))

if [ "$MODE" = "path" ]; then
  emit_finish_path
elif is_true "${LOG_WRAP_HEAD:-0}"; then
  emit_finish_head
else
  log_json "SUCCESS" "finish $node" "dur_ms=$dur_ms; exit=$code" "$code"
  rm -f "$stdout_tmp" "$stderr_tmp"
fi

exit "$code"


