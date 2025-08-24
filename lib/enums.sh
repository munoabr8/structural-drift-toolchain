<<<<<<< HEAD
# shellcheck shell=bash

# Constants for sourcing elsewhere.
# shellcheck disable=SC2034

# shellcheck disable=SC2034
: "${STDIN_TTY:=tty}" "${STDIN_PIPE:=pipe}" "${STDIN_FILE:=file}" "${STDIN_UNKNOWN:=unknown}"
readonly STDIN_TTY STDIN_PIPE STDIN_FILE STDIN_UNKNOWN
=======
#shellcheck=bash 
STDIN_TTY=tty; STDIN_PIPE=pipe; STDIN_FILE=file; STDIN_UNKNOWN=unknown
>>>>>>> 07c563a (Updated linting issues. added additional quereis.)
