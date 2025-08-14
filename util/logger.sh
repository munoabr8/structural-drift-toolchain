#!/usr/bin/env bash
# ./system/logger.sh
# JSON-based logger with optional file output and structured logging

# ========================
# ✅ USAGE EXAMPLES
# ========================
#   export LOG_OUTPUT_FILE="./logs/system_events.json"
#   log "INFO" "Starting process"
#   log "SUCCESS" "Process complete" "" "0"
#   log "ERROR" "Operation failed" "disk_full" "77"
#   log "FATAL" "Unrecoverable error" "panic" "99"

# ========================
# 🧪 INVARIANTS (MUST HOLD)
# ========================
# - log must be called with at least: LEVEL and MESSAGE
# - LEVEL ∈ {INFO, ERROR, FATAL, SUCCESS}
# - If LOG_OUTPUT_FILE is set, it must be writable
# - Output must always be valid JSON
# - Output must always appear on stderr (or stderr + file)

# ========================
# ⚠️ RISKS
# ========================
# - Silent misuse if caller ignores return codes
# - Unescaped quotes in messages can break JSON
# - Log file can grow without bound
# - If used in tight loops, may add performance overhead
# - Shell injection risk if log values contain untrusted content


# ========================
# 🔁 RELATIONSHIPS: Expectations, Invariants, Feedbacks
# ========================

# Expectation → Invariant
# - log_json must be called with at least LEVEL and MESSAGE
#   → Enforced by checking argument count (Invariant)
#
# - LEVEL must be one of INFO, ERROR, FATAL, SUCCESS
#   → Enforced with case statement (Invariant)
#
# - LOG_OUTPUT_FILE is optional but, if present, should be writable
#   → Implicit expectation, not yet validated at runtime

# Invariant → Feedback
# - Invalid LEVEL triggers error to stderr + exit code 98
# - Too few arguments triggers error to stderr + exit code 99
# - Valid log always produces JSON (even if minimal fields are empty)
#
# - If REDUCED_GRANULARITY is true and level is INFO
#   → Function returns silently (feedback = omission)

# Expectation → Feedback
# - Every log goes to stderr (unless skipped due to REDUCED_GRANULARITY)
# - If LOG_OUTPUT_FILE is set, log is also appended to file
#
# - Use of structured JSON logging supports external parsers and systems

# Meta-Expectation → Invariant → Feedback
# - Logging system should not redefine log_json if already sourced
#   → Guard clause checks for redefinition
#   → If conflict exists, print error and return 99

if command -v logger >/dev/null && [[ "$(type -t log_json)" == "file" ]]; then
  echo "❌ 'log_json' already defined elsewhere, aborting" >&2
  return 99
fi
 
 
safe_log() {
  local level="$1" message="$2" error_code="${3:-}" exit_code="${4:-}"
  
  # Always try JSON logging first (your existing implementation)
  log_json "$level" "$message" "$error_code" "$exit_code" || {
    echo "🛑 Logging failed. Exiting at level '$level' with message: $message" >&2
    exit 99
  }

  # Optional: also log a plain text line if LOG_FILE is set
  if [[ -n "${LOG_FILE:-}" ]]; then
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf "%s [%s] %s (err:%s exit:%s)\n" \
      "$timestamp" "$level" "$message" "$error_code" "$exit_code" \
      >> "$LOG_FILE"
  fi
}


log_json() {
  # ---- validate ----
  (( $# >= 2 )) || { echo "log_json: need LEVEL MESSAGE" >&2; return 99; }
  local level="$1" message="$2" detail="${3:-}" err="${4:-}" code="${5:-}"
  case "$level" in INFO|ERROR|FATAL|SUCCESS) ;; *) echo "log_json: bad level $level" >&2; return 98;; esac
  [[ "${QUIET:-false}" == "true" && "$level" != "ERROR" && "$level" != "FATAL" ]] && return 0

  # ---- helpers ----
  json_escape() {
    local s=$1
    s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
    printf '%s' "$s"
  }

  # ---- assemble ----
  local ts; ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  local j='{"timestamp":"'"$(json_escape "$ts")"'","level":"'"$level"'","message":"'"$(json_escape "$message")"'"'
  [[ -n "$detail" ]] && j+=',"detail":"'"$(json_escape "$detail")"'"'
  [[ -n "$err"    ]] && j+=',"error_code":"'"$(json_escape "$err")"'"'
  [[ -n "$code"   ]] && j+=',"exit_code":"'"$(json_escape "$code")"'"'
  j+=',"pid":'"$$"'}'

  # ---- output (stderr + optional file) ----
  if [[ -n "${LOG_OUTPUT_FILE:-}" ]]; then
    # create file if missing; append atomically
    umask 077; : >>"$LOG_OUTPUT_FILE"
    printf '%s\n' "$j" | tee -a "$LOG_OUTPUT_FILE" >&2
  
    else
    printf '%s\n' "$j" >&2
  fi
}


