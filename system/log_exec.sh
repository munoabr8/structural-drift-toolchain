#!/usr/bin/env bash
#./system/log_exec.sh
# Run a command with start/finish JSON logs; propagate child exit code.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=system/logger.sh
. "$SCRIPT_DIR/logger.sh"

 
now_ms() { python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
}

usage() { printf 'usage: %s <node-name> -- <cmd> [args...]\n' "$(basename "$0")" >&2; exit 64; }
[[ $# -ge 3 && "$2" == "--" ]] || usage
node="$1"; shift 2

ts_start_ms="$(now_ms)"
log_info "start $node"

stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
set +e
"$@" >"$stdout_file" 2>"$stderr_file"
code=$?
set -e

ts_end_ms="$(now_ms)"
dur_ms=$(( ts_end_ms - ts_start_ms ))

##############################
##############################


# stdout_bytes=$(wc -c <"$stdout_file" || echo 0)
# stderr_bytes=$(wc -c <"$stderr_file" || echo 0)

# log_json "SUCCESS" "finish $node" \
#   "dur_ms=$dur_ms; exit=$code; stdout_path=$stdout_file; stdout_bytes=$stdout_bytes; stderr_bytes=$stderr_bytes" \
#   "$code"


##############################
##############################

# stdout_head="$(head -c 4096 "$stdout_file")"
# stderr_head="$(head -c 4096 "$stderr_file")"
# rm -f "$stdout_file" "$stderr_file"

# log_json "SUCCESS" "finish $node" "dur_ms=$dur_ms; exit=$code; stdout_head=$(printf %q "$stdout_head"); stderr_head=$(printf %q "$stderr_head")" "$code"

 stdout_bytes=$(wc -c <"$stdout_file" 2>/dev/null || echo 0)
 stderr_bytes=$(wc -c <"$stderr_file" 2>/dev/null || echo 0)


safe_node="${node//\//__}"   # also handle spaces if needed: safe_node="${safe_node// /_}"

mkdir -p artifacts/stdout artifacts/stderr
out_path="artifacts/stdout/${safe_node}.out"
err_path="artifacts/stderr/${safe_node}.err"
mv "$stdout_file" "$out_path"; stdout_file="$out_path"
mv "$stderr_file" "$err_path";  stderr_file="$err_path"

is_true() { case "${1:-}" in 1|true|TRUE|yes|YES) return 0;; *) return 1;; esac; }

if is_true "${LOG_WRAP_HEAD:-1}"; then
  if is_true "${LOG_INLINE:-0}"; then
    inline() { head -c 4096 "$1" | jq -c . 2>/dev/null || head -c 4096 "$1"; }
    stdout_head="$(inline "$stdout_file")"
    stderr_head="$(inline "$stderr_file")"
    log_json "SUCCESS" "finish $node" \
      "dur_ms=$dur_ms; exit=$code; stdout_head=$(printf %q "$stdout_head"); stderr_head=$(printf %q "$stderr_head"); stdout_bytes=$stdout_bytes; stderr_bytes=$stderr_bytes" \
      "$code"
  else
    log_json "SUCCESS" "finish $node" \
      "dur_ms=$dur_ms; exit=$code; stdout_path=$stdout_file; stdout_bytes=$stdout_bytes; stderr_path=$stderr_file; stderr_bytes=$stderr_bytes" \
      "$code"
  fi
else
  log_json "SUCCESS" "finish $node" "dur_ms=$dur_ms; exit=$code" "$code"
fi



exit "$code"