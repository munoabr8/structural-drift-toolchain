#!/usr/bin/env bash
#./tools/gen_readme.sh


set -euo pipefail


# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT="$ROOT_DIR/README.generated.md"
MODULES_DIR="$ROOT_DIR/modules"
MAKEFILE="$ROOT_DIR/Makefile"

[[ -d "$(dirname "$OUTPUT")" ]] || mkdir -p "$(dirname "$OUTPUT")"
[[ -r "$MAKEFILE" ]] || echo "⚠️  $MAKEFILE not readable; commands section will be empty"
[[ -d "$MODULES_DIR" ]] || echo "⚠️  $MODULES_DIR not found; modules section will be empty"


# --- Generate ---
echo "🏗️ Auto-generating $OUTPUT..."
echo "# 🏗️ Project System Overview" > "$OUTPUT"
echo "" >> "$OUTPUT"

echo "Welcome!" >> "$OUTPUT"
echo "This system uses strict structure validation, module boundaries, and automation for resilience." >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "---" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# 📦 Project Modules
echo "## 📦 Project Modules" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "| Module | Notes |" >> "$OUTPUT"
echo "|:---|:---|" >> "$OUTPUT"

if [ -d "$MODULES_DIR" ]; then
  find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r dir; do
    mod_name="$(basename "$dir")"
    echo "| \`$mod_name/\` |  |" >> "$OUTPUT"
  done
else
  echo "⚠️ Warning: No modules directory found." >&2
fi

echo "" >> "$OUTPUT"
echo "---" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ⚙️ Available Commands
echo "## ⚙️ Available Commands" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "| Command | Purpose |" >> "$OUTPUT"
echo "|:---|:---|" >> "$OUTPUT"

awk '/^[a-zA-Z0-9_-]+:/ {print $1}' "$MAKEFILE" | sed 's/://g' | sort | while read -r target; do
  echo "| \`make $target\` |  |" >> "$OUTPUT"
done

 echo "" >> "$OUTPUT"
echo "---" >> "$OUTPUT"
echo "" >> "$OUTPUT"


echo "## 📊 Test Coverage Summary" >> "$OUTPUT"
echo "" >> "$OUTPUT"

if command -v bats > /dev/null; then
  total_tests=$(bats --count system-test/**/*.bats 2>/dev/null | awk '{sum+=$1} END {print sum}')
  echo "- Total BATS Tests: ${total_tests:-0}" >> "$OUTPUT"
else
  echo "- BATS not installed. Skipping test count." >> "$OUTPUT"
fi


echo "" >> "$OUTPUT"
echo "---" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "## ⚠️ Modules Missing structure.spec" >> "$OUTPUT"
echo "" >> "$OUTPUT"

missing=0

 if [ -d "$MODULES_DIR" ]; then
  for mod in "$MODULES_DIR"/*/; do
    if [ ! -f "${mod}structure.spec" ]; then
      echo "- $(basename "$mod")/" >> "$OUTPUT"
      missing=1
    fi
  done
fi
 
 MISSING_FLAG=".missing_module_specs"

if [ "$missing" -eq 1 ]; then
  echo "🚨 Missing specs detected."
  touch "$MISSING_FLAG"
else
  echo "_All modules have specs._" >> "$OUTPUT"
  rm -f "$MISSING_FLAG"
fi

echo "## ⚠️ Modules Missing structure.spec" >> "$OUTPUT"
echo "" >> "$OUTPUT"



 



echo "" >> "$OUTPUT"
echo "---" >> "$OUTPUT"
echo "" >> "$OUTPUT"


# 🧹 Structure Policy
echo "## 🧹 Structure Enforcement Policy" >> "$OUTPUT"
echo "" >> "$OUTPUT"
cat << EOF >> "$OUTPUT"
- All directories and files must be explicitly declared.
- Temporary artifacts like \`.structure.snapshot\` must not be committed.
- Structure drift is flagged by CI and requires manual review.
- Garbage detection prevents unknown or unauthorized files.
EOF



echo ""
echo "✅ README generated at $OUTPUT."
