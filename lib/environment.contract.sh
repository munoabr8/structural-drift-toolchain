#!/usr/bin/env bash
set -euo pipefail

# Contract-specific config
ENV_KEYS=(RULES_FILE PATH LANG LC_ALL APP_MODE)
: "${ENV_SNAPSHOT_STRATEGY:=fixed}"

# Load library (adjust path as needed)
. "$(dirname "${BASH_SOURCE[0]}")/../lib/contract_env.sh"
 

 
