#!/usr/bin/env bash
# Bats wrapper around _isolate_core
set -euo pipefail
. "$(dirname "$0")/_isolate_core.sh"

WS="${WS:-"$(mktemp -d)"}"
if [[ -z "${WS_PREPARED:-}" ]]; then
  snapshot_repo "$WS"
fi

cd "$WS" || { echo "ERR: workspace not created: $WS"; exit 64; }

# --- environment hardening ---
: "${TERM:=dumb}"; export TERM             # safe TERM for non-TTY runs
export NO_COLOR=1 BATS_NO_TPUT=1           # stop bats/bashrc from calling tput
export ALLOWLIST="${ALLOWLIST:-PATH HOME WS TERM LC_ALL}"  # keep TERM + LC_ALL
scrub_env                                  # scrub using allowlist

# --- pipeline commands (same defaults as CI) ---
: "${SETUP_CMD:=:}"
: "${BUILD_CMD:=:}"
: "${TEST_CMD:=bats --tap -r test}"        # default to bats runner
: "${REPORT_CMD:=bash ci/triage.sh job.log}"

# --- run pipeline ---
probe_env > before.json
run_step "$SETUP_CMD"
run_step "$BUILD_CMD"
run_step "$TEST_CMD" || exit $?
run_step "$REPORT_CMD"
probe_env > after.json
