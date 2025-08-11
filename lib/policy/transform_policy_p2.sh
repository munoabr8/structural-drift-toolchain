#!/usr/bin/env bash
set -euo pipefail

# transform_policy_rules: Filters ignores. Adds mode=literal|regex.
# In (STDIN):  type<TAB>path<TAB>condition<TAB>action
# Out:        type|path|condition|action|mode
transform_policy_rules() {
  local type path condition action mode
  while IFS=$'\t' read -r type path condition action; do
    [[ -z "${type:-}" ]] && continue
    [[ "$type" == "volatile" || "$condition" == "ignore" || "$action" == "ignore" ]] && continue
    mode=literal
    [[ "$path" =~ ^\^ || "$path" =~ \$$ || "$path" == *".*"* || "$path" == *"["* || "$path" == *"("* || "$path" == *"|"* ]] && mode=regex
    printf '%s|%s|%s|%s|%s\n' "$type" "$path" "$condition" "$action" "$mode"
  done
}

# If run directly, act as a filter: stdin → stdout.
# Example: yq -r '.[] | [.type,.path,.condition,.action] | @tsv' config/policy.rules.yml | this_script.sh
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  transform_policy_rules
fi
