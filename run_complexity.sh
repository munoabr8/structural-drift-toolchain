#!/bin/bash
# run_complexity.sh — Run complexity metric and ensure risk is explicit

set -euo pipefail

COMPLEXITY_PATH="${COMPLEXITY_PATH:-artifacts/complexity_report.json}"

# Check for risky output path
if [[ "$COMPLEXITY_PATH" == "/tmp"* || "$COMPLEXITY_PATH" == "." || "$COMPLEXITY_PATH" == "/" ]]; then
  echo "[RISK] Output path '$COMPLEXITY_PATH' is risky. Refusing to write." >&2
  exit 1
fi

# Warn if file exists
if [[ -f "$COMPLEXITY_PATH" ]]; then
  echo "[RISK] File '$COMPLEXITY_PATH' already exists. Use --force to overwrite." >&2
  exit 2
fi

# Run the complexity metric
python3 system/complexity/make_indirection_complexity.py -f Makefile > "$COMPLEXITY_PATH"
echo "[INFO] Complexity report written to $COMPLEXITY_PATH"
