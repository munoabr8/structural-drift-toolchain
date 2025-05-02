#!/usr/bin/env bash
#set -euo pipefail

echo "🔎 Scanning for duplicate Makefile targets..."

declare -A seen
declare -A duplicates

# Extract targets (lines like: target-name:) from all .mk files
for file in $(find ./../system/make -name '*.mk'); do
  while IFS= read -r line; do
    # Only consider lines ending in colon (":") that aren't indented or special
    if [[ "$line" =~ ^([a-zA-Z0-9._-]+): ]]; then
      target="${BASH_REMATCH[1]}"
      key="$target:$file"
      if [[ -n "${seen[$target]+set}" ]]; then
        duplicates["$target"]+="$file"$'\n'
      else
        seen["$target"]="$file"
      fi
    fi
  done < "$file"
done

# Report
if [[ ${#duplicates[@]} -eq 0 ]]; then
  echo "✅ No duplicate targets found across .mk files."
else
  echo "❌ Duplicate targets detected:"
  for tgt in "${!duplicates[@]}"; do
    echo "  • $tgt:"
    echo "${duplicates[$tgt]}" | sed 's/^/      ↪︎ /'
  done
  exit 1
fi

