#!/usr/bin/env bash

# system/bats-guard.sh
# Enforces minimal test invariants for BATS

require_file() {
  local file="$1"
  [[ -f "$file" ]] || {
    echo "❌ Required file missing: $file" >&2
    exit 97
  }
}

require_function() {
  local fn="$1"
  type -t "$fn" &>/dev/null || {
    echo "❌ Required function not defined: $fn" >&2
    exit 98
  }
}

log_guard_info() {
  echo "🔍 Guard: $1 passed" >&2
}

