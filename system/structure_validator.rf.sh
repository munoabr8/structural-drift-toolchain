#!/usr/bin/env bash
 
 #./system/structure_validator.rf.sh

# INVARIANTS — structure_validator.sh
# ===================================

# 1. Input Contract Invariant
# ---------------------------
# - The script must be invoked with a valid `structure.spec` file (unless using `--help`).
# - `structure.spec` must exist and be a readable file.
# - If `--help` or no argument is passed, usage is shown and exit is EXIT_OK (0).

# 2. Line Type Recognition Invariant
# ----------------------------------
# - Each line in the spec must be recognized as:
#   - `dir: path`
#   - `file: path`
#   - `link: src -> tgt`
#   - or a valid raw relative path (fallback)
# - Lines that are comments (`#`) or empty are skipped.

# 3. Path Resolution Invariant
# ----------------------------
# - All paths are evaluated relative to the current working directory at runtime.

# 4. Strict Existence Invariant
# -----------------------------
# - A `dir:` line must point to a directory (`-d`)
# - A `file:` line must point to a file (`-f`)
# - A `link:` line must:
#   - point to a symlink (`-L`)
#   - and match the expected target via `readlink`
# - Untyped fallback paths must exist as a file, directory, or symlink
# - If any validation fails, the script exits immediately.

 

# 6. Log Separation Invariant
# ---------------------------
# - If `--quiet` is passed, logging is suppressed.
# - Otherwise, human-readable, color-coded logs are printed.

# 7. Fail Fast Invariant
# ----------------------
# - The script stops at the first validation failure.
# - Only one failure is reported per run, immediately with correct exit code.


#What does this script achieve?
# --> Will read the specification file and validate the structure(format) of the
# --> specification file. I think what this scripts' current focus is to ensure that 
# --> the script(debuggingTools/structure-debug.sh generate_structure_spec .) that 
# --> generated the structure specification file did its job correctly.
#     --> So what I think this script( as well as variations ) percieved functionality is that
#     --> it will take a spec file and validate the structure against the following rules:
 
 

# Over-arching question: Is the capability of {validation of structure} == {enforcement of policy rules} 
#                       or is this something else? 
#                         --> The two capabilities are different. 

 
#                    Capabilities of the system under testing: 
                      # 1.) validation of structure
                      # 2.) enforcement of policy rules
# Will need to: identify what some edge cases may be,
#                    and clarify the distinction between 
#                    valiation of structure vs enforcement policy rules.
# I feel like validation of structure has to do with with the actual reading and writing
# of the system level elements?
# Enforcement of policy rules is the capability to notify of structural drift. These
# rules are set by the expectations that were put in place by the developer/user/agent(?)
# In essence, the set of expecations are invariants, variants, and volatile categories 
# that can be used to monitor for structural(maybe behavioral?) drift.



# Why is this important?
# --> This script appears to be acting as a kind of linter for the specification file.
#     --QUESTION: DOES ONLY THE SPECIFICATION FILE NEED TO BE RUN THROUGH A LINTER OR CAN 
#                 THE SNAPSHOT ALSO BE INCLUDED? 
# --> If the specficiation file causes an exit code other then 0
# --> then the next step(policy file reading & enforcement) cannot proceed. 
 

# How will it do this?
# --> The "linting behavior" will be accomplished by using modular functions.
# --> Reading the policy rule file should be delegated to another script. 



################################################################################
################################################################################
################################################################################

# What do I want? I want to maintain these invariants(as examples): 
# #- type: invariant
#   path: ^module/
#   condition: must_exist
#   action: error

# - type: invariant
#   path: ^system/
#   condition: must_exist
#   action: error

# - type: invariant
#   path: ^config/
#   condition: must_exist
#   action: error

# - type: invariant
#   path: ^config/policy.rules.yaml
#   condition: must_exist
#   action: error 

# That is saved in the file called policy.rules.yml file.
 
# what is likely to happen: false positives, false negatives.
# what should happen: clarity, alignment, action and intent become fused,with electricity so to speak.
#                     more practically, you should be able to start focusing on signal. 
#                     The notification is a signal.
#                         --> How would I build the notification?
#                                 -> Using a script?
#                          -> Capabilities Needed:
#                                 1.) Compare the cached data(spec and/or snapshots)
#                                 2.) Apply enforcement rules
#                                 3.) Propagate appropiate status code(this is the signal)                                 

