# test/p2_p3_smoke.bats
#!/usr/bin/env bats

setup() {
  ROOT="$PWD"                                   # where scripts live
  P2="$ROOT/transform_policy_p2.sh"
  P3="$ROOT/enforce_policy_p3.sh"
  SANDBOX="$(mktemp -d)"
  cd "$SANDBOX"

  mkdir -p bin
  : > README.md
  printf 'invariant\tbin\tmust_exist\terror\ninvariant\tREADME.md\tmust_exist\terror\n' > policy.tsv
}

teardown() { cd /; rm -rf "$SANDBOX"; }

@test "P2|P3 happy path" {
  [ -f "$P2" ] || { echo "missing $P2"; return 127; }
  [ -f "$P3" ] || { echo "missing $P3"; return 127; }
  run bash -o pipefail -c "bash \"$P2\" < policy.tsv | bash \"$P3\""
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ event\|violation ]]
}

@test "P2|P3 fails when README.md is missing" {
  rm -f README.md
  run bash -o pipefail -c "bash \"$P2\" < policy.tsv | bash \"$P3\""
  [ "$status" -ne 0 ]
  [[ "$output" =~ event\|violation ]]
}
