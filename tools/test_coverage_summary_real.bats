#!/usr/bin/env bats

setup() {
  OUTPUT_FILE="$BATS_TEST_TMPDIR/test_output.md"
 

 

 setup_environment_paths
 
  

 
 
  local original_script_path="$PROJECT_ROOT/tools/gen_readme.rf.rf.sh"

    sandbox_script="$BATS_TMPDIR/tools/gen_readme.sh"
  export sandbox_script



  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy gen_readme.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  


  }

source_utilities
 
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
source_utilities(){

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"

 
   source_or_fail "$sandbox_script" 


 }

 
 

resolve_project_root() {
  local from="${1:-${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}}"
  ( cd "$(dirname "$from")/../" && pwd -P ) || return 1
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}

@test "sandbox_script is available & evaluate_condition is defined" {
  [ -n "$sandbox_script" ]
  type -t generate_test_summary >/dev/null
}

 


@test "generate_test_summary outputs actual test count" {
  generate_test_summary "$OUTPUT_FILE" "$PROJECT_ROOT" || {
    echo "❌ Function exited non-zero"
    echo "----- OUTPUT_FILE CONTENT -----"
    cat "$OUTPUT_FILE"
    echo "----- END -----"
    exit 1
  }

  [ -f "$OUTPUT_FILE" ]

  run grep "## Test Coverage Summary" "$OUTPUT_FILE"
  echo "GREP OUTPUT: $output"
  [ "$status" -eq 0 ]
}


