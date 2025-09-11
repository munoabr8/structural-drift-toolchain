# shellcheck shell=bash   # tells ShellCheck the dialect
# tools/load_frame.sh
set -euo pipefail
declare -ag IMM_ENV=() MUT_ENV=() FS_PATHS=()

_allow(){ [[ $1 =~ ^(declare_frame_env|declare_mutable_env|declare_frame)$ ]]; }

declare_frame_env(){ IMM_ENV+=("$@"); }
declare_mutable_env(){ MUT_ENV+=("$@"); }
declare_frame(){ FS_PATHS+=("$@"); }

load_frame(){
  local f=$1
  while IFS= read -r line; do
    # strip comments
    line=${line%%#*}; line=${line## }
    [[ -z $line ]] && continue
    # parse: fn arg...
    set -- $line; fn=$1; shift || true
    _allow "$fn" || { echo "forbidden in frame: $fn" >&2; exit 250; }
    "$fn" "$@"
  done <"$f"
}

