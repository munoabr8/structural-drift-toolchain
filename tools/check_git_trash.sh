#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Checking for Git-tracked trash based on .gitignore..."

patterns=$(grep -Ev '^#|^$' .gitignore | tr '\n' ' ')

if [[ ! -f .gitignore ]]; then
  echo "❌ No .gitignore found in project root!"
  exit 1
fi

# Read patterns (ignore blank lines and comments)
 
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  patterns+=("$line")
done < .gitignore

found_any=0

# Check each pattern
for pat in "${patterns[@]}"; do
  # Normalize: If the pattern is a directory, match anything inside
  if [[ "$pat" == */ ]]; then
    pat="${pat}*"
  fi

  matches=$(git ls-files | grep -F "$pat" || true)
  if [[ -n "$matches" ]]; then
    echo "❌ Tracked files matching ignored pattern [$pat]:"
    echo "$matches"
    found_any=1
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "✅ No ignored trash is tracked in Git. All clean!"
else
  echo "⚠️  Remove trash from Git:"
  echo "Example: git rm --cached <file>"
  exit 1
fi
