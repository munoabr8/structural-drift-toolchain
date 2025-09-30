# --- at top: library-only guard ---
# Usage: source this file; never exits the shell
# Emits NDJSON to stderr; also appends to $LOG_OUTPUT_FILE if set.

log_json() {
  (( $# >= 2 )) || { printf 'log_json: need LEVEL MESSAGE\n' >&2; return 99; }
  local level="$1" message="$2" detail="${3:-}" err="${4:-}" code="${5:-}"
  case "$level" in INFO|ERROR|FATAL|SUCCESS) ;; *) printf 'log_json: bad level %s\n' "$level" >&2; return 98;; esac
  [[ "${QUIET:-false}" == "true" && "$level" != "ERROR" && "$level" != "FATAL" ]] && return 0

  json_escape() { local s=$1; s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}; printf '%s' "$s"; }

local ts; ts="$(date -u +'%Y-%m-%dT%H:%M:%S.%3NZ')"

  local j='{"timestamp":"'"$(json_escape "$ts")"'","level":"'"$level"'","message":"'"$(json_escape "$message")"'"'
  [[ -n "$detail" ]] && j+=',"detail":"'"$(json_escape "$detail")"'"'
  [[ -n "$err"    ]] && j+=',"error_code":"'"$(json_escape "$err")"'"'
  [[ -n "$code"   ]] && j+=',"exit_code":"'"$(json_escape "$code")"'"'
  j+=',"pid":'"$$"'}'

  # stderr only; optional append to file (no tee)
  printf '%s\n' "$j" >&2
  if [[ -n "${LOG_OUTPUT_FILE:-}" ]]; then
    umask 077; : >>"$LOG_OUTPUT_FILE" || { printf 'log_json: cannot write %s\n' "$LOG_OUTPUT_FILE" >&2; return 64; }
    printf '%s\n' "$j" >>"$LOG_OUTPUT_FILE"
  fi
}

log_success() { log_json "SUCCESS" "$1" "" "0"; }
log_info()    { log_json "INFO"    "$1" "" "0"; }
log_error()   { log_json "ERROR"   "$1" "${2:-}" "${3:-1}"; }
log_fatal()   { log_json "FATAL"   "$1" "${2:-}" "${3:-1}"; }
