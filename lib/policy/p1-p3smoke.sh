#!/usr/bin/env bash
set -euo pipefail

P1="$PWD/policy_query_p1.sh"
P2="$PWD/transform_policy_p2.sh"
P3="$PWD/enforce_policy_p3.sh"
[[ -f "$P1" && -f "$P2" && -f "$P3" ]] || { echo "missing P1/P2/P3" >&2; exit 127; }

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX"

# minimal project + policy
mkdir -p bin config
: > README.md
cat > config/policy.rules.yml <<'YAML'
- type: invariant
  path: bin
  condition: must_exist
  action: error
- type: invariant
  path: README.md
  condition: must_exist
  action: error
YAML



# happy path

POLICY_FILE="$SANDBOX/config/policy.rules.yml" \
bash -o pipefail -c "bash \"$P1\" | bash \"$P2\" | bash \"$P3\""
echo "OK:$?"   # expect 0

# failure path
rm -f README.md
set +e
POLICY_FILE="$SANDBOX/config/policy.rules.yml" \
bash -o pipefail -c "bash \"$P1\" | bash \"$P2\" | bash \"$P3\""
rc=$?
set -e
echo "FAIL:$rc"  # expect non-zero; P3 should emit event|violation

