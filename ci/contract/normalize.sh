#!/usr/bin/env bash
# CONTRACT-JSON-BEGIN
# {
#   "contract_schema": "contract/v1",
#   "args": [
#     "<contract.json>"
#   ],
#   "env": {},
#   "reads": "contract file; no network",
#   "writes": [],
#   "tools": [
#     "bash",
#     "jq"
#   ],
#   "exit": {
#     "ok": 0
#   },
#   "emits": []
# }
# CONTRACT-JSON-END
# ci/contracts/normalize.sh

set -euo pipefail
f="${1:?usage: $0 <contract.json>}"
ver="$(jq -r '.contract_schema // "contract/v1"' "$f")"
case "$ver" in
  contract/v1) jq -f ci/contract/jq/normalize_v1.jq "$f" ;;
  *) echo "ERR:unknown contract_schema:$ver" >&2; exit 2 ;;
esac

