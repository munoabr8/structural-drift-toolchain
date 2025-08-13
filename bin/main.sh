#!/usr/bin/env bash
#./bin/main.sh

umask 022
 set -euo pipefail


if [[ -n "${TEST_SHIM:-}" && -r "${TEST_SHIM}" ]]; then
  # shellcheck source=/dev/null
  source "$TEST_SHIM"
fi

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

 
 run_cmd() { command "$@"; }  # single choke point for externals

 bootstrap_env() {
  # --- Step 1: Bootstrap Project Root ---
  if [[ -n "${PROJECT_ROOT:-}" && -d "$PROJECT_ROOT" ]]; then
    root="$PROJECT_ROOT"
    echo "🟢 Using preset PROJECT_ROOT: $root"

  elif run_cmd -v git &>/dev/null; then
    root="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$root" || ! -d "$root" ]]; then
      echo "⚠️  Not in a Git repo. Falling back to current directory: $PWD" >&2
      root="$PWD"
    else
      echo "🟢 Using git project root: $root"
    fi

  else
    echo "❌ git is required and PROJECT_ROOT is not set" >&2
    exit 66
  fi

  export PROJECT_ROOT="$root"

  # --- Step 2: Initialize and Validate Environment ---
  source "$PROJECT_ROOT/util/core.rf.sh" || {
    echo "❌ Failed to source core.rf.sh" >&2
    exit 68
  }

  source "$PROJECT_ROOT/lib/env_init.sh" || {
    echo "❌ Cannot load env_init.sh from $PROJECT_ROOT/lib" >&2
    exit 65
  }

  : "${STRUCTURE_SPEC:=$PROJECT_ROOT/structure.spec}"

  env_init --path --quiet || {
    echo "❌ env_init failed" >&2
    exit 69
  }

  env_assert || {
    echo "❌ Environment assertion failed" >&2
    exit 70
  }

}

readonly EXIT_OK=0
readonly EXIT_USAGE=64
readonly EXIT_PRECONDITION=65
readonly EXIT_RUNTIME=70



is_query() {
  case "$1" in
    help|context|self-test) return 0 ;;   # read-only
    *)                      return 1 ;;
  esac
}


preflight_if_needed() {
  local cmd="$1"
  if ! is_query "$cmd"; then
    # load contracts only when needed
    # shellcheck source=/dev/null
    source "$LIB_DIR/command_contracts.sh"
    require_contract_for "$cmd" || {
      safe_log "ERROR" "Preflight contract failed for command: $cmd"
      exit "$EXIT_PRECONDITION"   # your existing code uses 65
    }
  fi
}


run_preflight() { preflight_if_needed "$@"; }

source_utilities() {
 
 bootstrap_env
 
 
  # --- Load Critical Utilities ---
  # Ensure source_or_fail_many is available
  if [[ ! -f "$UTIL_DIR/source_or_fail.sh" ]]; then
    echo "❌ Missing required file: source_or_fail.sh in $UTIL_DIR" >&2
    exit 71
  fi

  source "$UTIL_DIR/source_or_fail.sh" 
  
 

  source_or_fail "$UTIL_DIR/logger.sh" 
  source_or_fail "$UTIL_DIR/logger_wrapper.sh"
  source_or_fail "$SYSTEM_DIR/structure_validator.rf.sh" 


  safe_log "INFO" "[source] All utilities loaded successfully"
}

  
assert() {
  local cond="$1" msg="$2" src="${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
  if ! eval "$cond"; then
    printf '❌ ASSERT FAILED: %s\n   → %s\n' "$msg" "$src" >&2
    return 99          # non-zero so `set -e` stops the script
  fi
}

 


# When should enforcement of policy.rules.yml be executed?
# Is 

 show_help(){

    echo "Usage:"
    echo "  ./main.sh start       # Run primary workflow"
    echo "  ./main.sh context     # Display context for context"
    echo "  ./main.sh self-test   # Tests behavior of main and command_contracts"
    echo "  ./main.sh help        # Show this message"

 }
 
# commands
do_start()   { run_cmd "$VALIDATOR" --quiet validate "$STRUCTURE_SPEC"; }
do_context() { run_cmd "$CONTEXT_CHECK" "$@"; }
do_selftest(){   make test-all; }
do_enforce(){ 

  POLICY=

  run_policy_pipeline 

   }

int(){

 make test-all

}

dispatch_command() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
     start)   preflight_if_needed "$cmd"; do_start "$@"  ;;
  self-test)  do_selftest ;;
   context)   do_context "$@" ;;
   help|"")   show_help ;;
         *)   show_help "Unknown command: $cmd" ;;
esac

}

main() {
  source_utilities
 
  local cmd="${1:-}"; shift || true


  dispatch_command "$cmd" "$@"
}

# --- library guard ----------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
