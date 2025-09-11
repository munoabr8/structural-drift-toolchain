#!/usr/bin/env bash
# ./ci/check_frames.sh
set -euo pipefail
LC_ALL=C LANG=C TZ=UTC

SD="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./checklib.sh
. "$SD/checklib.sh"

REPO_ROOT="$(git -C "$SD" rev-parse --show-toplevel 2>/dev/null || echo "$SD")"

# collect files safely
files=()
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r -d '' rel; do
    abs="$REPO_ROOT/$rel"
    [[ -r $abs ]] && files+=("$abs")
  done < <(git -C "$REPO_ROOT" ls-files -z -- 'lib/frame.sh' 2>/dev/null || true)
fi
if ((${#files[@]}==0)); then
  abs="$REPO_ROOT/lib/frame.sh"
  [[ -r $abs ]] && files+=("$abs")
fi
((${#files[@]})) || { echo 'no lib/frame.sh found' >&2; exit 0; }

need='(--root.*--rules.*--|--rules.*--root.*--)'
ban='(\brm\b|\bmv\b|\bcp\b|[0-9]*>>?|>\|)'

run_check "$need" "$ban" pre_frame "${files[@]}"
