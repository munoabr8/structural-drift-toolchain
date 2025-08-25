#!/usr/bin/env bash
# ./contracts_env.sh
# Purpose: deterministic env drift detection on pinned keys + global shape.
 
 
# env-specific contract: pin selected env keys + global shape

# portable sha
# _sha256(){ command -v sha256sum >/dev/null 2>&1 && sha256sum | awk '{print $1}' \
#         || shasum -a 256 | awk '{print $1}'; 

#       }



_sha256_cmd() {
  if [ -n "${_SHA256_CMD:-}" ]; then printf '%s\n' "$_SHA256_CMD"; return 0; fi
  if [ -n "${SHA256_BACKEND:-}" ] && command -v "${SHA256_BACKEND%% *}" >/dev/null 2>&1; then
    _SHA256_CMD="$SHA256_BACKEND"
  elif command -v sha256sum >/dev/null 2>&1; then
    _SHA256_CMD="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    _SHA256_CMD="shasum -a 256"
  elif command -v sha256 >/dev/null 2>&1; then
    _SHA256_CMD="sha256 -q"
  elif command -v openssl >/dev/null 2>&1; then
    _SHA256_CMD="openssl dgst -sha256 -r"
  elif command -v python3 >/dev/null 2>&1; then
    _SHA256_CMD="python3"
  else
    return 127
  fi
  printf '%s\n' "$_SHA256_CMD"
}




envs_pins_snapshot() {
  local k v
  for k in "$@"; do
    if declare -p "$k" >/dev/null 2>&1; then v=${!k}; else v=; fi
    printf '%s=%s\n' "$k" "$v"
  done | LC_ALL=C sort
}

 

# config
: "${ENV_IGNORE_RE:='^(PWD=|SHLVL=|_=|OLDPWD=|TMPDIR=)'}"
: "${ENV_KEYS:=RULES_FILE PATH LANG LC_ALL APP_MODE}"
IFS=' ' read -r -a ENV_KEYS <<<"$ENV_KEYS"
ENV_STACK=()
EC_NO_BEGIN=200 EC_DRIFT=201

 

# internals
env_shape_digest()
{
  local re=${1:-$ENV_IGNORE_RE}
  LC_ALL=C env | sort | grep -vE "$re" | awk -F= '{print $1}' | _sha256_cmd

}


env_snapshot(){
  { 
  env_pins_snapshot "${ENV_KEYS[@]}"; printf 'SHAPE=%s\n' "$(env_shape_digest "$@")"; } | LC_ALL=C sort
}

# API
declare_frame_env(){ ENV_KEYS+=("$@"); }
begin_env_frame(){ ENV_STACK+=("$(env_snapshot)"); }
check_env_frame(){
  ((${#ENV_STACK[@]})) || { echo "env: begin_env_frame missing" >&2; return $EC_NO_BEGIN; }
  local start="${ENV_STACK[-1]}"; unset 'ENV_STACK[-1]'
  local end; end="$(env_snapshot)"
  [[ "$end" == "$start" ]] && return 0
  echo "env: drift" >&2
  comm -23 <(printf '%s\n' "$start") <(printf '%s\n' "$end") | sed 's/^/begin-only: /' >&2
  comm -13 <(printf '%s\n' "$start") <(printf '%s\n' "$end") | sed 's/^/end-only:   /' >&2
  return $EC_DRIFT
}
check_env_frame_fast(){
  ((${#ENV_STACK[@]})) || return $EC_NO_BEGIN
  local start="${ENV_STACK[-1]}"; unset 'ENV_STACK[-1]'
  local end; end="$(env_snapshot)"; [[ "$end" == "$start" ]] || return $EC_DRIFT
}

