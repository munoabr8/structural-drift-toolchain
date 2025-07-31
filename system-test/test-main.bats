#!/usr/bin/env bats

  
 
setup() {

 check_context_integrity
 
 resolve_project_root
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


  resolve_project_root() {
  local source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  cd "$(dirname "$source_path")/.." && pwd
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}




source_utilities(){

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "❌ Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"
 

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


@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}


#=== TEST DSL ===
# kind: argument_testing_harness
# goal: Ensure main.sh rejects or handles invalid and valid arguments properly
# strategy: Systematically test edge cases and common usage paths
# expectations:
#   - want: Clarity when argument is missing
#   - likely: Reject unknown commands
#   - should: Provide helpful usage output
#===============

 @test "Unknown command is rejected" {
    echo "⛏ Running script: $sandbox_script"
  echo "⛏ Does it exist?"; ls -l "$sandbox_script"

    # Given
     invalid_arg="frobnicate"

    # When
   run "$sandbox_script" "$invalid_arg"
 
#    # Then
    [ "$status" -eq 1 ]
 [[ "$output" == *"Unknown command"* ]]
 }


 @test "Help command displays usage instructions" {
  run "$sandbox_script" help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
 
}

@test "No command shows help message" {
  run "$sandbox_script"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}





 
