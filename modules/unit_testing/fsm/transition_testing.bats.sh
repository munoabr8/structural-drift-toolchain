#!/usr/bin/env bats




setup() {
 
    
    script_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    source "$script_dir/fsm_git_handler.sh"
    export json_object="$(pwd)/truths_fsm_handler.json"
    }


# Test 3: INITI clone command (Valid Input)
@test "2. FSM -- transition function -- currentState -- EXPECTATION" {
    run transition "INIT"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }
 
 # Test 3: INITI clone command (Valid Input)
@test "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- " {
    run transition "INIT"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }

# Test 3: INITI clone command (Valid Input)
@test "2. FSM -- transition function -- currentState=INIT -- PASS" {
    run transition "INIT"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }


 @test "2. FSM -- transition function -- currentState=ERROR -- PASS" {
    run transition "ERROR"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }


 @test "2. FSM -- transition function -- currentState=empty string -- FAIL" {
    run transition ""
 
    [[ -n "$status" ]] && [ "$status" -eq 1 ]

 }


  @test "2. FSM -- transition function -- currentState=DONE -- PASS" {
    run transition "DONE"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }



  @test "2. FSM -- transition function -- currentState=INVALID -- FAIL" {
    run transition "INVALID"
 
    [[ -n "$status" ]] && [ "$status" -eq 1 ]

 }
@test "2. FSM -- transition function -- currentState=EXECUTE_GIT -- PASS" {
    run transition "EXECUTE_GIT"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }



@test "2. FSM -- transition function -- currentState=VALIDATE_COMMAND -- PASS" {
    run transition "VALIDATE_COMMAND"
 
    [[ -n "$status" ]] && [ "$status" -eq 0 ]

 }
 

