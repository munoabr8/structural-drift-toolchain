#!/usr/bin/env bats

# test_logger.bats
# ----------------
# Strategic Purpose:
# This test suite validates the structure and reliability of logger.sh,
# a first-class logging utility used across scripts for consistent, structured output.
# These tests ensure the logger functions as a trusted signal generator for both humans and machines.

#load './test_helper.bash'  # Optional: shared mocks or formatting helpers

setup() {
  echo " Fail-fast module loading..." >&2
 
  

  
source ./source_or_fail.sh

source_or_fail "$BATS_TEST_DIRNAME/logger.sh"


source_or_fail "$BATS_TEST_DIRNAME/logger_wrapper.sh"

}

@test "logger outputs complete structured JSON when all fields are provided" {
  # WHY: This is the 'happy path' — verifies that full logging with all fields works as expected.
  # Critical because downstream log parsers (e.g. jq, ELK) assume complete structure.

  run log "ERROR" "Something failed" "E123" 42

  # Strategy: Always verify return code first
  [ "$status" -eq 0 ]

  # Strategy: Validate high-signal fields are present in structured output
  [[ "$output" == *'"level":"ERROR"'* ]]
  [[ "$output" == *'"message":"Something failed"'* ]]
  [[ "$output" == *'"error_code":"E123"'* ]]
  [[ "$output" == *'"exit_code":"42"'* ]]
}

@test "logger still emits valid JSON when optional fields are omitted" {
  # WHY: The logger must fail gracefully and provide valid, parseable output
  # even when optional fields are left empty (e.g. during early boot stages or dry runs)

  run log "INFO" "All good"

  [ "$status" -eq 0 ]

  # Strategy: Core fields must always be present and correctly populated
  [[ "$output" == *'"level":"INFO"'* ]]
  [[ "$output" == *'"message":"All good"'* ]]

  # Optional fields should default to empty but maintain structural placeholders
  [[ "$output" == *'"error_code":""'* ]]
  [[ "$output" == *'"exit_code":""'* ]]
}


####### Test for logger correct use(checking for arguments.)
@test "log() fails when called with a single concatenated argument" {
  run log "SUCCESS:Something broke"
  [ "$status" -eq 99 ]
  [[ "$output" == *"too few arguments"* ]]
}


@test "logs structured JSON with 4 valid args" {
  run log "INFO" "All good" "E000" "0"
  [[ "$output" == *'"level":"INFO"'* ]]
  [[ "$output" == *'"message":"All good"'* ]]
  [[ "$output" == *'"error_code":"E000"'* ]]
  [[ "$output" == *'"exit_code":"0"'* ]]
}


@test "emits valid JSON parsable by jq" {
  run log "INFO" "Parsable check"
  echo "$output" | jq . > /dev/null
  [ "$status" -eq 0 ]
}



@test "log_success emits proper JSON with 0 exit code" {
  run log_success "Validated something"

  echo "DEBUG: Output was => $output" >&2

  [[ "$output" == *'"level":"SUCCESS"'* ]]
  [[ "$output" == *'"exit_code":"0"'* ]]
}

# Optional Enhancement:
# You can uncomment and use this test if `jq` is installed to verify strict JSON syntax

# @test "logger emits valid JSON format for machine parsers" {
#   run log "INFO" "Machine-readable test"
#   echo "$output" | jq . > /dev/null
#   [ "$status" -eq 0 ]
# }

