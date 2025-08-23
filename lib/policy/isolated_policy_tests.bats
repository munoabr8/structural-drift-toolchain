#!/usr/bin/env bats
 

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TRANSFORM="$REPO_DIR/policy/transform_policy_rules"   # shim executable

  # sandbox FS (not used by transform, but keeps symmetry)
  TMPROOT="$BATS_TEST_TMPDIR/sbx"; mkdir -p "$TMPROOT"; cd "$TMPROOT"

  # point shim at the real source file that defines transform_policy_rules
  export CODE_ROOT="$REPO_DIR"
  : "${POLICY_SRC_TRANSFORM:=$REPO_DIR/policy/transform_policy_p2.sh}"  # <-- adjust if different
  export POLICY_SRC_TRANSFORM

  [[ -x "$TRANSFORM" ]] || { echo "missing shim: $TRANSFORM"; return 1; }
  [[ -r "$POLICY_SRC_TRANSFORM" ]] || { echo "missing source: $POLICY_SRC_TRANSFORM"; return 1; }
}

teardown() { true; }

assert_status() { [ "$status" -eq "${1:-0}" ]; }
assert_exe() { [[ -x "$1" ]] || { echo "not executable: $1"; return 1; }; }
assert_readable() { [[ -r "$1" ]] || { echo "not readable: $1"; return 1; }; }
assert_def() { type -t "$1" >/dev/null 2>&1 || { echo "missing func: $1"; return 1; }; }
assert_pipe5() { [[ "$1" =~ ^[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+$ ]]; }
assert_match() { [[ "$1" =~ $2 ]] || { echo "no match <$2>"; return 1; }; }
assert_single_terminal() {
  local o="$1"
  [[ $(grep -c '^event|check|' <<<"$o") -eq $(grep -Ec '^event\|(ok|violation|warn)\|' <<<"$o") ]]
}
assert_kv() { [[ "$1" =~ \|$2=$3(\||$) ]]; }  # usage: assert_kv "$line" key 'regex'
last_event() { grep '^event|' <<<"$1" | tail -n1; }


@test "precondition: symbol available after sourcing" {
  run env -i CODE_ROOT="$REPO_DIR" POLICY_SRC_TRANSFORM="$POLICY_SRC_TRANSFORM" \
    bash --noprofile --norc -lc '
      cd "$CODE_ROOT"; set +e +u; set +o pipefail
      source "$POLICY_SRC_TRANSFORM" >/dev/null 2>&1 || true
      declare -F transform_policy_rules >/dev/null
    '
  [ "$status" -eq 0 ]
}

@test "4-field TSV → infer mode: literal for plain, regex for strong metachars" {
  run "$TRANSFORM" <<< $'invariant\tplain.txt\tmust_exist\terror\n'
  assert_status 0
  assert_pipe5 "${output}"
  [[ "${output}" =~ \|literal$ ]]

  run "$TRANSFORM" <<< $'invariant\t^file\.txt$\tmust_exist\terror\n'
  assert_status 0
  assert_pipe5 "${output}"
  [[ "${output}" =~ \|regex$ ]]
}

@test "5-field TSV → passthrough mode" {
  run "$TRANSFORM" <<< $'invariant\tname.txt\tmust_exist\terror\tliteral\n'
  assert_status 0
  [[ "${output}" == "invariant|name.txt|must_exist|error|literal" ]]

  run "$TRANSFORM" <<< $'invariant\t^n.*e$\tmust_exist\terror\tregex\n'
  assert_status 0
  [[ "${output}" == "invariant|^n.*e$|must_exist|error|regex" ]]
}

@test "pipe-form (5 fields) → passthrough unchanged" {
  run "$TRANSFORM" <<< $'invariant|foo/bar|must_exist|error|literal\n'
  assert_status 0
  [[ "${output}" == "invariant|foo/bar|must_exist|error|literal" ]]
}

@test "malformed input → exit 65" {
  run "$TRANSFORM" <<< $'invariant\tonly3\tfields\n'
  [ "$status" -eq 65 ]
}

@test "transform: no stderr on success" {
  in=$'invariant\tok.txt\tmust_exist\terror\n'
  run env -i \
    HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    CODE_ROOT="$REPO_DIR" POLICY_SRC_TRANSFORM="$POLICY_SRC_TRANSFORM" \
    bash --noprofile --norc -c '
      set -e
      printf "%s" "$1" | "$2" 1>/dev/null 2>err.txt
      wc -c < err.txt
    ' _ "$in" "$REPO_DIR/policy/transform_policy_rules"
  [ "$status" -eq 0 ]
  [[ "${output//[[:space:]]/}" == "0" ]]
}




# @test "determinism: same input → same output" {
#   in=$'invariant\tplain.txt\tmust_exist\terror\n'
#   o1="$("$TRANSFORM" <<< "$in")"
#   o2="$("$TRANSFORM" <<< "$in")"
#   [[ "$o1" == "$o2" ]]
# }



# @test "enforce: exit code matrix and terminals" {
#   cd "$REPO_ROOT"; : > a.txt
#   run "$ENFORCE" 'invariant|a.txt|must_exist|error|literal'
#   [ "$status" -eq 0 ]
#   [[ "$output" =~ (^|\n)event\|ok\| ]]

#   run "$ENFORCE" 'invariant|missing.txt|must_exist|error|literal'
#   [ "$status" -eq 1 ]
#   [[ "$output" =~ (^|\n)event\|violation\| ]]

#   run "$ENFORCE" 'invariant|x|unsupported_condition|error|literal'
#   [ "$status" -eq 0 ]
#   [[ "$output" =~ (^|\n)event\|warn\| ]]
#   [[ $(grep -c '^event|check|' <<<"$output") -eq $(grep -Ec '^event\|(ok|violation|warn)\|' <<<"$output") ]]
# }

# @test "enforce: duration_ms numeric non-negative" {
#   cd "$REPO_ROOT"; : > t.txt
#   run "$ENFORCE" 'invariant|t.txt|must_exist|error|literal'
#   [ "$status" -eq 0 ]
#   line="$(grep '^event|' <<<"$output" | tail -n1)"
#   [[ "$line" =~ \|duration_ms=([0-9]+)($|\|) ]]
# }

# @test "enforce: literal vs regex semantics" {
#   cd "$REPO_ROOT"; mkdir -p d; : > d/ab.txt
#   # literal on basename should fail
#   run "$ENFORCE" 'invariant|ab.txt|must_exist|error|literal'
#   [ "$status" -eq 1 ]
#   [[ "$output" =~ (^|\n)event\|violation\| ]]
#   # regex anchored to full path should pass
#   run "$ENFORCE" 'invariant|(^|.*/)ab\.txt$|must_exist|error|regex'
#   [ "$status" -eq 0 ]
#   [[ "$output" =~ (^|\n)event\|ok\| ]]
# }

# @test "enforce: idempotence ignoring timing" {
#   cd "$REPO_ROOT"; : > idem.txt
#   rec='invariant|idem.txt|must_exist|error|literal'
#   run "$ENFORCE" "$rec"; o1="$output"
#   run "$ENFORCE" "$rec"; o2="$output"
#   o1c="$(printf "%s" "$o1" | sed -E 's/duration_ms=[0-9]+/duration_ms=/' )"
#   o2c="$(printf "%s" "$o2" | sed -E 's/duration_ms=[0-9]+/duration_ms=/' )"
#   [[ "$o1c" == "$o2c" ]]
# }

# @test "enforce: logging keys present and path_raw preserved" {
#   cd "$REPO_ROOT"; : > k.txt
#   run "$ENFORCE" 'invariant|k.txt|must_exist|error|literal'
#   [ "$status" -eq 0 ]
#   chk="$(grep '^event|check|' <<<"$output")"
#   fin="$(grep '^event|' <<<"$output" | tail -n1)"
#   [[ "$chk" =~ \|path_raw=k\.txt(\||$) ]]
#   [[ "$chk" =~ \|path=([^|]*) ]]
#   [[ "$chk" =~ \|mode=literal(\||$) ]]
#   [[ "$fin" =~ \|duration_ms=[0-9]+(\||$) ]]
# }


@test "transform: exactly one output line with 5 fields" {
  in=$'invariant\tplain.txt\tmust_exist\terror\n'
  out="$("$REPO_DIR/policy/transform_policy_rules" <<< "$in")"
  clean="$(printf '%s\n' "$out" | sed '/^[[:space:]]*$/d')"
  [[ "$(printf '%s' "$clean" | wc -l | tr -d '[:space:]')" -eq 1 ]]
  line="$(printf '%s' "$clean")"
  [[ "$line" =~ ^[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+$ ]]
  [[ ! "$line" =~ [[:space:]]$ ]]
}

 
@test "transform: unicode path round-trips and infers literal" {
  run "$REPO_DIR/policy/transform_policy_rules" <<< $'invariant\tmañana/файл.txt\tmust_exist\terror\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'mañana/файл.txt'* ]]
  [[ "$output" =~ \|literal$ ]]
}
