#!/usr/bin/env bash
set -euo pipefail


#./ci/git/lib-risk.sh

risk_branch() { git rev-parse --abbrev-ref HEAD; }
risk_upstream() { git rev-parse --abbrev-ref --symbolic-full-name @{u}; }

risk_clean() { git diff --quiet && git diff --cached --quiet; }

risk_ahead_behind() {
  local up; up=$(risk_upstream)
  git rev-list --left-right --count "${up}...HEAD" | awk '{print "behind=" $1 " ahead=" $2}'
}

risk_plan_print() {
  local up b ab
  up=$(risk_upstream) || { echo "require: upstream tracking branch"; return 2; }
  b=$(risk_branch)
  ab=$(risk_ahead_behind)
  echo "Risk plan:
  branch:   $b
  upstream: $up ($ab)
  clean:    $(risk_clean && echo yes || echo no)
  strategy: rebase --autostash"
}

risk_guard_require_clean() {
  risk_clean || { echo "refuse: dirty working tree. stash/commit first."; return 3; }
}

risk_guard_if_behind_refuse_dirty() {
  local up; up=$(risk_upstream) || return 2
  local behind; behind=$(git rev-list --left-right --count "${up}...HEAD" | awk '{print $1}')
  if [[ "${behind:-0}" -gt 0 ]] && ! risk_clean; then
    echo "refuse: behind upstream and dirty. stash/commit first."; return 4
  fi
}
