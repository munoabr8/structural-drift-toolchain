#!/usr/bin/env bash
# purity: class=frames
# shellcheck shell=bash



 #DEBUG_FRAME=1 GATE=hash WRITES="evidence.json" ./frame.sh --root "$PWD" 
 #--rules "./rules.json" -- bash -c 'date +%s%N >> evidence.json'; echo $?


 SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

 echo "$SCRIPT_DIR"


set -euo pipefail

usage(){ echo "usage: $0 --root DIR --rules FILE [--path PATH] -- CMD [ARGS...]"; exit 2; }

E_ROOT=""
E_RULES_FILE="" 
E_PATH=${E_PATH_OVERRIDE:-}

while (($#)); do
  case ${1-} in
    --root)  E_ROOT=${2-}; shift 2;;
    --rules) E_RULES_FILE=${2-}; shift 2;;
    --path)  E_PATH=${2-}; shift 2;;
    --) shift; break;;
    *) usage;;
  esac
done
[[ -n ${E_ROOT:-} && -n ${E_RULES_FILE:-} ]] || usage

# default PATH if not provided
if [[ -z ${E_PATH:-} ]]; then
  if [[ -d /opt/homebrew/bin ]]; then base=/opt/homebrew/bin; else base=/usr/local/bin; fi
  E_PATH="$HOME/.local/bin:$base:/usr/bin:/bin:/usr/sbin:/sbin"
fi

# shape guard
[[ $E_PATH != *$'\n'* && $E_PATH != :* && $E_PATH != *::* && $E_PATH != *' '* ]] || { echo "bad PATH shape" >&2; exit 2; }

# sanitize PATH (drop missing/non-exec, dedupe)
path_sanitize() {
  local p=$1 IFS=: d acc=
  for d in $p; do
    [[ -d $d && -x $d ]] || continue
    case ":$acc:" in *":$d:"*) : ;; *) acc="${acc:+$acc:}$d" ;; esac
  done
  [[ -n $acc ]] || return 1
  printf '%s\n' "$acc"
}
 
 #q: DIR -> list of tools shadowed later in PATH
