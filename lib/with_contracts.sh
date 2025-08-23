#!/usr/bin/env bash
 


 set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/lib/contract_env.sh"
. "$ROOT/lib/contract_fs.sh"

 
load_frame_() {
  local f="$1" line
  shopt -s extglob
 
  while IFS= read -r line || [[ -n $line ]]; do
    # strip CR (windows), trim comments, trim whitespace
    line=${line%$'\r'}
    line=${line%%#*}
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z $line ]] && continue

    # ignore bash no-ops like ": ..." or ": ${VAR:=...}"
    [[ $line == :* ]] && continue

    # allow simple scalar assignments for known keys
    case "$line" in
      FRAME_IGNORE_DIR_RE=*) FRAME_IGNORE_DIR_RE="${line#*=}"; continue;;
      WATCH_DIRS=*)          WATCH_DIRS="${line#*=}"; continue;;
    esac

    # allow only declare_* calls with plain args
    set -f                                # disable globbing
    read -r -a words <<<"$line"           # safe split
    set +f
    [[ ${#words[@]} -ge 1 ]] || continue

    case "${words[0]}" in
      declare_frame_env|declare_mutable_env|declare_frame)
        "${words[@]}"
        ;;
      *)
        printf 'invalid in frame: token=%q line=%q\n' "${words[0]}" "$line" >&2
        exit 250
        ;;
    esac
  done <"$f"
}

 
usage(){ echo "usage: $0 --frame FILE --contract FILE [--] CMD..."; }

