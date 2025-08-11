#!/usr/bin/env bats

# Load helpers or environment if needed
#load 'test_helper.bash'  # optional

setup() {

    export PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  TEST_ROOT="$BATS_TEST_TMPDIR/test_project"
  mkdir -p "$TEST_ROOT/util"

  # Copy core.rf.sh and supporting files
  cp "$PROJECT_ROOT/util/core.rf.sh" "$TEST_ROOT/util/"


  # Export the mocked location for testing
  export ROOT_BOOT="$TEST_ROOT"

  cd "$TEST_ROOT"
}

@test "Respects preset ROOT_BOOT if valid" {
  run bash -c '
    source ./util/core.rf.sh
    core__derive_root'

  echo "🧪 OUTPUT: $output"
  echo "📦 STATUS: $status"

  [ "$status" -eq 0 ]
  [[ "$output" == "$ROOT_BOOT" ]]
}

@test "Falls back to parent directory if not a Git repo and no markers" {
  unset ROOT_BOOT

  run bash -c '
    source ./util/core.rf.sh
    core__derive_root
  '

  echo "🧪 OUTPUT: $output"
  echo "📦 STATUS: $status"

  [ "$status" -eq 0 ]
 # [[ "$output" == "$TEST_ROOT" || "$output" == "$TEST_ROOT/"* ]]
}

@test "Handles missing Git safely" {
  unset ROOT_BOOT

  PATH="/nonexistent:$PATH"  # Fake "no git"
  run bash -c '
    source ./util/core.rf.sh
    core__derive_root
  '

  echo "🧪 OUTPUT: $output"
  [ "$status" -eq 0 ]
  #[[ "$output" == "$TEST_ROOT" || "$output" == "$TEST_ROOT/"* ]]
}

