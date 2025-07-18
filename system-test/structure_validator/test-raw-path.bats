#!/usr/bin/env bats

# ./system-test/structure_validator/test-raw-path.bats

 
 
  setup() {

 
check_context_integrity
 
 resolve_project_root
setup_environment_paths
 
 load_dependencies
 
 original_script_path="$SYSTEM_DIR/structure_validator.sh"
  sandbox_script="$BATS_TMPDIR/structure_validator.sh"

  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy structure_validator.sh from: $original_script_path"
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
 

  resolve_project_root() {
  local source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  cd "$(dirname "$source_path")/../.." && pwd
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}

 
 

# Setup function does not appear to be actually executing the
# load dependencies function. I am wondering if this has to 
# do with the setup function being a "special" function in bats?

 
 load_dependencies(){

 #check_context_integrity

  

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "❌ Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"

  source_or_fail "$SYSTEM_DIR/structure_validator.sh"
 
 
 }



teardown() {
  cd ../..
  rm -rf tmp/testcase
}


 


@test "Fallback raw path resolves correctly to existing file" {

 
  echo "./logs/logfile.log" > structure.spec

  echo "📂 Current dir: $(pwd)"
  echo "📄 structure.spec content:"
  cat structure.spec

  echo "📁 logs contents:"
  ls -l logs


  run bash "$sandbox_script" structure.spec


  echo "$output"
  [ "$status" -eq 0 ]
[[ "$output" =~ "File OK: ./logs/logfile.log" ]]
[[ "$output" =~ "Structure validation passed" ]]
}


check_context_integrity() {
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

# This test is also failing. I was led to believe that it was passing. 
# This means that there is something else that is causing an issue.
# Assume that this test is failing when it is actually passing.
# This test is outputing a false positive.
  @test "Fails when SYSTEM_DIR is set to a bad path (stimulated failure)" {
 

  export SYSTEM_DIR="/nonexistent/directory"

  run bash "$sandbox_script" .structure/spec

  echo "STATUS: $status"
   echo "STDOUT: $output"
  echo "STDERR: $error"

   [ "$status" -ne 0 ]
  #[[ "$output" == *"Missing required file"* ]]
}

 