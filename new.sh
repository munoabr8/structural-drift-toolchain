#!/usr/bin/env bash
# === smoke.sh ===
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ENFORCER="$ROOT/tools/enforce_policy.sh"
EXITCODES="$ROOT/tools/exit_codes_enforcer.sh"
