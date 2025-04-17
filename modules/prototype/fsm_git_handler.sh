#!/usr/bin/env bash

# ==========================
#        FSM-GIT-HANDLER
# ==========================
# Purpose: A Finite State Machine (FSM) to handle Git operations dynamically using `truths_fsm_git.json`
# Version: 2.1 (Minimal Global Variables)
# ==========================




# Exit codes:
# 0: successful completion of execution of program.
# 1: issue if execution fails 
# 2: if no parameters are not  provided 
# 3: If validation fails

 


# Git command executions should drive the building of the project.

umask 022

set -euo pipefail



# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "[ERROR] jq is required to parse JSON. Install it with 'brew install jq' or 'sudo apt install jq'."
    exit 1
fi
# ==========================
#       LOAD TRUTH FILE
# ==========================
TRUTH_FILE="truths_fsm_handler.json"

if [[ ! -f "$TRUTH_FILE" ]]; then
    echo "[ERROR] Truth file $TRUTH_FILE not found!"
    exit 1
fi

BASH_MIN_VERSION=$(jq -r '."bash_min_version"'  "$TRUTH_FILE")
DEFAULT_GIT_BRANCH=$(jq -r '.git.default_branch' "$TRUTH_FILE")
GIT_REMOTE=$(jq -r '."git_remote"' "$TRUTH_FILE")

# Load FSM states and valid commands dynamically
FSM_STATES=($(jq -r '."fsm_states"[]' "$TRUTH_FILE"))
# Instance 1 of this line of code.
#VALID_COMMANDS=($(jq -r '."valid_commands"[]' "$TRUTH_FILE"))

# Ensure minimum Bash version
CURRENT_BASH_VERSION=$(bash --version | head -n1 | awk '{print $4}')
if [[ "$(printf '%s\n' "$BASH_MIN_VERSION" "$CURRENT_BASH_VERSION" | sort -V | head -n1)" != "$BASH_MIN_VERSION" ]]; then
    echo "[ERROR] Bash version must be at least $BASH_MIN_VERSION. Current: $CURRENT_BASH_VERSION"
    exit 1
fi


  show_help (){
    echo "Usage: $0 <STATE> <COMMAND>"
    echo
    echo "Finite State Machine (FSM) Git Handler"
    echo
    echo "States:"
    echo "  INIT               - Starting state(idea: runs checks and executes tests); expects a valid command."
    echo "  VALIDATE_COMMAND   - Ensures command validity before execution."
    echo "  EXECUTE_GIT        - Runs the requested Git command."
    echo "  DONE               - Indicates successful completion."
    echo "  ERROR              - Indicates failure and exits."
    echo
    echo "Commands:"
    echo "  clone              - Clone a repository."
    echo "  branch <name>      - Create a new branch."
    echo "  commit             - Commit changes."
    echo
    echo "Examples:"
    echo "  $0 INIT clone"
    echo "  $0 INIT branch feature-x"
    echo "  $0 INIT commit"
    echo
    echo "For debugging, enable verbose output by running:"
    echo "  bash -x $0 INIT clone"
    exit 0
}

 
 

# ==========================
#    COMMAND VALIDATION
# ==========================

# Pre-conditions: takes in one parameter.
# 
validate_git_command() {
    local command="$1"
    
    echo "[DEBUG] validate_git_command received: '$command'"

    if [[ -z "$command" ]]; then
        return 1
    fi

    local valid_commands
    valid_commands=($(jq -r '."valid_commands"[]' "$TRUTH_FILE"))

    echo "[DEBUG] Valid commands: ${valid_commands[*]}"

    for valid in "${valid_commands[@]}"; do
        if [[ "$command" == "$valid" ]]; then
            return 0
        fi
    done

        return 1


}



 

retry_command() {
    local retries=3
    local count=0
    until "$@"; do
        count=$((count + 1))
        if [ "$count" -ge "$retries" ]; then
            echo "Error: Command failed after $retries attempts."
            return 1
        fi
        echo "Retrying ($count/$retries)..."
    done
}

# ==========================
#    GIT EXECUTION HANDLER
# ==========================
 


# I need to mock execution of the git command.
# I need to test that this function exits with the correct codes.
# Invariant: command is never used outside this function or passed.

execute_git_command() {
    local -r command="$1"; shift
    echo "[FSM] Executing: git $command $*"


    local -r result=$(git "$command" "$@")
    

    local success=$?
    
    if [ $success -eq 0 ]; then
        return 0
    else
        echo "Error: $result"
        return 1
    fi
}

