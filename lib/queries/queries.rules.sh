# ./lib/querues/queries.rules.sh
# shellcheck shell=bash
# guard against direct exec
# purity: class=queries
# shellcheck shell=bash

# All use $1 = path to rules file (default: $E_RULES_FILE)

 

# q: FILE -> Ω
rules_schema_valid() {
  local f=${1:-${E_RULES_FILE:?}}
  [[ -r $f && -s $f ]] || { echo "rules file missing/empty: $f" >&2; return 1; }

  jq -e -n --slurpfile r "$f" '
    def rows:
      if   ($r|type)=="array" then $r
      elif ($r|type)=="object" and ($r|has("rules")) and (($r.rules|type)=="array") then $r.rules
      else error("rules must be array") end;
    rows | type=="array"
  ' >/dev/null
}






 
rules_have_unique_ids() {  # q: FILE -> Ω
  local f=${1:-${E_RULES_FILE:?}}
  jq -e '
    def rows:
      if   (type=="array") then .
      elif (type=="object") and has("rules") and (.rules|type)=="array" then .rules
      else empty end;

    rows
    | all(has("id") and (.id|type=="string") and (.id|length>0))
    and ((map(.id)|length) == (map(.id)|unique|length))
  ' "$f" >/dev/null
}

 


debug(){
    local f=${1:-${E_RULES_FILE:?}}

jq -e '.' "$f" >/dev/null || { echo "invalid JSON: $f" >&2; return 2; }
# assert: rows selector yields an array
jq -e 'if type=="array" then 1 elif has("rules") and (.rules|type)=="array" then 1 else empty end' "$f" >/dev/null \
  || { echo "rules must be array (. or .rules)" >&2; return 2; }

}

# q: FILE -> Ω
rules_declare_reads_writes() {
  local f=${1:-${E_RULES_FILE:?}}
  # --- preconditions ---
  command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; return 2; }
  [[ -r $f && -s $f ]]          || { echo "rules file missing/empty: $f" >&2; return 2; }
  [[ ${DEBUG_RULES:-0} -eq 1 ]] && printf 'rules file=%q\n' "$f" >&2

  # --- evaluation (read-only) ---
  jq -e '
    def rows:
      if   (type=="array") then .
      elif (type=="object") and has("rules") and (.rules|type)=="array" then .rules
      else error("rules must be array (. or .rules)") end;

    rows | all(
      has("reads")  and (.reads  | type=="array") and
      has("writes") and (.writes | type=="array")
    )
  ' "$f" >/dev/null
  case $? in
    0) return 0 ;;      # post: condition holds
    1) return 1 ;;      # post: valid JSON but condition false
    *) echo "jq error" >&2; return 2 ;;
  esac
}



if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "This file must be sourced, not executed." >&2
  exit 2
fi

