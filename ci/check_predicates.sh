#!/usr/bin/env bash
set -euo pipefail

# shellcheck shell=bash
# shellcheck source=ci/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

f=${1:-../lib/predicates.sh}
echo "[predicates] $f"
# forbid any external procs + FS tests
deny='stat|find|ls|cat|grep|sed|awk|readlink|file|du|wc|ps|date|kill|xargs|tr|cut|head|tail|tee|cmp|diff'
tests='\[\[.*-([efdLs])'  # -e -f -d -L -s etc.
strip_case_labels <"$f" | strip_comments | {
  tok_grep "$deny" && { echo "Forbidden commands in $f"; exit 1; } || :
  grep -nE "$tests" && { echo "FS tests in $f"; exit 1; } || :
}
echo "OK"

