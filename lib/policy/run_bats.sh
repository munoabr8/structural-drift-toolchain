#!/usr/bin/env bash
set -euo pipefail
# Usage:
#   POLICY_SRC_ENFORCE=./lib/policy/enforce_policy_p3.sh \
#   POLICY_SRC_TRANSFORM=./lib/policy/transform_policy_p2.sh \
#   bash /mnt/data/test/run_bats.sh
if ! command -v bats >/dev/null 2>&1; then
  echo "bats not found. Install via: brew install bats-core"
  exit 1
fi

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bats "$HERE/isolated_policy_tests.bats"
