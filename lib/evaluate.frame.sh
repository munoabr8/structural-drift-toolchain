#!/usr/bin/env bash

#./evaluate.frame.sh
 
#COMMAND=(bash --noprofile --norc -c './evaluate.sh')

#declare_frame_env PATH LANG LC_ALL TZ
#declare_mutable_env TMPDIR
#declare_frame ./rules.json

 
 
pure_eval8() { ! ls /tmp/eval_* 2>/dev/null; }


# clean, pinned jq caller
jq_sane8() {
  env -i PATH="/opt/homebrew/bin:/usr/bin:/bin" LC_ALL=C HOME="$HOME" \
    /opt/homebrew/bin/jq "$@"
}

 
 
 

rules_valid_json8() {
  local f=${1:-$rules}

   [[ -f $f && -r $f && -s $f ]] || { echo "rules file missing/empty: $f" >&2; return 1; }
  python3 -m json.tool "$f" >/dev/null 2>&1 || { echo "rules file is not valid JSON: $f" >&2; return 1; }

  # best-effort jq pass only after Python ok; ignore segfaults
  env -i PATH="/opt/homebrew/bin:/usr/bin:/bin" LC_ALL=C /opt/homebrew/bin/jq -e . <"$f" >/dev/null 2>&1 || true


}

 

# findings_valid_json: fail fast if $findings missing/empty/invalid JSON
findings_valid_json8() {
  [[ -n "${findings-}" ]] || { echo "findings path not set" >&2; return 1; }
  [[ -s "$findings"     ]] || { echo "findings missing/empty: $findings" >&2; return 1; }
  jq -e 'type' "$findings" >/dev/null 2>&1 || { echo "findings not valid JSON: $findings" >&2; return 1; }
  jq -e 'type=="array" and length>=0' "$findings" >/dev/null || exit 116  # adjust to >0 if required

}


 

 
# evaluate_rules [file|uses $RULES_FILE]
# Accepts: [ {...}, ... ]  or  {"rules":[...]}
evaluate_rules8() {

   local src=${1:-${RULES_FILE:?RULES_FILE missing}}
  local jqbin=${JQ_BIN:-jq}
  local yqbin=${YQ_BIN:-yq}

  [[ $src != "-" ]] && [[ -r $src && -s $src ]] || { echo "missing/empty: $src" >&2; return 1; }

  # Convert YAML → JSON when needed, then apply one jq pass
  if [[ $src =~ \.ya?ml$ ]]; then
    "$yqbin" -o=json '.' "$src" \
    | "$jqbin" -e 'if type=="array" then map({id: .id, status:"ok"})
                   elif (type=="object" and has("rules") and (.rules|type=="array")) then .rules|map({id: .id, status:"ok"})
                   else error("rules must be array or .rules array") end'
  else
    "$jqbin" -e 'if type=="array" then map({id: .id, status:"ok"})
                 elif (type=="object" and has("rules") and (.rules|type=="array")) then .rules|map({id: .id, status:"ok"})
                 else error("rules must be array or .rules array") end' <"$src"
  fi
}
 
 




COMMAND=(./evaluate.sh)

# declare_frame_env PATH LANG LC_ALL TZ
# declare_mutable_env TMPDIR
# declare_frame ./rules
# declare_frame ./config
# declare_frame ./src



