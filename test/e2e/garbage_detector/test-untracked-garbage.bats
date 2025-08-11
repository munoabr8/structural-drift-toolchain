#!/usr/bin/env bats
#./garbage_detector/test-untracked-garbage.bats

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

  local original_script_path="$TOOLS_DIR/detect_garbage.sh"

  readonly sandbox_script="$BATS_TMPDIR/detect_garbage.sh"
  
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



 
 

@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}
 
 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$TOOLS_DIR" ]] || skip "env_init not sourced"
}




 
 
# @test "Undeclared file is flagged as garbage" {
#   run "$sandbox_script" ./structure.spec

 
#   # Choose the contract you want:
#   # If garbage should cause a non-zero exit:
# [ "$status" -ne 0 ]
#   # If script reports but exits zero:
#   [ "$status" -eq 0 ]

#   # Check presence of the rogue notice
#   [[ $output == *"Untracked: ./rogue.sh"* ]]

#   # And absence of false positives
#   [[ $output != *"Untracked: ./only_this.sh"* ]]
# }


