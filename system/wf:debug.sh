#!/usr/bin/env bash
set -euo pipefail

echo "[debug] repo=${REPO:-} main=${MAIN_BRANCH:-} env=${ENV:-} window=${WINDOW_DAYS:-}"
echo "[debug] events=${EVENTS:-} artname=${ARTNAME:-}"

# tools
printf "[tools] "
for t in bash jq gh python3; do
  if command -v "$t" >/dev/null 2>&1; then printf "%s " "$t"; else echo "missing $t" && exit 69; fi
done
echo

# gh auth + repo
echo "[gh] auth:"; gh auth status || true
echo "[gh] repo:"; gh repo view "${REPO:-}" --json nameWithOwner,defaultBranchRef \
  -q '.nameWithOwner+" default="+.defaultBranchRef.name' || echo "gh repo view failed"

# events status
if [[ -n "${EVENTS:-}" && -f "${EVENTS}" ]]; then
  sz=$(stat -f%z "${EVENTS}" 2>/dev/null || stat -c%s "${EVENTS}" 2>/dev/null || echo 0)
  echo "[events] ok size=$sz bytes"
  jq -s '{pr:map(select(.type=="pr_merged"))|length,
          dep:map(select(.type=="deployment"))|length,
          sample:(.[0]|.type?)}' "${EVENTS}" || true
else
  echo "[events] missing: ${EVENTS:-<unset>}"
fi

# latest run log tail (if using run-wf)
f=$(ls -1t artifacts/logs/run.*.ndjson 2>/dev/null | head -n1 || true)
if [[ -n "$f" ]]; then echo "[logs] $f"; tail -n 10 "$f"; else echo "[logs] none"; fi
