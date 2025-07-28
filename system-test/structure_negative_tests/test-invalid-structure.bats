#!/usr/bin/env bats

setup() {
  # Work in an isolated per‑test tmpdir
  cd "$BATS_TEST_TMPDIR"

  # Resolve repo paths from this test file (adjust ../.. if your layout differs)
  local self="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  PROJECT_ROOT="$(cd "$(dirname "$self")/../.." && pwd)"
  SYSTEM_DIR="$PROJECT_ROOT/system"
  SUT_SOURCE="$SYSTEM_DIR/structure_validator.sh"

  # Export what the SUT may expect
  export PROJECT_ROOT SYSTEM_DIR

  # Stage a sandbox copy of the SUT
  [[ -f "$SUT_SOURCE" ]] || {
    echo "❌ SUT not found: $SUT_SOURCE"
    echo "PROJECT_ROOT=$PROJECT_ROOT"
    echo "SYSTEM_DIR=$SYSTEM_DIR"
    return 1
  }
  sandbox_script="$BATS_TEST_TMPDIR/structure_validator.sh"
  cp "$SUT_SOURCE" "$sandbox_script" || { echo "❌ Failed to copy SUT"; return 1; }
  chmod +x "$sandbox_script"
}

teardown() { :; }  # Bats auto-cleans $BATS_TEST_TMPDIR

# Helpers
write_spec() { printf '%s\n' "$@" > structure.spec; }
run_sut()    { run bash "$sandbox_script" ./structure.spec; }

@test "Fails validation with missing file" {
  write_spec "file: ./missing.sh"

  run_sut
  echo "$output"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Missing file: ./missing.sh" ]]
}
