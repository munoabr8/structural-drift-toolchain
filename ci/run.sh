#!/usr/bin/env bash
# ci/run.sh
set -euo pipefail

: "${SETUP_CMD:=:}"
: "${BUILD_CMD:=:}"
: "${TEST_CMD:=bash ./test.sh}"
: "${REPORT_CMD:=bash ./triage.sh job.log}"

bash -lc "$SETUP_CMD"
bash -lc "$BUILD_CMD"

set +e
bash -lc "$TEST_CMD" | tee job.log
rc=${PIPESTATUS[0]}
set -e

if (( rc != 0 )); then
  bash -lc "$REPORT_CMD" > triage.json || true

fi

 

sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
ok=$([[ $rc -eq 0 ]] && echo true || echo false)
printf '{"schema":"ci/test/v1","sha":"%s","ok":%s}\n' "$sha" "$ok" > result.json || true

exit $rc