parse_cli() {
  FRAMEFILE=""; CONTRACTFILE=""; CMD=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --frame)     [[ $# -ge 2 ]] || { usage; return 2; }; FRAMEFILE=$2; shift 2 ;;
      --contract)  [[ $# -ge 2 ]] || { usage; return 2; }; CONTRACTFILE=$2; shift 2 ;;
      --)          shift; CMD=("$@"); break ;;
      -*)          echo "unknown option: $1" >&2; usage; return 2 ;;
      *)           CMD=("$@"); break ;;
    esac
  done

  [[ -n $FRAMEFILE ]] || { echo "missing --frame" >&2; usage; return 2; }
  [[ -r $FRAMEFILE && -s $FRAMEFILE ]] || { echo "bad frame file: $FRAMEFILE" >&2; return 2; }

  if [[ -n $CONTRACTFILE ]]; then
    [[ -r $CONTRACTFILE && -s $CONTRACTFILE ]] || { echo "bad contract file: $CONTRACTFILE" >&2; return 2; }
  fi


  # Do NOT require CMD here. main() will resolve: CLI CMD > frame COMMAND.
}


  frame_snapshot(){ printf '%s:%s\n' "$(_ce_snapshot)" "$(_cf_snapshot)" | sha256sum | awk '{print $1}'; }
  abs() { case "$1" in /*) printf '%s\n' "$1";; *) printf '%s\n' "$PWD/$1";; esac; }

 
 
 
# Always read files via -- "$VAR"
rules_schema_valid()         { "$JQ_BIN" -e 'type=="array"' -- "$RULES_FILE"    >/dev/null; }


rules_have_unique_ids3() {
  dup="$(jq -r '.[].id' "$RULES_FILE" | LC_ALL=C sort | uniq -d)"
  [ -z "$dup" ]
}


# rules_declare_reads_writes3() {
#   : "${RULES_FILE:?RULES_FILE unset}"
#   [[ -r "$RULES_FILE" ]] || { echo "unreadable: $RULES_FILE"; return 2; }
#   jq -e '
#     if type=="array" then (map(has("reads") and has("writes")) | all) else false end
#   ' -- "$RULES_FILE" >/dev/null
# }

findings_normalized()        { "$JQ_BIN" -e 'type=="array"' -- "$FINDINGS_FILE" >/dev/null; }


main() {
  parse_cli "$@"



    . ./purity.sh || { echo "missing purity.sh"; return 2; }

enforce_contract_purity "$CONTRACTFILE" || exit 1

 export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]}: '
LOG="obs.$$.log"; exec {XFD}>>"$LOG"; export BASH_XTRACEFD=$XFD



JQ_BIN="$(command -v jq)"    || { echo "FATAL: jq not found"; return 127; }
HEAD_BIN="$(command -v head)"|| { echo "FATAL: head not found"; return 127; }
SED_BIN="$(command -v sed)"  || { echo "FATAL: sed not found"; return 127; }
DIFF_BIN="$(command -v diff)"|| { echo "FATAL: diff not found"; return 127; }
JQ_DIR="${JQ_BIN%/*}"
export JQ_BIN HEAD_BIN SED_BIN DIFF_BIN

  
 
 # JQ_BIN="$(command -v jq)" || { echo "jq not found" >&2; return 127; }
#export JQ_BIN
#jq() { "$JQ_BIN" "$@"; }
#export -f jq

#JQ_BIN="$(command -v jq)" || { echo "jq not found" >&2; return 127; }
#JQ_DIR="${JQ_BIN%/*}"

# after contracts_reset_env/contracts_reset_fs
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

  # --- make paths absolute, export ---
  abs(){ case "$1" in /*) printf '%s\n' "$1";; *) printf '%s\n' "$PWD/$1";; esac; }
  : "${FRAMEFILE:?missing --frame}"
  : "${CONTRACTFILE:?missing --contract}"
  : "${RULES_FILE:=${rules:?set rules=...}}"
  : "${FINDINGS_FILE:=${findings:?set findings=...}}"
  RULES_FILE="$(abs "$RULES_FILE")"
  FINDINGS_FILE="$(abs "$FINDINGS_FILE")"
  export RULES_FILE FINDINGS_FILE

RULES_FILE="${RULES_FILE:-./rules.json}"
 

 jq -e 'if type=="array"
       then true
       elif (type=="object" and has("rules") and (.rules|type)=="array")
       then true
       else error("rules must be array or object.rules")
       end' "$RULES_FILE"



 
  contracts_reset_env
  contracts_reset_fs

  # --- source order ---
  . ./contract_dsl.sh || { echo "missing contracts_dsl.sh"; return 2; }

  . ./queries.sh       || { echo "missing queries.sh"; return 2; }



  . "$FRAMEFILE"       || { echo "bad frame: $FRAMEFILE"; return 2; }

 
 
  . "$CONTRACTFILE"    || { echo "bad contract: $CONTRACTFILE"; return 2; }
 

  # --- resolve command: CLI > frame COMMAND ---
  local _cmd=("${CMD[@]-}")
  (( ${#_cmd[@]} == 0 )) && (( ${#COMMAND[@]-} > 0 )) && _cmd=("${COMMAND[@]}")

  # ===== PLACE THE GUARD RIGHT HERE =====
  (( ${#_cmd[@]} > 0 )) || { echo "empty _cmd"; return 2; }
 
  [[ -n ${_cmd[0]} ]]   || { echo "blank _cmd[0]"; return 2; }

  command -v -- "${_cmd[0]}" >/dev/null || { echo "not found: ${_cmd[0]}"; return 127; }
  # optional debug:
  # declare -p _cmd; printf 'argv0=<%q>\n' "${_cmd[0]}"



 
export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]}: '

set -x

 
pre || echo "pre rc=$?"
 
 
set +x



jq -e 'if type=="array"
       then true
       elif (type=="object" and has("rules") and (.rules|type)=="array")
       then true
       else error("rules must be array or object.rules")
       end' "$RULES_FILE"
 
  preh="$(frame_snapshot)"
 
  # ===== PLACE THE env -i LINE RIGHT HERE =====
  set +e

RULES_FILE="${RULES_FILE:-lib/rules.json}"
jq -e 'if type=="array"
       then true
       elif (type=="object" and has("rules") and (.rules|type)=="array")
       then true
       else error("rules must be array or object.rules")
       end' "$RULES_FILE"
  env -i PATH="$PATH" LANG="$LANG" TZ=UTC \
    RULES_FILE="$RULES_FILE" FINDINGS_FILE="$FINDINGS_FILE" \
    "${_cmd[@]}" >"$FINDINGS_FILE"
  rc=$?

  set -e

  echo "exit code was $rc"
  (( rc==0 )) || return "$rc"

  posth="$(frame_snapshot)"
  [[ "$preh" == "$posth" ]] || { echo "frame violated"; return 201; }
}



[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

