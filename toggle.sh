#!/usr/bin/env bash

umask 022
set -euo pipefail


# ─── Configuration ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# ─── Help Message ──────────────────────────────────────────────
show_help() {
  echo ""
  echo "🔧 Usage: toggle.sh [module_name] <action> [subfeature]"
  echo ""
  echo "📦 Module Detection:"
  echo "  - Auto-detects module from \`pwd\` if not given"
  echo "  - Recommended: run inside \`modules/<module>\` or pass manually"
  echo ""
  echo "🎯 Examples:"
  echo "  ./toggle.sh unit_testing run build"
  echo "  cd modules/unit_testing && ../../toggle.sh run build"
  echo ""
  echo "🔁 Actions:"
  echo "  --status        - View dashboard of modules"
  echo "  --enable NAME   - Enable module"
  echo "  --disable NAME  - Disable module"
  echo "  run build       - Run 'build' inside module"
  echo ""
  echo "💡 Requires a toggle.state file in each module"
  echo ""
}

# ─── Dashboard View ────────────────────────────────────────────
show_status_dashboard() {
  echo -e "\n📊 Module Status Dashboard"
  echo "------------------------------------------"
  printf " %-20s | %-4s | %-6s\n" "Module" "On?" "State"
  echo "------------------------------------------"
  for path in "$MODULES_DIR"/*/; do
    mod=$(basename "$path")
 state=$(cat "${path}/toggle.state" 2>/dev/null || echo "on")

icon="✗"
[[ "$state" == "on" ]] && icon="✓"
    printf " %-20s | %-4s | %s\n" "$mod" "$state" "$icon"
  done
  echo "------------------------------------------"
  exit 0
}

# ─── Toggle Enable/Disable ─────────────────────────────────────
toggle_module() {
  local action="$1" module="$2"
  [[ -z "$module" ]] && { echo "❌ Module name required."; exit 1; }
  [[ ! -d "$MODULES_DIR/$module" ]] && { echo "❌ Module '$module' not found."; exit 2; }

  local state="on"; [[ "$action" == "--disable" ]] && state="off"
  echo "$state" > "$MODULES_DIR/$module/module.state"
  echo "🔁 Toggled '$module' to: $state"
  exit 0
}

# ─── Parse Mode-Based Commands ─────────────────────────────────
parse_mode_and_args() {
  case "${1:-}" in
    -h|--help|-help)
      show_help
      exit 0
      ;;
    --status)
      show_status_dashboard
      exit 0
      ;;
    --enable|--disable)
      toggle_module "$1" "${2:-}"
      exit 0
      ;;
  esac
}


resolve_module() {
  local input="$1"
  echo "${input:-$(basename "$PWD")}"
}

validate_module_exists() {
  local module="$1"
  local path="$MODULES_DIR/$module"
  [[ -d "$path" ]] || { echo "❌ Module '$module' not found at $path"; exit 1; }
}

validate_handler_exists() {
  local module="$1"
  local path="$MODULES_DIR/$module/handler.sh"
  [[ -f "$path" ]] || { echo "❌ handler.sh not found in '$module'"; exit 2; }
  source "$path"
}

check_toggle_state() {
  local toggle_file="$1"
  local state
  state=$(< "$toggle_file" 2>/dev/null || echo "on")
  [[ "$state" == "off" ]] && {
    echo "🚫 Module is toggled OFF"
    exit 0
  }
}

dispatch_action() {
  local action="$1"; shift || true
  if declare -f "$action" > /dev/null; then
    "$action" "$@" || {
      echo "⚠️ Action '$action' failed"
      exit 3
    }
  else
    echo "❌ Action '$action' not found"
    declare -f info > /dev/null && info
    exit 4
  fi
}

# ─── Entry Point ───────────────────────────────────────────────
main() {

  #set -x  # Uncomment for debug mode

  parse_mode_and_args "${1:-}" "${2:-}"

  local module
  module=$(resolve_module "${1:-}")
  [[ $# -gt 0 ]] && shift || true

  local module_path="$MODULES_DIR/$module"
  local toggle_file="$module_path/toggle.state"

  validate_module_exists "$module"
  validate_handler_exists "$module"
  check_toggle_state "$toggle_file"

  local action="${1:-info}"
  shift || true
  dispatch_action "$action" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
