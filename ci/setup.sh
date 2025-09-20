#!/usr/bin/env bash
# Prep tools and deps; idempotent, fast.
set -euo pipefail

log(){ printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

ENABLE_JAVA=${ENABLE_JAVA:-1}
ENABLE_PY=${ENABLE_PY:-1}
ENABLE_JS=${ENABLE_JS:-1}

# --- Python deps ---
if [[ "$ENABLE_PY" == "1" && ( -f requirements.txt || -f pyproject.toml ) ]]; then
  if have python3; then
    log "python deps"
    python3 -m pip install -U pip >/dev/null
    if [[ -f requirements.txt ]]; then
      python3 -m pip install -r requirements.txt
    else
      # PEP 517 projects
      python3 -m pip install -e .
    fi
  else
    log "SKIP python (python3 missing)"
  fi
fi

# --- Node deps ---
if [[ "$ENABLE_JS" == "1" && -f package.json ]]; then
  if have npm; then
    log "npm deps"
    if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
  else
    log "SKIP npm (npm missing)"
  fi
fi

# --- Java deps (go offline) ---
if [[ "$ENABLE_JAVA" == "1" && -f pom.xml ]]; then
  if have mvn; then
    log "maven go-offline"
    mvn -q -B -DskipTests dependency:go-offline
  else
    log "SKIP maven (mvn missing)"
  fi
fi

log "setup done"
