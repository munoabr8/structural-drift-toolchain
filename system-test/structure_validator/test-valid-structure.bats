#!/usr/bin/env bats

setup() {

  resolve_project_root
  setup_environment_paths

  load_dependencies

 
 original_script_path="$SYSTEM_DIR/structure_validator.sh"
  sandbox_script="$BATS_TMPDIR/structure_validator.sh"

  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy structure_validator.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }
  
  mkdir -p tmp/testcase/scripts
  cd tmp/testcase
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}



  resolve_project_root() {
  local source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
  cd "$(dirname "$source_path")/../.." && pwd
}

setup_environment_paths() {
  export PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
  export SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}


 load_dependencies(){

 

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "❌ Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"

  source_or_fail "$SYSTEM_DIR/structure_validator.sh"
 
 
 }



@test "Valid structure with one file passes validation" {
  touch scripts/entry.sh
  echo "file: ./scripts/entry.sh" > structure.spec

  run bash ../../system/structure_validator.sh ./structure.spec

  [ "$status" -eq 0 ]
  [[ "$output" =~ "File OK: ./scripts/entry.sh" ]]
  [[ "$output" =~ "Structure validation passed" ]]
}
