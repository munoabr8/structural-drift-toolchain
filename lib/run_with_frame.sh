#!/usr/bin/env bash
set -euo pipefail


 # shellcheck source=predicates.sh
# shellcheck source=enums.sh

 
. "$ROOT/predicates.sh"; echo "sourced: predicates"
. "$ROOT/enums.sh";      echo "sourced: enums"

 

# shellcheck source=contract_env.sh
# shellcheck source=contract_fs.sh

. ./lib/contract_env.sh
. ./lib/contract_fs.sh

contracts_reset_env; contracts_reset_fs
. contracts/evaluate.frame.sh           # declarations only

pre_env="$(_ce_snapshot)"; pre_fs="$(_cf_snapshot)"
"$@"; rc=$?
post_env="$(_ce_snapshot)"; post_fs="$(_cf_snapshot)"

(( rc==0 )) || exit "$rc"
[[ "$pre_env" == "$post_env" ]] || exit 201
[[ "$pre_fs"  == "$post_fs"  ]] || exit 202



help() {
  cat <<'USAGE'
Usage: run_with_frame.sh CMD [ARGS...]

Run CMD inside environment and filesystem contracts.
Detects unexpected drift and enforces declared invariants.

Environment:
  Sources: predicates.sh, enums.sh, contract_env.sh, contract_fs.sh
  Resets env/fs frames, loads contracts/evaluate.frame.sh

Checks:
  - Pre/post environment snapshot must match
  - Pre/post filesystem snapshot must match

Exit codes:
   0   CMD succeeded, no drift
 201   Environment drift detected
 202   Filesystem drift detected
  CMD  Propagates original CMD exit code

Examples:
  ./run_with_frame.sh make build
  ./run_with_frame.sh ./myscript.sh --flag
USAGE
}



[[ $# -eq 0 ]] && help && exit 2
