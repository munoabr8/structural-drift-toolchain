#!/usr/bin/env bash

log() {
  local level="${1:-""}"
  local message="${2:-""}"
  local error_code="${3:-""}"
  local exit_code="${4:-""}"

  echo "--- LOG CALL DEBUG ---" >&2
  echo "LEVEL:      [$level]" >&2
  echo "MESSAGE:    [$message]" >&2
  echo "ERROR_CODE: [$error_code]" >&2
  echo "EXIT_CODE:  [$exit_code]" >&2
  echo "------------" >&2

  printf '{"timestamp":"%s","level":"%s","message":"%s","error_code":"%s","exit_code":"%s"}\n' \
    "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    "$level" \
    "$message" \
    "$error_code" \
    "$exit_code"
}


main() {
  echo "🔍 Invoking logger with 4 arguments:"
  log "SUCCESS" "Structure validation passed." "" "0"
  log "SUCCESS" "Structure validation passed." "" "0"
}

# Entrypoint
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
