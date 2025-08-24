#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=./contract_env.sh
source ./contract_env.sh

: "${EC_ENV_DRIFT:=92}"
: "${EC_USAGE:=64}"

ENV_KEYS=(PATH RULES_FILE)
allowed_re='^(PATH|RULES_FILE)='

 

VERBOSE=${WITH_ENV_VERBOSE:-0}
log(){ ((VERBOSE)) && printf '%s\n' "$*"; }

apply_env_lines() {
  while IFS= read -r line; do
    [[ $line =~ $allowed_re ]] || { printf 'forbidden assignment: %s\n' "$line" >&2; exit 66; }
    log "export $line"
    eval "export $line"
  done
}

with_contract_env() {
  local proposer=${1:?proposer cmd missing}
  local before after
  before="$(env_snapshot_fixed)"
  "$proposer" | apply_env_lines
  after="$(env_snapshot_fixed)"

  strip_allowed(){ grep -Ev '^(PIN:(PATH=|RULES_FILE=)|SHAPE=)'; }
  diff -u <(printf '%s\n' "$before" | strip_allowed) \
          <(printf '%s\n' "$after"  | strip_allowed) >/dev/null \
    || { echo "env drift outside allowed pins" >&2; exit "$EC_ENV_DRIFT"; }

  ((VERBOSE)) && {
    echo "--- applied env (allowed pins) ---"
    env | grep -E '^(PATH|RULES_FILE)=' | sort
  }
}



# Is this sourcing from from lib -> bin????
proposer="${1:-../bin/emit-env}"
with_contract_env "$proposer"

