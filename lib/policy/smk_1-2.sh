#!/usr/bin/env bash
set -euo pipefail

P1="./policy_query_p1.sh"
P2="./transform_policy_p2.sh"

# 0. syntax
bash -n "$P1"; bash -n "$P2"

# 1. happy-path sample
input='{"k":"v"}'
out="$(printf '%s\n' "$input" | "$P1" | "$P2")" || rc=$?
printf 'OUT:\n%s\n' "${out:-}" ; printf 'RC:%s\n' "${rc:-0}"

# 2. propagate failure from P1
bad='__TRIGGER_ERROR__'
set +e
printf '%s\n' "$bad" | "$P1" | "$P2"
rc=$?
set -e
printf 'RC_FAIL_CHAIN:%s\n' "$rc"

