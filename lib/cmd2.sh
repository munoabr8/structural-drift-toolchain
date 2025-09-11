#shellcheck shell=bash 
# cmd.sh — wiring example (no prints inside predicates)
set -euo pipefail
. ./queries.sh
. ./predicates.sh

file_arg=${1-}             # optional path or "-"
want_read=1                 # policy knob
allow_block=0               # do not block on tty
allow_empty=0               # do not accept empty stdin
prefer=1                    # prefer stdin when sensible

# facts
stdin_kind=$(
  stdin_is_tty  && echo "$STDIN_TTY"  || \
  stdin_is_pipe && echo "$STDIN_PIPE" || \
  stdin_is_file && echo "$STDIN_FILE" || echo "$STDIN_UNKNOWN"
)
stdin_ready=$({ stdin_has_data_nb >/dev/null && echo 1; } || echo 0)

# decision
if prefer_stdin "$file_arg" "$prefer" "$stdin_kind" "$stdin_ready" \
   && should_read_stdin "$want_read" "$stdin_kind" "$stdin_ready" "$allow_block" "$allow_empty"
then
  # action: consume stdin
  data=$(cat)
else
  [[ -n ${file_arg-} ]] && file_readable "$file_arg" || { echo "no input" >&2; exit 1; }
  data=$(cat -- "$file_arg")
fi

printf '%s\n' "$data"  # do something with it

