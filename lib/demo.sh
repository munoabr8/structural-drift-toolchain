#!/usr/bin/env bash
set -euo pipefail

 SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

# guarded sourcing
. "$ROOT/lib/queries.sh"     || { echo "load queries.sh failed" >&2; exit 2; }
. "$ROOT/lib/predicates.sh"  || { echo "load predicates.sh failed" >&2; exit 2; }


#q_stdout_is_tty q_stderr_is_tty
out_tty=$(q_stderr_is_tty)   # query: 1 if stdout is a TTY, else 0
if safe_to_prompt "$out_tty"; then
  printf 'Prompt> ' >&2      # stderr
fi
echo "DATA"    
