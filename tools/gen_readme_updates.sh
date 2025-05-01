#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 📖 Auto-generate README.md from Make targets + modules
# ============================================

README_FILE="README.md"
MAIN_MAKEFILE="Makefile"

# --- Auto-detect top-level directories ---
MODULE_DIRS=()
while IFS= read -r -d '' dir; do
  MODULE_DIRS+=("${dir%/}") # Remove trailing slash
done < <(find . -maxdepth 1 -type d ! -name '.' -print0)

echo "📝 Generating $README_FILE ..."
echo "# Project Overview" > "$README_FILE"
echo "" >> "$README_FILE"
echo "_This README was partially auto-generated._" >> "$README_FILE"
echo "" >> "$README_FILE"

echo "## Available Make Targets" >> "$README_FILE"
echo "" >> "$README_FILE"

# Parse Makefile targets
awk '
  /^[a-zA-Z0-9_-]+:/ {
    target = $1
    sub(":", "", target)
    if (target != ".PHONY") {
      print "- `" target "`"
    }
  }
' "$MAIN_MAKEFILE" >> "$README_FILE"

echo "" >> "$README_FILE"
echo "## Detected Project Modules" >> "$README_FILE"
echo "" >> "$README_FILE"

# Detect modules and briefly document
for dir in "${MODULE_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "- **${dir#./}/**" >> "$README_FILE"
    if [ -f "$dir/structure.spec" ]; then
      echo "  - _(Structure enforced)_" >> "$README_FILE"
    fi
    echo "" >> "$README_FILE"
  fi
done

echo "✅ README generation complete!"
