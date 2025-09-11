#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck shell=bash
# ci/check_queries.sh — fail if queries perform writes/mutations

set -euo pipefail


script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"

f=${1:-"$repo_root/lib/queries.sh"}


echo "[queries] $f"




 
 


# 1) Forbid mutating commands. Allow pipes and ||.
deny_cmds='rm|mv|cp|chmod|chown|mkdir|rmdir|ln|truncate|tee'
if out=$(strip_case_labels <"$f" | strip_comments | tok_grep "$deny_cmds"); then
  printf '%s\n' "$out"
  printf 'Writes/mutation commands found in %s\n' "$f" >&2
  exit 1
fi

# 2) Forbid write redirections except to /dev/null and FD dup (>&2 etc.).
#    Catches: >  >>  >|  optional FD prefixes, and leaves /dev/null alone.
if out=$(
  strip_case_labels <"$f" | strip_comments \
  | grep -nE '(^|[[:space:]])[0-9]{0,2}>(\||>)?' \
  | grep -vE '/dev/null|>&[0-9]'
); then
  if [[ -n $out ]]; then
    printf '%s\n' "$out"
    printf 'Write redirection found in %s\n' "$f" >&2
    exit 1
  fi
fi

# 3) Forbid process-substitution writes: >(cmd) with optional space.
if out=$(
  strip_case_labels <"$f" | strip_comments \
  | grep -nE '(^|[[:space:]])[0-9]{0,2}>[[:space:]]*\('
); then
  if [[ -n $out ]]; then
    printf '%s\n' "$out"
    printf 'Process-substitution write found in %s\n' "$f" >&2
    exit 1
  fi
fi

echo "OK"
