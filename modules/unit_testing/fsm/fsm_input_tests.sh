#!/usr/bin/env bats


# This test suite will be focused in on the run_fsm function output.
# More specifically testing the logic paths for different inputted parameters to the function
# and observing the results.


# This testing seems to be teaching me about exit/return codes.
# This test suite is confirming the functionality of the run_fsm function.
# By testing different combinations of the parameters of the function,
# we can tell what path is being executed in the function.




# --- Setup and Teardown ---
setup() {
 
    # Determine script directory
    script_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"

    # Source required scripts
     source "$script_dir/fsm_git_handler.sh"

    export json_object="$(pwd)/truths_fsm_handler.json"

    PATH="$BATS_TEST_DIR/mock_bin:$PATH"
    mkdir -p "$BATS_TEST_DIR/mock_bin"
    echo -e '#!/bin/bash\necho "Mock git command"; exit 0' > "$BATS_TEST_DIR/mock_bin/git"
    chmod +x "$BATS_TEST_DIR/mock_bin/git"
    }



 
 

# Define valid user inputs
valid_inputs=(
    "valid_user valid_password"
    "test@example.com"
    "2025-01-01"
    "command arg1 arg2"
    "25"
    "/home/user/file.txt"
)

# Define invalid user inputs
invalid_inputs=(
    "invalid_user wrong_password"
    "invalidemail.com"
    "01-01-2025"
    "invalid_command arg1"
    "-5"
    "/nonexistent/file.txt"
)



declare -A exit_codes
declare -A return_codes

# Define exit codes for different outcomes
# 0 - Success, 1 - Failure, 2 - Invalid Input, 3 - Error
exit_codes["valid_input"]=0
exit_codes["invalid_input"]=1
exit_codes["invalid_email"]=2
exit_codes["file_not_found"]=1
exit_codes["command_not_found"]=2

# Define return codes for specific functions (e.g., login, file processing)
return_codes["login_success"]=0
return_codes["login_failure"]=1
return_codes["invalid_date"]=2
return_codes["command_execution_success"]=0
return_codes["command_execution_failure"]=1
return_codes["file_open_success"]=0
return_codes["file_open_failure"]=1







# @test "1 function_OR_module | important variables | invariants being tested | expected behavior" {

#     echo "This is the format for tests"

# }

 
    
    @test "mock git command" {
    run git clone https://repo.git
    [ "$output" = "Mock git command" ]


    }



# # --- Environment Tests ---
# @test "JSON object contains expected fields" {
  
# echo ""

# }

 
 
# @test "Transition from INIT to VALIDATE_COMMAND" {
#     run run_fsm "INIT" "clone"
#     #This test needs to be re-done.
#     [[ -n "$status" ]] && [ "$status" -eq 1 ]

#  }

# @test "Transition from VALIDATE_COMMAND to EXECUTE_GIT on valid command" {
#     result="$(run_fsm "VALIDATE_COMMAND" "valid_command")"
#     [ "$result" -eq 0 ]  # Should transition successfully if command is valid
# }

# @test "Transition from EXECUTE_GIT to DONE on successful command execution" {
#     result="$(run_fsm "EXECUTE_GIT" "valid_command")"
#     [ "$result" -eq 0 ]  # Should transition to DONE state on successful execution
# }



# # Test 3: INITI clone command (Valid Input)
# @test "FSM run_fsm function,state=DONE command=clone" {
#     run run_fsm "DONE" "clone"
 
#     [[ -n "$status" ]] && [ "$status" -eq 0 ]

#  }

#  @test "execute_git_command simulates git command failure" {
#     # Mock the git command to simulate failure
#     run_cmd() {
#         return 1  # Simulate failure
#     }

#     # Test the function with a failed git command
#     result="$(execute_git_command "clone" "https://github.com/repo.git")"
    
#     # Ensure that the error handling (commented out) is triggered in some form
#     # You may want to check if an error message would be logged in a real function.
#     [ "$status" -eq 1 ]  # Should return an error status on failure
# }



#  # Test 3: Error state
# @test "FSM with state=ERROR command=s" {
#    run run_fsm "ERROR" "s"

 
#     [[ -n "$status" ]] && [ "$status" -eq 2 ]
 
#  }

# # Test 2: Empty Command (Invalid Input)
# @test "FSM state=INIT command=empty" {
#     run run_fsm "INIT" ""

#     [[ -n "$status" ]] && [ "$status" -eq 2 ]

#  }

 
# # 2. Null Input
# @test "FSM fails with, state=empty command=clone" {
#     run run_fsm "" "clone"

#     [[ -n "$status" ]] && [ "$status" -eq 1 ]
#  }

 
# # 2. Null Input
# @test "FSM fails with, state=empty command=empty" {
#     run run_fsm "" ""

#     [[ -n "$status" ]] && [ "$status" -eq 1 ]
#  }

# # 3. Invalid State
# @test "FSM fails with state=INVALID_STATE command=clone" {
#     run run_fsm "INVALID_STATE" "clone"
#      [[ -n "$status" ]] && [ "$status" -eq 3 ]
#  }

# # 4. Malformed Input
#   @test "FSM fails with malformed command" {
#       run run_fsm "INIT" "!@#\$%^&*"

#  [[ -n "$status" ]] && [ "$status" -eq 2 ]
#   }

  
# # 6. Long Input
# @test "FSM fails with excessively long input" {
#     long_input=$(head -c 10000 < /dev/urandom | tr -dc 'a-zA-Z0-9')
#     run run_fsm "INIT" "$long_input"
#     echo "[DEBUG] Output: '$output'"
#     [ "$status" -eq 1 ]
#     [[ "$output" == *"Error: Invalid command"* ]]
# }