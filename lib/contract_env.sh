#shellcheck shell=bash 
# contract_env.sh  — decision point
# Decision: env snapshots use a fixed key set by default (higher cohesion).
# Set ENV_SNAPSHOT_STRATEGY=args before sourcing to opt into caller-supplied keys.

: "${ENV_SNAPSHOT_STRATEGY:=fixed}"          # fixed | args
ENV_KEYS=(RULES_FILE PATH LANG LC_ALL APP_MODE)

# optional overrides
if [[ -n ${ENV_KEYS_CSV-} ]]; then IFS=, read -r -a ENV_KEYS <<<"$ENV_KEYS_CSV"
elif [[ -n ${ENV_KEYS_SPC-} ]]; then read -r -a ENV_KEYS <<<"$ENV_KEYS_SPC"
fi

ENV_STACK=()

begin_env_frame() { ENV_STACK+=("$(env_snapshot_fixed)"); }   # safe default

env_snapshot_fixed() { _env_snapshot "${ENV_KEYS[@]}"; }      # stable, low risk

# Risky, ad-hoc keys. Must be explicitly acknowledged.
env_snapshot_for() {
  local accept=0; local -a keys=()
  while (($#)); do
    case $1 in
      --accept-risk) accept=1 ;;
      *) keys+=("$1") ;;
    esac; shift
  done
  ((${#keys[@]})) || { printf 'need at least one key\n' >&2; return "$EC_USAGE"; }
  ((accept)) || { printf 'risk not acknowledged (--accept-risk)\n' >&2; return "$EC_RISK_NOT_ACK"; }

  _risk_log "env_snapshot_for" "HIGH" "${keys[@]}"
  _env_snapshot "${keys[@]}"
}

_env_snapshot() {
  local keys=("$@")
  {
    env_pins_snapshot "${keys[@]}"
    printf 'SHAPE=%s\n' "$(env_shape_digest "${keys[@]}")"
  } | LC_ALL=C sort
}

_risk_log() { # $1=op $2=level $3+=keys
  printf '{"ts":"%s","op":"%s","risk":"%s","keys":%s}\n' \
    "$(date -u +%FT%TZ)" "$1" "$2" "$(printf '%s\n' "${@:3}" | jq -Rsc 'split("\n")[:-1]')" \
    >> "${RISK_LOG:-risk.log}"
}

[[ -z ${CONTRACTS_ENV_LOADED-} || ${CONTRACTS_ENV_FORCE_RESRC-} == 1 ]] || return
CONTRACTS_ENV_LOADED=1


# guard the decision at load

contracts_env_init() {
  case "${ENV_SNAPSHOT_STRATEGY:-fixed}" in
    fixed|args) ;;
    *) printf 'invalid ENV_SNAPSHOT_STRATEGY=%s\n' "$ENV_SNAPSHOT_STRATEGY" >&2; return 64 ;;
  esac
  if [[ $ENV_SNAPSHOT_STRATEGY == fixed && ${#ENV_KEYS[@]} -eq 0 ]]; then
    printf 'ENV_KEYS must be nonempty when strategy=fixed\n' >&2
    return 64
  fi
}

 
contracts_env_init || { rc=$?; return "$rc" 2>/dev/null ; }





# Print stable KEY=VALUE lines for the given keys.
# Read-only. Safe with `set -u`. Handles unset vars as empty.
env_pins_snapshot() {
  local k
  for k in "$@"; do
    if declare -p "$k" >/dev/null 2>&1; then
      printf '%s=%q\n' "$k" "${!k}"
    else
      printf '%s=%q\n' "$k" ""
    fi
  done
}
env_shape_digest() {
  local keys=("$@")
  printf '%s\n' "${keys[@]}" | LC_ALL=C sort | _sha256
}

 
 # Choose once, allow override, cache
_sha256() {
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
 

# Full check: compares entire sorted snapshot; prints diff on drift
check_env_frame() {
  ((${#ENV_STACK[@]})) || { echo "env: begin_env_frame missing" >&2; return "$EC_NO_BEGIN"; }
  local idx=$(( ${#ENV_STACK[@]} - 1 ))
  local start="${ENV_STACK[$idx]}"; unset "ENV_STACK[$idx]"
  local end; end="$(env_snapshot)"

  if [[ "$start" == "$end" ]]; then
    return 0
  fi

  echo "env: drift detected" >&2
  if command -v diff >/dev/null 2>&1; then
    diff -u <(printf '%s\n' "$start") <(printf '%s\n' "$end") >&2 || true
  else
    printf '--- start\n%s\n--- end\n%s\n' "$start" "$end" >&2
  fi
  return "$EC_ENV_DRIFT"
}

# Fast check: compares only the SHAPE digest
check_env_frame_fast() {
  ((${#ENV_STACK[@]})) || { echo "env: begin_env_frame missing" >&2; return "$EC_NO_BEGIN"; }
  local idx=$(( ${#ENV_STACK[@]} - 1 ))
  local start="${ENV_STACK[$idx]}"; unset "ENV_STACK[$idx]"

  local start_shape end_shape
  start_shape=$(printf '%s\n' "$start" | awk -F= '$1=="SHAPE"{print $2; exit}')
  end_shape=$(env_shape_digest "${ENV_KEYS[@]}")

  [[ -n "$start_shape" && -n "$end_shape" ]] || { echo "env: missing SHAPE" >&2; return "$EC_ENV_DRIFT"; }

  if [[ "$start_shape" == "$end_shape" ]]; then
    return 0
  fi
  printf 'env: drift SHAPE %s -> %s\n' "$start_shape" "$end_shape" >&2
  return "$EC_ENV_DRIFT"
}


 

 

 

 
# Requires: ENV_KEYS, env_snapshot, env_shape_digest, ENV_STACK, EC_NO_BEGIN, EC_ENV_DRIFT,
#           begin_env_frame, check_env_frame  (fast path uses its own pop)

 

run_with_env_guard() {
  local mode=${ENV_CHECK_MODE:-fast}
  local start start_shape end_shape rc idx

  # push start
  start="$(env_snapshot)"
  ENV_STACK+=("$start")

  # do work in current shell (so env mutations are visible)
  "$@"; rc=$?

  if [[ $mode == fast ]]; then
    # cheap compare by SHAPE, avoid full diff
    start_shape=$(printf '%s\n' "$start" | awk -F= '$1=="SHAPE"{print $2; exit}')
    end_shape=$(env_shape_digest "${ENV_KEYS[@]}")

    if [[ "$start_shape" == "$end_shape" ]]; then
      # pop and return command status
      idx=$(( ${#ENV_STACK[@]} - 1 )); unset "ENV_STACK[$idx]"
      return "$rc"
    fi

    # drift: produce diff and fail with drift code
    check_env_frame || true         # prints unified diff; pops stack
    return "$EC_ENV_DRIFT"
  else
    # full compare + diff; pops stack
    if check_env_frame; then
      return "$rc"
    else
      return "$EC_ENV_DRIFT"
    fi
  fi
}


help() {
  cat <<'USAGE'
Usage: source contract_env.sh [options]

Environment Contract Utilities:

  begin_env_frame             # push current env snapshot
  check_env_frame             # full check, show drift diff if any
  check_env_frame_fast        # fast check, compares only SHAPE digest
  run_with_env_guard CMD ...  # run CMD and check environment drift
  contracts_env_selfcheck     # self-test of environment guard

Options (before sourcing):
  ENV_SNAPSHOT_STRATEGY=fixed|args   # choose snapshot strategy (default=fixed)
  ENV_KEYS_CSV="K1,K2,..."           # override keys with CSV
  ENV_KEYS_SPC="K1 K2 ..."           # override keys with space-separated list
  RISK_LOG=path                      # log risky operations (default=risk.log)

Return codes:
  64   invalid configuration
  $EC_NO_BEGIN   begin_env_frame missing
  $EC_ENV_DRIFT  environment drift detected

Examples:
  source contract_env.sh
  begin_env_frame
  # ... make changes ...
  check_env_frame

  run_with_env_guard my_command --arg foo
USAGE
}


contracts_env_selfcheck() {
  # cheap check
  run_with_env_guard : || return
  # full drift check by re-sourcing this module
  ENV_CHECK_MODE=full CONTRACTS_ENV_FORCE_RESRC=1 run_with_env_guard source "${CONTRACTS_ENV_PATH:-${BASH_SOURCE[0]}}"
}




 