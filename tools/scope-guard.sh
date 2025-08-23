#!/usr/bin/env bash
# tools/scope_guard.sh
set -euo pipefail
shopt -s nullglob globstar


# discover SCOPE if not set
   ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
 # Exit codes: 0 ok, 3 violations, 4 missing deps/config

BASE=${BASE:-origin/main}

SCOPE="${SCOPE:-$ROOT/scope.yaml}"
[[ -f "$SCOPE" ]] || { echo "Error: open $SCOPE: no such file or directory"; exit 2; }
yq -e '.in_scope | length > 0' "$SCOPE" >/dev/null || { echo "scope_guard: no in_scope entries in scope.yaml"; exit 2; }

 
[[ -f "${SCOPE:-}" ]] || { echo "Error: open ${SCOPE:-<unset>}: no such file or directory"; exit 2; }


# Exit codes: 0 ok, 3 violations, 4 missing deps/config
 

echo "DEBUG SCOPE=$SCOPE"
yq -r '.in_scope' "$SCOPE"

need(){ command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 4; }; }
need yq; need git

# load in-scope
mapfile -t IN < <(yq -r '.in_scope[]?' "$SCOPE" || true)
((${#IN[@]})) || { echo "scope_guard: no in_scope entries in $SCOPE" >&2; exit 4; }

match_any() {
  local p="$1"
  for g in "${IN[@]}"; do [[ $p == $g ]] && return 0; done
  return 1
}

# build a generator that yields NUL-separated diff records
gen_diff() {
  if [[ "$BASE" == "HEAD" ]]; then
    # 1) staged
    git diff --name-status -z --cached
    # 2) if nothing staged, also check working tree (helps smoke tests)
    if [[ -z "$(git diff --name-only --cached)" ]]; then
      git diff --name-status -z
    fi
  else
    git diff --name-status -z "$BASE"...HEAD
  fi
}

viol=0
# records: "S<TAB>PATH" or "Rxxx<TAB>OLD<TAB>NEW"
while IFS= read -r -d '' rec; do
  [[ -z "$rec" ]] && continue
  IFS=$'\t' read -r status path maybe_new <<<"$rec" || continue
  [[ -z "${status:-}" ]] && continue
  [[ $status == D* ]] && continue
  [[ $status == R* ]] && path="$maybe_new"
  [[ -z "${path:-}" ]] && continue

  if ! match_any "$path"; then
    echo "UNMAPPED: $path"
    viol=3
  fi
done < <(gen_diff)

((viol==0)) && echo "scope_guard: ok"
exit "$viol"
