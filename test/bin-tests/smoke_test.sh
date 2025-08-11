#!/usr/bin/env bash
set -euo pipefail

# --- Set up ---
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAIN_SCRIPT="$ROOT_DIR/bin/main.sh"

echo "Running smoke test for main.sh start"
echo "------------------------------------"

# --- Validate that main script exists and is executable ---
if [[ ! -x "$MAIN_SCRIPT" ]]; then
  echo "❌ main.sh not found or not executable at: $MAIN_SCRIPT"
  exit 1
fi

# --- Run the start command ---
set +e
OUTPUT=$("$MAIN_SCRIPT" start 2>&1)
EXIT_CODE=$?
set -e

# --- Report results ---
echo "$OUTPUT"
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "❌ Smoke test failed with exit code $EXIT_CODE"
  exit $EXIT_CODE
else
  echo "✅ Smoke test passed"
fi

