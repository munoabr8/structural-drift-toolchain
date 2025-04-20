#!/usr/bin/env bats

setup() {
  mkdir -p tmp/testcase/scripts
  cd tmp/testcase
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}

@test "Valid structure with one file passes validation" {
  touch scripts/entry.sh
  echo "file: ./scripts/entry.sh" > structure.spec

  run bash ../../system/validate_structure.sh ./structure.spec

  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ File OK: ./scripts/entry.sh" ]]
  [[ "$output" =~ "🎉 Structure validation passed" ]]
}
