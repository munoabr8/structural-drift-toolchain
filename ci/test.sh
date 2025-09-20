#!/usr/bin/env bash
# ci/test.sh
set -euo pipefail

# Usage: bash scripts/test.sh [--filter "<pattern>"]
FILTER=""
if [[ "${1:-}" == "--filter" ]]; then
  FILTER="${2:-}"; shift 2 || true
fi

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

run() {
  local name=$1; shift
  log "START $name"
  local t0 t1
  t0=$(date +%s)
  "$@"
  t1=$(date +%s)
  log "END   $name (${t1-t0}s)"
}

exists() { command -v "$1" >/dev/null 2>&1; }

# Toggles (auto-detect; override with 0/1)
ENABLE_JAVA=${ENABLE_JAVA:-1}
ENABLE_PY=${ENABLE_PY:-1}
ENABLE_JS=${ENABLE_JS:-1}
ENABLE_BATS=${ENABLE_BATS:-1}
ENABLE_LINT=${ENABLE_LINT:-0}   # default off; enable when ready

JAVA_PRESENT=$([[ -f pom.xml ]] && echo 1 || echo 0)
PY_PRESENT=$([[ -d tests || -f pyproject.toml || -f pytest.ini ]] && echo 1 || echo 0)
JS_PRESENT=$([[ -f package.json ]] && echo 1 || echo 0)
BATS_PRESENT=$([[ -d tests || -d test ]] && ls -1 **/*.bats >/dev/null 2>&1 && echo 1 || echo 0)

# Lint (optional, fast gate)
if [[ "${ENABLE_LINT}" == "1" ]]; then
  if exists shellcheck; then
    run "shellcheck" bash -lc 'git ls-files "*.sh" | xargs -r shellcheck'
  else
    log "SKIP shellcheck (not installed)"
  fi
fi

# Java tests (Maven)
if [[ "${ENABLE_JAVA}" == "1" && "${JAVA_PRESENT}" == "1" ]]; then
  if exists mvn; then
    if [[ -n "$FILTER" ]]; then
      run "maven-tests(filter=$FILTER)" mvn -q -DfailIfNoTests=false -Dtest="$FILTER" test
    else
      run "maven-tests" mvn -q -DfailIfNoTests=false test
    fi
  else
    log "SKIP maven (mvn not found)"
  fi
fi

# Python tests (pytest)
if [[ "${ENABLE_PY}" == "1" && "${PY_PRESENT}" == "1" ]]; then
  if exists pytest; then
    if [[ -n "$FILTER" ]]; then
      run "pytest(filter=$FILTER)" pytest -q -k "$FILTER"
    else
      run "pytest" pytest -q
    fi
  else
    log "SKIP pytest (pytest not found)"
  fi
fi

# Node/Jest tests (via npm test)
if [[ "${ENABLE_JS}" == "1" && "${JS_PRESENT}" == "1" ]]; then
  if exists npm; then
    if [[ -n "$FILTER" ]]; then
      # Many setups use Jest; pass pattern through
      run "npm-test(filter=$FILTER)" bash -lc 'npm test -- --watchAll=false --testNamePattern "'"$FILTER"'"'
    else
      run "npm-test" npm test -- --watchAll=false
    fi
  else
    log "SKIP npm (npm not found)"
  fi
fi

# Bash tests (Bats)
if [[ "${ENABLE_BATS}" == "1" && "${BATS_PRESENT}" == "1" ]]; then
  if exists bats; then
    if [[ -n "$FILTER" ]]; then
      run "bats(filter=$FILTER)" bats -r -f "$FILTER" .
    else
      run "bats" bats -r .
    fi
  else
    log "SKIP bats (bats not found)"
  fi
fi

log "ALL DONE"
