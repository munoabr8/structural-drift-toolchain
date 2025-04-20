#!/usr/bin/env bats

setup() {
  mkdir -p tmp/testcase
  cd tmp/testcase
  echo "file: ./only_this.sh" > structure.spec
  touch only_this.sh
  touch rogue.sh
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}

@test "Undeclared file is flagged as garbage" {
  run bash ../../tools/detect_garbage.sh structure.spec

  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "❌ Untracked: ./rogue.sh" ]]
}
