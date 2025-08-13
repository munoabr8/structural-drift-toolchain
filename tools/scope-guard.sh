#!/usr/bin/env bash

# tools/scope_guard.ss
set -euo pipefail
shopt -s nullglob globstar

SCOPE=${SCOPE:-./../scope.yaml}
BASE=${BASE:-origin/main}

need(){ command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 4; }; }
need yq; need git

mapfile -t IN < <(yq -r '.in_scope[]?' "$SCOPE")

# NUL-separated: STATUS<TAB>PATH(…maybe\tOLDPATH for renames)
readarray -d '' RECS < <(git diff --name-status -z "$BASE"...HEAD)

match_any() { # arg: path
  local p="$1"
  for g in "${IN[@]}"; do [[ "$p" == $g ]] && return 0; done
  return 1
}

viol=0
for rec in "${RECS[@]}"; do
  [[ -z "$rec" ]] && continue
  status=${rec%%$'\t'*}
  rest=${rec#*$'\t'}
  # handle rename: "R100\told\tnew"
  if [[ "$status" == R* ]]; then
    IFS=$'\t' read -r _ _ new <<<"$rec"
    path="$new"
  else
    path="$rest"
  fi
  [[ "$status" == D ]] && continue
  if ! match_any "$path"; then
    echo "UNMAPPED: $path"
    viol=3
  fi
done

[[ $viol -eq 0 ]] && echo "scope_guard: ok"
exit "$viol"
