#!/usr/bin/env bats
  
 
setup() {

  [[ "${DEBUG:-}" == "true" ]] && set -x


 resolve_project_root
setup_environment_paths
 
 load_dependencies

 
  local original_script_path="$PROJECT_ROOT/main.rf.sh"

    sandbox_script="$BATS_TMPDIR/main.sh"
 


  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy main.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }


 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
  
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


 }
 
  check_context_integrity() {

  if [[ "${DEBUG:-}" != "true" ]]; then return; fi
  echo "🧭 Context Integrity Check"
  echo "📂 Current Working Directory: $(pwd)"
  echo "📄 Script: $0"
  echo "📁 Directory Contents:"
  ls -1a
  echo "📦 PROJEC_DIR: ${PROJECT_ROOT:-<not set>}"
  echo "📦 SYSTEM_DIR: ${SYSTEM_DIR:-<not set>}"
  echo "🐚 Shell: ${SHELL:-<not set>}"
  echo
}


@test "Given that we have setup a sandbox script to test, when we assert that the variable is non-zero(not set) then we know it is set " {
  echo "SCRIPT: $sandbox_script"
  # -n is non-zero length
  # -Z zero length, true when the string is empty.
  [ -n "$sandbox_script" ]   
}


 
# Mocks a successful context check script
mock_toggle_flags_success() {
  RUNTIME_TOGGLE_FLAGS="$BATS_TMPDIR/mock_runtime_flags.sh"
  cat > "$RUNTIME_TOGGLE_FLAGS" <<EOF
#!/usr/bin/env bash
echo "TOGGLE FLAGS OK"
exit 0
EOF
  chmod +x "$RUNTIME_TOGGLE_FLAGS"
  export RUNTIME_TOGGLE_FLAGS
}

# Mocks a failing context check script
mock_toggle_flags_failure() {
  RUNTIME_TOGGLE_FLAGS="$BATS_TMPDIR/mock_runtime_flags.sh"
  cat > "$RUNTIME_TOGGLE_FLAGS" <<EOF
#!/usr/bin/env bash
echo "TOGGLE FLAGS FAILED"
exit 1
EOF
  chmod +x "$RUNTIME_TOGGLE_FLAGS"
  export RUNTIME_TOGGLE_FLAGS
}

 
@test "Given toggle command is entered, when the toggle script is successful, then the main script should succeed." {

 
mock_toggle_flags_success

  run "$sandbox_script" toggle

  [ "$status" -eq 0 ]
  [[ "$output" == *"TOGGLE FLAGS OK"* ]]  # or whatever context-status prints
}



@test "Given toggle command is entered, when the toggle flags script fails, then the main script should fail." {

 
 mock_toggle_flags_failure


  run "$sandbox_script" toggle

  [ "$status" -eq 1 ]
  [[ "$output" == *"TOGGLE FLAGS FAILED"* ]]  # or whatever context-status prints
}


@test "Given help command is entered, when the toggle flag script fails, then the useage should still display" {
  mock_toggle_flags_failure  # Should not be invoked
   COMMAND="help"

  run "$sandbox_script" "$COMMAND"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}




 