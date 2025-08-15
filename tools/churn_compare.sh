#!/usr/bin/env bash
# tools/churn_compare.sh  <refA> <refB>
# Example: tools/churn_compare.sh origin/main HEAD
set -euo pipefail
shopt -s nullglob globstar dotglob



refA="${1:?need refA}"   # e.g., origin/main
refB="${2:?need refB}"   # e.g., HEAD

base=$(git merge-base "$refA" "$refB")  # or: git merge-base --fork-point "$refA" "$refB"


ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
SCOPE="${SCOPE:-$ROOT/scope.yaml}"

command -v yq >/dev/null
command -v git >/dev/null

# load layer->glob TSV
mapfile -t MAP < <(yq -r '.layer_map | to_entries[] | .key as $k | .value[] | [$k,.] | @tsv' "$SCOPE")

layer_of() {
  local p="$1" row layer glob
  for row in "${MAP[@]}"; do IFS=$'\t' read -r layer glob <<<"$row"
    [[ $p == $glob ]] && { echo "$layer"; return; }
  done
  echo "UNMAPPED"
}

agg_range() { # $1=range "X..Y"
  declare -A agg=()
  while read -r _ path; do
    [[ -z $path ]] && continue
    L=$(layer_of "$path")
    agg["$L"]=$(( ${agg["$L"]:-0} + 1 ))
  done < <(git diff --name-status "$1" | awk 'NF==2 && $1!="D"')
  for k in "${!agg[@]}"; do printf "%s\t%d\n" "$k" "${agg[$k]}"; done
}
# collect
mapfile -t A < <(agg_range "$base..$refB")
mapfile -t B < <(agg_range "$refB~1..$refB" || true)

# join on layer
{
  printf "layer\tall_changes(%s..%s)\tlast_commit(%s)\n" "$refA" "$refB" "$refB"
  join -t $'\t' -a1 -a2 -e 0 -o 0,1.2,2.2 \
    <(printf "%s\n" "${A[@]}" | sort) \
    <(printf "%s\n" "${B[@]}" | sort)
} | column -t







 