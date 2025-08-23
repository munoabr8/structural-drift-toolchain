#!/usr/bin/env bash
# contracts_env_core.sh
# Purpose: deterministic env drift detection on pinned keys + global shape.
 
 
# env-specific contract: pin selected env keys + global shape

# portable sha
_sha256(){ command -v sha256sum >/dev/null 2>&1 && sha256sum | awk '{print $1}' \
        || shasum -a 256 | awk '{print $1}'; }

# config
: "${ENV_IGNORE_RE:='^(PWD=|SHLVL=|_=|OLDPWD=|TMPDIR=)'}"
: "${ENV_KEYS:=RULES_FILE PATH LANG LC_ALL APP_MODE}"
IFS=' ' read -r -a ENV_KEYS <<<"$ENV_KEYS"
ENV_STACK=()
EC_NO_BEGIN=200 EC_DRIFT=201

# internals
env_shape_digest(){
  local re=${1:-$ENV_IGNORE_RE}
  LC_ALL=C env | sort | grep -vE "$re" | awk -F= '{print $1}' | _sha256
}


env_pins_snapshot(){ 
  LC_ALL=C 
  for k in "$@"; do
 printf '%s=%s\n' "$k" "${!k-}"; 
done | sort; 


}



env_snapshot(){
  { env_pins_snapshot "${ENV_KEYS[@]}"; printf 'SHAPE=%s\n' "$(env_shape_digest)"; } | LC_ALL=C sort
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


#############################################

 : "${STRICT_MUT:=0}"
IMM_ENV=(); MUT_ENV=()
contracts_reset_env(){ IMM_ENV=(); MUT_ENV=(); }
declare_frame_env(){ IMM_ENV+=("$@"); }
declare_mutable_env(){ MUT_ENV+=("$@"); }

_ce_snapshot() {
  # Hash of: IMM values, optional MUT values (if STRICT_MUT=1), and env "shape" hash of untracked names.
  {
    # 1) immutable env key=val lines
    for k in "${IMM_ENV[@]}"; do
      printf 'IMM:%s=%s\n' "$k" "${!k-}"
    done

    # 2) mutable env key=val lines only if strict
    if (( STRICT_MUT )); then
      for k in "${MUT_ENV[@]}"; do
        printf 'MUT:%s=%s\n' "$k" "${!k-}"
      done
    fi

    # 3) shape hash of env names excluding noisy keys and tracked keys
    env | LC_ALL=C sort | awk -F= '{print $1}' \
      | grep -vE '^(PWD|SHLVL|_|OLDPWD|TMPDIR)$' \
      | comm -23 - <(printf '%s\n' "${IMM_ENV[@]}" "${MUT_ENV[@]}" | LC_ALL=C sort -u) \
      | sha256sum | awk '{print "SHAPE:"$1}'
  } | sha256sum | awk '{print $1}'
}


_ce_dump() {
  (
    export LC_ALL=C
    for k in "${IMM_ENV[@]}"; do
      printf 'IMM:%s=%s\n' "$k" "${!k-}"
    done
    env | sort
  )
}

