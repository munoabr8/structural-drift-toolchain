#!/usr/bin/env bats

# What is its purpose/intent: generates a developer snapshot before switching branches.
# What is the likely invariants of the pre-git-switch script?
# Where should a pre-git-switch be located?(Location?)

 

setup() {
 cd "$BATS_TMPDIR"

  # Strategic clarity: we do not test the real system script directly.
  # This avoids side effects and ensures safe, reproducible testing.
  cp "$BATS_TEST_DIRNAME/../tools/pre-git-switch.sh" pre-git-switch.sh

  # Should I use a sandbox script(instead of the actual one) for all scripts that I unit test?

  sandbox_script="$BATS_TMPDIR/pre-git-switch.sh"

  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"
    exit 1
  }

  export SYSTEM_DIR="system"

  mkdir -p tools system

  # Create the file before initializing Git and .gitignore
  echo "echo foo" > foo.sh

  git init --quiet
  git config --local core.excludesfile /dev/null
  echo "*" > .gitignore
  echo "!foo.sh" >> .gitignore

  cp "$BATS_TEST_DIRNAME/../system/logger.sh" system/
  cp "$BATS_TEST_DIRNAME/../system/logger_wrapper.sh" system/
  cp "$BATS_TEST_DIRNAME/../system/source_or_fail.sh" system/

  source system/source_or_fail.sh
  source_or_fail system/logger.sh
  source_or_fail system/logger_wrapper.sh
  source_or_fail pre-git-switch.sh
}

 

teardown() {
  rm -rf .git/dev_snapshots
  rm -f foo.sh
}

@test "Fails when SYSTEM_DIR is set to a bad path (stimulated failure)" {
  export SYSTEM_DIR="/nonexistent/directory"
  run bash "$sandbox_script"

  echo "STATUS: $status"
  echo "STDOUT: $output"
  echo "STDERR: $error"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required file"* ]]
}


@test "Is actually in a sandbox directory" {
  [[ "$PWD" == "$BATS_TMPDIR"* ]]
}


@test "Creates snapshot for modified file--0" {
 
  echo "# modified" >> foo.sh  # add this

  run bash "$sandbox_script"

  echo "STATUS: $status"
  echo "STDOUT: $output"
  echo "STDERR: $error"

  [ "$status" -eq 0 ]


  snapshot=$(find .git/dev_snapshots -name '*.tar.gz')
  [[ -f "$snapshot" ]]
  [[ "$(tar -tzf "$snapshot")" == *"foo.sh"* ]]
}




@test "Creates snapshot for modified file--1" {
  echo "Modifying foo.sh"
  echo "# modified" >> foo.sh


  run bash "$sandbox_script"

  echo "Exit code: $status"
  echo "Output: $output"

  [ "$status" -eq 0 ]
  snapshot=$(find .git/dev_snapshots -name '*.tar.gz')
  [[ -f "$snapshot" ]]
  [[ "$(tar -tzf "$snapshot")" == *"foo.sh"* ]]
}

@test "Creates snapshot for modified file--2" {
  echo "Checking script exists: "


  ls "$sandbox_script"


 
  echo "# modified" >> foo.sh

  run bash "$sandbox_script"

   echo "Exit code: $status"
  echo "Output: $output"

  [ "$status" -eq 0 ]
  snapshot=$(find .git/dev_snapshots -name '*.tar.gz')
  [[ -f "$snapshot" ]]
  [[ "$(tar -tzf "$snapshot")" == *"foo.sh"* ]]
}

@test "Multiple runs create multiple snapshot logs--3" {
  echo "# change" >> foo.sh
  run bash "$sandbox_script"
  echo "$output"

  sleep 1
  echo "# another change" >> foo.sh
  run bash "$sandbox_script"
  echo "$output"

  echo "Snapshot log:"
  cat .git/dev_snapshots/snapshot_log.json || echo "Log file missing"

  log_count=$(grep -c '"snapshot":' .git/dev_snapshots/snapshot_log.json)
  [ "$log_count" -eq 2 ]
}
@test "Snapshot log is appended in JSON format--4" {
  echo "# change" >> foo.sh
  run bash "$sandbox_script"

  echo "Exit code: $status"
  echo "Output: $output"

  [ "$status" -eq 0 ]

  echo "Checking snapshot_log.json..."
  ls -l .git/dev_snapshots
  cat .git/dev_snapshots/snapshot_log.json || echo "Log not found"

  [[ -f .git/dev_snapshots/snapshot_log.json ]]
  grep -q '"snapshot":' .git/dev_snapshots/snapshot_log.json
}


@test "Skips snapshot when no changes exist--5" {
  git status
  git diff
  git log --oneline

   run bash "$sandbox_script"
  echo "Exit code: $status"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes detected"* ]]
}
 