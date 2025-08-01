#!/usr/bin/env bash



# Strategic Rule of Thumb
# Situation	Use of subshell vs pushd/popd
# You want to return a value without changing state	✅ Use a subshell
# You want to temporarily cd for lookup or scanning	✅ Use a subshell
# You need to change global state (e.g. cd, export)	❌ Avoid subshell — use pushd/popd or document side effect
# You're writing pure helpers or test utilities	✅ Subshells promote statelessness and testability




  resolve_project_root() {
	 local   source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
	 readonly source_path
  	cd "$(dirname "$source_path")/../" && pwd
}

setup_environment_paths() {
     PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}"
    SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
}


 
setup_environment_paths

#################################################
########### ENVIORNMENTAL VARIABLES #############
#################################################

export PROJECT_ROOT SYSTEM_DIR  
 
#################################################
#################################################
#################################################

# Pre-conditions: 
# --> SYSTEM_DIR is set.
# --> source_OR_fail.sh must be a valid file(correct permissions)
# --> source_OR_fail.sh must contain a source_or_fail function.
# --> logger.sh must be a valid file,
# --> logger_wrapper.sh must be a valid file. 
source_bats_utilities(){

	local sandbox="$1"

  if [[ ! -f "$SYSTEM_DIR/source_OR_fail.sh" ]]; then
    echo "Missing required file: source_OR_fail.sh"
    exit 1
  fi

  source "$SYSTEM_DIR/source_OR_fail.sh"

  source_or_fail "$SYSTEM_DIR/logger.sh"
  source_or_fail "$SYSTEM_DIR/logger_wrapper.sh"

  source_or_fail "$sandbox"
 

 }
 

  

 #POSSIBLE FUTURE:

# resolve_project_root() {
#   local source_path="${BATS_TEST_FILENAME:-${BASH_SOURCE[0]}}"
#   local levels_up="${1:-1}"
#   local path="$(dirname "$source_path")"

#   for ((i = 0; i < levels_up; i++)); do
#     path="$path/.."
#   done

#   ( cd "$path" && pwd )
# }

# Useage:
# resolve_project_root         # default 1 level up
# resolve_project_root 2       # go two levels up




 
 