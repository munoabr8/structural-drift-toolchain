#!/usr/bin/env bash
set -euo pipefail

STRUCTURE_SPEC="${1:-system/structure.spec}"
VALIDATOR="./system/validate_structure.sh"
GARBAGE_DETECTOR="./tools/detect_garbage.sh"
SNAPSHOT_GEN="../debugtools/structureDebugging.sh"

echo "🩺 Running Doctor Diagnostic Panel"
echo "────────────────────────────────────"

# 1. Structure Drift Check
echo ""
echo "🔍 Structure Drift:"
if [ ! -x "$SNAPSHOT_GEN" ]; then
  echo "❌ Snapshot generator not found at $SNAPSHOT_GEN"
  exit 1
else
  "$SNAPSHOT_GEN" generate_structure_spec > .structure.snapshot
  if diff -u "$STRUCTURE_SPEC" .structure.snapshot; then
    echo "✅ No structure drift detected."
  else
    echo "❌ Structure drift detected."
    exit 1
  fi
fi

# 2. Validate Structure Spec
echo ""
echo "✅ Validating Declared Structure:"
if [ -x "$VALIDATOR" ]; then
  bash "$VALIDATOR" "$STRUCTURE_SPEC"
else
  echo "❌ Validator script missing or not executable: $VALIDATOR"
  exit 1
fi

# 3. Garbage Scan
echo ""
echo "🧹 Garbage Detection:"
if [ -x "$GARBAGE_DETECTOR" ]; then
  bash "$GARBAGE_DETECTOR" "$STRUCTURE_SPEC"
else
  echo "❌ Garbage detector script missing or not executable: $GARBAGE_DETECTOR"
  exit 1
fi

# 4. Run Full Structure Test Suites
echo ""
echo "🧪 Running Structure Test Suite:"
make test-structure

echo ""
echo "❗ Running Negative Test Suite:"
make test-negative-structure

echo ""
echo "🧹 Running Garbage Test Suite:"
make test-garbage-detector

echo ""
echo "✅ All checks passed. System is structurally healthy."
