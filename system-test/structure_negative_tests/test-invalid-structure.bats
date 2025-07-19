#!/usr/bin/env bats

setup() {
  mkdir -p tmp/testcase
  cd tmp/testcase
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}

@test "Fails validation with missing file" {
  echo "file: ./missing.sh" > structure.spec

  run bash ../../system/structure_validator.sh ./structure.spec


  [ "$status" -ne 0 ]
  [[ "$output" =~ "Missing file: ./missing.sh" ]]
}
