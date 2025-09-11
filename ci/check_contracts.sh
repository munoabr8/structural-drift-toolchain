#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob


# shellcheck source-path=SCRIPTDIR
# shellcheck source=./lib.sh

 

# Inputs: repo files under lib/*.contract.sh
# Output: report lines + exit 0 if all OK, 1 if any violation/preprocess error.

LC_ALL=C LANG=C TZ=UTC

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR")"

# helpers: strip_case_labels, strip_comments, tok_grep must live here
. "$SCRIPT_DIR/lib.sh"

# Build file list: prefer git index, fall back to glob
mapfile -d '' -t files < <(git -C "$REPO_ROOT" ls-files -z -- 'lib/*.contract.sh' 2>/dev/null || true)
((${#files[@]})) || files=("$REPO_ROOT"/lib/*.contract.sh)

# Forbid: redirections and mutating/dangerous commands
forbid='([0-9]*>>?|>\|)|\brm\b|\bmv\b|\bcp\b|\bchmod\b|\bchown\b|\bmkdir\b|\brmdir\b|\bln\b|\btee\b|\btruncate\b|sed[[:space:]]+-i\b|perl[[:space:]]+-i\b|\bed\b|\bcurl\b|\bwget\b|\bnc\b|\bssh\b'

ok=0
scanned=0
bad=0

for f in "${files[@]}"; do
  [[ -r "$f" ]] || continue
  rel="${f#"$REPO_ROOT"/}"
  echo "[contract] ${rel}"
  scanned=$((scanned+1))

  # Preprocess separately so failures are caught
  if ! pre="$(strip_case_labels <"$f" | strip_comments)"; then
    echo "Preprocess failed: ${rel}"
    ok=1
    continue
  fi

  if tok_grep "$forbid" <<<"$pre"; then
    echo "Forbidden ops in ${rel}"
    bad=$((bad+1))
    ok=1
  else
    echo "OK"
  fi
done

echo "Scanned: $scanned  Violations: $bad"
exit "$ok"

