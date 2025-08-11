#!/usr/bin/env bats

# --- per-test setup (runs in same process as each test) ---
#!/usr/bin/env bats

# system-test/structure_validator_queries.sh
 
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
 

@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}
 
 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$BIN_DIR" ]] || skip "env_init not sourced"
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
 # [[ "$output" =~ "File OK: ./scripts/entry.sh" ]]
  #[[ "$output" =~ "Structure validation passed" ]]
}
