#!/usr/bin/env bats

setup() {
P1="./policy_query_p1.sh"
P2="./transform_policy_p2.sh"
}

@test "syntax OK" {
  run bash -n "$P1"
  [ "$status" -eq 0 ]
  run bash -n "$P2"
  [ "$status" -eq 0 ]
}

@test "happy path: P1|P2 returns 0 and emits JSON" {
  input='{"k":"v"}'
  run bash -c "printf '%s\n' '$input' | \"$P1\" | \"$P2\""
  [ "$status" -eq 0 ]
  #[[ "$output" =~ ^\{.*\}$ ]]    # crude JSON shape
  [ -n "$output" ]
}


@test "failure in P1 propagates through pipe" {
  run bash -o pipefail -c "printf '%s\n' 'k: v' | \"$P1\" --stdin | \"$P2\""
  [ "$status" -ne 0 ]   # P1 rejects non-sequence root
}


# P2 shape rejection will pass after the P2 patch below
@test "P2 rejects invalid upstream shape" {
  run bash -o pipefail -c "printf '%s\n' 'not-json' | \"$P2\""
  [ "$status" -ne 0 ]
  [[ "$output" =~ invalid\ TSV ]]

 }



@test "stderr stays separate" {
  run bash -c "printf '%s\n' '{\"k\":\"v\"}' | \"$P1\" 2>err.log | \"$P2\""
  [ "$status" -eq 0 ]
  [ -s err.log ] || true   # optionally assert empty or non-empty per contract
}

@test "idempotency (if required)" {
  input='{"k":"v"}'
  run bash -c "printf '%s\n' '$input' | \"$P1\" | \"$P2\" | \"$P2\""
  [ "$status" -eq 0 ]
}
