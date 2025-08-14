#!/usr/bin/env bash

# These exit codes are exclusively used within ./system/structure_validator.rf.sh 
# Future refactoring: remove common codes that can be used by other scripts. 

# system/exit-codes/exit_codes_validator.sh
# Guard: define once
if [[ -z "${EXIT_CODES_LOADED:-}" ]]; then
  readonly EXIT_OK=0
  readonly EXIT_USAGE=64
  readonly EXIT_PARSE_ERROR=65
  readonly EXIT_INTERNAL_ERROR=70
  readonly EXIT_MISSING_SPEC=2
  readonly EXIT_MISSING_PATH=3
  readonly EXIT_INVALID_SYMLINK=4
  readonly EXIT_VALIDATION_FAIL=5
  readonly EXIT_MISSING_POLICY=6
  readonly EXIT_POLICY_VIOLATION=7
  readonly EXIT_CODES_LOADED=1
fi

 



echo "Exit codes are loaded."