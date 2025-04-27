#!/usr/bin/env bash
set -euo pipefail

echo "# Aggregated structure.spec (auto-generated)"
echo ""

find . -name 'structure.spec' ! -path './system/*' | sort | while read -r spec; do
  mod=$(dirname "$spec")
  echo "# From $mod" 
  grep -vE '^#|^$' "$spec" || true
  echo ""
done | sort -u
