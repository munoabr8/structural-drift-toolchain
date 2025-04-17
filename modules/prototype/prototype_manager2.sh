#!/usr/bin/env bash

#Assumption: A repo has already been instantiated.

#Assumption: This script should be able to run from anywhere. 
#            The implication is that the pwd command will not be used
#            to set any arguments.


#Assumption: If cloning a repo is requested, the new repo will be saved 
#            to the directory: "/Users/someUser/git/"
#            and will have a unique name: "uniqueRepoName_n". 

#Assumption: The directory: /Users/someUser/git/ will be validated before anything else occurs.

#Assumption: In the clone script, there will be a manner to automate the
#            naming of the new repo.

#Assumption: If the cloning operation is requested, then only the 
#            $DEFAULT_LOCAL_REPO_PATH variable will be required as an argument.

#Assumption: DEFAULT_LOCAL_REPO_PATH is given as an argument to the clone script.

# Assumption: As of 08/01/24, -d <repo-dir>  is hard-coded to make it easier for the user.(In the case of using the clone 
# command)

 

#Assumption: Script owner was changed to abrahammunoz. 08/01/24 1423.


# Assumption: 
#               CLI: scriptName.sh_command_option 
#         variables: $0_$1_$2


umask 022

#Turned off for testing
 #set -euo pipefail


 



# --- Global Variables ---
DEBUG_MODE=false
LOG_FILE="script_debug.log" 


 
# project folder location: /Users/abrahammunoz/git/bin_pro/prototypeProject

TRUTH_HOME="/TRUTH_HOME"


# ==========================
#    SOURCING ENVIORMENT
# ==========================

if [ -f ./$TRUTH_HOME"/prototypeManager.env" ]; then
    source ./prototypeManager.env
fi

#mkdir -p "$LOG_DIR"

#ls -a



 
#  if [[ -z "$LOG_DIR" ]]; then
#     echo "Error: LOG_DIR not set."
#     exit 1
# fi

 
# --- Logging Functions ---
log_info() {
    if [ "$DEBUG_MODE" = true ]; then
         echo "[INFO][prototype_manager2.sh] $1"
    fi
}

log_error() {
    echo "[ERROR][prototype_manager2.sh] $1" >&2
    return 1
}

 


# --- Validation Functions ---
is_valid_repo() {
    local repo_dir="$1"
    [ -d "$repo_dir" ] && [ -d "$repo_dir/.git" ]
}

