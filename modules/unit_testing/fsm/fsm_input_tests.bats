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
 
    
    script_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    source "$script_dir/fsm_git_handler.sh"
    export json_object="$(pwd)/truths_fsm_handler.json"
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
 



# # --- Environment Tests ---
# @test "JSON object contains expected fields" {
  
# echo ""

# }

 
 


# @test "Transition from VALIDATE_COMMAND to EXECUTE_GIT on valid command" {
#     result="$(run_fsm "VALIDATE_COMMAND" "valid_command")"
#     [ "$result" -eq 0 ]  # Should transition successfully if command is valid
# }

# @test "Transition from EXECUTE_GIT to DONE on successful command execution" {
#     result="$(run_fsm "EXECUTE_GIT" "valid_command")"
#     [ "$result" -eq 0 ]  # Should transition to DONE state on successful execution
# }




# Exit codes:
# 0: successful completion of execution of program.
# 1: issue if execution fails 
# 2: if no parameters are not  provided 
# 3: If validation fails


# Test 3: INITI clone command (Valid Input)
@test "2. FSM -- run_fsm function -- state=DONE -- command=clone" {
    run run_fsm "DONE" "clone"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }

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




# Exit codes:
# 0: successful completion of execution of program.
# 1: issue if execution fails 
# 2: if no parameters are not  provided 
# 3: If command validation fails


# Write unit tests that will allow you to iterate through correct States, incorrect States, Correct commands,
# Incorrect commands.

 # Test 3: Error state
@test "3. FSM -- run_fsm function -- state=ERROR -- command=s" {
   run run_fsm "ERROR" "s"

 
    [[ -n "$status" ]] && [ "$status" -eq 1 ]
 
 }

# Test 2: Empty Command (Invalid Input)


@test "Fails on invalid state passed to run_fsm" {
  run run_fsm "INVALID_STATE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid transition"* ]]
}



# Exit codes:
# 0: successful completion of execution of program.
# 1: issue if execution fails 
# 2: if validation of git command fails
# 3: If validation of command fails


 

@test "Fails with missing command in VALIDATE_COMMAND (precondition)" {
  run run_fsm VALIDATE_COMMAND
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing command in state VALIDATE_COMMAND"* ]]
}

@test "Fails with missing command in EXECUTE_GIT (precondition)" {
  run run_fsm EXECUTE_GIT
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing command in state EXECUTE_GIT"* ]]
}

@test "Succeeds with no command in INIT (allowed)" {
  run run_fsm INIT
  # INIT → VALIDATE_COMMAND → fails due to missing command
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing command in state VALIDATE_COMMAND"* ]]
}

@test "Succeeds with no command in DONE (allowed terminal state)" {
  run run_fsm DONE
  [ "$status" -eq 0 ]
  [[ "$output" == *"FSM completed with state: DONE"* ]]
}

@test "Succeeds with no command in ERROR (allowed terminal state)" {
  run run_fsm ERROR
  [ "$status" -eq 1 ]
  [[ "$output" == *"FSM completed with state: ERROR"* ]]
}



@test "FSM completes successfully with valid command" {
  run run_fsm INIT "git status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FSM completed with state: DONE"* ]]
}

@test "FSM fails with missing command in VALIDATE_COMMAND state" {
  run run_fsm VALIDATE_COMMAND
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing command in state VALIDATE_COMMAND"* ]]
}
  
# # 6. Long Input
# @test "FSM fails with excessively long input" {
#     long_input=$(head -c 10000 < /dev/urandom | tr -dc 'a-zA-Z0-9')
#     run run_fsm "INIT" "$long_input"
#     echo "[DEBUG] Output: '$output'"
#     [ "$status" -eq 1 ]
#     [[ "$output" == *"Error: Invalid command"* ]]
# }