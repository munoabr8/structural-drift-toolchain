#!/usr/bin/env bash
# Minimal churn by layer. Default window: 30.days
set -euo pipefail
shopt -s nullglob globstar dotglob

since="${1:-30.days}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
SCOPE="${SCOPE:-$ROOT/scope.yaml}"

command -v yq >/dev/null
command -v git >/dev/null

# Load layer→glob as real TSV rows (layer<TAB>glob)
mapfile -t MAP < <(
  yq -r '.layer_map | to_entries[] | .key as $k | .value[] | [$k, .] | @tsv' "$SCOPE"
)

layer_of() { # echo first matching layer, else UNMAPPED
  local p="$1" row layer glob
  for row in "${MAP[@]}"; do
    IFS=$'\t' read -r layer glob <<<"$row"
    [[ $p == $glob ]] && { echo "$layer"; return 0; }
  done
  echo "UNMAPPED"
}

declare -A agg=()
while read -r cnt path; do
  [[ -z "${path:-}" ]] && continue
  L=$(layer_of "$path")
  agg["$L"]=$(( ${agg["$L"]:-0} + cnt ))
done < <(git log --since="$since" --name-only --pretty=format: | awk 'NF' | sort | uniq -c)

printf "churn (since=%s)\n" "$since"
for k in "${!agg[@]}"; do printf "%8d  %s\n" "${agg[$k]}" "$k"; done | sort -nr