shadow_report() {
  local dir=$1 x bn other
  for x in "$dir"/*; do
    [[ -x $x && -f $x ]] || continue
    bn=${x##*/}
    other=$(PATH=${PATH#*:"$dir":} command -v -- "$bn" 2>/dev/null || true)
    [[ -n $other && $other != "$x" ]] && printf '%s -> %s\n' "$bn" "$other"
  done
}


 
E_PATH=$(path_sanitize "$E_PATH") || { echo "dirs missing/!x and nothing usable" >&2; exit 1; }


case "$E_RULES_FILE" in /*) ;; *) E_RULES_FILE="$E_ROOT/${E_RULES_FILE#./}";; esac
# validate root and rules
[[ -d $E_ROOT && -r $E_ROOT ]] || { echo "bad root: $E_ROOT" >&2; exit 1; }
[[ -f $E_RULES_FILE && -r $E_RULES_FILE ]] || { echo "bad rules file: $E_RULES_FILE" >&2; exit 1; }
 
export PATH="$E_PATH"
export E_ROOT E_RULES_FILE RULES_FILE="$E_RULES_FILE"

   
case ${GATE:-change} in
  off)    gate=off   metric=none ;;
  exist)  gate=exist metric=mtime,size ;;
  change) gate=change metric=mtime,size ;;
  hash)   gate=change metric=sha256 ;;
  *) echo "invalid GATE=$GATE" >&2; exit 2 ;;
esac

# log environment (to stderr)
printf 'E_ROOT=%q E_RULES_FILE=%q PATH=%q\n' "$E_ROOT" "$E_RULES_FILE" "$PATH" >&2

# ---- minimal implicit no-change gate ----
derive_writes_from_args(){
  local w=() i=1
  while (( i <= $# )); do
    case "${!i}" in
      --out|--output|--dst)
        (( i+1 <= $# )) || { echo "missing value for ${!i}" >&2; exit 2; }
        ((i++)); w+=("${!i}") ;;
      --out=*|--output=*|--dst=*)
        w+=("${!i#*=}") ;;
    esac
    ((i++))
  done
  printf '%s\n' "${w[@]}"
}

 
_snap(){ local s=() p; for p in "$@"; do s+=("$p|$(_stat2 "$p")"); done; printf '%s\n' "${s[@]}"; }



# snapshot functions
_stat2(){ [[ -e $1 ]] || { printf MISSING; return; }
          stat -f '%m,%z' -- "$1" 2>/dev/null || stat -c '%Y,%s' -- "$1" 2>/dev/null; }
_snap_stat(){ local p; for p in "$@"; do printf '%s|%s\n' "$p" "$(_stat2 "$p")"; done; }
_snap_sha(){  local p h
  for p in "$@"; do
    if [[ -f $p ]]; then
      if command -v sha256sum >/dev/null; then h=$(sha256sum -- "$p" | awk '{print $1}')
      elif command -v shasum   >/dev/null; then h=$(shasum -a 256 -- "$p" | awk '{print $1}')
      else h=$(openssl dgst -sha256 -r -- "$p" | awk '{print tolower($1)}'); fi
      printf '%s|%s\n' "$p" "$h"
    else
      printf '%s|MISSING\n' "$p"
    fi
  done
}

# allowed outputs = predeclared WRITES + derived flags
#mapfile -t _drv < <(derive_writes_from_args "$@")
#ALLOW=( "${WRITES[@]:-}" "${_drv[@]}" )

ALLOW=()
if [[ -n ${WRITES:-} ]]; then IFS=': ' read -r -a _env_w <<<"$WRITES"; ALLOW+=("${_env_w[@]}"); fi
mapfile -t _drv < <(derive_writes_from_args "$@"); ALLOW+=("${_drv[@]}")

# clean + anchor
_clean=(); for p in "${ALLOW[@]}"; do [[ -n $p ]] || continue; p=${p#\(}; p=${p%\)}; _clean+=("$p"); done
_abs=();   for p in "${_clean[@]}"; do case $p in /*) _abs+=("$p");; *) _abs+=("$E_ROOT/$p");; esac; done
ALLOW=("${_abs[@]}")
#printf 'ALLOW:\n'; printf '  %s\n' "${ALLOW[@]}" >&2



snap=_snap_stat
[[ $metric == sha256 ]] && snap=_snap_sha

# optional log
[[ ${DEBUG_FRAME:-0} -eq 1 ]] && printf 'frame: gate=%s metric=%s writes=%s\n' "$gate" "$metric" "$(IFS=,; echo "${ALLOW[*]}")" >&2


 

case $gate in
  off)
    "$@"; exit $?
    ;;
  exist)
    "$@"; rc=$?
    if (( rc==0 && ${#ALLOW[@]}>0 )); then
      for p in "${ALLOW[@]}"; do [[ -e $p ]] || { echo "missing: $p" >&2; exit 91; }; done
    fi
    exit $rc
    ;;
  change)
    PRE=$($snap "${ALLOW[@]}")
    "$@"; rc=$?
    POST=$($snap "${ALLOW[@]}")
    if (( rc==0 && ${#ALLOW[@]}>0 )); then
      changed=$(
        join -t '|' -a1 -a2 -e '' -o 0,1.2,2.2 \
          <(printf '%s\n' "$PRE"  | LC_ALL=C sort) \
          <(printf '%s\n' "$POST" | LC_ALL=C sort) \
        | awk -F'|' '$2!=$3{c++} END{print c+0}'
      )
      (( changed>0 )) || { echo 'frame: no declared outputs changed' >&2; exit 91; }
    fi
    exit $rc
    ;;
esac


 
 


 
 

 

#if (($#)); then exec "$@"; else exec "${SHELL:-/bin/bash}"; fi
