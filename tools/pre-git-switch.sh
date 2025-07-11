#!/usr/bin/env bash
# tools/pre-git-switch.sh
#
# Usage:
#   ./tools/pre-git-switch.sh [--help|-h]
#
# Description:
#   This script creates a snapshot (compressed archive) of all untracked and modified files
#   before switching Git branches. The snapshot is stored in `.git/dev_snapshots/` with a timestamp,
#   and a corresponding JSON log entry is appended to `snapshot_log.json`.
#   This allows for quick recovery of unsaved changes after branch switches.
#
# Environment Variables:
#   SYSTEM_DIR (optional) – path to the directory containing source_OR_fail.sh and logger scripts.
#   Default is `../system`.


# Expectations:
# - This script is run *before* switching branches.
# - The working directory is a valid Git repository.
# - The user has untracked or modified files they want to preserve temporarily.
# - SYSTEM_DIR contains required logger and helper scripts (can be overridden).


# Invariants:
# - Required helper scripts must exist and be loadable.
# - Snapshot file must not overwrite existing files (timestamp-based uniqueness).
# - If no changes are found, script exits without error.
# - If snapshot creation fails, it must log the error and exit with code 77.

 show_help() {
  cat <<EOF
Usage: ./tools/pre-git-switch.sh [--help|-h]

This script safeguards your uncommitted and untracked changes by
creating a snapshot before switching Git branches. It stores the
snapshot as a compressed archive and logs the event in JSON.

Snapshot Location:
  .git/dev_snapshots/pre_switch_<timestamp>.tar.gz

Log File:
  .git/dev_snapshots/snapshot_log.json

Environment:
  SYSTEM_DIR (optional) – directory containing required system scripts.
  Default: ../system

Options:
  -h, --help    Show this help message and exit.

 

Expectations:
  • Run this before switching Git branches.
  • Git repo has changes not yet committed or tracked.
  • SYSTEM_DIR points to working logging helpers.

Invariants:
  • Snapshot filename must be unique (timestamp-based).
  • Helper scripts must exist and load successfully.
  • Log must record each snapshot attempt (success or failure).
  • If no changes exist, the script exits gracefully.

Feedback:
  • A tar.gz archive is created in .git/dev_snapshots/
  • A structured JSON log entry is written with the timestamp and file path.
  • Colored terminal logging provides real-time status.

Options:
  -h, --help    Show this help message and exit.

EOF
}

 
load_dependencies() {



  local system_dir="${SYSTEM_DIR:-../system}"

  if [[ ! -f "$system_dir/source_OR_fail.sh" ]]; then
    echo "❌ Missing required file: $system_dir/source_OR_fail.sh"
    exit 1
  fi
  source "$system_dir/source_OR_fail.sh"

  source_or_fail "$system_dir/logger.sh"
  source_or_fail "$system_dir/logger_wrapper.sh"


 
 }


 pre_git_switch() {

  
 
  local repo_root
repo_root=$(git rev-parse --show-toplevel) || {
  safe_log "ERROR" "Not inside a Git repository" "not_git_repo" 76
  exit 76
}
local snapshot_dir="$repo_root/.git/dev_snapshots"

# Invariant: snapshot_dir must physically exist before writing any snapshot-related files.

if [[ ! -d "$snapshot_dir" ]]; then
  safe_log "INFO" "Creating snapshot directory" "$snapshot_dir"
  mkdir -p "$snapshot_dir"
fi


if [[ -d "$snapshot_dir" ]]; then
  safe_log "INFO" "Snapshot directory location $(realpath "$snapshot_dir")"
else
  # Is this next line not correct? There is no missing_snapshot_dir every declared.
  safe_log "ERROR" "Snapshot directory not found for realpath" "missing_snapshot_dir"
fi


  local absolute_snapshot_dir
  absolute_snapshot_dir=$(realpath "$snapshot_dir" 2>/dev/null || echo "<unknown>")

  local timestamp snapshot_file log_file
  timestamp=$(date +"%Y%m%d_%H%M%S")
  snapshot_file="$snapshot_dir/pre_switch_$timestamp.tar.gz"
  log_file="$snapshot_dir/snapshot_log.json"

  safe_log "INFO" "Creating pre-branch-switch snapshot $snapshot_file"
  safe_log "INFO" "Snapshot directory location $absolute_snapshot_dir"



[[ -d "$snapshot_dir" ]] || {
  safe_log "ERROR" "Snapshot directory does not exist before writing file list" "$snapshot_dir" 76
  exit 76
}
  git ls-files -o -m --exclude-standard > "$snapshot_dir/tmp_file_list.txt"

  if [[ ! -s "$snapshot_dir/tmp_file_list.txt" ]]; then
    safe_log "INFO" "No changes detected, skipping snapshot."
    return 0
  fi

  if tar -czf "$snapshot_file" -T "$snapshot_dir/tmp_file_list.txt"; then
    safe_log "INFO" "Snapshot created $snapshot_file"
    printf '{"timestamp":"%s","snapshot":"%s"}\n' "$timestamp" "$snapshot_file" >> "$log_file"
    safe_log "INFO" "Snapshot logged in $log_file"
  else
    safe_log "ERROR" "Snapshot creation failed" "tar_error" 77
    return 77
  fi

  rm "$snapshot_dir/tmp_file_list.txt"
}

main() {


#   echo "DEBUG: Entered main" >&2
# echo "DEBUG: SYSTEM_DIR=$SYSTEM_DIR" >&2
# type -t log_error >&2 || echo "DEBUG: log_error not found" >&2

# ========================
# 🚦 Granularity Control
# ========================
REDUCED_GRANULARITY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|--compact)
      REDUCED_GRANULARITY=true
      shift
      ;;
    *) break ;;  # stop on first non-option
  esac
done

if [[ "$REDUCED_GRANULARITY" == true ]]; then
  echo "🔇 Logging granularity reduced (--quiet mode enabled)" >&2
fi



  local arg="${1:-}"
  case "$arg" in
    -h|--help)
      show_help
      exit 0
      ;;
    "")
      load_dependencies
      pre_git_switch
      ;;
    *)
      echo "❌ Unknown option: $arg"
      show_help
      exit 1
      ;;
  esac
}

# Only run if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
