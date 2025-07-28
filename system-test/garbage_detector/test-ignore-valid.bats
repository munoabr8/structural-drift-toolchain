#!/usr/bin/env bats

setup() {
  # Work in an isolated per‑test tmpdir
  cd "$BATS_TEST_TMPDIR"

  # Resolve repo paths from this test file’s location (adjust ../.. if needed)
  local self="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  PROJECT_ROOT="$(cd "$(dirname "$self")/../.." && pwd)"
  TOOLS_DIR="$PROJECT_ROOT/tools"
  SUT_SOURCE="$TOOLS_DIR/detect_garbage.sh"

  # Export anything your script might expect
  export PROJECT_ROOT TOOLS_DIR

  # Stage a sandbox copy of the SUT
  [[ -f "$SUT_SOURCE" ]] || { echo "❌ SUT not found: $SUT_SOURCE"; return 1; }
  sandbox_script="$BATS_TEST_TMPDIR/detect_garbage.sh"
  cp "$SUT_SOURCE" "$sandbox_script" || { echo "❌ Failed to copy SUT"; return 1; }
  chmod +x "$sandbox_script"

  # Fixture
  printf 'untracked.tmp\n' > .structure.ignore
  touch untracked.tmp
  printf 'file: ./declared.sh\n' > structure.spec
  touch declared.sh
}

teardown() { :; } # Bats auto-cleans $BATS_TEST_TMPDIR

# Helper to run the SUT against the local spec
run_sut() { run bash "$sandbox_script" ./structure.spec; }

@test "File listed in .structure.ignore is NOT flagged as garbage" {
  run_sut
  echo "$output"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "❌ Untracked: ./untracked.tmp" ]]
}
