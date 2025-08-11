 
#!/usr/bin/env bats
 


sandbox_script=""

setup() {
 

  PROJECT_ROOT="$(git rev-parse --show-toplevel)"

  
  source "$PROJECT_ROOT/lib/env_init.sh"
  env_init --path --quiet
  env_assert
  
  setup_sandbox

  source_utilities
 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
 
  
  }


setup_sandbox(){


  local original_script_path="$SYSTEM_DIR/structure_validator.rf.sh"


sandbox_dir="$BATS_TEST_TMPDIR/sandbox"
  mkdir -p "$sandbox_dir"


  readonly sandbox_script="$sandbox_dir/structure_validator.sh"


 cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy main.sh from: $original_script_path"
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

 
 

 }


 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$BIN_DIR" ]] || skip "env_init not sourced"
}



 
# Helpers
write_spec() { printf '%s\n' "$@" > structure.spec; }
run_sut()    { run bash "$sandbox_script" ./structure.spec; }

# @test "Broken symlink fails validation" {
#   # Create a broken symlink (target doesn't exist)
#   ln -s nonexistent_target.sh bad_link.sh

#   # Spec describing the symlink and intended target
#   write_spec "link: ./bad_link.sh -> ./nonexistent_target.sh"

#   run_sut
#   echo "$output"

#   # Expect failure status
#   [ "$status" -ne 0 ]

#   # Optional: assert on message (adjust to your validator's wording)
#   # [[ "$output" =~ "broken symlink" ]] || [[ "$output" =~ "points to.*nonexistent" ]]
# }
