#!/usr/bin/env bash
set -euo pipefail
err=0

# bin must NOT source util directly
grep -Rn --include='*.sh' 'source .*util/' bin/ && { echo "bin→util forbidden"; err=1; } || true
# lib must NOT source bin
grep -Rn --include='*.sh' 'source .*bin/'  lib/ && { echo "lib→bin forbidden";  err=1; } || true
# util must NOT source anything outside util
grep -Rn --include='*.sh' -E 'source .*((bin|lib|test|system)/)' util/ && { echo "util importing up"; err=1; } || true
# no one should source tests or system/infra
grep -Rn --include='*.sh' 'source .*test/'   . && { echo "importing tests";  err=1; } || true
grep -Rn --include='*.sh' 'source .*system/' . && { echo "importing system"; err=1; } || true

exit "$err"
