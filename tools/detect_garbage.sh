#!/usr/bin/env bash
set -euo pipefail

SPEC_FILE="${1:-system/structure.spec}"

if [ ! -f "$SPEC_FILE" ]; then
  echo "❌ Spec file not found: $SPEC_FILE"
  exit 1
fi

echo "🗑️  Detecting undeclared files and directories..."
echo "📘 Input spec path: $SPEC_FILE"
echo "📍 PWD: $(pwd)"

IGNORE_DIRS=(".git" "__pycache__" "node_modules" ".idea" ".vscode" ".structure.snapshot")
declare -A declared_paths

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
  echo "📜 Declared spec path (norm): $real"
  declared_paths["$real"]=1
done < "$SPEC_FILE"

# === FILE SYSTEM WALKER ===
while IFS= read -r actual; do
  skip=0
  for ignore in "${IGNORE_DIRS[@]}"; do
    if [[ "$actual" == *"/$ignore"* ]]; then
      skip=1
      break
    fi
  done
  [ "$skip" -eq 1 ] && continue

  abs=$(realpath -sm "$actual")
  echo "🔍 FS path (norm): $abs"
  if [[ -z "${declared_paths["$abs"]+x}" ]]; then
    echo "❌ Untracked: $actual"
  fi
done < <(find . -type f -o -type d -o -type l)
