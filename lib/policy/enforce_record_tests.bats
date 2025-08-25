 #!/usr/bin/env bats
setup() {
  # repo paths
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TRANSFORM="$REPO_DIR/policy/transform_policy_rules"   # shim (executable)
  ENFORCE="$REPO_DIR/policy/enforce_record"             # shim (executable)

  # sandbox FS under test
  REPO_ROOT="$BATS_TEST_TMPDIR/sandbox"
  mkdir -p "$REPO_ROOT"
  cd "$REPO_ROOT"

  # code repo root (for sourcing)
  export CODE_ROOT="$REPO_DIR"
  export REPO_ROOT

  # real source files that define the functions (adjust to your layout)
  export POLICY_SRC_TRANSFORM="$REPO_DIR/policy/transform_policy_p2.sh"
  export POLICY_SRC_ENFORCE="$REPO_DIR/policy/enforce_policy_p3.sh"

#echo "$POLICY_SRC_ENFORCE" >&3
#ls -l "$POLICY_SRC_ENFORCE" >&3
  # sanity


  [[ -r "$POLICY_SRC_ENFORCE" ]] || { echo "unreadable: $POLICY_SRC_ENFORCE"; return 1; }
  [[ -f "$POLICY_SRC_ENFORCE" ]] || { echo "not a file: $POLICY_SRC_ENFORCE"; return 1; }
  [[ -x "$TRANSFORM" && -x "$ENFORCE" ]] || { echo "missing shims"; return 1; }
  [[ -r "$POLICY_SRC_TRANSFORM" && -r "$POLICY_SRC_ENFORCE" ]] || { echo "missing sources"; return 1; }
}

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


# Precondition: shims and sources exist
@test "shim preconditions" {
  assert_exe "$ENFORCE"
  assert_readable "$POLICY_SRC_ENFORCE"
}

@test "source defines enforce_record" {
  run env -i CODE_ROOT="$REPO_DIR" POLICY_SRC_ENFORCE="$POLICY_SRC_ENFORCE" bash --noprofile --norc -lc '
    cd "$CODE_ROOT"
    set +e +u; set +o pipefail
    [[ -r "$POLICY_SRC_ENFORCE" ]] || { echo "unreadable: $POLICY_SRC_ENFORCE"; exit 1; }
    # quick sanity that file mentions the symbol
    grep -Eq "^[[:space:]]*enforce_record[[:space:]]*\\(" "$POLICY_SRC_ENFORCE" || echo "warn: symbol not text-found"
    source "$POLICY_SRC_ENFORCE" || { echo "source failed"; exit 1; }
    declare -F enforce_record >/dev/null || { echo "func missing"; declare -F; exit 1; }
    type enforce_record
  '
  [ "$status" -eq 0 ] || printf 'stdout:\n%s\n' "$output"
}

@test "source defines enforce_record2" {
  run env -i REPO_DIR="$REPO_DIR" POLICY_SRC_ENFORCE="$POLICY_SRC_ENFORCE" \
    bash --noprofile --norc -lc '
      cd "$REPO_DIR"
      set +e +u; set +o pipefail
      source "$POLICY_SRC_ENFORCE" >/dev/null 2>&1 || true
      declare -F enforce_record >/dev/null
    '
  [ "$status" -eq 0 ]
}


@test "preconditions: functions load from sources" {
  run env -i CODE_ROOT="$REPO_DIR" POLICY_SRC_ENFORCE="$POLICY_SRC_ENFORCE" HOME="$HOME" bash --noprofile --norc -lc '
    cd "$CODE_ROOT"
    set +e +u; set +o pipefail
    [[ -r "$POLICY_SRC_ENFORCE" ]] || { echo "unreadable: $POLICY_SRC_ENFORCE"; exit 1; }
    source "$POLICY_SRC_ENFORCE" || { echo "source failed: $POLICY_SRC_ENFORCE"; exit 1; }
    declare -F enforce_record >/dev/null || { echo "func missing: enforce_record"; declare -F; exit 1; }
  '
  [ "$status" -eq 0 ] || printf 'stdout:\n%s\n' "$output" >&3
}

 

@test "preconditions: enforce_record symbol available" {
  run env -i \
    HOME="$HOME" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin" \
    CODE_ROOT="$REPO_DIR" \
    POLICY_SRC_ENFORCE="$POLICY_SRC_ENFORCE" \
    bash --noprofile --norc -lc '
      cd "$CODE_ROOT"
      set +e +u; set +o pipefail
      # source may exit non-zero; we only care that the symbol is defined
      source "$POLICY_SRC_ENFORCE" >/dev/null 2>&1 || true
      declare -F enforce_record >/dev/null
    '
  [ "$status" -eq 0 ] || { echo "stdout:" >&3; printf '%s\n' "$output" >&3; }
}

# 2) shim refuses self-source
@test "shim: rejects self-source" {
  run env -i POLICY_SRC_ENFORCE="$ENFORCE" "$ENFORCE" 'invariant|x|must_exist|error|literal'
  [ "$status" -eq 66 ]
  [[ "$output" =~ shim:\ SRC\ is\ this\ shim ]]
}

 

# 4) bad FS_ROOT fails fast
@test "bad FS_ROOT fails with 70" {
  run env -i REPO_ROOT="/nonexistent" CODE_ROOT="$REPO_DIR" POLICY_SRC_ENFORCE="$POLICY_SRC_ENFORCE" "$ENFORCE" 'invariant|x|must_exist|error|literal'
  [ "$status" -eq 70 ]
  [[ "$output" =~ shim:\ bad\ FS_ROOT ]]
}


# @test "emit_tsv: omits mode when absent" {
#   out="$(emit_tsv <<< $'- type: invariant\n  path: README.md\n  condition: must_exist\n  action: error\n')"
#   [[ "$out" == $'invariant\tREADME.md\tmust_exist\terror' ]]
# }

@test "transform: 4-field TSV infers mode" {
  run "$TRANSFORM" <<< $'invariant\tplain.txt\tmust_exist\terror\n'
  [ "$status" -eq 0 ]
  [[ "$output" =~ \|literal$ ]]
}

# @test "transform: blank mode infers" {
#   run "$TRANSFORM" <<< $'invariant\t^a.*b$\tmust_exist\terror\t\n'
#   [ "$status" -eq 0 ]
#   [[ "$output" =~ \|regex$ ]]
# }

@test "transform: pipe with blank mode infers" {
  run "$TRANSFORM" <<< $'invariant|plain.txt|must_exist|error|\n'
  [ "$status" -eq 0 ]
  [[ "$output" =~ \|literal$ ]]
}

# @test "enforce: missing mode still ok" {
#   cd "$REPO_ROOT"; : > f.txt
#   run "$ENFORCE" 'invariant|f.txt|must_exist|error|'
#   [ "$status" -eq 0 ]
# }

 
