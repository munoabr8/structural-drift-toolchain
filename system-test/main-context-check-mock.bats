#!/usr/bin/env bats

#./system-test/main-context-check-mocks.bats
 
setup() {

  [[ "${DEBUG:-}" == "true" ]] && set -x


 #resolve_project_root
setup_environment_paths
 
 source_utilities

 
  local original_script_path="$PROJECT_ROOT/main.sh"

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
source_utilities(){

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


@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}


 
# Mocks a successful context check script
mock_context_check_success() {
  CONTEXT_CHECK="$BATS_TMPDIR/mock_context_check.sh"
  cat > "$CONTEXT_CHECK" <<EOF
#!/usr/bin/env bash
echo "Context OK"
exit 0
EOF
  chmod +x "$CONTEXT_CHECK"
  export CONTEXT_CHECK
}

# Mocks a failing context check script
mock_context_check_failure() {
  CONTEXT_CHECK="$BATS_TMPDIR/mock_context_check.sh"
  cat > "$CONTEXT_CHECK" <<EOF
#!/usr/bin/env bash
echo "Context FAILED"
exit 1
EOF
  chmod +x "$CONTEXT_CHECK"
  export CONTEXT_CHECK
}


 
@test "check command runs context-status script successfully" {

 
 mock_context_check_success


  run "$sandbox_script" check

  [ "$status" -eq 0 ]
  [[ "$output" == *"Context OK"* ]]  # or whatever context-status prints
}



@test "check command fails when context-status script fails" {

 
 mock_context_check_failure


  run "$sandbox_script" check

  [ "$status" -eq 1 ]
  [[ "$output" == *"Context FAILED"* ]]  # or whatever context-status prints
}


@test "run_preflight skipped for 'help' command" {
  mock_context_check_failure  # Should not be invoked
   COMMAND="help"

  run "$sandbox_script" "$COMMAND"

  [ "$status" -eq 0 ]
  #[[ "$output" == *"Usage"* ]]
}




 