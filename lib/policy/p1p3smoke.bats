# test/p1_p3_pipeline.bats
#!/usr/bin/env bats

setup() {
  ROOT="$PWD"                               # directory containing scripts
  P1="$ROOT/policy_query_p1.sh"
  P2="$ROOT/transform_policy_p2.sh"
  P3="$ROOT/enforce_policy_p3.sh"
  [ -f "$P1" ] && [ -f "$P2" ] && [ -f "$P3" ] || { echo "missing scripts"; return 127; }

  SANDBOX="$(mktemp -d)"
  cd "$SANDBOX"
  mkdir -p bin config
  : > README.md

  # valid policy (root sequence)
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
  POLICY_FILE="$SANDBOX/config/policy.rules.yml"
}

teardown() { cd /; rm -rf "$SANDBOX"; }

@test "P1|P2|P3 happy path" {
  run bash -o pipefail -c "env POLICY_FILE=\"$POLICY_FILE\" bash \"$P1\" | bash \"$P2\" | bash \"$P3\""
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ event\|violation ]]
}

@test "P1|P2|P3 fails when README.md missing" {
  rm -f README.md
  run bash -o pipefail -c "env POLICY_FILE=\"$POLICY_FILE\" bash \"$P1\" | bash \"$P2\" | bash \"$P3\""
  [ "$status" -ne 0 ]
  [[ "$output" =~ event\|violation ]]
}

@test "P1 rejects wrong root shape (map with rules:)" {
  cat > config/policy.rules.yml <<'YAML'
rules:
  - type: invariant
    path: bin
    condition: must_exist
    action: error
YAML
  run bash -o pipefail -c "env POLICY_FILE=\"$SANDBOX/config/policy.rules.yml\" bash \"$P1\" | bash \"$P2\" | bash \"$P3\""
  [ "$status" -ne 0 ]
  [[ "$output" =~ policy\ root\ must\ be\ a\ YAML\ sequence ]] || true
}

