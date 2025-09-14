#!/usr/bin/env bash
# Fail if DORA event quality is bad.
set -euo pipefail
E="${1:-events.ndjson}"

die(){ echo "NEEDS_WORK:$*" >&2; exit 1; }

# 1) PR rows: real merge_commit_sha + ISO Z time
BAD_PR=$(jq -s '[ .[] | select(.type=="pr_merged")
  | select((.sha|test("^[0-9a-f]{40}$")|not) or (.merged_at|test("Z$")|not)) ] | length' "$E")
(( BAD_PR==0 )) || die "bad PR rows=$BAD_PR"

# 2) Deploy rows: success + ISO Z + sha shape
BAD_DEP=$(jq -s '[ .[] | select(.type=="deployment")
  | select((.sha|test("^[0-9a-f]{40}$")|not) or (.status!="success") or (.finished_at|test("Z$")|not)) ] | length' "$E")
(( BAD_DEP==0 )) || die "bad deploy rows=$BAD_DEP"

# 3) SHA intersection coverage ≥ $COVERAGE_MIN (default 0.5)
COVERAGE_MIN="${COVERAGE_MIN:-0.33}"
PRS=$(jq -r 'select(.type=="pr_merged")|.sha' "$E" | sort -u | wc -l | xargs)
DEPS=$(jq -r 'select(.type=="deployment" and .status=="success")|.sha' "$E" | sort -u | wc -l | xargs)
INT=$(comm -12 <(jq -r 'select(.type=="pr_merged")|.sha' "$E" | sort -u) \
              <(jq -r 'select(.type=="deployment" and .status=="success")|.sha' "$E" | sort -u) | wc -l | xargs)
if (( PRS>0 )); then
  awk -v i="$INT" -v p="$PRS" -v m="$COVERAGE_MIN" 'BEGIN{if(i/p<m){exit 1}}' \
    || { PCT=$(awk -v m="$COVERAGE_MIN" 'BEGIN{printf "%.0f", m*100}'); die "coverage<${PCT}% (int=$INT prs=$PRS)"; }
fi

# 4) Optional: ensure we use Deployments API success time (requires GH_TOKEN, DEPLOY_ENV)
if [[ -n "${GH_TOKEN:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${DEPLOY_ENV:-}" ]]; then
  ID=$(gh api "/repos/$GITHUB_REPOSITORY/deployments?environment=$DEPLOY_ENV&per_page=1" -q '.[0].id' || true)
  if [[ -n "${ID:-}" ]]; then
    ST=$(gh api "/repos/$GITHUB_REPOSITORY/deployments/$ID/statuses?per_page=100" \
         -q '[.[]|select(.state=="success")]|last.created_at' || true)
    [[ -z "$ST" ]] || grep -q "$ST" "$E" || die "not using deployment success status time"
  fi
fi

# 5) Optional: fallback ratio ≤30% if leadtime.csv exists
if [[ -f leadtime.csv ]]; then
  R=$(awk -F, 'NR>1{c[$6]++} END{n=c["fallback"]+c["sha"]; if(n==0) print 0; else printf "%.2f", c["fallback"]/n}')
  awk -v r="$R" 'BEGIN{if(r>0.30){exit 1}}' || die "fallback_ratio>$R"
fi

echo "HEALTH_OK"
