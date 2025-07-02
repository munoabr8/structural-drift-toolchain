#!/usr/bin/env bash

POLICY_FILE="../config/policy.rules.yml"
SNAPSHOT=$(find . -type f -o -type d | sort)

declare -a ERRORS
declare -a WARNINGS

### ────────── Field Extraction ────────── ###
read_rule_fields() {
  local index="$1"
  RULE_TYPE=$(yq e ".[$index].type" "$POLICY_FILE")
  RULE_PATH=$(yq e ".[$index].path" "$POLICY_FILE")
  RULE_CONDITION=$(yq e ".[$index].condition" "$POLICY_FILE")
  RULE_ACTION=$(yq e ".[$index].action" "$POLICY_FILE")
}

### ────────── Condition Evaluation ────────── ###
evaluate_condition() {
  case "$RULE_CONDITION" in
    must_exist)
      echo "$SNAPSHOT" | grep -E "$RULE_PATH" >/dev/null
      return $?  # 0 = satisfied, 1 = violation
      ;;
    ignore)
      return 0
      ;;
    allowed)
      return 0
      ;;
    *)
      echo "Unknown condition: $RULE_CONDITION"
      return 1
      ;;
  esac
}

### ────────── Action Dispatcher ────────── ###
perform_action() {
  local result="$1"
  if [[ "$result" -ne 0 ]]; then
    case "$RULE_ACTION" in
      error) ERRORS+=("Violation ($RULE_TYPE): $RULE_PATH") ;;
      warn)  WARNINGS+=("Warning ($RULE_TYPE): $RULE_PATH") ;;
      ignore) ;;  # No action
      *) echo "Unknown action: $RULE_ACTION" ;;
    esac
  fi
}

### ────────── Rule Dispatcher ────────── ###
dispatch_rule() {
  local index="$1"
  read_rule_fields "$index"
  evaluate_condition
  perform_action "$?"
}

### ────────── Report Output ────────── ###
print_results() {
  echo "===== Policy Check ====="
  for e in "${ERRORS[@]}"; do echo "ERROR: $e"; done
  for w in "${WARNINGS[@]}"; do echo "WARN : $w"; done
  echo "========================"
}

### ────────── Main Entrypoint ────────── ###
main() {
  rule_count=$(yq e '. | length' "$POLICY_FILE")
  for ((i=0; i<rule_count; i++)); do
    dispatch_rule "$i"
  done

  print_results
  exit ${#ERRORS[@]}
}

main "$@"

