#!/usr/bin/env bash

# ./tools/structure/structure_snapshot_gen.sh


# Please generate expectations/invariants/constraints.

# Will need to refactor the sourcing of utilities.

#





 set -euo pipefail
#HISTTIMEFORMAT="${HISTTIMEFORMAT:-}"

 #set -x  # Trace every command

# Need to reduce granularity of output.
# Refactor in order to seperate query and commands
# Refactor utilities to source_utilities function.
# Begin unit testing.


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

 
source "$SCRIPT_DIR/../../system/source_or_fail.sh"


source_or_fail "$SCRIPT_DIR/../../system/logger.sh"
source_or_fail "$SCRIPT_DIR/../../system/logger_wrapper.sh"


type log_json | grep -q 'function' || {
  echo "❌ log function not defined. Exiting." >&2
  exit 99
}

safe_log "INFO" "Ending session, staged for probe_structure refactor. Will need to move the function generate_structure_spec to system/tools/observe_module/probe_structure.sh. \n Also will need to be split up." "" "0"
 
 
generate_structure_spec() {
safe_log "INFO" "Entered structure snap function" "" "0"


  local root="${1:-}"

  echo "🔍 generate_structure_spec ARGS: $root" >&2

  if [[ -z "$root" || ! -d "$root" ]]; then
    echo "❌ Invalid or missing root: '$root'" >&2
    return 1
  fi

  if [[ ! -r "$root" ]]; then
    echo "❌ Cannot read module directory: $root" >&2
    return 1
  fi

  echo "# Auto-generated structure.spec"
  echo ""
  echo "🧪 Running structure scan in: $root" >&2

  echo "📁 Scanning directories..." >&2
  # if ! find "$root" -type d ! -name 'structure.spec' | grep -vE '\.git' | sort | sed 's|^|dir: |' | sed 's|$$|/|'; then
  #   echo "❌ Failed during directory scan" >&2
  #   return 1
  # fi
    if ! find "$root" -type d ! -name 'structure.spec' | grep -vE '\.git' | sort | sed 's|^|dir: |' | sed 's|$|/|'; then
    echo "❌ Failed during directory scan" >&2
    return 1
  fi




  echo "🔍 Scanning files in: $root" >&2
  if ! find "$root" -type f \
    ! -name 'structure.spec' \
    ! -name '.structure.snapshot' \
    ! -name '*.log' \
    ! -name '*.tmp' \
    ! -path "$root/tmp/*" \
    ! -path "$root/.git/*" \
    2>/dev/null | sort | sed 's|^|file: |'; then
    echo "❌ Failed during file scan for module: $root" >&2
    return 1
  fi

echo "🔗 Scanning symlinks..." >&2

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


  main(){

 

   generate_structure_spec .


 

  }




  if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    # Only run main if not sourced
    main "$@"
  fi

