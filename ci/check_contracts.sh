#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fns=$(git ls-files '../lib/*.contract.sh' 2>/dev/null || echo ./lib/*.contract.sh)
ok=1
for f in $fns; do
  echo "[contract] $f"
  
forbid='(>[^>]|>>|rm|mv|cp|chmod|chown|mkdir|rmdir|ln|tee|truncate|sed[[:space:]]+-i|perl[[:space:]]+-i|ed|curl|wget|nc|ssh)'
  strip_case_labels <"$f" | strip_comments \
  | tok_grep "$forbid" && { echo "Forbidden ops in $f"; ok=0; } || echo "OK"
done
exit $ok

