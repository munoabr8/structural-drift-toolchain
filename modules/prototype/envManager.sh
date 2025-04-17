#!/usr/bin/env bash

### Constants ###

# This can be refactored so that the array is passed to the valdiation function
# in order to minimize the use of global variables.
EXPECTED_ENV_VARS=("UTILITY_DIR" "GIT_REPO_DIR" "DEFAULT_LOCAL_REPO_PATH")


set -euo pipefail
umask 022



# --- Global Variables ---
DEBUG_MODE=false
 

### Functions ###

# Function to load the environment file
set_env() {

 

    # Assume that set_env accepts one parameter which is the enviorment file.
    local env_file="$1"

    if [ ! -f "$env_file" ]; then
        echo "Error: Environment file '$env_file' not found."
        exit 1
    fi

    # File execution.
    source "$env_file"
    log_info "Environment variables loaded from $env_file"

        # Debug loaded variables
    #log_info "Loaded variables:"
    #log_info "UTILITY_DIR: $UTILITY_DIR"
    #log_info "GIT_REPO_DIR: $GIT_REPO_DIR"
    #log_info "DEFAULT_LOCAL_REPO_PATH: $DEFAULT_LOCAL_REPO_PATH"


}

displayArguments() {

    local array=("$@")
    echo "..........Arguments received:"
    for arg in "${array[@]}"; do
        echo "$arg"
    done
}


 

# Function to validate required environment variables
# 
validate_env_vars() {

    local array=("$@")
    displayArguments "$array"

    # I don't think that the EXPECTED_ENV_VARS array is treated as an object?

    local missing_vars=()

    for var in "${EXPECTED_ENV_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ "${#missing_vars[@]}" -gt 0 ]; then
        echo "Error: The following environment variables are missing or unset:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi
}

# Function to display environment variables
#Works only with --debug?
show_env() {

    log_info "####################################################################################################################"

    log_info "### Loaded Environment Variables ###"

    for var in "${EXPECTED_ENV_VARS[@]}"; do
        log_info "$var=${!var}"
    done

    log_info "#####################################################################################################################"
}

 



log_info() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "[INFO][envManager.sh] $1"
    fi
}

log_error() {
    echo "[ERROR][envManager.sh] $1" >&2
    exit 1
}

 


show_help() {
  cat << EOF
Usage: $0 [options]

This script manages environment variables and settings for prototype-related scripts.

Options:
  --help, -h    Display this help message and exit
  --set-env     Set up the required environment variables
  --show-env    Display the current environment variable settings
  --reset-env   Reset environment variables to default values
  --debug       Enable debug logging during script execution

Examples:
  $0 --help        Display this help message
  $0 --set-env     Set up environment variables
  $0 --show-env    Show the current environment settings
  $0 --reset-env   Reset to default environment variables
  $0 --debug --set-env   Enable debug logging and set environment variables
EOF
}

# Function: Parse arguments for debug mode and env file
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG_MODE=true
                log_info "Debug mode enabled."
                ;;
            --env-file)
                shift
                ENV_FILE="$1"
                log_info "Environment file specified: $ENV_FILE"
                set_env $ENV_FILE

                ;;
            *)
                # Pass other arguments for handling
                set -- "$@" "$1"
                ;;
        esac
        shift
    done
}


# Function: Handle script arguments
# handle_arguments() {
#     case "$1" in
#         --help|-h)
#             show_help
#             ;;
#         --set-env)
#             set_env
#             ;;
#         --show-env)
#             show_env
#             ;;
#         --reset-env)
#             reset_env
#             ;;
#         *)
#             log_error "Invalid option."
#             ;;
#     esac
# }


# Main function
main() {
 
    log_info "################################      EXECUTING: Enviornment Manager Script     ################################"


    #displayArguments "$@"


    parse_arguments "$@"

 
    #handle_arguments "$1"

    local -r env_file="prototypeManager.env"


    if [ ! -f "$env_file" ]; then
    log_error "Error: Environment file '$env_file' not found."
    exit 1
    fi

    # Load the environment file (default or custom if provided)
    #set_env "$env_file" 
  

    # Validate that all required environment variables are set
    # Both validate_env_vars and display_env_vars will need EXPECTED_ENV_VARS array.
    validate_env_vars "$EXPECTED_ENV_VARS"

    # Display the loaded environment variables
    show_env

    log_info "################################      TERMINATING: Enviornment Manager Script     ################################"
    log_info "#####################################################################################################################"

}

 
# Main Execution: Only execute if script is sourced. 
# This script  must be called from another script or from your interactive
# shell session with source
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    main "$@"
else
    log_error "This script must be sourced, not executed directly."
fi
