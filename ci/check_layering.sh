#!/usr/bin/env bash
# check_layering.sh — silent on success

# will need to be extended so that different depths of directories also get checked.
fail=0
for f in ../lib/*.sh ../util/*.sh; do
  while read -r line; do
    norm=$(echo "$line" | tr -s '[:space:]' ' ')
    if [[ $norm =~ ^[[:space:]]*(source|\.)[[:space:]]+.*bin/ ]]; then
        echo "Layer violation: $f sources from bin/"
         fail=1
    fi
    # If we're in utils/, also forbid sourcing lib
    if [[ $f == util/* ]] && [[ $norm =~ ^[[:space:]]*(source|\.)[[:space:]]+lib/ ]]; then
      echo "Layer violation: $f sources from lib/"
      fail=1
    fi
  done <"$f"
done
exit "$fail"


 