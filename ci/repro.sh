

#!/usr/bin/env bash
# One-command local repro that mirrors CI pipeline
set -euo pipefail

# Optional: --filter "pattern" appended to TEST_CMD if your test runner supports it
FILTER=""
if [[ "${1:-}" == "--filter" ]]; then
  FILTER="${2:-}"; shift 2 || true
fi

# Same env defaults as CI
: "${SETUP_CMD:=:}"
: "${BUILD_CMD:=:}"
: "${TEST_CMD:=bash ./test.sh}"
: "${REPORT_CMD:=bash ./triage.sh job.log}"

# If a filter was provided and TEST_CMD looks like scripts/test.sh, append it
if [[ -n "$FILTER" && "$TEST_CMD" =~ ./test\.sh ]]; then
  TEST_CMD="$TEST_CMD --filter \"$FILTER\""
elif [[ -n "$FILTER" ]]; then
  # Generic fallback: just append; your runner must accept it
  TEST_CMD="$TEST_CMD $FILTER"
fi

export SETUP_CMD BUILD_CMD TEST_CMD REPORT_CMD

# Run the same pipeline CI uses; produces job.log, result.json, triage.json (on fail)
bash ./run.sh
