#!/usr/bin/env bats
  
sandbox_script=""

setup() {
 

  PROJECT_ROOT="$(git rev-parse --show-toplevel)"

  
  source "$PROJECT_ROOT/lib/env_init.sh"
  env_init --path --quiet
  env_assert
  
  setup_sandbox

  source_utilities
 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
 
  
  }

    setup_sandbox(){


  local original_script_path="$BIN_DIR/main.sh"


sandbox_dir="$BATS_TEST_TMPDIR/sandbox"
  mkdir -p "$sandbox_dir"


  readonly sandbox_script="$sandbox_dir/main.sh"


 cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy main.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }


}

source_utilities(){

  if [[ ! -f "$UTIL_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$UTIL_DIR/source_OR_fail.sh"

  source_or_fail "$UTIL_DIR/logger.sh"
  source_or_fail "$UTIL_DIR/logger_wrapper.sh"

   source_or_fail "$PROJECT_ROOT/bin/main.sh"  # or wherever run_preflight is defined
 

 }
 


@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}


 
 
 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$BIN_DIR" ]] || skip "env_init not sourced"
}


@test "Given that we have setup a sandbox script to test, when we assert that the variable is non-zero(not set) then we know it is set " {
  echo "SCRIPT: $sandbox_script"
  # -n is non-zero length
  # -Z zero length, true when the string is empty.
  [ -n "$sandbox_script" ]   
}


# ───────────────────────────── make_mock CONTRACT ─────────────────────────────
# EXPECTATIONS ─ what the caller can safely rely on
#   • An executable stub is written to "$BATS_TMPDIR/$1".  Each time the stub is
#     run it appends “<stub‑basename> <args…>” to "$BATS_TMPDIR/calls" and exits
#     with status $2.
#   • "$BATS_TMPDIR" is prepended to PATH, so an unqualified command lookup
#     (e.g.  `validator`) resolves to the stub even if a real binary exists.
#   • An environment variable whose name equals $1 (e.g.  VALIDATOR) is exported
#     and set to the stub’s full path.  Scripts that invoke "$VALIDATOR" pick up
#     the mock automatically.
#
# INVARIANTS ─ conditions that must always hold during / after execution
#   • $BATS_TMPDIR already exists and is writable.
#   • The stub script is created with a POSIX‑compliant shebang and +x permission.
#   • Every stub invocation appends exactly one new line to "$BATS_TMPDIR/calls";
#     the file is never truncated inside make_mock.
#   • PATH keeps all its previous segments; only a single left‑most insertion of
#     "$BATS_TMPDIR" is performed.
#
# CONSTRAINTS ─ external limits / responsibilities of the caller
#   • make_mock must run inside a Bats test where $BATS_TMPDIR is unique per test;
#     otherwise call logs from parallel tests will collide.
#   • Caller must pass *two* arguments:
#       1. $1  – a shell‑compatible identifier (no spaces, quotes, or ‘=’).
#       2. $2  – an integer exit status between 0 and 255.
#   • Re‑using the same $1 within one test silently overwrites the previous stub.
#   • Frequent calls can bloat "$BATS_TMPDIR/calls"; clean it in setup/teardown
#     if size matters.
#   • Because PATH is modified process‑wide, later code that genuinely needs the
#     real binary of the same name must invoke it via an absolute path.
# ──────────────────────────────────────────────────────────────────────────────

 
make_mock2 () {            # $1 = env‑var name, $2 = exit‑status
  local path="$BATS_TMPDIR/$1"

  cat >"$path" <<EOF
#!/usr/bin/env bash
echo "\$0 \$*" >> "$BATS_TMPDIR/calls"
exit $2
EOF
  chmod +x "$path"

  # prepend temp dir so our mock shadows any real binary
  PATH="$BATS_TMPDIR:$PATH"       # ← no back‑slash
  export "$1=$path"               # quote the assignment
}

make_mock() {
  local name="$1"
  local exit_status="$2"
  local mock_path="$BATS_TMPDIR/$name"

  mkdir -p "$(dirname "$mock_path")"

  echo "#!/usr/bin/env bash" >  "$mock_path"
  echo "echo '💥 MOCK FIRED: $name' >&2" >> "$mock_path"
  echo "echo '$name called' >> \"$BATS_TMPDIR/calls\"" >> "$mock_path"
  echo "exit $exit_status" >> "$mock_path"

  chmod +x "$mock_path"
}


 

 

@test "help does not call preflight" {
  EXTRA_LIB="$BATS_TMPDIR/shim-contract-bomb.sh"
  cat >"$EXTRA_LIB" <<'SH'
require_contract_for(){ echo "SHOULD-NOT-CALL" >&2; exit 99; }
SH
  chmod +x "$EXTRA_LIB"; export EXTRA_LIB
  run "$sandbox_script" help
  [ "$status" -ne 99 ]            # would be 99 if preflight ran
  [[ "$output" != *"SHOULD-NOT-CALL"* ]]
}


 

@test "start aborts when contract fails" {
  EXTRA_LIB="$BATS_TMPDIR/shim.sh"
  cat >"$EXTRA_LIB" <<'SH'
require_contract_for(){ return 1; }
SH
  chmod +x "$EXTRA_LIB"
  export EXTRA_LIB           # make it visible to the SUT process

  run "$sandbox_script" start
  [ "$status" -eq 65 ]
  [[ "$output" == *"Preflight contract failed"* ]]
}


@test "start calls preflight (contract stub prints marker)" {
  # 1) Shim preflight so we can see it ran
  EXTRA_LIB="$BATS_TMPDIR/shim-contract-mark.sh"
  cat >"$EXTRA_LIB" <<'SH'
require_contract_for(){ echo "[contract-called:$1]" >&2; return 0; }
SH
  chmod +x "$EXTRA_LIB"; export EXTRA_LIB

  # 2) Fake a project with the default validator path
  PROJ="$BATS_TMPDIR/proj"; mkdir -p "$PROJ/system"
  # spec the script expects
  : > "$PROJ/structure.spec"
  # validator at the default location your script uses
  cat >"$PROJ/system/structure_validator.rf.sh" <<'SH'
#!/usr/bin/env bash
# accept any args; succeed
exit 0
SH
  chmod +x "$PROJ/system/structure_validator.rf.sh"
  export PROJECT_ROOT="$PROJ"

  run "$sandbox_script" start
  if [ "$status" -ne 0 ]; then echo "---- OUTPUT ----"; echo "$output"; fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"[contract-called:start]"* ]]
}

 