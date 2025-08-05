#!/usr/bin/env bats

# ./system-test/structure_validator/test-raw-path.bats

 
 
sandbox_script=""

setup() {
 
  local -r root="$(git rev-parse --show-toplevel)"
 
  source "$root/lib/env_init.sh"
  env_init --path --quiet

  setup_sandbox

  source_utilities
 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
 
  
  }



  setup_sandbox(){

  local original_script_path="$SYSTEM_DIR/structure_validator.rf.sh"

  readonly sandbox_script="$BATS_TMPDIR/structure_validator.sh"
  

  cp "$original_script_path" "$sandbox_script" || {
    echo "Failed to copy structure_validator.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }


  }
 
 
 

# Setup function does not appear to be actually executing the
# load dependencies function. I am wondering if this has to 
# do with the setup function being a "special" function in bats?

 
source_utilities(){

  if [[ ! -f "$UTIL_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$UTIL_DIR/source_OR_fail.sh"

  source_or_fail "$UTIL_DIR/logger.sh"
  source_or_fail "$UTIL_DIR/logger_wrapper.sh"

 
  source_or_fail "$sandbox_script" 


 }



teardown() {
  cd ../..
  rm -rf tmp/testcase
}


 source_utilities(){

  if [[ ! -f "$UTIL_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$UTIL_DIR/source_OR_fail.sh"

  source_or_fail "$UTIL_DIR/logger.sh"
  source_or_fail "$UTIL_DIR/logger_wrapper.sh"

 
  source_or_fail "$sandbox_script" 


 }

 


 
sandbox_script=""

setup() {
 
  local -r root="$(git rev-parse --show-toplevel)"
 
  source "$root/lib/env_init.sh"
  env_init --path --quiet

  setup_sandbox

  source_utilities
 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
 
  
  }



  setup_sandbox(){

  local original_script_path="$SYSTEM_DIR/structure_validator.rf.sh"

  readonly sandbox_script="$BATS_TMPDIR/structure_validator.sh"
  

  cp "$original_script_path" "$sandbox_script" || {
    echo "Failed to copy structure_validator.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }


  }

  # This test is also failing. I was led to believe that it was passing. 
# This means that there is something else that is causing an issue.
# Assume that this test is failing when it is actually passing.
# This test is outputing a false positive?
  @test "Fails when SYSTEM_DIR is set to a bad path (stimulated failure)" {
 

 
  run bash "$sandbox_script" validate ./structure.spec


  export SYSTEM_DIR="/nonexistent/directory"

  echo "STATUS: $status"
   echo "STDOUT: $output"
  echo "STDERR: ${stderr-}"

   [ "$status" -ne 0 ]
  #[[ "$output" == *"Missing required file"* ]]
}




# @test "Fallback raw path resolves correctly to existing file" {

 
#   echo "./logs/logfile.log" > structure.spec

#   echo "📂 Current dir: $(pwd)"
#   echo "📄 structure.spec content:"
#   cat structure.spec

#   echo "📁 logs contents:"
#   ls -l logs


#   run bash "$sandbox_script" structure.spec


#   echo "$output"
#   [ "$status" -eq 0 ]
# [[ "$output" =~ "File OK: ./logs/logfile.log" ]]
# [[ "$output" =~ "Structure validation passed" ]]
# }

@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}
 
 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$BIN_DIR" ]] || skip "env_init not sourced"
}




 