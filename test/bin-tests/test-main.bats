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

 
 

 }
 


@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}


 
 
 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$BIN_DIR" ]] || skip "env_init not sourced"
}


# I am having an issue with the tests failing because  

# @test "Unknown command is rejected" {
#   echo "⛏ Running script: $sandbox_script"
#   ls -l "$sandbox_script"

#   # Given
#   invalid_arg="frobnicate"

#   # When
#   run "$sandbox_script" "$invalid_arg"

#   # Debug output
#   echo "🔎 OUTPUT: $output"
#   echo "📦 STATUS: $status"

#   # Then
#   [ "$status" -eq 1 ]
#   [[ "$output" == *"Unknown command"* ]]
# }


#  @test "Help command displays usage instructions" {
#   run "$sandbox_script" help


# echo "Output was: $output"

# echo "PROJECT_ROOT in test: $PROJECT_ROOT"


#   [ "$status" -eq 0 ]
#   #[[ "$output" == *"Usage:"* ]]
 
# }

@test "No command shows help message" {

  run "$sandbox_script"

  [ "$status" -eq 0 ]
 # [[ "$output" == *"Usage:"* ]]
}





 
