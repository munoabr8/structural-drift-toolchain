#!/usr/bin/env bash

# These exit codes are exclusively used within ./system/structure_validator.rf.sh 
# Future refactoring: remove common codes that can be used by other scripts. 

#GROUP A
readonly EXIT_OK=0
readonly EXIT_USAGE=64

readonly EXIT_PARSE_ERROR=71
readonly EXIT_INTERNAL_ERROR=72


#GROUP B
readonly EXIT_MISSING_SPEC=65
readonly EXIT_MISSING_PATH=66
readonly EXIT_INVALID_SYMLINK=67
readonly EXIT_VALIDATION_FAIL=68

#GROUP C
readonly EXIT_MISSING_POLICY=69
readonly EXIT_POLICY_VIOLATION=70

 



echo "Exit codes are loaded."