#!/usr/bin/env bash

#./evaluate.frame.sh
 
#COMMAND=(bash --noprofile --norc -c './evaluate.sh')

#declare_frame_env PATH LANG LC_ALL TZ
#declare_mutable_env TMPDIR
#declare_frame ./rules.json


 
 # rules_schema_valid [path] [root_type]
# root_type: object|array (optional). Returns:
# 0=ok, 1=file missing/empty, 2=invalid JSON, 3=wrong root type
rules_schema_valid() {
 

  local f=${1:-${RULES_FILE:-}}
  local want=${2:-}  # optional: object|array
 
  [[ -n $f && -s $f && -r $f ]] || { echo "rules file missing/empty: $f" >&2; return 1; }
 
  # Validate JSON with Python (stable, no segfaults)
  if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "invalid JSON: $f" >&2
    return 2
  fi
               echo "----------- --------------------"

  # Optional root-type check via Python to avoid jq
  if [[ -n $want ]]; then
    python3 - "$f" "$want" >/dev/null <<'PY' || { echo "wrong root type: expected $2 in $1" >&2; exit 3; }
import json,sys
p,w=sys.argv[1],sys.argv[2]
t=type(json.load(open(p)))
ok=(w=="object" and t is dict) or (w=="array" and t is list)

sys.exit(0 if ok else 3)
PY
  fi
 
  return 0
}

 
pure_eval() { ! ls /tmp/eval_* 2>/dev/null; }


# clean, pinned jq caller
jq_sane() {
  env -i PATH="/opt/homebrew/bin:/usr/bin:/bin" LC_ALL=C HOME="$HOME" \
    /opt/homebrew/bin/jq "$@"
}

 
 rules_have_unique_ids() {
  local f=${1:-${RULES_FILE:?missing}}
  jq -e '
    def rows: if type=="array" then .
              elif (type=="object" and has("rules") and (.rules|type)=="array") then .rules
              else error("no rules array") end;
    (rows | all(has("id") and (.id|type=="string") and (.id|length>0))) and
    ( (rows|map(.id)|length) == (rows|map(.id)|unique|length) )
  ' "$f" >/dev/null
}

 
 

rules_valid_json() {
  local f=${1:-$rules}

   [[ -f $f && -r $f && -s $f ]] || { echo "rules file missing/empty: $f" >&2; return 1; }
  python3 -m json.tool "$f" >/dev/null 2>&1 || { echo "rules file is not valid JSON: $f" >&2; return 1; }

  # best-effort jq pass only after Python ok; ignore segfaults
  env -i PATH="/opt/homebrew/bin:/usr/bin:/bin" LC_ALL=C /opt/homebrew/bin/jq -e . <"$f" >/dev/null 2>&1 || true


}

# rules_schema_valid [path] [root_type]
# root_type optional: object|array
rules_schema_valid() {
  local f=${1:-${RULES_FILE:-}}
  local want=${2:-}
  [[ -n $f && -r $f && -s $f ]] || { echo "rules file missing/empty: $f" >&2; return 1; }

  # 1) Fast system validator (never segfaults)
  if /usr/bin/plutil -lint -s "$f" >/dev/null 2>&1; then
    :
  else
    # 2) System Python only (bypass Conda)
    if ! env -i PATH="/usr/bin:/bin" LC_ALL=C /usr/bin/python3 -m json.tool "$f" >/dev/null 2>&1; then
      echo "invalid JSON: $f" >&2
      return 2
    fi
  fi

  # Optional root-type check via system Python
  if [[ -n $want ]]; then
    env -i PATH="/usr/bin:/bin" LC_ALL=C /usr/bin/python3 - "$f" "$want" >/dev/null <<'PY' || return 3
import json,sys
p,w=sys.argv[1],sys.argv[2]
with open(p,'rb') as fh: b=fh.read().replace(b'\x00',b'')
try: s=b.decode('utf-8')
except UnicodeDecodeError: s=b.decode('utf-16')
v=json.loads(s)
ok=(w=="object" and isinstance(v,dict)) or (w=="array" and isinstance(v,list))
sys.exit(0 if ok else 3)
PY
  fi
  return 0
}


 

# findings_valid_json: fail fast if $findings missing/empty/invalid JSON
findings_valid_json() {
  [[ -n "${findings-}" ]] || { echo "findings path not set" >&2; return 1; }
  [[ -s "$findings"     ]] || { echo "findings missing/empty: $findings" >&2; return 1; }
  jq -e 'type' "$findings" >/dev/null 2>&1 || { echo "findings not valid JSON: $findings" >&2; return 1; }
  jq -e 'type=="array" and length>=0' "$findings" >/dev/null || exit 116  # adjust to >0 if required

}


 

 
# evaluate_rules [file|uses $RULES_FILE]
# Accepts: [ {...}, ... ]  or  {"rules":[...]}
evaluate_rules() {

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
 
rules_declare_reads_writes() {
  local f=${1:-${RULES_FILE:?RULES_FILE missing}}
  [[ -r $f && -s $f ]] || { echo "rules file missing/empty: $f" >&2; return 2; }
  jq -e '
    def rows:
      if type=="array" then .
      elif (type=="object" and has("rules") and (.rules|type=="array")) then .rules
      else error("rules must be array or object.rules") end;
    rows
    | all(.[]; has("reads") and (.reads|type=="array")
                 and has("writes") and (.writes|type=="array"))
  ' "$f" >/dev/null
}






COMMAND=(./evaluate.sh)

# declare_frame_env PATH LANG LC_ALL TZ
# declare_mutable_env TMPDIR
# declare_frame ./rules
# declare_frame ./config
# declare_frame ./src