validate_repo() {
    if ! is_valid_repo "$1"; then
        log_error "Invalid repository: $1. Ensure the directory exists and contains a '.git' folder."
    fi
}



 
validate_input() {
    local -r command="$1"
    shift
    local args=("$@")
local -r error_message_prefix="Validation failed for command '$command'."

    case "$command" in
        clone)
            local -r required_args_count=1
            if (( ${#args[@]} < required_args_count )); then

                log_error "$error_message_prefix Default local repository path is required."           
                return 1
            fi
            ;;
        commit)
            local -r required_args_count=2
            if (( ${#args[@]} < required_args_count )); then

                log_error "$error_message_prefix Repository name and commit hash are required."          

                 return 1
            fi
            ;;
        branch)
            local -r required_args_count=2
            if (( ${#args[@]} < required_args_count )); then
                log_error "$error_message_prefix Repository name and branch name are required."
                return 1
            fi
            ;;
        help|*)
            # No additional validation required
            ;;
    esac
    return 0
}
 
 

is_commit_valid() {
    git -C "$GIT_REPO_DIR/$REPOSITORY_NAME" rev-parse "$COMMIT_HASH" >/dev/null 2>&1
}

 

# --- Command Execution ---
execute_command() {

    validate_input "$1"

    case "$1" in
        clone) handle_clone ;;
        commit) handle_commit ;;
        branch) handle_branch ;;
        help|*) display_usage ;;
    esac
}


# --- Command Handlers ---
handle_clone() {
    log_info "Handling clone command for path: $DEFAULT_LOCAL_REPO_PATH."
    validate_repo "$DEFAULT_LOCAL_REPO_PATH"
    #"$UTILITY_DIR/repoCloning" "$DEFAULT_LOCAL_REPO_PATH"
}

handle_commit() {
    log_info "Handling commit command for repository: $REPOSITORY_NAME."
    validate_repo "$GIT_REPO_DIR/$REPOSITORY_NAME"
    echo "Experimenting with commit $COMMIT_HASH in repository $REPOSITORY_NAME."
    "$UTILITY_DIR/commitExp" -r "$REPOSITORY_NAME" -c "$COMMIT_HASH"
}

handle_branch() {
    log_info "Handling branch command for repository: $REPOSITORY_NAME."
    validate_repo "$GIT_REPO_DIR/$REPOSITORY_NAME"
    "$UTILITY_DIR/branchExp" "$REPOSITORY_NAME" "$BRANCH_NAME"
}

 



abolutePath(){
# Ensure pathmaster.sh exists

   # Set PATHMASTER_SCRIPT
local -r pathmaster_script="$UTILITY_DIR/pathmaster.sh"

 
 if [ ! -f "$pathmaster_script" ]; then
    log_error "Pathmaster.sh not found===== in $UTILITY_DIR"
    exit 1
 fi


    local input_path="$1"

    log_info "Input path is : $input_path"

 
  

}






 
# --- Utility Functions ---
# Can this function be moved to the envManager script?
# Does this script(prototype_manager2.sh) absoluetly need to be responsbile for 
# loading the enviornment that it needs in order to execute correctly?


# Idea: maybe I could place this function in the INIT state OR
#       call the envManager.sh script in the INITI state.

load_env_manager() {


     local -r DEFAULT_ENV_FILE="prototypeManager.env"


    local -r env_file="${1:-$DEFAULT_ENV_FILE}"
    local -r env_manager_path="$(dirname "${BASH_SOURCE[0]}")/envManager.sh"

    log_info "ENV_MANAGER_PATH: $env_manager_path"
    log_info "Loading environment manager script."

    # Check if the environment file exists
    if [ ! -f "$env_file" ]; then
        log_error "Environment file '$env_file' not found."
        return 1
    fi

 
    # Source the environment manager script
    if ! source "$env_manager_path" --env-file $ ; then
        log_error "Failed to source environment manager script at $env_manager_path."
        return 1
    fi

    # Verify essential variables and functions
    if [ -z "$(declare -f set_env)" ] || [ -z "$env_file" ]; then
        log_error "Environment manager script did not execute as expected."
        return 1
    fi

    # Check essential variables
    if [ -z "$UTILITY_DIR" ] || [ -z "$GIT_REPO_DIR" ] || [ -z "$DEFAULT_LOCAL_REPO_PATH" ]; then
        log_error "Essential variables (UTILITY_DIR, GIT_REPO_DIR, DEFAULT_LOCAL_REPO_PATH) are missing after loading envManager."
        return 1
    fi

    log_info "Environment manager loaded successfully."

  
  # Ensure log directory exists after sourcing the environment
if [ -n "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    log_info "Log directory ensured at: $LOG_DIR"
else
    log_error "LOG_DIR variable is not defined in the environment file."
    return 1
fi

    return 0
}

 
 


# Function to display usage
display_usage() {
    echo
    echo
    echo "Useage: $0 {clone|commit|branch|help} [options...]"
    echo
    echo
    echo "Commands:"
    echo
    echo "  clone        : Clone a repository."
    echo "    -d <repo-dir>     : Directory of the repository"
    echo
    echo
    echo "  commit       : Experiment on a specific commit."
    echo "    -d <repo-dir>     : Directory of the repository"
    echo "    -c <commit-hash>  : Commit hash"
    echo
    echo "  branch       : Experiment on a branch."
    echo "    -d <nameOfRepo>          : Repository name (path or directory)"
    echo "    -b <base-name-for-branch-name>  : Abstraction being worked on"
    echo
    echo
    echo "Help options:"
    echo "  help         : Display this help message"
    echo
    exit 1
}


displayScriptArguments() {
    echo "Arguments received:"
    for arg in "$@"; do
        echo "$arg"
    done
}
 
# Assumption: all the functions have access to 
# the arguments of the script.
parse_input() {

 
    local   command=""
    local   repository_name=""
    local   commit_hash=""
    local  branch_name=""

    local remaining_args="$#"
 

    while [[ $remaining_args -gt 0 ]]; do
        local current_arg="$1"
        case "$current_arg" in
            -debug|--debug)DEBUG_MODE=true;;
            clone|commit|branch|help) command="$current_arg" ;;
            -d|--repo-dir) shift; repository_name="$1" ;;
            -c|--commit-hash) shift; commit_hash="$1" ;;
            -b|--branch-name) shift; branch_name="$1" ;;
            *) log_error "Unknown option: $1" ;;
        esac
        
        shift  # Remove the processed argument
        ((remaining_args--))  # Decrease counter for clarity
    done

 
    # Ensure a valid command is provided
    if [[ -z "$command" ]]; then
        log_error "During parsing, no valid command obtained."
        display_usage
    fi

    # Return the parsed values as a string
    echo "$command|$repository_name|$commit_hash|$branch_name|$DEBUG_MODE"
         #echo "clone|my-repo|123abc|feature-branch|true"
  }

 


 
# Assumptions of main logic:
# 
# --- Main Function ---
main() {

 
    if [[ -z "$@" ]]; then
        log_error "No command provided." 
        display_usage
        exit 1
    fi

     load_env_manager


 
    local parsed_output
    parsed_output=$(parse_input "$@")
 

 
IFS='|' read -r -a parsed_values <<< "$parsed_output"

# Define field names dynamically
field_names=("Command" "Repository" "Commit Hash" "Branch Name" "Debug Mode")
 
# Iterate and print dynamically
for i in "${!parsed_values[@]}"; do

    log_info "${field_names[$i]}: ${parsed_values[$i]}"

done

 
 execute_command "${parsed_values[0]}"
 
 
}

# --- Start Script Execution ---
 #main "$@"





