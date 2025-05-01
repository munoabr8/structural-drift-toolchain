#!/usr/bin/env bash
#set -euo pipefail

echo "🔍 CWD: $(pwd)"
echo "🔍 .structure.ignore contents:"
cat .structure.ignore

IGNORE_FILE=".structure.ignore"

echo "🚮 Validating .structure.ignore..."

if [ ! -f "$IGNORE_FILE" ]; then
  echo "❌ .structure.ignore missing!"
  exit 1
fi

if [ ! -s "$IGNORE_FILE" ]; then
  echo "❌ .structure.ignore is empty!"
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue  # Skip empty lines
  if [ ! -e "$line" ]; then
    echo "❌ Ignored path does not exist: $line"
    exit 1
  fi
done < "$IGNORE_FILE"

echo "✅ .structure.ignore is valid."
