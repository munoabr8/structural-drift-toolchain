#!/usr/bin/env bash
# ci/env/probe_env.sh  — emits JSON to assert env state
set -euo pipefail
j(){ jq -nc "$@"; }
v(){ command -v "$1" >/dev/null && "$1" --version 2>&1 | head -1 || echo "missing"; }

j --arg os "$(uname -a)" \
  --arg bash "$BASH_VERSION" \
  --arg git "$(v git)" \
  --arg node "$(v node)" \
  --arg python "$(v python3)" \
  --arg jq "$(v jq)" \
  --arg path "$PATH" \
  --arg locked "$(test -f package-lock.json || test -f poetry.lock || test -f requirements.txt && echo yes || echo no)" \
  '{schema:"env/probe/v1", os:$os, tools:{bash:$bash,git:$git,node:$node,python:$python,jq:$jq}, path:$path, lock:$locked}'
