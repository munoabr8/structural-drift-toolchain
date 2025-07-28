#!/usr/bin/env bats
#./garbage_detector/test-untracked-garbage.bats

setup() {
  # Isolate per test
  cd "$BATS_TEST_TMPDIR"

  # Resolve paths without changing CWD
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
setup_environment_paths
  # If you really need dependencies, load them here or remove this call
  # load_dependencies

  # Stage SUT in sandbox (adjust source path if needed)
  sandbox_script="$BATS_TEST_TMPDIR/detect_garbage.sh"
  cp "$PROJECT_ROOT/tools/detect_garbage.sh" "$sandbox_script" || {
    echo "❌ Failed to copy detect_garbage.sh from: $PROJECT_ROOT/tools"
    exit 1
  }

  source_utilities
  chmod +x "$sandbox_script"

  # Minimal fixture: allow only one file
  printf 'file: ./only_this.sh\n' > structure.spec
  touch only_this.sh rogue.sh
}


 

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
  local src="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  ( cd "$(dirname "$src")/../.." && pwd )
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}


@test "Undeclared file is flagged as garbage" {
  run "$sandbox_script" structure.spec

  echo "$output"

  # Choose the contract you want:
  # If garbage should cause a non-zero exit:
  # [ "$status" -ne 0 ]
  # If script reports but exits zero:
  [ "$status" -eq 0 ]

  # Check presence of the rogue notice
  [[ $output == *"Untracked: ./rogue.sh"* ]]

  # And absence of false positives
  [[ $output != *"Untracked: ./only_this.sh"* ]]
}
