#!/usr/bin/env bats


@test "happy path via --stdin" {
  yaml=$'- type: invariant\n  path: README.md\n  condition: must_exist\n  action: error\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -eq 0 ]
  # 1 line, 4 fields
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
  echo "$output" | awk -F'\t' 'NF!=4 { exit 99 }'
  [ "$?" -ne 99 ]
  [ "$output" = $'invariant\tREADME.md\tmust_exist\terror' ]
}


@test "reads YAML from stdin" {
  yaml=$'- type: invariant\n  path: README.md\n  condition: must_exist\n  action: error\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -eq 0 ]
  [ "$output" = $'invariant\tREADME.md\tmust_exist\terror' ]
}

@test "allow-empty skips missing file without error" {
  run bash ./policy_query_p1.sh --policy /no/such/file --allow-empty
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}


@test "missing file error vs allow-empty" {
  run bash ./policy_query_p1.sh --policy /no/such/file
  [ "$status" -ne 0 ]
  [[ "$output" == *"policy not found"* ]]

  run bash ./policy_query_p1.sh --policy /no/such/file --allow-empty
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-array top-level fails" {
  yaml=$'key: value\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -ne 0 ]
}

@test "missing fields produce nulls" {
  yaml=$'- type: invariant\n  path: README.md\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -eq 0 ]
  [ "$output" = $'invariant\tREADME.md\tnull\tnull' ]
}

@test "two rules preserve order" {
  yaml=$'- type: invariant\n  path: A\n  condition: must_exist\n  action: error\n'\
$'- type: invariant\n  path: B\n  condition: must_exist\n  action: error\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 2 ]
  first=$(echo "$output" | sed -n '1p')
  second=$(echo "$output" | sed -n '2p')
  [ "$first" = $'invariant\tA\tmust_exist\terror' ]
  [ "$second" = $'invariant\tB\tmust_exist\terror' ]

}


@test "fails when policy file missing" {
  run bash ./policy_query_p1.sh --policy /no/such/file
  [ "$status" -ne 0 ]
  [[ "$output" == *"policy not found"* ]]
}

# 2) Non-array root via --stdin
@test "fails on non-sequence root (map)" {
  yaml=$'key: value\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"policy root must be a YAML sequence"* ]]
}

# 3) Invalid YAML syntax
@test "fails on malformed YAML" {
  yaml=$'- type: invariant\n  path: [unterminated\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -ne 0 ]
}

# 4) yq error is propagated (shim)
@test "propagates yq nonzero exit (PATH shim, -e passes)" {
  tmp="$(mktemp -d)"
  cat >"$tmp/yq" <<'SH'
#!/usr/bin/env bash
# If called with -e (root-type check), succeed.
if [[ "$1" == "-e" ]]; then exit 0; fi
# Otherwise fail like yq -r … (the data query path)
exit 42
SH
  chmod +x "$tmp/yq"

  run env PATH="$tmp:$PATH" bash ./policy_query_p1.sh --stdin <<<'[]'

  [ "$status" -eq 42 ]
  [ -z "$output" ]
}



@test "fails on unknown argument" {
  run bash ./policy_query_p1.sh --unknown-flag
  [ "$status" -ne 0 ]
}

# 6) Unreadable policy file (permissions)
@test "fails when policy file unreadable" {
  tmp="$BATS_TMPDIR/p.yml"; printf '%s\n' '--' >"$tmp" >"$tmp"; chmod 000 "$tmp"
  run bash ./policy_query_p1.sh --policy "$tmp"
  [ "$status" -ne 0 ]
  chmod 644 "$tmp"
}

 
@test "fails on multi-document YAML" {
  yaml=$'---\n- {type: invariant, path: A, condition: must_exist, action: error}\n---\n- {type: invariant, path: B, condition: must_exist, action: error}\n'
  run bash ./policy_query_p1.sh --stdin <<<"$yaml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"multiple YAML documents not supported"* ]]
}