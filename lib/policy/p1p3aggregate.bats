# test/p1_p3_aggregate.bats
#!/usr/bin/env bats

setup() {
  ROOT="$PWD"; P1="$ROOT/policy_query_p1.sh"; P2="$ROOT/transform_policy_p2.sh"; P3="$ROOT/enforce_policy_p3.sh"
  SANDBOX="$(mktemp -d)"; cd "$SANDBOX"
  mkdir -p bin util tools; : > README.md; : > tools/enforce_policy.sh
  # omit main.sh and config/policy.rules.yml to force two violations
  cat > config.yml <<'YAML'
- {type: invariant, path: bin,                         condition: must_exist, action: error}
- {type: invariant, path: README.md,                   condition: must_exist, action: error}
- {type: invariant, path: main.sh,                     condition: must_exist, action: error}
- {type: invariant, path: config/policy.rules.yml,     condition: must_exist, action: error}
- {type: invariant, path: tools/enforce_policy.sh,     condition: must_exist, action: error}
YAML
}

teardown(){ cd /; rm -rf "$SANDBOX"; }

@test "aggregate: all results and counts visible" {
run bash -o pipefail -c \
  "FAIL_FAST=0 POLICY_FILE=\"$SANDBOX/config.yml\" bash \"$P1\" | bash \"$P2\" | bash \"$P3\""
[ "$status" -ne 0 ]

# specific OKs
[[ "$output" =~ event\|ok\|path~=bin ]]
[[ "$output" =~ event\|ok\|path~=README\.md ]]
[[ "$output" =~ event\|ok\|path~=tools/enforce_policy\.sh ]]

# specific violations
[[ "$output" =~ event\|violation.*path~=main\.sh ]]
[[ "$output" =~ event\|violation.*path~=config/policy\.rules\.yml ]]

# optional counts
[ "$(grep -c 'event|ok' <<<"$output")" -eq 3 ]
[ "$(grep -c 'event|violation' <<<"$output")" -eq 2 ]

}

