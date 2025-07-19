#!/usr/bin/env bats

setup() {
  mkdir -p tmp/testcase
  cd tmp/testcase
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}

@test "Broken symlink fails validation" {
  ln -s nonexistent_target.sh bad_link.sh
  echo "link: ./bad_link.sh -> ./nonexistent_target.sh" > structure.spec

  run bash ../../system/structure_validator.sh ./structure.spec


  [ "$status" -ne 0 ]
  #[[ "$output" =~ "Symlink ./bad_link.sh points to" ]]
}
