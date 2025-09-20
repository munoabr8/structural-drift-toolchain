#!/usr/bin/env bash
set -euo pipefail

log="${1:-job.log}"
[[ -r "$log" ]] || { echo '{"schema":"./triage/v1","code":"NO_LOG"}'; exit 0; }

TAX_YML="${TAX_YML:-./failure_taxonomy.yml}"
PAT_MAP="${PAT_MAP:-./patterns.map}"

code="TEST_LOGIC"

if command -v yq >/dev/null 2>&1 && [[ -f "$TAX_YML" ]]; then
  while IFS= read -r line; do
    c="${line%%|*}"; rx="${line#*|}"
    if grep -Eiq -- "$rx" "$log"; then code="$c"; break; fi
  done < <(yq -r '.rules[] | .code as $c | .match[] | "\($c)|\(.)"' "$TAX_YML")
elif [[ -f "$PAT_MAP" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    c="${line%%|*}"; pats="${line#*|}"; IFS='|' read -r -a arr <<< "$pats"
    for rx in "${arr[@]}"; do
      if grep -Eiq -- "$rx" "$log"; then code="$c"; break 2; fi
    done
  done < "$PAT_MAP"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
printf '{"schema":"ci/triage/v1","sha":"%s","code":"%s","ts":"%s","log":"%s"}\n' "$sha" "$code" "$ts" "$log"
