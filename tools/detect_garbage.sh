#!/usr/bin/env bash
set -euo pipefail

#tools/
#├── structure/
#│   ├── validate_structure.sh
#│   ├── detect_garbage.sh        split + slim down
#│   ├── parse_structure_spec.sh  reusable normalized path extractor
#│   ├── read_structure_ignore.sh reusable ignore pattern matcher
#│   └── generate_snapshot.sh     DRY snapshot logic


#!/usr/bin/env bash
set -euo pipefail

SPEC_FILE="${1:-system/structure.spec}"
IGNORE_FILE=".structure.ignore"

if [ ! -f "$SPEC_FILE" ]; then
  echo "❌ Spec file not found: $SPEC_FILE"
  exit 1
fi

echo "🗑️  Detecting undeclared files and directories..."
echo "📘 Input spec path: $SPEC_FILE"
echo "📍 PWD: $(pwd)"

IGNORE_DIRS=(".git" "__pycache__" "node_modules" ".idea" ".vscode")
declare -A declared_paths
declare -a ignored_patterns

# Load .structure.ignore if it exists
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    ignored_patterns+=("$line")
  done < "$IGNORE_FILE"
fi

# === SPEC PARSER ===
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  clean=$(echo "$line" | sed -E 's/^(dir:|file:|link:)\s*//' | sed 's/^ *//;s/ *$//')

  if [[ "$clean" == *"->"* ]]; then
    clean=$(echo "$clean" | awk '{print $1}')
  fi

  if [ ! -e "$clean" ]; then
    echo "⚠️  Skipping unresolved: '$clean' — does not exist"
    continue
  fi

  real=$(realpath -sm "$clean" 2>/dev/null || echo "$clean")
  declared_paths["$real"]=1
done < "$SPEC_FILE"

# === FILE SYSTEM WALKER ===
while IFS= read -r actual; do
  skip=0

  # Skip ignored directories
  for ignore in "${IGNORE_DIRS[@]}"; do
    if [[ "$actual" == *"/$ignore"* ]]; then
      skip=1
      break
    fi
  done
  [ "$skip" -eq 1 ] && continue

  # Normalize path
  abs=$(realpath -sm "$actual")

  # Skip ignored patterns
  for pattern in "${ignored_patterns[@]}"; do
    if [[ "$actual" == $pattern || "$actual" == ./$pattern ]]; then
      skip=1
      break
    fi
  done
  [ "$skip" -eq 1 ] && continue

  # Compare against declared
  if [[ -z "${declared_paths["$abs"]+x}" ]]; then
    echo "❌ Untracked: $actual"
  fi
done < <(find . -type f -o -type d -o -type l)

