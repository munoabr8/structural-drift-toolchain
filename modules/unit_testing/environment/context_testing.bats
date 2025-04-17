#!/usr/bin/env bats

# ====================================
# BATS Test Suite for Core Functions
# ====================================

# --- Setup and Teardown ---
setup() {
 
   
    # Determine script directory
    script_dir=$(realpath ../../)
  truth_dir=$(realpath ../../"TRUTH_HOME")

 
 
  }

 

# --- Environment Tests ---
@test "Required scripts are found" {
 
    [ -d "$script_dir" ]

    [ -x "$script_dir/prototype_manager2.sh" ]
    [ -x "$script_dir/fsm_git_handler.sh" ]
    [ -x "$script_dir/envManager.sh" ]

}


#--- Checking that truth files required are present ---
@test "Required truth files are found" {
 
    [ -d "$truth_dir" ]

 
    [ -f "$truth_dir/prototypeManager.env" ]

 
    [ -f "$truth_dir/truths_fsm_handler.json" ]

}




 
# # --- Environment Tests ---
@test "Environment variables are loaded" {
    [ -n "$script_dir/$GIT_REPO_DIR" ]
    [ -n "$script_dir/$UTILITY_DIR" ]
    [ -x "$BATS_TEST_FILENAME" ]
 
}


 
 
 
 

