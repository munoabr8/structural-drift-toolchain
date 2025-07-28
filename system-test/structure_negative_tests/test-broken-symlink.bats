 
#!/usr/bin/env bats

setup() {
  # Work in an isolated per‑test tmpdir
  cd "$BATS_TEST_TMPDIR"

  # Resolve repo paths from this test file location (adjust ../.. if your layout differs)
  local self="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  PROJECT_ROOT="$(cd "$(dirname "$self")/../.." && pwd)"
  SYSTEM_DIR="$PROJECT_ROOT/system"
  SUT_SOURCE="$SYSTEM_DIR/structure_validator.sh"

  # Export what the SUT may expect
  export PROJECT_ROOT SYSTEM_DIR

  # Stage a sandbox copy of the SUT
  [[ -f "$SUT_SOURCE" ]] || { echo "❌ SUT not found: $SUT_SOURCE"; return 1; }
  sandbox_script="$BATS_TEST_TMPDIR/structure_validator.sh"
  cp "$SUT_SOURCE" "$sandbox_script" || { echo "❌ Failed to copy SUT"; return 1; }
  chmod +x "$sandbox_script"
}

teardown() { :; }  # Bats auto-cleans $BATS_TEST_TMPDIR

# Helpers
write_spec() { printf '%s\n' "$@" > structure.spec; }
run_sut()    { run bash "$sandbox_script" ./structure.spec; }

@test "Broken symlink fails validation" {
  # Create a broken symlink (target doesn't exist)
  ln -s nonexistent_target.sh bad_link.sh

  # Spec describing the symlink and intended target
  write_spec "link: ./bad_link.sh -> ./nonexistent_target.sh"

  run_sut
  echo "$output"

  # Expect failure status
  [ "$status" -ne 0 ]

  # Optional: assert on message (adjust to your validator's wording)
  # [[ "$output" =~ "broken symlink" ]] || [[ "$output" =~ "points to.*nonexistent" ]]
}
