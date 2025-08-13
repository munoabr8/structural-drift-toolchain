#!/usr/bin/env bash
set -euo pipefail

# transform_policy_rules: Filters ignores. Adds mode=literal|regex.
# In (STDIN):  type<TAB>path<TAB>condition<TAB>action
# Out:        type|path|condition|action|mode
transform_policy_rules() {
   local line type path condition action mode extra
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue

    if [[ "$line" == *$'\t'* ]]; then
      IFS=$'\t' read -r type path condition action extra <<<"$line"
      if [[ -n "${extra:-}" || -z "${path:-}" || -z "${condition:-}" || -z "${action:-}" ]]; then
        echo "invalid TSV" >&2; exit 65
      fi
      [[ "$type" == "volatile" || "$condition" == "ignore" || "$action" == "ignore" ]] && continue

    mode=literal
      if [[ $path =~ [\^\$\*\[\]\(\)\|] ]]; then
        mode=regex
      fi

      printf '%s|%s|%s|%s|%s\n' "$type" "$path" "$condition" "$action" "$mode"

    elif [[ "$line" == *'|'* ]]; then
      IFS='|' read -r type path condition action mode extra <<<"$line"
      if [[ -n "${extra:-}" || -z "$type" || -z "$path" || -z "$condition" || -z "$action" || -z "$mode" ]]; then
        echo "invalid pipe shape" >&2; exit 65
      fi
      # pass-through to be idempotent
      printf '%s|%s|%s|%s|%s\n' "$type" "$path" "$condition" "$action" "$mode"

    else
      echo "invalid TSV" >&2; exit 65
    fi
  done
}


 

# If run directly, act as a filter: stdin → stdout.
# Example: yq -r '.[] | [.type,.path,.condition,.action] | @tsv' config/policy.rules.yml | this_script.sh
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  transform_policy_rules
fi
