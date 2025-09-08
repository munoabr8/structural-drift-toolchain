#!/usr/bin/env bash
set -euo pipefail
. ci/git/lib-risk.sh

risk_plan_print
# refuse if behind and dirty; otherwise continue
risk_guard_if_behind_refuse_dirty
risk_guard_require_clean

ensure_hooks() {
  want="tools/git-hooks"
  got=$(git config --local core.hooksPath || echo "")
  [[ "$got" == "$want" ]] || {
    echo "warn: hooks not installed (core.hooksPath != $want). Run: make install-hooks" >&2
  }
}


ensure_hooks


exec git pull --rebase --autostash
