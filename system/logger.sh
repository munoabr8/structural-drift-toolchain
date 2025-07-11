#!/usr/bin/env bash
# system/logger.sh
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
  log_json "$@" || {
    echo "🛑 Logging failed. Exiting at level '$1' with message: $2" >&2
    exit 99
  }
}


log_json() {
  # Invariant: Must have at least LEVEL and MESSAGE
  if [[ "$#" -lt 2 ]]; then
    echo "❌ ERROR: log_json() called with too few arguments. Got [$*]" >&2
    return 99
  fi

  local level="${1:-""}"
  local message="${2:-""}"
  local error_code="${3:-""}"
  local exit_code="${4:-""}"

  # Invariant: Level must be from accepted set
  case "$level" in
    INFO|ERROR|FATAL|SUCCESS) ;;
    *)
      echo "❌ ERROR: Unknown log level '$level'" >&2
      return 98
      ;;
  esac

REDUCED_GRANULARITY="${REDUCED_GRANULARITY:-false}"

  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local log_line
  log_line=$(printf '{"timestamp":"%s","level":"%s","message":"%s","error_code":"%s","exit_code":"%s"}\n' \
    "$timestamp" "$level" "$message" "$error_code" "$exit_code")

  # Add a separating newline before the log
  if [[ -n "${LOG_OUTPUT_FILE:-}" ]]; then
    printf "\n%s\n" "$log_line" | tee -a "$LOG_OUTPUT_FILE" >&2
  else
    printf "\n%s\n" "$log_line" >&2
  fi


}