# Command
#load() {

 #environment,truth file,fsm_states
  #  }


# Query

#check(){

#checks current bash version and script protection

#}
    
 

# ==========================
#       TRANSITION FUNCTION
# ==========================

#Pre-condition: Requires the current_state and next state.(Can the assumption be made that if you have a current state,
# that the next_state will be known? In other words if you have the current state, you should be able to infer the 
#next state.The goal goals is to reduce the number of parameters that the transition function requires.)
# Major assumption: Whoever calls this function will know the different states possible and no state validation
# will be done.This function should break when there is no information about the current_state.
# Current version of the function requires that two parameters be fed to the function in order to work correctly.


#######################################################################################################################
#######################################################################################################################
# Refactored version: 
# Pre-condition: takes in one parameter(current state)
# Invariant: 
#   a.) current_state remains the same throughout the entire execution.
#   b.) 
# Post-condition: state is stored locally only. Does not modify a global state.
# Function simply takes an input and outpus the next state.

#######################################################################################################################
#######################################################################################################################


# Query

transition() {
    local -r current_state="$1"

    case "$current_state" in
        "INIT")
            #Could I initialize the enviorment here? 
            echo "VALIDATE_COMMAND"
            return 0
            ;;
        "VALIDATE_COMMAND") 
            echo "EXECUTE_GIT"
            return 0
            ;;
        "EXECUTE_GIT") 
            echo "DONE"
            return 0
            ;;
        "DONE"|"ERROR") 
            echo "$current_state"
            return 0
            ;;
        *) 
            echo "[ERROR] Invalid state: $current_state" >&2
            return 1
            ;;
    esac
}




# Function to validate and execute Git commands
handle_command() {
    local state="$1"
    local command="$2"

    case "$state" in
        "VALIDATE_COMMAND")
            validate_git_command "$command" || return 1
            ;;
        "EXECUTE_GIT")
            execute_git_command "$command" || return 1
            ;;
    esac
}




# ==========================
#      FSM MAIN FUNCTION
# ==========================
 

# Current level of understanding is that this function must have a state 
# provided as an argument, but a command may or may not be required depending
# what the current state is.  
# So the logical conclusion is that this method MUST always recieve the state
# as a parameter when it is called. 
# If the function does not recieve a command parameter, than we know that it is
# in a "DONE" or "ERROR" state.

# Pre-condition: must recieve atleast one string parameter. 


run_fsm() {
    local state="$1"
    local command="${2:-}"

    while [[ "$state" != "DONE" && "$state" != "ERROR" ]]; do
        echo "[DEBUG] Current state: $state, Command: ${command:-NONE}"

        # Ensure required command is present
        if [[ -z "$command" && "$state" =~ ^(VALIDATE_COMMAND|EXECUTE_GIT)$ ]]; then
            echo "[ERROR] Missing command in state $state"
            state="ERROR"
            continue
        fi

        # Process command if needed
        [[ "$state" =~ ^(VALIDATE_COMMAND|EXECUTE_GIT)$ ]] && handle_command "$state" "$command"

        # Determine the next state
        state=$(transition "$state") || { echo "[ERROR] Invalid transition"; exit 1; }
    done

    echo "[INFO] FSM completed with state: $state"
    [[ "$state" == "ERROR" ]] && exit 1 || exit 0
}


 
 
 
# ==========================
#  SCRIPT PROTECTION CHECKS
# ==========================
PROTECT_SCRIPT=$(jq -r '."script_protection.enforce_read_only"' "$TRUTH_FILE")
AUTO_REGENERATE=$(jq -r '."script_protection.auto_regenerate"' "$TRUTH_FILE")

if [[ "$PROTECT_SCRIPT" == "true" ]]; then
    chmod -w "$0"
    echo "[SECURITY] Script is now read-only."
fi

if [[ "$AUTO_REGENERATE" == "true" && "$TRUTH_FILE" -nt "$0" ]]; then
    echo "[INFO] Detected changes in $TRUTH_FILE. Regenerating script..."
    # generate_fsm_script has not been created yet.
    bash generate_fsm_script.sh  # Calls script generator
    exit 0
fi

# ==========================
#       MAIN FUNCTION
# ==========================
main() {

    #set -x
     echo "[FSM] Starting Git FSM..."
     run_fsm "INIT" "status"

    echo "[DEBUG] FSM received args: $@"
    # Add functionality to determine if user wants to bring up the help menu depending if -h | -help | --help | --h option is used.

echo "FSM State: DONE" >&1  # Ensure stdout output
}

 #main "$@"




