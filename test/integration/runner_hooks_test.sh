#!/usr/bin/env bash
# test/run_hooks_in_tmp.sh
set -euo pipefail

# locate repo root and test file
ROOT="$(git rev-parse --show-toplevel)"
TEST_PATH=""
if   [[ -f "$ROOT/test/hooks_install.bats" ]]; then TEST_PATH="test/hooks_install.bats"
elif [[ -f "$ROOT/test/integration/hooks_install.bats" ]]; then TEST_PATH="test/integration/hooks_install.bats"
else
  echo "hooks_install.bats not found under test/ or test/integration/" >&2
  exit 1
fi

# require bats
command -v bats >/dev/null || { echo "bats not installed"; exit 127; }

# temp clone (depth honored via file://)
TMP="$(mktemp -d)"
git clone --depth=1 "file://$ROOT" "$TMP"

pushd "$TMP" >/dev/null

# hard-clean runtime hooks inside the CLONE only
DST="$(git rev-parse --git-path hooks)"
rm -f "$DST"/{pre-commit,pre-push,pre-merge-commit,post-merge,post-rewrite,pre-rebase} 2>/dev/null || true
rm -f "$DST/README.mirrored" 2>/dev/null || true
git config --local --unset core.hooksPath || true

# run just the hooks test
echo "Running: bats $TEST_PATH in $TMP"
bats "$TEST_PATH"

popd >/dev/null
rm -rf "$TMP"
