#!/usr/bin/env bash
#.lib/policy/c
set -euo pipefail

[[ "${_TRANSFORM_P2_LOADED:-0}" -eq 1 ]] && return 0 || readonly _TRANSFORM_P2_LOADED=1
 

# Adapter 1: streaming interface (replacement for select_input_source)
# Usage: select_input_source [FILE|-] [ALLOW_EMPTY=1]
# Preconditions/Invariants/Post enforced version
# Assumes: require, invariant, ensure, is_bool, _die are defined.

args_le() { (( $1 <= $2 )); }                    # args_le "$#" 2
src_is_streamable() { [[ $1 == stdin || $1 == file:* ]]; }

select_input_source() {
  local file="${1:-}" allow="${2:-1}" strict="${STRICT_SRC:-0}"

  # PRE
  _pre is_bool "$allow"                            "ALLOW_EMPTY must be 0|1"
  _pre is_bool "$strict"                           "STRICT_SRC must be 0|1"
  _pre args_le "$#" 2                              "usage: select_input_source [FILE|-] [ALLOW_EMPTY]"
  if (( strict )) && [[ -n "$file" ]]; then
    _pre is_tty_stdin                              "both file and stdin provided"
  fi

  # CALL (binds stdin; sets IN_SRC/IN_TMP/IN_PATH)
  resolve_input "$file" "$allow" stream

  # INVARIANTS (stream mode)
  _inv is_empty "${IN_PATH:-}"                     "IN_PATH must be empty in stream mode"
  _inv src_is_streamable "${IN_SRC:-}"             "IN_SRC must be stdin or file:*"

  # POST
  _post stdin_present                              "stdin must be bound (not a TTY)"
  if [[ "${IN_SRC:-}" == file:* ]]; then
    local p="${IN_SRC#file:}"
    _post is_readable "$p"                         "source file unreadable"
  fi
  if [[ -n "${IN_TMP:-}" ]]; then
    _post is_readable "$IN_TMP"                    "IN_TMP unreadable"
    (( allow == 0 )) && _post is_nonempty_file "$IN_TMP" "stdin empty"
  fi
  return 0
}

# Minimal contract helpers (no eval)
_pre()  { local msg="${*: -1}"; "${@:1:$#-1}" || _die pre  "$msg" 97; }
_inv()  { local msg="${*: -1}"; "${@:1:$#-1}" || _die inv  "$msg" 96; }
_post() { local msg="${*: -1}"; "${@:1:$#-1}" || _die post "$msg" 95; }

# Predicates used
is_bool()           { [[ $1 == 0 || $1 == 1 ]]; }
matches()           { [[ $1 =~ $2 ]]; }
is_readable()       { [[ -r $1 ]]; }
is_nonempty()       { [[ -n $1 ]]; }
is_empty()          { [[ -z $1 ]]; }
is_nonempty_file()  { [[ -s $1 ]]; }
is_tty_stdin()      { [[ -t 0 ]]; }   # true if no piped stdin
stdin_ready() { read -t 0 -N 0; }   # success if data is available
stdin_present() { [[ ! -t 0 ]]; }

_die(){ printf 'contrac222222t:%s:%s\n' "$1" "$2" >&2; exit "${3:-99}"; }
require()    { eval "$1" || _die pre  "$2" 97; }
ensure()     { eval "$1" || _die post "$2" 98; }


is_file_r()  { [[ -f "$1" && -r "$1" ]]; }
# --- validators for this filter ---
_valid_mode(){ [[ "$1" == "literal" || "$1" == "regex" ]]; }
_has_5(){ awk -F'|' 'NF!=5{exit 1} END{exit 0}'; }   # used post-hoc




