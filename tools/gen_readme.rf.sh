#!/usr/bin/env bash
# ./tools/gen_readme.sh
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT="$ROOT_DIR/README.generated.md"
MODULES_DIR="$ROOT_DIR/modules"
MAKEFILE="$ROOT_DIR/Makefile"

[[ -d "$(dirname "$OUTPUT")" ]] || mkdir -p "$(dirname "$OUTPUT")"
[[ -r "$MAKEFILE" ]] || echo "⚠️  $MAKEFILE not readable; commands section will be empty" >&2
[[ -d "$MODULES_DIR" ]] || echo "⚠️  $MODULES_DIR not found; modules section will be empty" >&2

# --- Generate ---
echo "🏗️ Auto-generating $OUTPUT..."
{
  echo "# 🏗️ Project System Overview"
  echo
  echo "Welcome!"
  echo "This system uses strict structure validation, module boundaries, and automation for resilience."
  echo
  echo "---"
  echo
  echo "## 📦 Project Modules"
  echo
  echo "| Module | Notes |"
  echo "|:---|:---|"
} > "$OUTPUT"

# Portable modules listing (no GNU find needed)
if [[ -d "$MODULES_DIR" ]]; then
  shopt -s nullglob
  for d in "$MODULES_DIR"/*/ ; do
    [[ -d "$d" ]] || continue
    echo "| \`$(basename "$d")/\` |  |" >> "$OUTPUT"
  done
  shopt -u nullglob
else
  echo "⚠️ Warning: No modules directory found." >&2
fi

{
  echo
  echo "---"
  echo
  echo "## ⚙️ Available Commands"
  echo
  echo "| Command | Purpose |"
  echo "|:---|:---|"
} >> "$OUTPUT"

# Only run awk if Makefile is readable
if [[ -r "$MAKEFILE" ]]; then
  awk -F':|##' '/^[A-Za-z0-9_.-]+:.*##/{
    gsub(/^[ \t]+|[ \t]+$/,"",$1);
    gsub(/^[ \t]+|[ \t]+$/,"",$3);
    printf("| `make %s` | %s |\n",$1,$3)
  }' "$MAKEFILE" >> "$OUTPUT"
else
  echo "⚠️  $MAKEFILE not readable; commands section will be empty" >&2
fi

{
  echo
  echo "---"
  echo
  echo "## 📊 Test Coverage Summary"
  echo
} >> "$OUTPUT"

if command -v bats >/dev/null; then
  # Avoid set -e/pipefail killing the script when no tests match
  shopt -s globstar || true
  set +e
  total_tests=$(bats --count "$ROOT_DIR"/system-test/**/*.bats "$ROOT_DIR"/system-test/*.bats 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
  set -e
  echo "- Total BATS Tests: ${total_tests:-0}" >> "$OUTPUT"
else
  echo "- BATS not installed. Skipping test count." >> "$OUTPUT"
fi

{
  echo
  echo "---"
  echo
  echo "## ⚠️ Modules Missing structure.spec"
  echo
} >> "$OUTPUT"

missing=0
if [[ -d "$MODULES_DIR" ]]; then
  for mod in "$MODULES_DIR"/*/ ; do
    [[ -d "$mod" ]] || continue
    if [[ ! -f "${mod}structure.spec" ]]; then
      echo "- $(basename "$mod")/" >> "$OUTPUT"
      missing=1
    fi
  done
fi

MISSING_FLAG="$ROOT_DIR/.missing_module_specs"
if [[ "$missing" -eq 1 ]]; then
  echo "🚨 Missing specs detected."
  : > "$MISSING_FLAG"
else
  echo "_All modules have specs._" >> "$OUTPUT"
  rm -f "$MISSING_FLAG"
fi

{
  echo
  echo "---"
  echo
  echo "## 🧹 Structure Enforcement Policy"
  echo
  cat << 'EOF'
- All directories and files must be explicitly declared.
- Temporary artifacts like `.structure.snapshot` must not be committed.
- Structure drift is flagged by CI and requires manual review.
- Garbage detection prevents unknown or unauthorized files.
EOF
} >> "$OUTPUT"

echo "✅ README generated at $OUTPUT."
