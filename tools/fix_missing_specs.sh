#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="./modules"
DEBUG_SCRIPT="./tools/structure/structure_snapshot_gen.sh"

echo "🔧 Scanning for missing structure.spec files..."
missing=0

for mod in "$MODULES_DIR"/*; do
  [ -d "$mod" ] || continue  # Skip non-directories
  mod=$(basename "$mod")
  path="$MODULES_DIR/$mod"
  spec="$path/structure.spec"

  if [ ! -f "$spec" ]; then
    echo "⚡ Generating missing spec for module: $mod"
    "$DEBUG_SCRIPT" generate_structure_spec "$path" > "$spec"
    git add "$spec"
    missing=1
  fi
done




if [[ "$missing" -eq 0 ]]; then
  echo "✅ All modules already have structure.spec files."
else
  echo "✅ Missing specs generated and staged."
fi
