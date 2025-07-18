#!/usr/bin/env bash

umask 022
 set -euo pipefail

# === Config Paths ===
STRUCTURE_SPEC="./system/structure.spec"
VALIDATOR="./system/structure_validator.sh"
CONTEXT_CHECK="./attn/context-status.sh"

# === Load Central Config (deferred) ===
# source "$(dirname "$0")/config/ssot.sh"

# === Parse Command ===
COMMAND="${1:-}"
shift || true

# === Pre-flight Checks (can later move to preflight.sh) ===
run_preflight() {
  if [[ "$COMMAND" != "check" && "$COMMAND" != "help" ]]; then
    echo "🚦 Running preflight checks..."
    
    if ! "$VALIDATOR" "$STRUCTURE_SPEC"; then
      echo "❌ Structure invalid. Aborting."
      exit 1
    fi

    if ! "$CONTEXT_CHECK"; then
      echo "❌ Context invalid. Aborting."
      exit 1
    fi
  fi
}

# Execute preflight
run_preflight

# === Command Dispatcher ===
case "$COMMAND" in
  check)
    "$CONTEXT_CHECK" "$@"
    ;;
  toggle)
    ./config/runtime_flags.sh "$@"
    ;;
  help|"")
    echo "🧭 Usage:"
    echo "  ./main.sh start     # Run primary workflow"
    echo "  ./main.sh check     # Run dev attention dashboard"
    echo "  ./main.sh toggle    # Toggle runtime flags"
    echo "  ./main.sh help      # Show this message"
    ;;
  *)
    echo "❌ Unknown command: '$COMMAND'"
    echo "Run './main.sh help' for usage."
    exit 1
    ;;
esac