################################################################################
################################################################################
################################################################################
################################################################################
                   

 set -euo pipefail

 #set -x

: "${EXIT_OK:=0}" "${EXIT_USAGE:=64}" "${EXIT_MISSING_SPEC:=2}" \
  "${EXIT_MISSING_PATH:=3}" "${EXIT_INVALID_SYMLINK:=4}" "${EXIT_VALIDATION_FAIL:=5}"

# source once if available
if [[ -z "${EXIT_CODES_LOADED:-}" ]] && [[ -f "system/exit-codes/exit_codes_validator.sh" ]]; then
  # adjust path if needed
  source system/exit-codes/exit_codes_validator.sh
fi

  
 

# Optional libraries; skip if absent
if [[ -d "${BASH_SOURCE[0]%/*}/../util" ]]; then
  # best effort; do not hard-fail if missing
  UTIL_DIR="${UTIL_DIR:-$(cd "${BASH_SOURCE[0]%/*}/../util" && pwd)}"
  SYSTEM_DIR="${SYSTEM_DIR:-$(cd "${BASH_SOURCE[0]%/*}/../system" && pwd)}"
  [[ -f "$UTIL_DIR/source_OR_fail.sh" ]] && source "$UTIL_DIR/source_OR_fail.sh" || true
  [[ -f "$UTIL_DIR/logger.sh" ]] && source "$UTIL_DIR/logger.sh" || true
  [[ -f "$UTIL_DIR/logger_wrapper.sh" ]] && source "$UTIL_DIR/logger_wrapper.sh" || true
  [[ -f "$SYSTEM_DIR/exit-codes/exit_codes_validator.sh" ]] && source "$SYSTEM_DIR/exit-codes/exit_codes_validator.sh" || true
fi
 

if [[ "${1:-}" == "--quiet" ]]; then
  export QUIET=true
  shift
fi

  
show_usage() {
  echo "/system/structure_validator.rf.sh [validate|enforce|help] [options] <structure.spec>"

  echo
  echo "Each line must be one of:"
  echo "  - A valid relative file or dir path (e.g. ./attn/context-status.sh)"
  echo "  - A line starting with: 'dir:', 'file:', or 'link:'"
  echo "    - dir: ./path"
  echo "    - file: ./path"
  echo "    - link: ./symlink -> ./target"
  echo
}

  

validate_line() {
  local raw="$1"
  local line

  # Trim leading/trailing whitespace
  # Extract the transformation of what will be fed into sed.
  line="$(echo "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  safe_log "INFO" "Validating line: '$line'" >&2

  #COMMENT_REGEX='^#.*$'
  #EMPTY_LINE_CHECK='-z "$line"'

  [[ "$line" =~ ^#.*$ || -z "$line" ]] && return $EXIT_OK

  if [[ "$line" == dir:* ]]; then
    local dir_path="${line#dir: }"
    safe_log "INFO" "Checking if directory exists: '$dir_path'" >&2
    if [ ! -d "$dir_path" ]; then
      safe_log "ERROR" "Missing directory: $dir_path" "" "$EXIT_MISSING_PATH"
      return $EXIT_MISSING_PATH
    fi
    safe_log "SUCCESS" "Directory OK: $dir_path"
    return $EXIT_OK
  fi

 
  if [[ "$line" == file:* ]]; then
    local file_path="${line#file: }"
    safe_log "INFO" "Checking if file exists: '$file_path'" >&2
    if [ ! -f "$file_path" ]; then
      safe_log "ERROR" "Missing file: $file_path" "" "$EXIT_MISSING_PATH"
      return $EXIT_MISSING_PATH
    fi
    safe_log "SUCCESS" "File OK: $file_path"
    return $EXIT_OK
  fi

  if [[ "$line" == link:* ]]; then
    local link_def="${line#link: }"
    local src tgt actual
    src=$(awk '{print $1}' <<< "$link_def")
    tgt=$(awk '{print $3}' <<< "$link_def")

    echo "🔗 Checking if symlink '$src' points to '$tgt'" >&2

    if [ ! -L "$src" ]; then
      safe_log "ERROR" "Missing symlink: $src" "" "$EXIT_INVALID_SYMLINK"
      return $EXIT_INVALID_SYMLINK
    fi

    actual="$(readlink "$src")"
    if [ "$actual" != "$tgt" ]; then
      safe_log "ERROR" "Symlink $src points to $actual, expected $tgt" "" "$EXIT_INVALID_SYMLINK"
      return $EXIT_INVALID_SYMLINK
    fi

    safe_log "SUCCESS" "Symlink OK: $src -> $tgt"
    return $EXIT_OK
  fi

 
  # Fallback: untyped path
  local trimmed_line="$line"
  echo "🪛 Fallback path: '$trimmed_line'" >&2
  if [ -f "$trimmed_line" ]; then
    safe_log "SUCCESS" "File OK: $trimmed_line" "" ""
  elif [ -d "$trimmed_line" ]; then
    safe_log "SUCCESS" "Directory OK: $trimmed_line"
  elif [ -L "$trimmed_line" ]; then
    safe_log "SUCCESS" "Symlink OK (untyped): $trimmed_line -> $(readlink "$trimmed_line")"
  else
    safe_log "ERROR" "Missing or unknown path: $trimmed_line" "" "$EXIT_MISSING_PATH"
    return $EXIT_MISSING_PATH
  fi

  return $EXIT_OK
}

validate_file_structure() {
  local spec_file="$1"
  local rc=$EXIT_OK

  while IFS= read -r line || [[ -n "$line" ]]; do
    validate_line "$line"
    rc=$?
    if [ "$rc" -ne "$EXIT_OK" ]; then
      break
    fi
  done < "$spec_file"

  if [ "$rc" -eq "$EXIT_OK" ]; then
safe_log "SUCCESS" "Structure validation passed." "" "0"

  fi

  return "$rc"
}

 
# Can refactor these two functions so that scripts can simply source
# ./util/core.sh and get the same functionality?
# I would need to access to the soucre_OR_fail function.
resolve_project_root() {
  local src="${BASH_SOURCE[0]}"
  #
  printf '%s\n' "$(cd "$(dirname "$src")/.." && pwd)" || return 1
}

setup_environment_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}" || return $?
  
  UTIL_DIR="${UTIL_DIR:-$PROJECT_ROOT/util}"

  SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
  export PROJECT_ROOT SYSTEM_DIR UTIL_DIR
}

source_utilities() {

resolve_project_root
setup_environment_paths

 
  if [[ ! -f "$UTIL_DIR/source_or_fail.sh" ]]; then
    echo "Missing required file: $UTIL_DIR/source_or_fail.sh"
    exit 1
  fi
  source "$UTIL_DIR/source_or_fail.sh"

  source_or_fail "$UTIL_DIR/logger.sh"
  source_or_fail "$UTIL_DIR/logger_wrapper.sh"

  source_or_fail "$SYSTEM_DIR/exit-codes/exit_codes_validator.sh"


 
 }



#––– Preconditions & checks (QUERY) –––––––––––––––––––––––––––––––––––––––––––––––––
check_file_exists() {
  local path="$1" label="$2" code="$3"
  [[ -f $path ]] || exit "$code"
}

#––– Core logic (QUERY) –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
validate_structure() {
  local spec="$1"
  validate_file_structure "$spec"
  return $?
}

enforce_policy() {
  local spec="$1" policy="$2"
  enforce_policy_rules "$spec" "$policy"
  return $?
}


# Usage: parse_CLI_args <state-name> -- "$@"
parse_CLI_args() {
  local -n S=$1; shift
  : "${EXIT_USAGE:=64}"

  # defaults
  S=(
    [MODE]=validate
    [SPEC]=
    [POLICY]=
    [QUIET]=false
    [VERBOSE]=false
    [ERROR]=
  )

 
  while (($#)); do
    case "$1" in
      validate|enforce|help)
        S[MODE]="$1"
        ;;
      --spec)
        [[ -n "${2:-}" ]] || { S[ERROR]="--spec needs a value"; return $EXIT_USAGE; }
        S[SPEC]="$2"; shift
        ;;
      -p|--policy)
        [[ -n "${2:-}" ]] || { S[ERROR]="--policy needs a value"; return $EXIT_USAGE; }
        S[POLICY]="$2"; shift
        ;;
      -q|--quiet)
        S[QUIET]=true
        ;;
      -v|--verbose)
        S[VERBOSE]=true
        ;;
      -h|--help)
        S[MODE]=help
        ;;
      --)
        shift; break
        ;;
      -*)
        S[ERROR]="Unknown option: $1"; return $EXIT_USAGE
        ;;
      *)
        # first non-option = SPEC if not set
        if [[ -z "${S[SPEC]}" ]]; then
          S[SPEC]="$1"
        else
          S[ERROR]="Unexpected argument: $1"; return $EXIT_USAGE
        fi
        ;;
    esac
    shift
  done

  # enforce requires policy
  if [[ "${S[MODE]}" == "enforce" && -z "${S[POLICY]}" ]]; then
    S[ERROR]="enforce requires --policy <file>"; return $EXIT_USAGE
  fi

  return 0
}


enter_spec_directory() {
  local spec_file=$1
  local spec_path spec_dir

  # resolve absolute path
  spec_path=$(realpath "$spec_file" 2>/dev/null || echo "$spec_file")

  # cd into its directory
  spec_dir=$(dirname "$spec_path")
  safe_log "INFO" "Changing into spec directory: $spec_dir" "" "$EXIT_OK"
  pushd "$spec_dir" > /dev/null
}

exit_spec_directory() {
  popd > /dev/null
}

 

# locate_spec_file() {
#   local requested="$1"
#   # 1) if it exists as given, use it
#   [[ -f $requested ]] && { echo "$requested"; return; }

#   # 2) otherwise, start from this script’s parent and walk up
#   local dir
#   dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)
#   while [[ $dir != / ]]; do
#     if [[ -f $dir/$requested ]]; then
#       echo "$dir/$requested"
#       return
#     fi
#     dir=$(dirname "$dir")
#   done

#   # 3) not found
#   return 1
# }

# locate_spec_file() {
#   local requested="${1:-structure.spec}"
#   local anchor; anchor=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
#   local dir="$anchor"
#   while :; do
#     [[ -f "$dir/$requested" ]] && { printf '%s\n' "$dir/$requested"; return 0; }
#     [[ "$dir" == "/" ]] && break
#     dir=$(dirname "$dir")
#   done
#   return 1
# }

# locate_spec_file() {
#   local in="$1"
#   if [[ -f "$in" ]]; then
#     printf '%s\n' "$(cd "$(dirname "$in")" && pwd)/$(basename "$in")"
#     return 0
#   fi
#   # common fallbacks
#   if [[ -f "./$in" ]]; then
#     printf '%s\n' "$(pwd)/$in"; return 0
#   fi
#   if [[ -f "structure.spec" ]]; then
#     printf '%s\n' "$(pwd)/structure.spec"; return 0
#   fi
#   return 1
# }


locate_spec_file() {
  local requested="${1:-structure.spec}"
  # 1) explicit path
  if [[ -f "$requested" ]]; then
    printf '%s\n' "$(cd "$(dirname "$requested")" && pwd)/$(basename "$requested")"; return 0
  fi
  # 2) search paths (colon-separated)
  local pth IFS=:
  for pth in ${SPEC_SEARCH_PATHS:-.}; do
    [[ -z "$pth" ]] && continue
    if [[ -f "$pth/$requested" ]]; then
      printf '%s\n' "$(cd "$pth" && pwd)/$requested"; return 0
    fi
  done
  # 3) walk up from script’s parent (repo root-friendly)
  local dir; dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
  while :; do
    if [[ -f "$dir/$requested" ]]; then printf '%s\n' "$dir/$requested"; return 0; fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done
  return 1
}

  
 # Will need to ensure that the policy file exists. 
 # The policy.rule file is what I am validating against.

 # Main function needs to be refactored so that the spec_file variable is not conflated
 # with options. 


 # TODO: break script so that it can read the specification file
 # TODO: break up script so that it can read the policy file.
 # TODO: make new script to enforce policy patterns. 

 # How will this script typically be called?(CLI vs sourced in another script)
#

# You can safely drop that -- marker for 99% of use‑cases—your parser will simply treat the very first token after CLI_STATE as the subcommand (e.g. “validate”) and then pick up the spec (and policy) filenames in turn. The only time you’d really need the -- is if you wanted to pass a filename that begins with a dash (e.g. -foo.spec), since otherwise any -… token will be treated as an option.

# So, in short:

#     Removing -- will not break your normal flows (validate structure.spec or enforce -p policy.rules structure.spec).

#     You’ll lose only the ability to disambiguate “real” positional args that themselves start with -.

# If you never have spec or policy names that begin with hyphens, feel free to call:
#parse_CLI_args CLI_STATE "$@"
# main() {

#   source_utilities
#   echo "----->"

#   declare -A CLI_STATE
#   parse_CLI_args CLI_STATE "$@"

#   # 2️⃣ Pull out raw inputs
#   local mode="${CLI_STATE[MODE]}"
#   local spec_input  spec_file
#   spec_input="${CLI_STATE[SPEC]}"


#   if [[ "$mode" == help ]]; then
#     show_usage
#     exit $EXIT_OK
#   fi

#   # 4️⃣ Ensure the user actually gave a spec
#   if [[ -z "$spec_input" ]]; then
#     show_usage
#     exit $EXIT_MISSING_SPEC
#   fi



# spec_file="${spec_input:-structure.spec}"
# spec_file="$(locate_spec_file "$spec_file" || true)"
# [[ -z "$spec_file" ]] && { echo "missing structure.spec" >&2; exit "$EXIT_MISSING_SPEC"; }


#  if ! spec_file="$(locate_spec_file "$spec_input")"; then
#     safe_log "ERROR" "Spec file not found: $spec_input" "" "$EXIT_MISSING_SPEC"
#     exit $EXIT_MISSING_SPEC
#   fi
 
 
#   safe_log "INFO" "Reading structure spec: $spec_file" "" "$EXIT_OK"

#   enter_spec_directory "$spec_file"
#   validate_file_structure "$(basename "$spec_file")"
#   rc=$?
#   exit_spec_directory
#   exit "$rc"


# }

main() {
  set -euo pipefail
  : "${EXIT_OK:=0}" "${EXIT_USAGE:=64}" "${EXIT_MISSING_SPEC:=2}"

  # 0) Help must win immediately
  case "${1-}" in
    help|-h|--help) show_usage; exit "$EXIT_OK" ;;
  esac

  # 1) Parse args (your function or inline)
  declare -A CLI
  if ! parse_CLI_args CLI "$@"; then
    [[ -n "${CLI[ERROR]}" ]] && echo "${CLI[ERROR]}" >&2
    show_usage; exit "$EXIT_USAGE"
  fi

  # 2) Enforce spec only for non-help modes
  [[ -n "${CLI[SPEC]:-}" ]] || { echo "Spec not provided" >&2; exit "$EXIT_MISSING_SPEC"; }

  # 3) Locate and validate
  local spec_file
  if ! spec_file="$(locate_spec_file "${CLI[SPEC]}")"; then
    echo "ERROR: Spec file not found: ${CLI[SPEC]}" >&2
    exit "$EXIT_MISSING_SPEC"
  fi

  pushd "$(dirname "$spec_file")" >/dev/null
  local rc=0
  validate_file_structure "$(basename "$spec_file")" || rc=$?
  popd >/dev/null
  exit "$rc"
}

 



#Entrypoint
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi


########## Things to consider ####################
 

# I need to seperate between queries and commands.
 
########## TODO #############

#### ACTION ########
# Functions still need to be refactored. 

##### DECISION #####
# What should the name of the functions be called that will enable this script to 
# read,parse, and enforce policy rule files.


#### INCREASE OF GRANULARITY ######
# Scenerios
  # 1.) Defining what is in the policy files(intent and syntax)
  # 2.) Assuming that there is a policy file that exists, how will it be read?
  # 3.) Assuming that a policy file exists and has been read, how will it be parsed?
  # 4.) Assuming that a policy file exists,has been read, parsed, how will the policy be enforced?



#1) Defining policy.rules intent
  # Given that a policy rule file exists,
  # when a system is being monitored for structural drift,
  # then a policy rule contains the logic that governs what patterns are being observed 
  # and what actions are being executed.

 #1.a) Given that system is being monitored for structural drift,
 #     when policy.rule file is written or generated
 #     then the system must be checked against the policy.


 



 














 
