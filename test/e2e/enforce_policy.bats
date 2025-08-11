#!/usr/bin/env bats

# ./tools/enforce_policy.sh
 
sandbox_script=""

setup() {
 

  PROJECT_ROOT="$(git rev-parse --show-toplevel)"

  
  source "$PROJECT_ROOT/lib/env_init.sh"
  env_init --path --quiet
  env_assert

  setup_sandbox

  source_utilities
 
  mkdir -p "$BATS_TEST_TMPDIR/logs"
  touch "$BATS_TEST_TMPDIR/logs/logfile.log"
  cd "$BATS_TEST_TMPDIR"
 
   declare -ga SNAPSHOT
  SNAPSHOT=( "modules" "system" "foo/bar" "config/policy.rules.yaml" )
  
  
  }

  setup_sandbox(){


  local original_script_path="$TOOLS_DIR/enforce_policy.sh"


sandbox_dir="$BATS_TEST_TMPDIR/sandbox"
  mkdir -p "$sandbox_dir"


  readonly sandbox_script="$sandbox_dir/enforce_policy.sh"


 cp "$original_script_path" "$sandbox_script" || {
    echo "❌ Failed to copy main.sh from: $original_script_path"
    exit 1
  }
 
  [[ -f "$sandbox_script" ]] || {
    echo "Script under test not found: $sandbox_script"

        echo "$PWD"

    exit 1
  }

 
}



source_utilities(){

  if [[ ! -f "$UTIL_DIR/source_or_fail.sh" ]]; then
    echo "Missing required file: source_or_fail.sh"
    exit 1
  fi

  source "$UTIL_DIR/source_or_fail.sh"

  source_or_fail "$UTIL_DIR/logger.sh"
  source_or_fail "$UTIL_DIR/logger_wrapper.sh"

 
 

 }
 

 


@test "sandbox_script is available & evaluate_condition is defined" {
  [ -n "$sandbox_script" ]
  type -t evaluate_condition >/dev/null
}

 

  
 @test "env initialized" {
  [[ -n "$PROJECT_ROOT" && -d "$BIN_DIR" ]] || skip "env_init not sourced"
}


 

@test "Check if sandbox_script is really available" {
  echo "SCRIPT: $sandbox_script"
  [ -n "$sandbox_script" ]  # This will fail if it's unset
}


# @test "dispatch_rule: violation path returns 0 (still counted later)" {

#     ERRORS=()
#   WARNINGS=()
#   SNAPSHOT=("modules")
#   POLICY_FILE="/dev/null"   # so yq doesn't blow up when execute() runs


#   # Stub the pieces dispatch_rule calls
#   read_rule_fields() { RULE_TYPE=invariant; RULE_PATH="^modules(/|$)"; RULE_CONDITION="must_exist"; RULE_ACTION=error; }
#   evaluate_condition() { return 1; }   # violation
#   apply_action() { :; }                # no-op

#   run dispatch_rule 0
#   [ "$status" -eq 0 ]
# }



# @test "dispatch_rule: unknown/internal condition returns 1" {


#       ERRORS=()
#   WARNINGS=()
#   SNAPSHOT=("modules")
#   POLICY_FILE="/dev/null"   # so yq doesn't blow up when execute() runs


#   read_rule_fields() { RULE_TYPE=invariant; RULE_PATH="^modules(/|$)"; RULE_CONDITION="nope_condition"; RULE_ACTION=error; }
#   evaluate_condition() { return 2; }   # unknown
#   apply_action() { :; }

#   run dispatch_rule 0
#   [ "$status" -eq 1 ]
# }


# @test "must_exist satisfied" {
#   run evaluate_rule '{"path":"modules","condition":"must_exist"}' modules
#   [ "$status" -eq 0 ]
# }


 
 
 

# # ------------------------------------------
# # must_exist — satisfied
# # ------------------------------------------

# @test "must_exist → rc=0 when pattern matches at least one path" {
#   RULE_CONDITION="must_exist"
#   RULE_PATH="^modules$"

#   run evaluate_condition
#   [ "$status" -eq 0 ]
# }

# # @test "must_exist (regex prefix) → rc=0" {
# #   RULE_CONDITION="must_exist"
# #   RULE_PATH="^foo/"

# #   run evaluate_condition
# #   [ "$status" -eq 0 ]
# # }

# @test "evaluate_condition uses global SNAPSHOT" {
#   declare -ag SNAPSHOT=("foo" "foo/bar" "zzz")
#   RULE_CONDITION="must_exist"
#   RULE_PATH="^foo(/|$)"

#   evaluate_condition
#   status=$?
#   [ "$status" -eq 0 ]
# }

# @test "must_exist (regex prefix) → rc=0" {
#   run rule_status_pure must_exist '^foo(/|$)' foo foo/bar other
#   [ "$status" -eq 0 ]
# }

# @test "must_exist (no match) → rc=1" {
#   run rule_status_pure must_exist '^foo(/|$)' bar baz/qux
#   [ "$status" -eq 1 ]
# }




# # ------------------------------------------
# # must_exist — violation
# # ------------------------------------------

# @test "must_exist → rc=1 when pattern doesn't match" {
#   RULE_CONDITION="must_exist"
#   RULE_PATH="^does-not-exist"

#   run evaluate_condition
#   [ "$status" -eq 1 ]
# }

# @test "must_exist with empty SNAPSHOT → rc=1" {
#   RULE_CONDITION="must_exist"
#   RULE_PATH="^modules$"

#   SNAPSHOT=()   # override
#   run evaluate_condition
#   [ "$status" -eq 1 ]
# }



# # ------------------------------------------
# # ignore / allowed — always satisfied
# # ------------------------------------------

# @test "ignore → rc=0 regardless of SNAPSHOT" {
#   RULE_CONDITION="ignore"
#   RULE_PATH="anything"

#   run evaluate_condition
#   [ "$status" -eq 0 ]
# }

# @test "allowed → rc=0 regardless of SNAPSHOT" {
#   RULE_CONDITION="allowed"
#   RULE_PATH="^missing$"

#   SNAPSHOT=()
#   run evaluate_condition
#   [ "$status" -eq 0 ]
# }


# # ------------------------------------------
# # unknown condition
# # ------------------------------------------

# @test "unknown condition → rc=2" {
#   RULE_CONDITION="wtf_is_this"
#   RULE_PATH="^modules$"

#   run evaluate_condition
#   [ "$status" -eq 2 ]
# }


# # ------------------------------------------
# # regex edge case
# # ------------------------------------------

# @test "must_exist handles regex metacharacters in RULE_PATH" {
#   RULE_CONDITION="must_exist"
#   # Ensure something with a dot (.) works as regex (dot = any). Your grep -E allows this.
#   RULE_PATH="config/policy\.rules\.yaml"

#   run evaluate_condition
#   [ "$status" -eq 0 ]
# }








