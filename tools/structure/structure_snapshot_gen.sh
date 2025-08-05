#!/usr/bin/env bash

# ./tools/structure/structure_snapshot_gen.sh


# Please generate expectations/invariants/constraints.

 
#





 set -euo pipefail
 
 #set -x  # Trace every command

# Need to reduce granularity of output.
# Refactor in order to seperate query and commands
# Refactor utilities to source_utilities function.
# Begin unit testing.


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

 
source "./util/source_or_fail.sh"


source_or_fail "./util/logger.sh"
source_or_fail "./util/logger_wrapper.sh"


type log_json | grep -q 'function' || {
  echo "❌ log function not defined. Exiting." >&2
  exit 99
}

safe_log "INFO" "Ending session, staged for probe_structure refactor. Will need to move the function generate_structure_snapshot to system/tools/observe_module/probe_structure.sh. \n Also will need to be split up." "" "0"
 

 # alphaWave_refactor(){


 # }
 

generate_structure_snapshot() {
  safe_log "INFO" "Entered structure snapshot function" "" "0"

  local root="${1:-}"

  local file_list=""

  if [[ -z "$root" || ! -d "$root" ]]; then
    echo "❌ Invalid or missing root: '$root'" >&2
    return 1
  fi

  # Build ignore filter if .structure.ignore exists
  local ignore_file="$root/.structure.ignore"
  local grep_ignore_dirs=""
  local grep_ignore_files=""
  # if [[ -f "$ignore_file" ]]; then
  #   # Remove empty/comment lines and build grep patterns
  #   # For files, use -vFf to exclude exact matches; for directories, append '/'.
  #   grep_ignore_files="grep -vFf \"$ignore_file\""
  #   # To ignore directories entirely (optional), you could prepare a separate pattern:
  #   # grep_ignore_dirs="grep -vFf \"$ignore_file\""
  # fi

  if [[ -f "$ignore_file" ]]; then
  file_list=$(printf '%s\n' "$file_list" | grep -vFf "$ignore_file" || true)
fi

  echo "# Auto-generated structure.spec"
  echo ""

  echo " Scanning directories..." >&2
  # List directories, optionally filtering out ignored ones
  if ! find "$root" -type d ! -name 'structure.spec' | grep -vE '\.git' \
         | sort | sed 's|^|dir: |' | sed 's|$|/|' ; then
    echo "❌ Failed during directory scan" >&2
    return 1
  fi



  echo " Scanning files in: $root" >&2
  # List files, filter ignore patterns, and format
  if ! find "$root" -type f \
        ! -name 'structure.spec' \
        ! -name '.structure.snapshot' \
        ! -name '*.log' \
        ! -name '*.tmp' \
        ! -name '.DS_Store' \
        ! -path "$root/tmp/*" \
        ! -path "$root/.git/*" \
        2>/dev/null \
        | { if [[ -n "$grep_ignore_files" ]]; then eval "$grep_ignore_files"; else cat; fi; } \
        | sort | sed 's|^|file: |' ; then
    echo "❌ Failed during file scan for module: $root" >&2
    return 1
  fi

  echo " Scanning symlinks..." >&2
  local tmp_symlink_flag
  tmp_symlink_flag="$(mktemp)"
  echo "0" > "$tmp_symlink_flag"

  while IFS= read -r link; do
    if target="$(readlink "$link" 2>/dev/null)"; then
      echo "link: $link -> $target"
    else
      echo "❌ readlink failed for: $link" >&2
      echo "1" > "$tmp_symlink_flag"
    fi
  done < <(find "$root" -type l ! -name 'structure.spec' | grep -vE '\.git' | sort)

  if [[ "$(cat "$tmp_symlink_flag")" == "1" ]]; then
    echo "❌ Failed during symlink scan" >&2
    rm -f "$tmp_symlink_flag"
    return 1
  else
    echo "✅ Symlink scan completed successfully" >&2
    rm -f "$tmp_symlink_flag"
  fi

  return 0
}

main() {
 
 
  generate_structure_snapshot .
}




  if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    # Only run main if not sourced
    main "$@"
  fi

