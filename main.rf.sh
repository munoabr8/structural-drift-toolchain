#!/usr/bin/env bash

umask 022
 set -euo pipefail


# What is it you want to achieve?
# --> Make it easy for the developer to use this system
# --> in order to maximize clarity.

# What kind of script is this?
# --> Executable and entry point into the system

# Measures?
# --> # of Paths that have been tested

# CHATGPT:
# What are the current expectations,invariants and constraints?
# --> Please make them explicit



# TODO:
# 1.) Help me decide what to test next for the preflight.
# Expectations  
# • SYSTEM_DIR points to a directory containing required helper scripts.
# • structure.spec reflects the on‑disk state when start runs.
# • Validator and context‑check exit 0 on success, >0 on failure.

# Invariants  • Commands start, check, toggle, help are the complete public interface.
# • run_preflight is never executed for read‑only operations (check, help).
# • Every externally invoked script is executable (chmod +x).

# Constraints • Script must be invoked from project root (paths are relative).
# • Missing dependency ⇒ hard fail with non‑zero exit.
# • Unhandled command ⇒ usage message + non‑zero exit.


 
# === Config Paths ===
STRUCTURE_SPEC="./system/structure.spec"

VALIDATOR="${VALIDATOR:-./system/structure_validator.sh}"

CONTEXT_CHECK="${CONTEXT_CHECK:-./attn/context-status.sh}"

RUNTIME_TOGGLE_FLAGS="${RUNTIME_TOGGLE_FLAGS:-./config/runtime_flags.sh}"

 
 
# === Pre-flight Checks (can later move to preflight.sh) ===
 
run_preflight() {

# Assumes caller has already decided this command requires preflight.
  # Optional: accept cmd just for logging.
  local cmd="${1:-start}"
  safe_log "INFO" "Preflight begin: $cmd"

  "$VALIDATOR" "$STRUCTURE_SPEC" || { echo "Structure invalid." >&2; return 1; }
  "$CONTEXT_CHECK"               || { echo "Context invalid."   >&2; return 1; }

  safe_log "INFO" "Preflight passed: $cmd"
  return 0
}


 

# Refactor location of these scripts to actually be in a 
# utility directory.
 source_utilities(){
 
  local system_dir="${SYSTEM_DIR:-./system}"

    
  if [[ ! -f "$system_dir/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$system_dir/source_OR_fail.sh"

  source_or_fail "$system_dir/logger.sh"
  source_or_fail "$system_dir/logger_wrapper.sh"

  source_or_fail "$system_dir/structure_validator.sh"
 
 
 }


 show_usage(){

    echo "Usage:"
    echo "  ./main.sh start     # Run primary workflow"
    echo "  ./main.sh check     # Run dev attention dashboard"
    echo "  ./main.sh toggle    # Toggle runtime flags"
    echo "  ./main.sh help      # Show this message"


 }


main() {                      

  source_utilities

  local cmd="${1:-}"; shift || true
  case "$cmd" in
    start)
      run_preflight "$cmd"
      ;;                         # primary workflow would follow here
    check)
      "$CONTEXT_CHECK" "$@"
      ;;
    toggle)
      "$RUNTIME_TOGGLE_FLAGS" "$@"
      ;;
    help|"")
      show_usage
      ;;
    *)
      echo "Unknown command: '$cmd'"
      show_usage
      return 1
      ;;
  esac
}

# --- library guard ----------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
