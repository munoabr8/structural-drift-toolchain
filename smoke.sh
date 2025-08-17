#!/usr/bin/env bash
# === smoke.sh ===
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ENFORCER="$ROOT/tools/enforce_policy.sh"
EXITCODES="$ROOT/tools/exit_codes_enforcer.sh"

# shellcheck source=/dev/null


source "$EXITCODES"

pass() { printf "✔ %s\n" "$1"; }
fail() { printf "✘ %s (rc=%s, expected=%s)\n" "$1" "$2" "$3"; exit 1; }

run_expect() {
  local desc="$1" cmd="$2" expect="$3"
  set +e
  bash -c "$cmd"
  local rc=$?
  set -e
  [[ $rc -eq $expect ]] && pass "$desc" || fail "$desc" "$rc" "$expect"
}

# 0) Baseline OK (uses your real policy)
run_expect "Baseline OK" \
  "\"$ENFORCER\" >/dev/null" \
  "$EXIT_OK"

# 1) Run from a subdir (path resolver must still work)
run_expect "Run from subdir still OK" \
  "(cd \"$ROOT/system\" && \"$ENFORCER\" >/dev/null)" \
  "$EXIT_OK"

# 2) Violation -> EXIT_POLICY_VIOLATIONS
cat > /tmp/policy.violate.yml <<'YAML'
- type: invariant
  path: ^does-not-exist$
  condition: must_exist
  action: error
YAML
run_expect "Violation returns EXIT_POLICY_VIOLATIONS" \
  "POLICY_FILE=/tmp/policy.violate.yml \"$ENFORCER\" >/dev/null" \
  "$EXIT_POLICY_VIOLATIONS"

# 3) WARN-only -> EXIT_OK but prints WARN
cat > /tmp/policy.warn.yml <<'YAML'
- type: invariant
  path: ^does-not-exist$
  condition: must_exist
  action: warn
YAML
set +e
OUT=$(POLICY_FILE=/tmp/policy.warn.yml "$ENFORCER")
rc=$?
set -e
[[ $rc -eq $EXIT_OK && "$OUT" == *"WARN :"* ]] && pass "Warn-only returns EXIT_OK and prints WARN" || fail "Warn-only" "$rc" 

#exit "$EXIT_OK"   # or just: exit 0


# 4) Unknown condition -> EXIT_UNKNOWN_CONDITION
: "${EXIT_UNKNOWN_CONDITION:=13}"   # if you didn't define it yet
cat > /tmp/policy.unknown.yml <<'YAML'
- type: invariant
  path: ^modules(/|$)
  condition: nope_condition
  action: error
YAML
run_expect "Unknown condition------ -> EXIT_POLICY_VIOLATIONS" \
  "POLICY_FILE=/tmp/policy.unknown.yml \"$ENFORCER\" >/dev/null" \
  "$EXIT_UNKNOWN_CONDITION"



# 5) Missing policy file -> EXIT_POLICY_FILE_NOT_FOUND
run_expect "Missing policy file -> EXIT_POLICY_FILE_NOT_FOUND" \
  "POLICY_FILE=/tmp/this-file-does-not-exist.yml \"$ENFORCER\" >/dev/null" \
  "$EXIT_POLICY_FILE_NOT_FOUND"




# 6) yq missing -> EXIT_DEP_YQ_MISSING
mkdir -p /tmp/fakebin
PATH="/tmp/fakebin" run_expect "Missing yq -> EXIT_DEP_YQ_MISSING" \
  "POLICY_FILE=/tmp/policy.warn.yml PATH=\"/tmp/fakebin\" \"$ENFORCER\" >/dev/null" \
  "$EXIT_DEP_YQ_MISSING"

# 7) Snapshot missing -> regenerates without crashing (expect EXIT_OK)
rm -f "$ROOT/.structure.snapshot"
run_expect "Snapshot missing -> regenerates and passes" \
  "\"$ENFORCER\" >/dev/null" \
  "$EXIT_OK"

echo
echo "All smoke checks passed ✅"
exit "$EXIT_OK"   # or just: exit 0

