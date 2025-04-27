#!/usr/bin/env bash

#set -euxo pipefail

set -euo pipefail

#SNAPSHOT_GEN=./../debugTools/structureDebugging.sh

 #cd "$(dirname "$0")/.."
 
# 🔒 Use hardcoded absolute path for structure function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEBUGTOOLS_PATH="$(cd "$SCRIPT_DIR/../../debugTools" && pwd)"

STRUCTURE_FN="$DEBUGTOOLS_PATH/structureDebugging.sh"

echo "🐛 DEBUGTOOLS_PATH: $DEBUGTOOLS_PATH"
echo "🐛 STRUCTURE_FN: $STRUCTURE_FN"

# 📎 Ensure structureDebugging.sh exists
if [[ ! -f "$STRUCTURE_FN" ]]; then
  echo "❌ structureDebugging.sh not found at: $STRUCTURE_FN"
  exit 1
fi



safe_source() {
  local file="$1"



  if [[ -z "${file:-}" ]]; then
    echo "❌ safe_source(): No file provided to source" >&2
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "❌ safe_source(): File not found: $file" >&2
    return 1
  fi

  echo "📥 safe_source(): Sourcing $file" >&2
  source "$file"
}


# # 📥 Source the function
 safe_source "$STRUCTURE_FN"  

 
echo "✅ Module spec generation complete"

if declare -f generate_structure_spec > /dev/null; then
  echo "✅ Function loaded"
else
  echo "❌ Function NOT found"
  exit 1
fi



 




# Discover top-level modules

MODULES=$(find . -maxdepth 1 -type d ! -name "." ! -name ".git" ! -name "system" ! -name "tmp" | sed 's|^\./||')

failed_modules=()

for mod in $MODULES; do
  echo "🔧 Generating structure.spec for module: $mod"
  if [ -d "$mod" ]; then
    if ! generate_structure_spec "$mod" > "$mod/structure.spec"; then
      echo "⚠️  Spec generation failed for module: $mod"
      failed_modules+=("$mod")
    fi
  else
    echo "⚠️  Skipping missing module: $mod"
  fi
done

if (( ${#failed_modules[@]} )); then
  echo ""
  echo "❌ The following modules had generation issues:"
  for mod in "${failed_modules[@]}"; do
    echo "   - $mod"
  done
  exit 1
fi
