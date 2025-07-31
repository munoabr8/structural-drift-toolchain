#!/usr/bin/env bats
  
 
setup() {

  [[ "${DEBUG:-}" == "true" ]] && set -x


 #resolve_project_root
setup_environment_paths
 
  

 
  local original_script_path="$PROJECT_ROOT/main.sh"

    sandbox_script="$BATS_TMPDIR/main.sh"
 export sandbox_script




  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy main.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }

load_dependencies

  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
 
  
  }


# Pre-conditions: 
# --> SYSTEM_DIR is set.
# --> source_OR_fail.sh must be a valid file(correct permissions)
# --> source_OR_fail.sh must contain a source_or_fail function.
# --> logger.sh must be a valid file,
# --> logger_wrapper.sh must be a valid file.
load_dependencies(){

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"

   source_or_fail "$sandbox_script" 



 }

  # Project root is the top level directory. 
# The top level directory includes a .git(version control is required)
# Changing directories will be subject to change.
# 
#
  resolve_project_root() {
  local source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  cd "$(dirname "$source_path")/.." && pwd
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
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

 
make_mock () {            # $1 = env‑var name, $2 = exit‑status
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


@test "run_preflight aborts when context check fails" {
  make_mock VALIDATOR     0   # validator passes
  make_mock CONTEXT_CHECK 1   # context check fails

 
export COMMAND="start"

  run run_preflight
  [ "$status" -eq 1 ]

  # optional interaction assertions
 # grep -q "VALIDATOR ./system/structure.spec" "$BATS_TMPDIR/calls"
 # grep -q "CONTEXT_CHECK"                     "$BATS_TMPDIR/calls"
}


@test "run_preflight aborts when validator fails" {
  make_mock VALIDATOR     1   # validator passes
  make_mock CONTEXT_CHECK 0   # context check fails

 export COMMAND="start"


  run run_preflight
  [ "$status" -eq 1 ]

  # optional interaction assertions
  #grep -q "VALIDATOR ./system/structure.spec" "$BATS_TMPDIR/calls"
 # grep -q "CONTEXT_CHECK"                     "$BATS_TMPDIR/calls"
}

@test "run_preflight aborts when both fails" {
  make_mock VALIDATOR     1   # validator passes
  make_mock CONTEXT_CHECK 1   # context check fails

 
 
  run run_preflight
  [ "$status" -eq 1 ]

  # optional interaction assertions
  #grep -q "VALIDATOR ./system/structure.spec" "$BATS_TMPDIR/calls"
  #grep -q "CONTEXT_CHECK"                     "$BATS_TMPDIR/calls"
}


@test "run_preflight succeeds when both succeed" {
  make_mock VALIDATOR     0   # validator passes
  make_mock CONTEXT_CHECK 0   # context check fails

 
#export COMMAND="start"
  run run_preflight  
  [ "$status" -eq 0 ]

  # optional interaction assertions
  #grep -q "VALIDATOR ./system/structure.spec" "$BATS_TMPDIR/calls"
  #grep -q "CONTEXT_CHECK"                     "$BATS_TMPDIR/calls"
}


@test "run_preflight" {
  make_mock VALIDATOR     0    
  make_mock CONTEXT_CHECK 0    

 
 #local COMMAND="help"
  run run_preflight   
  [ "$status" -eq 0 ] 

  # optional interaction assertions
  #grep -q "VALIDATOR ./system/structure.spec" "$BATS_TMPDIR/calls"
  #grep -q "CONTEXT_CHECK"                     "$BATS_TMPDIR/calls"
}