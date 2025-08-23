# tools/run-table.sh
#!/usr/bin/env bash
set -o pipefail
#exec </dev/null     # <-- neuter stdin for the whole runner


set -euo pipefail
. ./predicates.sh
. ./enums.sh
 set -u
set -o pipefail
# no -e while debugging
echo "start: $$"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
 


 
set -o pipefail
set +u
. "$ROOT/predicates.sh"; echo "sourced: predicates"
. "$ROOT/enums.sh";      echo "sourced: enums"

 set -u


tsv="${1:-}"; [[ -n $tsv ]] || { echo "no arg"; exit 2; }
[[ -r $tsv ]] || { echo "not readable: $tsv"; exit 2; }
echo "file: $(wc -l <"$tsv") lines"


 
verbose=${VERBOSE:-0}
pass=0; fail=0

norm() { printf '%s' "$1" | tr -d ' \t\r' ; }



#map_kind(){ case "$1" in tty) echo "$STDIN_TTY";; pipe) echo "$STDIN_PIPE";; file) echo "$STDIN_FILE";; *) echo "$STDIN_UNKNOWN";; esac; }



trim(){ sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
  lower() { LC_ALL=C printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
 
 
run_file() {

  local tsv=$1
  echo "file: $(wc -l <"$tsv") lines  $tsv"
  exec 3<"$tsv"
  local raw left expect s w r b e pref file kind k
  while IFS= read -r raw <&3 || [[ -n ${raw-} ]]; do
    left=${raw%%|*}; expect=${raw#*|}
    left=$(printf '%s' "$left" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z $left || ${left#\#} != "$left" ]] && continue
    if [[ "$raw" != *"|"* ]]; then
      set -- $left; expect=${!#}; left=${left%$expect}; left=${left%[[:space:]]}
    else
      expect=$(tr -d ' \t\r' <<<"$expect")
    fi
    case "$expect" in 0|1|2) ;; *) expect=2 ;; esac

    set -- $left
    case "$1" in
      0|1)  # should_read_stdin: want kind ready block empty
        w=$(norm "$1"); kind=$(lower "$(norm "${2:-}")"); r=$(norm "${3:-}"); b=$(norm "${4:-}"); e=$(norm "${5:-}")
        k="$kind"
        if is_bool01 "$w" && is_bool01 "$r" && is_bool01 "$b" && is_bool01 "$e" && is_stdin_kind "$k"; then
          s=0; should_read_stdin "$w" "$k" "$r" "$b" "$e" || s=$?
        else
          s=2
        fi
        [[ ${VERBOSE:-0} -eq 1 ]] && echo "$left -> $s (expect $expect)"
        ;;
      *)    # prefer_stdin: file prefer kind ready
        file="$1"; pref=$(norm "${2:-}"); kind=$(lower "$(norm "${3:-}")"); r=$(norm "${4:-}")
        k="$kind"
        if is_bool01 "$pref" && is_bool01 "$r" && is_stdin_kind "$k"; then
          s=0; prefer_stdin "$file" "$pref" "$k" "$r" || s=$?
        else
          s=2
        fi
        [[ ${VERBOSE:-0} -eq 1 ]] && echo "$left -> $s (expect $expect)"
        ;;
    esac

    if [[ "$s" == "$expect" ]]; then
      pass=$((pass+1))
    else
      fail=$((fail+1))
      printf 'FAIL: %s -> %s != %s\n' "$left" "$s" "$expect" >&2
    fi
  done
  exec 3<&-
}

# Yes, but only if nothing in the runner (or sourced libs) ever reads from stdin.

# Keep it if:

# any helper might call read, cat, head, tr without a file/FD

# you use process substitutions or commands that could touch FD 0

# If you want to scope it tighter, do:
#run_file_future(){

#    local tsv=$1
#   exec 3<"$tsv"
#   { exec </dev/null    # neuter stdin only inside the loop
#     while IFS= read -r raw <&3 || [[ -n ${raw-} ]]; do
#       # ...
#     done
#   }
#   exec 3<&-
 
# }



pass=0; fail=0
for f in "$@"; do run_file "$f"; done
echo "pass=$pass fail=$fail"
