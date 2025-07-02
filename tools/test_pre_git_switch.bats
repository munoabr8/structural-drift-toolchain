#!/usr/bin/env bats

# What is its purpose/intent: generates a developer snapshot before switching branches.
# What is the likely invariants of the pre-git-switch script?
# Where should a pre-git-switch be located?(Location?)

setup() {
  cd "$BATS_TMPDIR"
  script_under_testing="$BATS_TEST_DIRNAME/tools/pre-git-switch.sh"

  git init --quiet


  mkdir -p tools_probe system_probe

  [[ -d tools_probe ]] || { echo "❌ tools_probe/ directory missing in BATS_TMPDIR"; exit 1; }
  [[ -d system_probe ]] || { echo "❌ system_probe/ directory missing in BATS_TMPDIR"; exit 1; }



source "$BATS_TEST_DIRNAME/../system_probe/source_or_fail.sh"
 cp "$BATS_TEST_DIRNAME/../tools_probe/pre-git-switch.sh" tools_probe/
 
  #cp /tools_probe/pre-git-switch.sh tools_probe/
  cp /system_probe/logger.sh system_probe/

source_or_fail "tools_probe/pre-git-switch.sh"
  

 
  echo "echo foo" > foo.sh
}

 

teardown() {
  rm -rf .git/dev_snapshots
  rm -f foo.sh
}



@test "Creates snapshot for modified file" {
  run bash tools/pre-git-switch.sh
  [ "$status" -eq 0 ]
  snapshot=$(find .git/dev_snapshots -name '*.tar.gz')
  [[ -f "$snapshot" ]]
  [[ "$(tar -tzf "$snapshot")" == *"foo.sh"* ]]
}

# @test "Skips snapshot when no changes exist" {
#   git add foo.sh && git commit -m "init"
#   run bash tools/pre-git-switch.sh
#   [ "$status" -eq 0 ]
#   [[ "$output" == *"No changes detected"* ]]
# }