resolve_input() {
  local arg="${1:-}" allow="${2:-1}" mode="${3:-stream}" strict="${STRICT_SRC:-0}"

  # Preconditions
  _pre is_bool "$allow"                 "ALLOW_EMPTY must be 0|1"
  _pre is_bool "$strict"                "STRICT_SRC must be 0|1"
  _pre matches "$mode" '^(stream|path)$' "MODE must be stream|path"

  IN_SRC=""; IN_TMP=""; IN_PATH=""

  if [[ -z "$arg" || "$arg" == "-" ]]; then
    # stdin case
    if (( allow == 0 )) || [[ "$mode" == path ]]; then
      IN_TMP="$(mktemp -t in.stdin.XXXXXX)" || _die pre "mktemp failed" 97
      cat >"$IN_TMP"
      (( allow == 0 )) && _pre is_nonempty_file "$IN_TMP" "stdin empty"
      IN_SRC="stdin"
      if [[ "$mode" == stream ]]; then
        exec <"$IN_TMP"
      else
        IN_PATH="$IN_TMP"
        _pre is_readable "$IN_PATH" "tmp unreadable"
      fi
    else
      _pre stdin_present "no stdin and no file"
      IN_SRC="stdin"  # stream, empty allowed
      # stdin passes through unchanged
    fi
  else
    # file case
    _pre is_readable "$arg" "unreadable: $arg"
    (( strict )) && [[ ! -t 0 ]] && _die pre "both file and stdin provided" 97
    (( allow == 0 )) && _pre is_nonempty_file "$arg" "file empty: $arg"
    IN_SRC="file:$arg"
    if [[ "$mode" == stream ]]; then exec <"$arg"; else IN_PATH="$arg"; fi
  fi

  # Invariants
  _inv is_nonempty "$IN_SRC" "IN_SRC must be set"
  if [[ "$mode" == stream ]]; then
    _inv is_empty "${IN_PATH:-}" "IN_PATH must be empty in stream mode"
  else
    _inv is_nonempty "$IN_PATH"          "IN_PATH must be set in path mode"
    _inv is_readable "$IN_PATH"          "IN_PATH must be readable"
    (( allow == 0 )) && _inv is_nonempty_file "$IN_PATH" "IN_PATH must be nonempty when allow=0"
  fi

  # Postconditions
  if [[ "$mode" == path ]]; then
    _post is_readable "$IN_PATH"         "post: IN_PATH not readable"
    (( allow == 0 )) && _post is_nonempty_file "$IN_PATH" "post: IN_PATH empty"
  fi
}


 
 no_args()         { [[ $# -eq 0 ]]; }
nonblank()        { [[ -n "${1//[[:space:]]/}" ]]; }
valid_mode()      { [[ $1 == literal || $1 == regex ]]; }

# transform_policy_rules2: stdin TSV/pipe → stdout pipe with 5 fields
 transform_policy_rules2() {
  _pre no_args "$@"                "no arguments supported"
  _pre stdin_present               "stdin required"

  local line type path condition action mode extra

  infer_mode() { [[ $1 =~ [][(){}^$*+?|\\] ]] && echo regex || echo literal; }

  while IFS= read -r line; do
    # normalize and skip noise
    line=${line%$'\r'}
    nonblank "$line" || continue
    [[ $line == event\|* ]] && continue

    if [[ $line == *$'\t'* ]]; then
      IFS=$'\t' read -r type path condition action mode extra <<<"$line"
      [[ -n ${extra:-} || -z ${type:-} || -z ${path:-} || -z ${condition:-} || -z ${action:-} ]] \
        && _die pre "invalid TSV shape" 65
    elif [[ $line == *'|'* ]]; then
      IFS='|' read -r type path condition action mode extra <<<"$line"
      [[ -n ${extra:-} || -z ${type:-} || -z ${path:-} || -z ${condition:-} || -z ${action:-} ]] \
        && _die pre "invalid pipe shape" 65
    else
      _die pre "invalid record: $(printf %q "$line")" 65
    fi

    [[ -n ${mode:-} ]] || mode="$(infer_mode "$path")"
    _inv valid_mode "$mode" "mode must be literal|regex"

    printf '%s|%s|%s|%s|%s\n' "$type" "$path" "$condition" "$action" "$mode"
  done
}
 
 
args_le()      { (( $1 <= $2 )); }                      # args_le "$#" 1
valid_mode()   { [[ $1 == literal || $1 == regex ]]; }
 
has_valid_shape() {
  local t p c a m extra
  IFS='|' read -r t p c a m extra <<<"$1"
  # require first 4 fields nonempty and no extra fields;
  # allow missing mode or mode ∈ {literal,regex}
  [[ -n $t && -n $p && -n $c && -n $a && -z ${extra+x} ]] &&
  [[ -z ${m:-} || $m == literal || $m == regex ]]
}


has_fields_between() {
  local line=$1 min=$2 max=$3 count=1
  while [[ $line == *"|"* ]]; do
    line=${line#*"|"}   # strip up to first '|'
    ((count++))
  done
  (( count >= min && count <= max ))
}

main() {
  _pre args_le "$#" 1 "usage: main [FILE|-]"

  select_input_source "${1:-}" 1

  local out
  out="$(transform_policy_rules2)"

  # Postconditions: each line has 4 or 5 fields, mode valid if present
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
_post has_fields_between "$line" 4 5 "line must have 4 or 5 fields"
  done <<<"$out"
echo "---------------..,,.,.,.,."
  printf '%s\n' "$out"
  return 0
}

 

 

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"