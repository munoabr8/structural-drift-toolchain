#!/usr/bin/env bash

# config/runtime_flags.sh
# This script is called by the main.sh script.
# This will modify run-time behavior.

umask 022
set -euo pipefail

CONFIG_FILE="./runtime.cfg"

# ─── Invariant Check ─────────────────────────────────────────────
[[ -f "$CONFIG_FILE" ]] || { echo "❌ Config file not found at $CONFIG_FILE"; exit 99; }
[[ -w "$CONFIG_FILE" ]] || { echo "❌ Config file is not writable"; exit 98; }

# ─── Helper: Show CLI Guide ──────────────────────────────────────
show_help() {
  echo ""
  echo "🎛️  runtime_flags.sh - Manage runtime behavior flags"
  echo ""
  echo "🔧 Usage:"
  echo "  enable <KEY>       - Sets KEY=1"
  echo "  disable <KEY>      - Sets KEY=0"
  echo "  show <KEY>         - Show current value"
  echo "  list               - Show all keys"
  echo "  help               - Show this help message"
  echo ""
  echo "⚠️  This controls runtime behavior flags in $CONFIG_FILE"
  echo "   It does NOT affect module toggles (module.state)"
  echo ""
}

# ─── Validation Helpers ──────────────────────────────────────────
validate_key_format() {
  local key="$1"
  if [[ ! "$key" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "❌ Invalid key format: '$key'"
    echo "🔒 Keys must be alphanumeric with underscores only"
    exit 10
  fi
}

update_flag() {
  local key="$1"
  local value="$2"

  validate_key_format "$key"

  grep -q "^${key}=" "$CONFIG_FILE" && sed -i '' "/^${key}=/d" "$CONFIG_FILE"
  echo "${key}=${value}" >> "$CONFIG_FILE"

  if grep -q "^${key}=${value}" "$CONFIG_FILE"; then
    echo "✅ Set ${key}=${value}"
  else
    echo "❌ Failed to set ${key}=${value}"
    exit 20
  fi
}

show_flag() {
  local key="$1"
  validate_key_format "$key"

  grep -q "^${key}=" "$CONFIG_FILE" && {
    echo "🔍 $key → $(grep "^${key}=" "$CONFIG_FILE" | cut -d '=' -f2)"
  } || {
    echo "⚠️  $key is not set"
    exit 21
  }
}

main() {
  local COMMAND="${1:-}"
  local KEY="${2:-}"

  case "$COMMAND" in
    enable)
      [[ -z "$KEY" ]] && { echo "❌ Missing flag name."; show_help; exit 1; }
      update_flag "$KEY" "1"
      ;;
    disable)
      [[ -z "$KEY" ]] && { echo "❌ Missing flag name."; show_help; exit 1; }
      update_flag "$KEY" "0"
      ;;
    show)
      [[ -z "$KEY" ]] && { echo "❌ Missing flag name."; show_help; exit 1; }
      show_flag "$KEY"
      ;;
    list)
      echo -e "\n📋 All flags in $CONFIG_FILE"
      echo "-----------------------------------"
      cat "$CONFIG_FILE"
      echo "-----------------------------------"
      ;;
    help|-h|--help)
      show_help
      ;;
    *)
      echo "❌ Unknown command: '$COMMAND'"
      show_help
      exit 2
      ;;
  esac
}

# ─── Execute if Run Directly ─────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
