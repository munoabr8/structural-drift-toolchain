#!/usr/bin/env bats
  
 
setup() {

  [[ "${DEBUG:-}" == "true" ]] && set -x


 resolve_project_root
setup_environment_paths
 
 source_utilities

 
  local original_script_path="$PROJECT_ROOT/system/structure_validator.rf.sh"

    sandbox_script="$BATS_TMPDIR/system/structure_validator.rf.sh"
 


  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy main.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }


 
  mkdir -p tmp/testcase/logs
  touch tmp/testcase/logs/logfile.log
  cd tmp/testcase
 
 
  
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


# Project root is the top level directory. 
# The top level directory includes a .git(version control is required)
# Changing directories will be subject to change.
 
  resolve_project_root() {
  local source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  cd "$(dirname "$source_path")/.." && pwd
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}





@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}

