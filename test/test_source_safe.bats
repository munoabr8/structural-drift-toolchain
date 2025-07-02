#!/usr/bin/env bats


setup() {


  source "../system/source_safe.sh"
  source_safe "../system/logger.sh" bats
  source_safe "../system/logger_wrapper.sh" bats
}


 
@test "source_safe fails cleanly on missing file" {
  run source_safe "not_here.sh" bats
  [ "$status" -eq 101 ]
  [[ "$output" == *"File not found"* ]]
}
