#!/usr/bin/env bats




setup() {
  OUTPUT_FILE="$BATS_TEST_TMPDIR/test_output.md"
 
  
  source "../system-test/testing-setup.sh"
   

local original_script_path="$PROJECT_ROOT/tools/gen_readme.rf.rf.sh"

      sandbox_script="$BATS_TMPDIR/tools/gen_readme.sh"
 


  cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy gen_readme.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  


  }

  source_bats_utilities "$sandbox_script" 
   
 

  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"

  
    
  }

@test "sandbox_script is available & evaluate_condition is defined" {
  [ -n "$sandbox_script" ]
  type -t generate_test_summary >/dev/null
}

 


@test "generate_test_summary outputs actual test count" {
  generate_test_summary "$OUTPUT_FILE" "$PROJECT_ROOT" || {
    echo "❌ Function exited non-zero"
    echo "----- OUTPUT_FILE CONTENT -----"
    cat "$OUTPUT_FILE"
    echo "----- END -----"
    exit 1
  }

  [ -f "$OUTPUT_FILE" ]

  run grep "## Test Coverage Summary" "$OUTPUT_FILE"
  echo "GREP OUTPUT: $output"
  [ "$status" -eq 0 ]
}


