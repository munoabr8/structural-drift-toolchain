#!/usr/bin/env bats

#./test/lib-tests/main-context-check-mocks.bats
 



  
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


  run "$sandbox_script" context

  echo "$output"
  [ "$status" -eq 0 ]
  #[[ "$output" == *"Context OK"* ]]  # or whatever context-status prints
}



@test "context command fails when context-status script fails" {

 
 mock_context_check_failure


  run "$sandbox_script" context
echo "DEBUG: status=$status"
echo "DEBUG: output=$output"
  [ "$status" -eq 1 ]
  #[[ "$output" == *"Context FAILED"* ]]  # or whatever context-status prints
}


# @test "run_preflight skipped for 'help' command" {
#   mock_context_check_failure  # Should not be invoked
#    COMMAND="help"

#   run "$sandbox_script" help

#   [ "$status" -eq 1 ]
#   #[[ "$output" == *"Usage"* ]]
# }




 
