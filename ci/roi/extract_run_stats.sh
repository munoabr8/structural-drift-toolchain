#!/usr/bin/env bash
# ci/roi/extract_run_stats.sh  — emit runs + avg_sec (mean|p50) from runs.json
set -euo pipefail

IN="${1:-runs.json}"
: "${IN:?missing runs.json}"

# Filters (can be overridden by workflow env)
HEAD_BRANCH="${HEAD_BRANCH:-}"                         # e.g. main or dev; empty = all
RUN_NAME_REGEX="${RUN_NAME_REGEX:-}"                   # e.g. (?i)(accept|purity|structure|shellcheck)
DURATION_METRIC="${DURATION_METRIC:-p50}"              # p50 | mean

read -r RUNS MEAN_SEC P50_SEC < <(
  jq -rf ci/roi/run_stats.jq \
     --arg b "${HEAD_BRANCH:-}" \
     --arg re "${RUN_NAME_REGEX:-}" \
     "$IN"
)

case "${DURATION_METRIC,,}" in
  mean) AVG_SEC="$MEAN_SEC" ;;
  p50|median|"") AVG_SEC="$P50_SEC" ;;
  *) echo "Unknown DURATION_METRIC: $DURATION_METRIC" >&2; exit 2 ;;
esac

 
 
# Emit GitHub outputs (required by your aggregator/baseline jobs)
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "runs=${RUNS}"
    echo "mean_sec=${MEAN_SEC}"
    echo "p50_sec=${P50_SEC}"
    echo "avg_sec=${AVG_SEC}"
  } >> "$GITHUB_OUTPUT"
fi

# Optional: brief log
echo "run_stats: runs=$RUNS avg_sec=${AVG_SEC} (metric=${DURATION_METRIC})" >&2
