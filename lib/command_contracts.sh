#!/usr/bin/env bash
# Purpose: Define command-level contracts (what each command requires)
# Loaded by main.sh to enforce preconditions per command

[[ -n "${__COMMAND_CONTRACTS_SH__:-}" ]] && return 0
__COMMAND_CONTRACTS_SH__=1

# -------------------------------
# Contract metadata per command
# -------------------------------
# Format: "env=1 context=1 deps=1 mutate=1"

declare -A CMD_CONTRACTS=(
  [help]="env=0 context=0 deps=0 mutate=0"
  [start]="env=1 context=1 deps=1 mutate=1"
  [context]="env=1 context=1 deps=0 mutate=0"
  [self-test]="env=1 context=0 deps=0 mutate=0"
  [init]="env=1 context=0 deps=1 mutate=1"
)

 
# -------------------------------
# Require contract for a command
# -------------------------------
require_contract_for() {
  #debug_contracts
  local cmd="${1:-}"

 
  #echo "$cmd"
    [[ -z "$cmd" ]] && {
    echo "❌ No command provided to require_contract_for" >&2
    return 1
  }

 local  contract

if declare -p CMD_CONTRACTS &>/dev/null && [[ "$(declare -p CMD_CONTRACTS 2>/dev/null)" == *"$cmd"* ]]; then
  contract="${CMD_CONTRACTS[$cmd]}"
  echo "Contract keys: ${!CMD_CONTRACTS[@]}"
else
  echo "⚠️ No contract defined for '$cmd', defaulting..." >&2
  contract="env=1 deps=1 context=0"
fi
 
  _contract_log "$cmd" "$contract"

  local status=0

  if [[ "$contract" == *"env=1"* ]]; then
    env_assert || { echo "❌ ENV check failed for '$cmd'" >&2; status=1; }
  fi

  if [[ "$contract" == *"deps=1"* ]]; then
    deps_check || { echo "❌ Dependency check failed for '$cmd'" >&2; status=1; }
  fi

  if [[ "$contract" == *"context=1"* ]]; then
    context_check || { echo "❌ Context check failed for '$cmd'" >&2; status=1; }
  fi

  return "$status"
}

# -------------------------------
# Optional: Pretty-print contracts
# -------------------------------
contract::print_table() {
  printf "📋 Command Contracts\n"
  printf "%-12s | %s\n" "Command" "env  deps  context  mutate"
  printf -- "------------------------------\n"
  for cmd in "${!CMD_CONTRACTS[@]}"; do
    local c="${CMD_CONTRACTS[$cmd]}"
    local env=$(echo "$c" | grep -o "env=." | cut -d= -f2)
    local deps=$(echo "$c" | grep -o "deps=." | cut -d= -f2)
    local ctx=$(echo "$c" | grep -o "context=." | cut -d= -f2)
    local mut=$(echo "$c" | grep -o "mutate=." | cut -d= -f2)
    printf "%-12s |  %s     %s      %s       %s\n" "$cmd" "$env" "$deps" "$ctx" "$mut"
  done
}

  context_check(){


CONTEXT_CHECK="${CONTEXT_CHECK:-$PROJECT_ROOT/attn/context-status.sh}"
  ${CONTEXT_CHECK} || { echo "Context invalid."   >&2; return 1; }


  }

_contract_log() {
  local cmd="$1"
  local contract="$2"
  echo "🔐 Checking command contract for '$cmd': [$contract]"
}



main (){


require_contract_for "$@" 

}


# --- library guard ----------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

