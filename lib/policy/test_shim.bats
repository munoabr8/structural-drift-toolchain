# test_predicates.bats
#!/usr/bin/env bats
load "./predicates-shim.sh"   # or your predicates lib

# Generic assert helpers
assert_true()  { "$@"; [ "$?" -eq 0 ] || { echo "expected true: $*"; return 1; }; }
assert_false() { "$@"; [ "$?" -ne 0 ] || { echo "expected false: $*"; return 1; }; }

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  SHIM="$REPO_DIR/policy/transform_policy_rules_shim"
  SANDBOX="$BATS_TEST_TMPDIR/$BATS_TEST_NAME"; mkdir -p "$SANDBOX"
}

@test "has_shebang matches bash" {
  # Ensure shebang on line 1
  assert_true has_shebang "$SHIM" 'bash'
}

@test "stdin_present detects pipe" {
  run bash -lc 'source "'"$BATS_TEST_DIRNAME/predicates-shim.sh"'"; printf x | stdin_present'
  [ "$status" -eq 0 ]   # true when piped
  run bash -lc 'source "'"$BATS_TEST_DIRNAME/predicates-shim.sh"'"; stdin_present'
  [ "$status" -ne 0 ]   # false on TTY
}


@test "has_valid_shape enforces shape + mode" {
  assert_true  has_valid_shape "t|p|c|a"            # 4 fields, no mode
  assert_true  has_valid_shape "t|p|c|a|literal"    # valid mode
  assert_true  has_valid_shape "t|p|c|a|regex"
 
}

@test "fn_defined sees functions after source" {
  run bash -lc 'source "'"$BATS_TEST_DIRNAME/predicates-shim.sh"'"; fn_defined has_shebang'
  [ "$status" -eq 0 ]
}


# helper: capture a command's return code without subshells
rc_of() { "$@"; printf '%s' $?; }

@test "valid: 4 fields, no mode" {
  has_valid_shape "t|p|c|a"
  [ "$?" -eq 0 ]
}

@test "valid: 5 fields, literal" {
  [ "$(rc_of has_valid_shape 't|p|c|a|literal')" -eq 0 ]
}

@test "valid: 5 fields, regex" {
  [ "$(rc_of has_valid_shape 't|p|c|a|regex')" -eq 0 ]
}

@test "invalid: empty line → rc=1" {
  [ "$(rc_of has_valid_shape '')" -eq 1 ]
}

@test "invalid: too many fields (>5) → rc=2" {
  [ "$(rc_of has_valid_shape 't|p|c|a|literal|extra')" -eq 2 ]
}

@test "invalid: fewer than 4 fields → rc=3" {
  [ "$(rc_of has_valid_shape 't|p|c')" -eq 3 ]
}

@test "invalid: empty required field (4th empty) → rc=3" {
  [ "$(rc_of has_valid_shape 't|p|c|')" -eq 3 ]
}

@test "invalid: bad mode → rc=4" {
  [ "$(rc_of has_valid_shape 't|p|c|a|weird')" -eq 4 ]
}

@test "valid: CRLF normalized" {
  [ "$(rc_of has_valid_shape $'t|p|c|a\r')" -eq 0 ]
}
