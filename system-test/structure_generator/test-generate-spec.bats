#!/usr/bin/env bats


SCRIPT_PATH="../../debugtools/structureDebugging.sh"


setup() {
  mkdir -p tmp/test_module/subdir
  touch tmp/test_module/file1.sh
  touch tmp/test_module/subdir/file2.txt
   cd tmp
}

teardown() {
  cd ..
  rm -rf tmp
}


@test "Debug Info" {
  pwd
  ls -la
  run bash "$SCRIPT_PATH" generate_structure_spec test_module
  echo "$output" >&2
  [ "$status" -eq 0 ]
}

 

@test "generate_structure_spec generates correct entries" {
  run bash "$SCRIPT_PATH" generate_structure_spec test_module

  [ "$status" -eq 0 ]
  [[ "$output" =~ "dir: test_module" ]]
  [[ "$output" =~ "dir: test_module/subdir" ]]
  [[ "$output" =~ "file: test_module/file1.sh" ]]
  [[ "$output" =~ "file: test_module/subdir/file2.txt" ]]
}

 
