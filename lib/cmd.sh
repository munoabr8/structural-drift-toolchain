#!/usr/bin/env bash
# bin/cmd.sh

set -euo pipefail

# shellcheck source-path=ROOT
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)"


 # shellcheck source=../lib/queries.sh
. "$ROOT/lib/queries.sh"
  # shellcheck source=../lib/predicates.sh
. "$ROOT/lib/predicates.sh"
 # shellcheck source=../lib/trace.sh
. "$ROOT/lib/trace.sh"

echo "$ROOT"


# facts
k="$(q_stdin_kind)"           # tty|pipe|file|unknown
r="$(q_stdin_ready)"          # 0|1 (non-blocking readiness)
out="$(q_stderr_is_tty)"      # 0|1
fact stdin_kind "$k"
fact stdin_ready "$r"
fact stderr_tty "$out"


case "$k" in tty) allow_block=1; allow_empty=0 ;; pipe|file) allow_block=0; allow_empty=1 ;; *) allow_block=0; allow_empty=0 ;; esac
# # policy knobs by stdin kind
# case "$k" in
#   tty)       allow_block=0; allow_empty=0 ;;
#   pipe|file) allow_block=0; allow_empty=1 ;;
#   *)         allow_block=0; allow_empty=0 ;;
# esac

# decision
s=0; should_read_stdin 1 "$k" "$r" "$allow_block" "$allow_empty" || s=$?
dec should_read_stdin "$s" "want=1 kind=$k ready=$r block=$allow_block empty=$allow_empty"

# action
if (( s==0 )); then
  cat
fi





main(){


echo "dfkjflkdj"


}
