#!/usr/bin/env bats

setup() {
 # 1. Create isolated temp directory
TMP_DIR=$(mktemp -d)

# 2. Define module name and expected structure
MODULE_NAME="sample_module"
MODULES_DIR="$TMP_DIR/modules"
MODULE_PATH="$MODULES_DIR/$MODULE_NAME"

# 3. Ensure module folder exists
mkdir -p "$MODULE_PATH"

# 4. Export MODULES_DIR so the script picks it up
export MODULES_DIR

# 5. Source the target script relative to the test location
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
source "$SCRIPT_DIR/toggle.sh"
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "precondition fails if module is missing" {
  rm -rf "$MODULE_PATH"

  run toggle_module --enable '$MODULE_NAME'


  [ "$status" -eq 2 ]
}

@test "postcondition: toggle.state is set to 'on'" {
  touch "$MODULE_PATH/toggle.state"
  echo "off" > "$MODULE_PATH/toggle.state"

  run toggle_module --enable '$MODULE_NAME'
 

  [ "$status" -eq 0 ]
  run cat "$MODULE_PATH/toggle.state"
  [ "$output" = "on" ]
}

