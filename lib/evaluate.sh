#!/usr/bin/env bash

#evaluate.sh

# WRITES: path1 path2
# READS:  pathA pathB
# ENVS:   VAR1 VAR2

set -euo pipefail


 
: "${RULES_FILE:?missing}"
CTX_FILE="${CTX_FILE:-/dev/null}"

jq '
  if type=="array"
  then map({id, status:"ok"})
  else error("rules must be array")
  end
' -- "$RULES_FILE"

. "./contracts_dsl.sh"
. "./evaluate.contract.sh"

require rules_have_unique_ids
require rules_declare_reads_writes
require no_time_or_random_sources
assert_i pure_eval
assert_i order_invariant
assert_i hermetic
findings=$(evaluate_rules "$RULES_FILE" "$CTX_FILE")
ensure findings_normalized "$FINDINGS_FILE"

 