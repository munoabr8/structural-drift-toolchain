#!/usr/bin/env bash

#evaluate.sh

# WRITES: path1 path2
# READS:  pathA pathB
# ENVS:   VAR1 VAR2

set -euo pipefail
 
 
: "${RULES_FILE:?missing}"
 

LIB="./queries/queries.rules.sh"

# shellcheck source=lib/queries/queries.rules.sh
[[ -r "$LIB" ]] || { echo "missing: $LIB" >&2; exit 2; }
. "$LIB"

 
 rules_schema_valid         || echo "schema fail"
rules_have_unique_ids      || echo "ids fail"
 debug || echo "debug fail"
rules_declare_reads_writes || echo "reads/writes fail"
    
 
# parse --out or --out=...
out=
while (($#)); do
  case $1 in
    --out)     out=${2:?}; shift 2 ;;
    --out=*)   out=${1#*=}; shift ;;
    *)         shift ;;
  esac
done
: "${out:?missing --out}"

# resolve relative paths to E_ROOT (exported by the frame)
case $out in /*) target=$out ;; *)
  : "${E_ROOT:?E_ROOT not set by frame}"
  target="$E_ROOT/$out"
esac
mkdir -p -- "$(dirname "$target")"

# write bytes that actually change
tmp=$(mktemp)
# replace this line with your real output
printf 'result:%s\n' "$(date +%s%N)" > "$tmp"
mv -f -- "$tmp" "$target"




echo "Eval complete?"

 

 