#!/usr/bin/env bash

set -euo pipefail
umask 022

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/runtime.cfg"

PROJECT_CONTEXT="${PROJECT_CONTEXT:-config}"

POLICY_FILE="${POLICY_FILE:-"$PROJECT_CONTEXT/policy.rules.yml"}"

 
# ─── Functions ─────────────────────────────────────────────

show_help() {
  echo ""
  echo "🎛️  context-status - Display active context health and key exports"
  echo ""
  echo "🔧 Usage:"
  echo "  ./attn/context-status.sh           # Run default health check"
  echo "  ./attn/context-status.sh help      # Show this message"
  echo ""
  echo "📦 Checks Performed:"
  echo "  - PROJECT_CONTEXT and SSOT_LOADED"
  echo "  - Exported context vars (e.g. LOG_PATH)"
  echo "  - Existence of runtime.cfg"
  echo "  - Directory presence (LOG_PATH, DATA_DIR)"
  echo ""
}

print_context_summary() {
  echo ""
  echo "🧭 CONTEXT SUMMARY"
  echo "────────────────────────────"
  if [[ -n "${PROJECT_CONTEXT:-}" ]]; then
    echo "📌 PROJECT_CONTEXT = $PROJECT_CONTEXT"
    echo "📂 Context File    = config/${PROJECT_CONTEXT}/ssot.sh"
    echo "🧠 Mode Inferred   = ${PROJECT_CONTEXT^^} mode"
  else
    echo "❌ PROJECT_CONTEXT is not set"
  fi

  if [[ "${SSOT_LOADED:-0}" == "1" ]]; then
    echo "✅ SSOT_LOADED is set (context loaded successfully)"
  else
    echo "⚠️  SSOT_LOADED flag is not set"
  fi
}

print_exported_variables() {
  echo ""
  echo "📦 Exported Context Variables"
  echo "──────────────────────────────"
  for var in CONTEXT_ACTIVE DEBUG_MODE DATA_DIR LOG_PATH; do
    value="${!var:-}"
    if [[ -n "$value" ]]; then
      echo "🧩 $var = $value"
    else
      echo "⚠️  $var is not defined"
    fi
  done
}



resolve_project_root() {
  local src="${BASH_SOURCE[0]}"
  #
  printf '%s\n' "$(cd "$(dirname "$src")/.." && pwd)" || return 1
}

 
setup_environment_paths() {


PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}" || return $?

  SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
  TOOLS_DIR="${TOOLS_DIR:-$PROJECT_ROOT/tools}"

POLICY_FILE="${POLICY_FILE:-$PROJECT_ROOT/config/policy.rules.yml}"

  export PROJECT_ROOT SYSTEM_DIR TOOLS_DIR POLICY_FILE
}

 
source_utilities() {

resolve_project_root
setup_environment_paths

echo "DEBUG PROJECT_ROOT=$PROJECT_ROOT"
echo "DEBUG SYSTEM_DIR=$SYSTEM_DIR"
 
  local system_dir="${SYSTEM_DIR:-./system}"
  local tools_dir="${TOOLS_DIR:-./tools}"


  if [[ ! -f "$system_dir/source_OR_fail.sh" ]]; then
    echo "Missing required file: $system_dir/source_OR_fail.sh"
    exit 1
  fi
  source "$system_dir/source_OR_fail.sh"

  source_or_fail "$system_dir/logger.sh"
  source_or_fail "$system_dir/logger_wrapper.sh"

  #source_or_fail "$PROJECT_ROOT/tools/exit_codes_enforcer.sh"

     
 
 }


check_runtime_cfg() {
  echo ""
  echo "📘 Config File Check"
  echo "────────────────────"
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "✅ runtime.cfg found at $CONFIG_FILE"
  else
    echo "❌ runtime.cfg not found at $CONFIG_FILE"
  fi
}

check_directory_paths() {
  echo ""
  echo "📁 Directory Checks"
  echo "────────────────────"
  for dir_var in DATA_DIR LOG_PATH; do
    path="${!dir_var:-}"
    if [[ -n "$path" ]]; then
      if [[ -d "$path" ]]; then
        echo "✅ Directory exists: $dir_var → $path"
      else
        echo "⚠️  Directory missing: $dir_var → $path"
      fi
    fi
  done
}

print_final_summary() {
  echo ""
  echo "📊 Final Status"
  echo "────────────────────"
  if [[ "${SSOT_LOADED:-0}" == "1" && -f "$CONFIG_FILE" ]]; then
    echo "✅ CONTEXT HEALTH: STABLE"
  else
    echo "⚠️  CONTEXT HEALTH: DEGRADED (missing flags or config)"
  fi
}

# ─── Entry Point ──────────────────────────────────────────

if [[ "${1:-}" == "help" ]]; then
  show_help
  exit 0
fi
source_utilities
print_context_summary
print_exported_variables
check_runtime_cfg
check_directory_paths
print_final_summary



# ─── TODOs ────────────────────────────────────────────────
# - Add --json output
# - Add --strict validation mode
# - Add --summary-only flag
