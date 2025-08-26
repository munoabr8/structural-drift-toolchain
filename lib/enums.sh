# shellcheck shell=bash

# Constants for sourcing elsewhere.

# shellcheck disable=SC2034
: "${STDIN_TTY:=tty}" "${STDIN_PIPE:=pipe}" "${STDIN_FILE:=file}" "${STDIN_UNKNOWN:=unknown}"
readonly STDIN_TTY STDIN_PIPE STDIN_FILE STDIN_UNKNOWN
