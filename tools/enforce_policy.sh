#!/usr/bin/env bash


# ./tools/enforce_policy.rf.sh
set -Eeuo pipefail


declare -a SNAPSHOT
declare -a ERRORS
declare -a WARNINGS



resolve_project_root() {
  local src="${BASH_SOURCE[0]}"
  #
  printf '%s\n' "$(cd "$(dirname "$src")/.." && pwd)" || return 1
}

 
setup_environment_paths() {


PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}" || return $?

  SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
  TOOLS_DIR="${TOOLS_DIR:-$PROJECT_ROOT/tools}"
 export LIB_DIR="${LIB_DIR:-$PROJECT_ROOT/lib}"
POLICY_FILE="${POLICY_FILE:-$PROJECT_ROOT/config/policy.rules.yml}"

  export PROJECT_ROOT SYSTEM_DIR TOOLS_DIR POLICY_FILE
}

 
source_utilities() {

#resolve_project_root
setup_environment_paths

echo "DEBUG PROJECT_ROOT=$PROJECT_ROOT"
echo "DEBUG SYSTEM_DIR=$SYSTEM_DIR"
 
  local system_dir="${SYSTEM_DIR:-./system}"
  local tools_dir="${TOOLS_DIR:-./tools}"
  

  if [[ ! -f "$LIB_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: $LIB_DIR/source_OR_fail.sh"
    exit 1
  fi
  source "$LIB_DIR/source_OR_fail.sh"

  source_or_fail "$LIB_DIR/logger.sh"
  source_or_fail "$LIB_DIR/logger_wrapper.sh"

  source_or_fail "$PROJECT_ROOT/tools/exit_codes_enforcer.sh"

     
 
 }

read_rule_fields() {
  local index="$1"
  RULE_TYPE=$(yq e ".[$index].type" "$POLICY_FILE")
  RULE_PATH=$(yq e ".[$index].path" "$POLICY_FILE")
  RULE_CONDITION=$(yq e ".[$index].condition" "$POLICY_FILE")
  RULE_ACTION=$(yq e ".[$index].action" "$POLICY_FILE")
}


 
rule_status_pure() {
  local condition="$1" path="$2"; shift 2
  local -a snapshot=("$@")

  case "$condition" in
    must_exist)
      printf '%s\n' "${snapshot[@]}" | grep -Eq -- "^${path}(/|$)"
      return $?
      ;;
    ignore|allowed) return 0 ;;
    *)              return 2 ;;
  esac
}



evaluate_condition() {
  rule_status_pure "$RULE_CONDITION" "$RULE_PATH" "${SNAPSHOT[@]}"
  return $?
}

apply_action() {
  local status="$1"
  case "$status" in
    0) : ;; # satisfied
    1)
      case "$RULE_ACTION" in
        error)  ERRORS+=("Violation ($RULE_TYPE): $RULE_PATH") ;;
        warn)   WARNINGS+=("Warning  ($RULE_TYPE): $RULE_PATH") ;;
        ignore) ;;
        *)      ERRORS+=("Unknown action '$RULE_ACTION' for '$RULE_PATH'") ;;
      esac
      ;;
    2)
      ERRORS+=("Unknown condition '$RULE_CONDITION' for '$RULE_PATH'")
      ;;
    *)
      ERRORS+=("Internal error processing rule")
      ;;
  esac
}

 
 
perform_action() {
  local result="$1"
  if [[ "$result" -ne 0 ]]; then
    case "$RULE_ACTION" in
      error)  ERRORS+=("Violation ($RULE_TYPE): $RULE_PATH") ;;
      warn)   WARNINGS+=("Warning ($RULE_TYPE): $RULE_PATH") ;;
      ignore) ;;
      *)      echo "Unknown action: $RULE_ACTION" >&2 ;;
    esac
  fi
  echo "DEBUG: perform_action result=$result action=$RULE_ACTION" >&2
}

 
capture_snapshot() {
  local snapshot_file="$PROJECT_ROOT/.structure.snapshot"

  pushd "$PROJECT_ROOT" >/dev/null
  # ... same logic as before, but run find/grep against $PROJECT_ROOT
  if [[ -r "$snapshot_file" ]]; then
    mapfile -t SNAPSHOT < <(
      grep -E '^(dir: |file: )' "$snapshot_file" \
        | sed -E 's/^(dir: |file: )//' \
        | sed 's|^\./||' \
        | sort
    )
  else
    mapfile -t SNAPSHOT < <(
      find . -type f -o -type d \
        | sed 's|^\./||' \
        | sort
    )
    printf '%s\n' "${SNAPSHOT[@]}" > "$snapshot_file"
  fi
  popd >/dev/null
}

dispatch_rule() {
  local idx="$1"
  read_rule_fields "$idx" || { ERRORS+=("Failed to read rule $idx"); return 1; }

  evaluate_condition
  local st=$?
  apply_action "$st"

  [[ $st -ge 2 ]] && return 1 || return 0
}

print_results() {
  local checked="$1"
  echo "===== Policy Check ====="
  if ((${#ERRORS[@]} == 0 && ${#WARNINGS[@]} == 0)); then
    echo "OK: $checked rules satisfied."
  else
    for e in "${ERRORS[@]}";  do echo "ERROR: $e";  done
    for w in "${WARNINGS[@]}"; do echo "WARN : $w";  done
  fi
  echo "========================"
}

evaluate_rule() {               # json rule, snapshot…
  local json=$1; shift
  local -a snap=("$@")
  local cond path
  cond=$(yq e '.condition' <<<"$json")
  path=$(yq e '.path'      <<<"$json")
  case "$cond" in
    must_exist) printf '%s\n' "${snap[@]}" | grep -Eq "^${path}(/|$)";;
    ignore|allowed) return 0;;
    *) return 2;;
  esac
}


execute() {
  ERRORS=()
  WARNINGS=()

  capture_snapshot

  local rule_count
  rule_count=$(yq e '. | length' "$POLICY_FILE")
  for ((i=0; i<rule_count; i++)); do
    dispatch_rule "$i" || true
  done

  print_results "$rule_count"
  return ${#ERRORS[@]}   # <-- return ONLY. let main() map to exit codes.
}

main() {
  echo "DEBUG: entering main" >&2
  source_utilities

  command -v yq >/dev/null 2>&1 || exit "$EXIT_DEP_YQ_MISSING"
  POLICY_FILE="${POLICY_FILE:-$PROJECT_ROOT/config/policy.rules.yml}"
  [[ -r "$POLICY_FILE" ]] || exit "$EXIT_POLICY_FILE_NOT_FOUND"

  set +e
  execute "$@"
  local violations=$?
  set -e

  echo "DEBUG: execute returned violations=$violations, EXIT_POLICY_VIOLATIONS=$EXIT_POLICY_VIOLATIONS" >&2

  if (( violations > 0 )); then
    exit "$EXIT_POLICY_VIOLATIONS"
  else
    exit "$EXIT_OK"
  fi
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
