#!/usr/bin/env bash
# tools/structure.sh

 

compare_structures() {
  local spec_file="${1:-${STRUCTURE_SPEC:-./structure.spec}}"
  local snapshot_file="${2:-.structure.snapshot}"
  echo "------------>>>>>>>>>>>>>>"

  # Optionally (re)generate the snapshot when using the default target
  if [[ -x "${SNAPSHOT_GEN:-}" && "$snapshot_file" == ".structure.snapshot" ]]; then
    bash "$SNAPSHOT_GEN" generate_structure_spec . > "$snapshot_file" || return 1
  fi

  [[ -r "$spec_file" && -r "$snapshot_file" ]] || return 1

  diff -u --label "SPEC:$spec_file" --label "SNAP:$snapshot_file" \
       "$spec_file" "$snapshot_file"
  case $? in
    0) 
     echo "No drift!"
     return 0 ;;  # no drift
    1) return 2 ;;  # drift found
    *) return 1 ;;  # diff/error
  esac
}



if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  compare_structures "${1:-${STRUCTURE_SPEC:-./structure.spec}}" "${2:-./.structure.snapshot}"
fi