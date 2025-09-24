#!/usr/bin/env bash

#./ci/env/isolate_ci.sh

set -euo pipefail
. "$(dirname "$0")/_isolate_core.sh"

: "${LC_ALL:=C}"; export LC_ALL

umask 0022
export LC_ALL=C TZ=UTC



# remember repo root before we cd into WS
ROOT_DIR="$(pwd -P)"
 
WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
snapshot_repo "$WS"
cd "$WS" || { echo "ERR: workspace not created"; exit 64; }

init_write_marker
# keep CI-allowed vars (ensure PWD stays whitelisted in your scrub)
scrub_env "PATH HOME GH_TOKEN CI PWD TERM LC_ALL"

: "${SETUP_CMD:=:}"
: "${BUILD_CMD:=:}"
: "${TEST_CMD:=bash ./ci/test.sh}"
: "${REPORT_CMD:=bash ./ci/triage.sh job.log}"

probe_env > before.json
run_step "$SETUP_CMD"
run_step "$BUILD_CMD"
run_step "$TEST_CMD | tee job.log"
run_step "$REPORT_CMD"
probe_env > after.json

# ---- export artifacts to repo root, not WS ----
ENV_ARTDIR="${ENV_ARTDIR:-artifacts/env}"
DEST="$ROOT_DIR/$ENV_ARTDIR"
mkdir -p "$DEST"

# optional: verify files exist before copying (helps debug)
test -s before.json || echo "WARN: before.json missing"
test -s after.json  || echo "WARN: after.json missing"
test -s job.log     || echo "WARN: job.log missing"

cp -f before.json "$DEST/before.json" 2>/dev/null || true
cp -f after.json  "$DEST/after.json"  2>/dev/null || true
cp -f job.log     "$DEST/job.log"     2>/dev/null || true
 
echo "Artifacts exported → $DEST"

# ---- checks (optional) ----
assert_min_env
assert_tools
assert_locale
assert_umask
assert_lock
assert_probe_schema

assert_writes_confined
