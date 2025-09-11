#!/usr/bin/env bats

sandbox_script=""

setup() {
 
  local -r root="$(git rev-parse --show-toplevel)"
 
  source "$root/lib/env_init.sh"
  env_init --path --quiet

  setup_sandbox

  source_utilities
 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
 
  
  }
  setup_sandbox(){

  local original_script_path="$SYSTEM_DIR/structure_validator.rf.sh"

  readonly sandbox_script="$BATS_TMPDIR/structure_validator.sh"
  

  cp "$original_script_path" "$sandbox_script" || {
    echo "Failed to copy structure_validator.sh from: $original_script_path"
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

 
  source_or_fail "$sandbox_script" 


 }
teardown() { :; }  # Bats auto-cleans $BATS_TEST_TMPDIR

# Helpers
write_spec() { printf '%s\n' "$@" > structure.spec; }
run_sut()    { run bash "$sandbox_script" validate ./structure.spec; }

@test "Fails validation with missing file" {
  write_spec "file: ./missing.sh"

  run_sut
  echo "$output"

  [ "$status" -ne 0 ]
  #[[ "$output" =~ "Missing file: ./missing.sh" ]]
}
