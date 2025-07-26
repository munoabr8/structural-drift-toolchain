#!/usr/bin/env bash


# tools/exit_codes_enforcer.sh
# 0–9: success / soft statuses
readonly EXIT_OK=0

# 10–19: policy file / rule problems
readonly EXIT_POLICY_VIOLATIONS=10        # one or more rules violated
readonly EXIT_POLICY_FILE_NOT_FOUND=11


# 30–39: environment / dependency problems
readonly EXIT_DEP_YQ_MISSING=30

readonly EXIT_POLICY_MALFORMED=12 # Currently not used
readonly EXIT_UNKNOWN_CONDITION=13 # Currently not used
readonly EXIT_UNKNOWN_ACTION=14 # Currently not user

# 20–29: snapshot problems
readonly EXIT_SNAPSHOT_MISSING=20 # Currently not user
readonly EXIT_SNAPSHOT_GEN_FAILED=21 # Currently not user

 

# 90–99: generic/internal
readonly EXIT_INTERNAL_ERROR=99 # Currently not user
