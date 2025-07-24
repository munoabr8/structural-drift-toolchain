#!/usr/bin/env bash


# ./tools/enforce_policy.rf.sh


POLICY_FILE="../config/policy.rules.yml"
#SNAPSHOT=$(find . -type f -o -type d | sort)

declare -a SNAPSHOT

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
    echo "DEBUG: RULE_CONDITION=$RULE_CONDITION, RULE_PATH=$RULE_PATH" >&2
  # maybe show a few lines of SNAPSHOT too:
  printf 'DEBUG: SNAPSHOT head:\n%s\n' "$(printf '%s\n' "$SNAPSHOT" | head -n5)" >&2


  case "$RULE_CONDITION" in
    must_exist)


      echo "$SNAPSHOT" | grep -E "(\./)?${RULE_PATH}" >/dev/null

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
  local idx=$1

  read_rule_fields "$idx" \
    && echo "read_rule_fields succeeded" >&2 \
    || { echo "read_rule_fields failed" >&2; return 1; }

  evaluate_condition "$idx" \
    && echo "evaluate_condition succeeded" >&2 \
    || { echo "evaluate_condition failed" >&2; return 1; }

  perform_action "$idx" \
    && echo "perform_action succeeded" >&2 \
    || { echo "perform_action failed" >&2; return 1; }

  echo "Exiting dispatch rule" >&2
}


### ────────── Report Output ────────── ###
print_results() {
  echo "===== Policy Check ====="
  for e in "${ERRORS[@]}"; do echo "ERROR: $e"; done
  for w in "${WARNINGS[@]}"; do echo "WARN : $w"; done
  echo "========================"
}
 # capture_snapshot() {

 #   SNAPSHOT=$(find . -type f -o -type d | sort)
 # } 


# capture_snapshot() {
#   local root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   pushd "$root_dir" >/dev/null
#   SNAPSHOT=$(find . -type f -o -type d | sort)
#   popd >/dev/null
# }


# capture_snapshot() {
#   local snapshot_file="./.structure.snapshot"
#   if [[ -r "$snapshot_file" ]]; then
#     echo "DEBUG: Loading existing snapshot from $snapshot_file" >&2
#     mapfile -t SNAPSHOT < <(
#       grep -E '^(dir: |file: )' "$snapshot_file" \
#         | sed -E 's/^(dir: |file: )//' \
#         | sed 's|^\./||' \
#         | sort
#     )
#   else
#     echo "DEBUG: No snapshot found; generating new one" >&2
#     mapfile -t SNAPSHOT < <(find . -type f -o -type d | sed 's|^\./||' | sort)
#     printf '%s\n' "${SNAPSHOT[@]}" > "$snapshot_file"
#   fi
# }


# capture_snapshot() {
#   local snapshot_file="./.structure.snapshot"

#   if [[ -r "$snapshot_file" ]]; then
#     echo "DEBUG: Loading existing snapshot from $snapshot_file" >&2
#     mapfile -t SNAPSHOT < <(
#       grep -E '^(dir: |file: )' "$snapshot_file" \
#         | sed -E 's/^(dir: |file: )//' \
#         | sed 's|^\./||' \
#         | sort
#     )
#   else
#     echo "DEBUG: No snapshot found; generating new one" >&2
#     mapfile -t SNAPSHOT < <(
#       find . -type f -o -type d \
#         | sed 's|^\./||' \
#         | sort
#     )
#     printf '%s\n' "${SNAPSHOT[@]}" > "$snapshot_file"
#   fi
# }

capture_snapshot() {
  # 1) Find the directory this script lives in
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # 2) Assume project root is one level up
  local project_root
  project_root="$(cd "$script_dir/.." && pwd)"

  # 3) Snapshot file lives in the project root
  local snapshot_file="$project_root/.structure.snapshot"

  # 4) Load or generate a clean list of relative paths
  if [[ -r "$snapshot_file" ]]; then
    echo "DEBUG: Loading existing snapshot from $snapshot_file" >&2
    mapfile -t SNAPSHOT < <(
      find "$project_root" -type f -o -type d \
        | sed "s|^$project_root/||" \
        | sort
    )
  else
    echo "DEBUG: No snapshot found; generating new one" >&2
    mapfile -t SNAPSHOT < <(
      find "$project_root" -type f -o -type d \
        | sed "s|^$project_root/||" \
        | sort
    )
    printf '%s\n' "${SNAPSHOT[@]}" > "$snapshot_file"
  fi

  # 5) Debug: show the first few entries
  echo "DEBUG: SNAPSHOT head (first 5):" >&2
  for entry in "${SNAPSHOT[@]:0:5}"; do
    echo "  $entry" >&2
  done
}


execute() {


  ERRORS=()
  capture_snapshot

  echo "DEBUG: inside execute(), ERRORS=${#ERRORS[@]}" >&2


  rule_count=$(yq e '. | length' "$POLICY_FILE")

  echo "DEBUG: rule_count=$rule_count" >&2


  for ((i=0; i<rule_count; i++)); do

    dispatch_rule "$i"
  done


 
  print_results
  return ${#ERRORS[@]}
}



  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    execute "$@"
  fi


