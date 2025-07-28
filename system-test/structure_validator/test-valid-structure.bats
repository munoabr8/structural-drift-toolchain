#!/usr/bin/env bats

# --- per-test setup (runs in same process as each test) ---
setup() {
  # Work in an isolated dir
  cd "$BATS_TEST_TMPDIR"

  # Resolve repo root from this test file's location
  local self="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  PROJECT_ROOT="$(cd "$(dirname "$self")/../.." && pwd)"
  SYSTEM_DIR="$PROJECT_ROOT/system"
  SUT_SOURCE="$SYSTEM_DIR/structure_validator.sh"

  # Export what the SUT expects
  export PROJECT_ROOT SYSTEM_DIR

  # Sanity checks (fail early with useful context)
  if [[ ! -f "$SUT_SOURCE" ]]; then
    echo "❌ SUT not found."
    echo "   PROJECT_ROOT=$PROJECT_ROOT"
    echo "   SYSTEM_DIR=$SYSTEM_DIR"
    echo "   SUT_SOURCE=$SUT_SOURCE"
    echo "   ls SYSTEM_DIR:"
    ls -la "$SYSTEM_DIR" || true
    return 1
  fi

  # Stage a sandbox copy of the SUT
  sandbox_script="$BATS_TEST_TMPDIR/structure_validator.sh"
  cp "$SUT_SOURCE" "$sandbox_script" || { echo "❌ Copy failed"; return 1; }
  chmod +x "$sandbox_script"

  # Optional: verify runtime deps exist; the SUT will source them
  [[ -f "$SYSTEM_DIR/source_OR_fail.sh" ]] || { echo "❌ Missing source_OR_fail.sh"; return 1; }
  [[ -f "$SYSTEM_DIR/logger.sh"         ]] || { echo "❌ Missing logger.sh";       return 1; }
  [[ -f "$SYSTEM_DIR/logger_wrapper.sh" ]] || { echo "❌ Missing logger_wrapper.sh"; return 1; }
}

teardown() { :; }  # Let Bats clean $BATS_TEST_TMPDIR

# Helpers
write_spec() { printf '%s\n' "$@" > structure.spec; }
run_sut()    { run bash "$sandbox_script" ./structure.spec; }

@test "Valid structure with one file passes validation" {
  mkdir -p scripts
  touch scripts/entry.sh
  write_spec "file: ./scripts/entry.sh"

  run_sut

  [ "$status" -eq 0 ]
  [[ "$output" =~ "File OK: ./scripts/entry.sh" ]]
  [[ "$output" =~ "Structure validation passed" ]]
}
