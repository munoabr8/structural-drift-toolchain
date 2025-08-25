#!/usr/bin/env bash
# purity: class=frames
# shellcheck shell=bash

 SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

 echo "$SCRIPT_DIR"


set -euo pipefail

usage(){ echo "usage: $0 --root DIR --rules FILE [--path PATH] -- CMD [ARGS...]"; exit 2; }

E_ROOT= E_RULES_FILE= E_PATH=${E_PATH_OVERRIDE:-}

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
  local dir=$1; shift
  command -v >/dev/null || return 0  # shell builtin exists
  for x in "$dir"/*; do
    [[ -x $x && -f $x ]] || continue
    bn=${x##*/}; other=$(PATH=${PATH#*:$dir:} command -v -- "$bn" || true)
    [[ -n $other ]] && printf '%s -> %s\n' "$bn" "$other"
  done
}

 
E_PATH=$(path_sanitize "$E_PATH") || { echo "dirs missing/!x and nothing usable" >&2; exit 1; }


case "$E_RULES_FILE" in /*) ;; *) E_RULES_FILE="$E_ROOT/${E_RULES_FILE#./}";; esac
# validate root and rules
[[ -d $E_ROOT && -r $E_ROOT ]] || { echo "bad root: $E_ROOT" >&2; exit 1; }
[[ -f $E_RULES_FILE && -r $E_RULES_FILE ]] || { echo "bad rules file: $E_RULES_FILE" >&2; exit 1; }
 
export PATH="$E_PATH"
export E_ROOT E_RULES_FILE RULES_FILE="$E_RULES_FILE"

# log environment
#Cant see thisneed to find out why...
printf 'E_ROOT=%q E_RULES_FILE=%q PATH=%q\n' "$E_ROOT" "$E_RULES_FILE" "$PATH"

 
 

 

if (($#)); then exec "$@"; else exec "${SHELL:-/bin/bash}"; fi
