#!/usr/bin/env bash
set -euo pipefail
# DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# . "$DIR/lib/contracts2.sh"

# run_with_frame() {
#   local pre post
#   pre=$(frame_snapshot)
#   "$@"
#   post=$(frame_snapshot)
#   if [[ "$pre" != "$post" ]]; then
#     echo "frame violated" >&2
#     exit 1
#   fi
# }


 

 




. lib/contract_env.sh
. lib/contract_fs.sh

contracts_reset_env; contracts_reset_fs
. contracts/evaluate.frame.sh           # declarations only

pre_env="$(_ce_snapshot)"; pre_fs="$(_cf_snapshot)"
"$@"; rc=$?
post_env="$(_ce_snapshot)"; post_fs="$(_cf_snapshot)"

(( rc==0 )) || exit "$rc"
[[ "$pre_env" == "$post_env" ]] || exit 201
[[ "$pre_fs"  == "$post_fs"  ]] || exit 202
