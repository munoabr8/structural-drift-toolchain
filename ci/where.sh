#!/usr/bin/env bash
set -euo pipefail; export LC_ALL=C
echo "PWD=$(pwd)"
echo "UTC=$(date -u +%FT%TZ)"
echo "GH_AUTH=$({ gh auth status >/dev/null && echo ok; } || echo no)"
echo "WORKFLOWS=$({ gh api repos/{owner}/{repo}/actions/workflows -q '.workflows|length'; } || echo 0)"
for f in events.ndjson leadtime.csv dora.json; do
  [[ -f "$f" ]] && echo "HAS_$f=1" || echo "HAS_$f=0"
done
make -f vm.mk vm/run CMD='bash ci/where.sh'