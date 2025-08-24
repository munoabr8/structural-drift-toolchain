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
