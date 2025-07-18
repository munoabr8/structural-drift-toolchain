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
  local COMMAND= "$1"

  if [[ "$COMMAND" != "check" && "$COMMAND" != "help" ]]; then
    #echo "🚦 Running preflight checks..."
    
    if ! "$VALIDATOR" "$STRUCTURE_SPEC"; then
       echo "Structure invalid. Aborting."
      exit 1
    fi

    if ! "$CONTEXT_CHECK"; then
       echo "Context invalid. Aborting."
      exit 1  
    fi
  fi
}
 


 load_dependencies(){
 

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"

  source_or_fail "$SYSTEM_DIR/structure_validator.sh"
 
 
 }


 show_usage(){

    echo "Usage:"
    echo "  ./main.sh start     # Run primary workflow"
    echo "  ./main.sh check     # Run dev attention dashboard"
    echo "  ./main.sh toggle    # Toggle runtime flags"
    echo "  ./main.sh help      # Show this message"


 }


main() {                     # ← call this instead of relying on $COMMAND
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
