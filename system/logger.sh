#!/usr/bin/env bash
# logger.sh
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

log() {
  # Invariant: Must have at least LEVEL and MESSAGE
  if [[ "$#" -lt 2 ]]; then
    echo "❌ ERROR: log() called with too few arguments. Got [$*]" >&2
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

  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local log_line
  log_line=$(printf '{"timestamp":"%s","level":"%s","message":"%s","error_code":"%s","exit_code":"%s"}\n' \
    "$timestamp" "$level" "$message" "$error_code" "$exit_code")

  # Output to stderr and optionally to file
  if [[ -n "${LOG_OUTPUT_FILE:-}" ]]; then
    echo "$log_line" | tee -a "$LOG_OUTPUT_FILE" >&2
  else
    echo "$log_line" >&2
  fi
}
