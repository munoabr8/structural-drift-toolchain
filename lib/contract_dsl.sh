#!/usr/bin/env bash

require()  { "$@" || { echo "require failed: $*" >&2; return 1; }; }
assert_i() { "$@" || { echo "assert failed: $*"  >&2; return 1; }; }
ensure()   { "$@" || { echo "ensure failed: $*"  >&2; return 1; }; }