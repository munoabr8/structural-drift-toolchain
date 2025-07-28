#!/usr/bin/env bats

j

setup() {
  mkdir -p tmp/validate_ignore_test/foo
  mkdir -p tmp/validate_ignore_test/bar
  cd tmp/validate_ignore_test
}

teardown() {
  cd ../..
  rm -rf tmp/validate_ignore_test
}

@test "Valid .structure.ignore passes validation" {
  mkdir -p foo
  mkdir -p bar
  echo "./foo" > .structure.ignore
  echo "./bar" >> .structure.ignore

  echo "PWD inside test: $(pwd)" >&2
ls -la >&2

  run bash ./../../tools/validate_ignore.sh

  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ .structure.ignore is valid." ]]
}

@test "Missing .structure.ignore fails validation" {
  run bash ./../../tools/validate_ignore.sh

  [ "$status" -eq 1 ]
  [[ "$output" =~ "❌ .structure.ignore missing!" ]]
}

@test ".structure.ignore with nonexistent path fails validation" {
  mkdir -p foo
  echo "./foo" > .structure.ignore
  echo "./does_not_exist" >> .structure.ignore

  run bash ./../../tools/validate_ignore.sh

  [ "$status" -eq 1 ]
  [[ "$output" =~ "❌ Ignored path does not exist" ]]
}
