#!/usr/bin/env bash
# ./ci/roi/fetch_artifacts.sh

set -euo pipefail

: "${REPO:?REPO is required}"
mkdir -p artifacts && cd artifacts

fetch() {
  local name=$1 id
  id=$(
    gh api "/repos/$REPO/actions/artifacts?per_page=100" |
    jq -r --arg n "$name" '
      .artifacts
      | map(select(.name==$n and .expired==false))
      | sort_by(.created_at) | last | .id // empty'
  )
  if [[ -n "${id:-}" ]]; then
    gh api -H "Accept: application/vnd.github+json" "/repos/$REPO/actions/artifacts/$id/zip" > "$name.zip"
    unzip -o "$name.zip" >/dev/null
    case "$name" in
      workflow-stats) [[ -f workflow-stats.csv || -f runs.json ]] || echo "MISSING_FILE:$name" >> ../missing ;;
      pr-first-pass)  [[ -f first_pass.json ]] || echo "MISSING_FILE:$name" >> ../missing ;;
      ci-hours)       [[ -f ci-hours.csv   ]] || echo "MISSING_FILE:$name" >> ../missing ;;
      roi-baseline)   [[ -f baseline.json  ]] || echo "MISSING_FILE:$name" >> ../missing ;;
    esac
  else
    echo "MISSING:$name" >> ../missing
  fi
}



fetch workflow-stats
fetch pr-first-pass
fetch ci-hours
fetch roi-baseline

cd ..
if [[ -f missing ]]; then
  echo "Missing artifacts:"; cat missing
  exit 78
fi

# Move extracted files to workspace root for downstream scripts
shopt -s nullglob
mv artifacts/*.{json,csv} . 2>/dev/null || true
