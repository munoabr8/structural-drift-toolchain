#!/usr/bin/env bats


SCRIPT_PATH="../../debugtools/structureDebugging.sh"

# What invariant violation is generating the output:
#  ✗ Debug Info
#    (in test file system-test/structure_generator/test-generate-spec.bats, line 26)
#      `[ "$status" -eq 0 ]' failed with status 2
   
#    /Users/abrahammunoz/git/bin_pro/prototypeProject/system-test/structure_generator/test-generate-spec.bats: line 26: [: : integer expression expected
#    Removing tmp folder...

# 1 test, 1 failure



setup() {

 


 source ../prototypeProject/system/source_or_fail.sh
 source_or_fail ../prototypeProject/system/logger.sh
  source_or_fail ../prototypeProject/system/logger_wrapper.sh

type log_json | grep -q 'function' || {
  echo "❌ log function not defined. Exiting." >&2
  exit 99
}

 
  #source "../../system/source_OR_fail.sh"  # or whatever file defines `log`

  mkdir -p tmp/test_module/subdir
  touch tmp/test_module/file1.sh
  touch tmp/test_module/subdir/file2.txt
  cd tmp
}

teardown() {
  cd ..
  echo "Removing tmp folder..."
  rm -rf tmp
}


@test "Debug Info" {
  pwd
  ls -la
   run bash "$SCRIPT_PATH" generate_structure_spec test_module
  echo "$output" >&2
  [ "$status" -eq 0 ]
}

 

# @test "generate_structure_spec generates correct entries" {
#   run bash "$SCRIPT_PATH" generate_structure_spec test_module

#   [ "$status" -eq 0 ]
#   [[ "$output" =~ "dir: test_module" ]]
#   [[ "$output" =~ "dir: test_module/subdir" ]]
#   [[ "$output" =~ "file: test_module/file1.sh" ]]
#   [[ "$output" =~ "file: test_module/subdir/file2.txt" ]]
# }

 
