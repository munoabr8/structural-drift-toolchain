#!/usr/bin/env bats

setup() {
  mkdir -p tmp/testcase
  cd tmp/testcase
  echo "untracked.tmp" > .structure.ignore
  touch untracked.tmp
  echo "file: ./declared.sh" > structure.spec
  touch declared.sh
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}

@test "File listed in .structure.ignore is NOT flagged as garbage" {
  run bash ../../tools/detect_garbage.sh structure.spec

  echo "$output"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "❌ Untracked: ./untracked.tmp" ]]
}
