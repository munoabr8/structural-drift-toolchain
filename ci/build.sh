#!/usr/bin/env bash
# Compile/package without running tests; no side effects beyond build artifacts.
set -euo pipefail

log(){ printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

ENABLE_JAVA=${ENABLE_JAVA:-1}
ENABLE_PY=${ENABLE_PY:-1}
ENABLE_JS=${ENABLE_JS:-1}

# --- Java build ---
if [[ "$ENABLE_JAVA" == "1" && -f pom.xml ]]; then
  if have mvn; then
    log "maven package (skip tests)"
    mvn -q -B -DskipTests package
  else
    log "SKIP maven (mvn missing)"
  fi
fi

# --- Python build (editable install for runtime imports) ---
if [[ "$ENABLE_PY" == "1" && ( -f setup.cfg || -f pyproject.toml ) ]]; then
  if command -v python3 >/dev/null 2>&1; then
    log "python editable install"
    python3 -m pip install -e .
  else
    log "SKIP python (python3 missing)"
  fi
fi

# --- Node build ---
if [[ "$ENABLE_JS" == "1" && -f package.json ]]; then
  if have npm; then
    if grep -q '"build"' package.json; then
      log "npm run build"
      npm run -s build
    else
      log "SKIP npm build (no script)"
    fi
  else
    log "SKIP npm (npm missing)"
  fi
fi

log "build done"
