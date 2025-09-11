#!/usr/bin/env bash
# bin/risk_pull.sh
set -euo pipefail
. ci/git/lib-risk.sh

usage(){ cat <<EOF
usage: $(basename "$0") [--plan] [--hooks|--no-hooks] [--base upstream|main] [--onto <ref>]
Default: rebase with upstream (git pull --rebase --autostash)
--base main     rebase current branch onto local 'main'
--onto <ref>    rebase onto an explicit ref (branch/PR/SHA)
--plan          print risk plan only
--hooks         enable hooks (default)
--no-hooks      disable hooks
EOF
exit 2; }

PLAN=0
BASE="upstream"   # upstream|main
ONTO=""           # explicit ref
HOOKS=1           # 1=on, 0=off
# env compat
[[ "${DISABLE_HOOKS:-}" == "1" ]] && HOOKS=0
[[ "${RISK_BULK:-0}" == "1" ]] && HOOKS=0

while (( $# )); do
  case "$1" in
    --plan) PLAN=1 ;;
    --hooks) HOOKS=1 ;;
    --no-hooks) HOOKS=0 ;;
    --base) BASE="${2:-}"; shift ;;
    --onto) ONTO="${2:-}"; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac; shift
done

risk_plan_print
risk_guard_if_behind_refuse_dirty
risk_guard_require_clean

# hooks toggle
if (( HOOKS==0 )); then export DISABLE_HOOKS=1; fi

# plan-only
if (( PLAN==1 )); then exit 0; fi

# choose strategy
if [[ -n "$ONTO" ]]; then
  # explicit target ref (branch/PR/SHA)
  git fetch --prune origin || true
  exec git rebase --autostash "$ONTO"
fi

case "$BASE" in
  upstream)
    # standard: pull from configured upstream
    exec git pull --rebase --autostash
    ;;
  main)
    # rebase onto local 'main' (assumes you keep it current)
    git rev-parse --verify main >/dev/null 2>&1 || { echo "error: local 'main' not found"; exit 65; }
    exec git rebase --autostash main
    ;;
  *)
    echo "error: --base must be 'upstream' or 'main'"; exit 64
    ;;
esac
