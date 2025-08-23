#!/usr/bin/env bash
# util/core.sh (idempotent)
[[ -n ${__CORE_SH__:-} ]] && return 0; __CORE_SH__=1
set -Eeo pipefail; 
shopt -s extglob # I don't know what this line does.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

ROOT_BOOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"   # project root guess
# This appears static and not very dynamic. I like its simplicity but I wonder if
# if for some reason the location of this script changed, what problems this would bring to 
# my future self?
# What if there was a script thats purpose is to observe where another script lives, and determine
# how far it is from the root.


# Should exit codes be determined per script? Or per directory? Or per behavior?
EXIT_OK=0; EXIT_PRECONDITION=65; EXIT_DEPS=66; EXIT_SYNTAX=67; EXIT_RUNTIME=70
export ROOT_BOOT EXIT_OK EXIT_PRECONDITION EXIT_DEPS EXIT_SYNTAX EXIT_RUNTIME
