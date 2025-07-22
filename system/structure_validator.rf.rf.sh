#!/usr/bin/env bash
 
 #./system/structure_validator.rf.sh
             

 set -euo pipefail

 #set -x

  

QUIET=false
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=true
  shift
fi

  
show_usage() {
  echo "/system/structure_validator.rf.rf.sh [validate|enforce|help] [options] <structure.spec>"

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

 

resolve_project_root() {
  local src="${BASH_SOURCE[0]}"
  #
  printf '%s\n' "$(cd "$(dirname "$src")/.." && pwd)" || return 1
}

setup_environment_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root)}" || return $?
  SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
  export PROJECT_ROOT SYSTEM_DIR
}

source_utilities() {

resolve_project_root
setup_environment_paths

  local system_dir="${SYSTEM_DIR:-./system}"

  if [[ ! -f "$system_dir/source_OR_fail.sh" ]]; then
    echo "Missing required file: $system_dir/source_OR_fail.sh"
    exit 1
  fi
  source "$system_dir/source_OR_fail.sh"

  source_or_fail "$system_dir/logger.sh"
  source_or_fail "$system_dir/logger_wrapper.sh"

  source_or_fail "$system_dir/exit-codes/exit_codes_validator.sh"


 
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


# Usage: parse_CLI_args <state‑array‑name> <all the CLI args>
parse_CLI_args() {
  local -n S=$1  # nameref to your state array
  shift
  
  # defaults
  S=(
    [MODE]=help
    [SPEC]=
    [POLICY]=
    [QUIET]=false
    [VERBOSE]=false
  )
  
  # walk the rest of args
  while (( $# )); do
    case "$1" in
      validate|enforce|help)
        S[MODE]=$1
        ;;
      -p|--policy)
        S[POLICY]=$2
        shift
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
        shift
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit $EXIT_USAGE
        ;;
      *)
        # first non‑option is the spec
        if [[ -z ${S[SPEC]} ]]; then
          S[SPEC]=$1
        else
          echo "Unexpected argument: $1" >&2
          exit $EXIT_USAGE
        fi
        ;;
    esac
    shift
  done
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

 

locate_spec_file() {
  local requested="$1"
  # 1) if it exists as given, use it
  [[ -f $requested ]] && { echo "$requested"; return; }

  # 2) otherwise, start from this script’s parent and walk up
  local dir
  dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)
  while [[ $dir != / ]]; do
    if [[ -f $dir/$requested ]]; then
      echo "$dir/$requested"
      return
    fi
    dir=$(dirname "$dir")
  done

  # 3) not found
  return 1
}

  
  main() {

  source_utilities


  declare -A CLI_STATE
  parse_CLI_args CLI_STATE "$@"

   local mode="${CLI_STATE[MODE]}"
  local spec_input  spec_file
  spec_input="${CLI_STATE[SPEC]}"


  if [[ "$mode" == help ]]; then
    show_usage
    exit $EXIT_OK
  fi

   if [[ -z "$spec_input" ]]; then
    show_usage
    exit $EXIT_MISSING_SPEC
  fi



 if ! spec_file="$(locate_spec_file "$spec_input")"; then
    safe_log "ERROR" "Spec file not found: $spec_input" "" "$EXIT_MISSING_SPEC"
    exit $EXIT_MISSING_SPEC
  fi
 
 
  safe_log "INFO" "Reading structure spec: $spec_file" "" "$EXIT_OK"

  enter_spec_directory "$spec_file"
  validate_file_structure "$(basename "$spec_file")"
  exit_spec_directory

  exit $?
}


#Entrypoint
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi


 
 



 














 
