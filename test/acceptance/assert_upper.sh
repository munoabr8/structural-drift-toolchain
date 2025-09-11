#!/usr/bin/env bash
# assert_upper.sh — codomain assertion
# Asserts that all input lines contain no lowercase a–z characters.
# Reads from stdin, writes pass/fail message, sets exit code accordingly.

set -euo pipefail

if grep -q '[a-z]' -; then
  echo "Q FAIL: lowercase detected" >&2
  exit 1
else
  echo "Q OK"
  exit 0
fi

