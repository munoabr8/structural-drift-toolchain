#shellcheck shell=bash 
 
# system/env/load.sh  (source this file)
__opts="$(set +o)"; set +u   # disable nounset temporarily
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || return 1
echo ""
set -a
[ -f config/default.env ] && . config/default.env
[ -f config/local.env   ] && . config/local.env
if [ -n "${CI:-}" ] && [ -f config/ci.env ]; then . config/ci.env; fi
set +a

eval "$__opts"; unset __opts



export ENV_LOADED=1