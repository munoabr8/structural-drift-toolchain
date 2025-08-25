#!/usr/bin/env bash

 
. "./contracts_dsl.sh"

. "./evaluate.frame.sh"

# --- queries (read-only) you must provide ---

# Always read files via -- "$VAR"


RULES_FILE="${rules:-${RULES_FILE:-./rules.json}}"

findings_normalized()        { "$JQ_BIN" -e 'type=="array"' -- "$FINDINGS_FILE" >/dev/null; }
 


ctx_schema_valid(){ jq -e type "$ctx" >/dev/null; }


order_invariant() {
  local a b
  a=$(evaluate_rules "$RULES_FILE" ${ctx:+ "$ctx"} | sha256sum)
  b=$(jq '.[]' "$RULES_FILE" | shuf | jq -s . | evaluate_rules - ${ctx:+ "$ctx"} | sha256sum)
  [[ "$a" == "$b" ]]
}
hermetic() {
  local h1 h2
  h1=$(PATH=/usr/bin evaluate_rules "$RULES_FILE" ${ctx:+ "$ctx"} | sha256sum)
  h2=$(PATH=/bin     evaluate_rules "$RULES_FILE" ${ctx:+ "$ctx"} | sha256sum)
  [[ "$h1" == "$h2" ]]
}
findings_is_json(){ jq -e type "$findings" >/dev/null; }
findings_normalized(){ jq -S . "$findings" | diff -u "$findings" - >/dev/null; }

findings_have_unique_ids() {
  local dups
  dups="$(jq -r '.[].id' "$findings" | LC_ALL=C sort | uniq -d)"
  [[ -z $dups ]]
}


no_time_or_random_sources() {
  # fail if time or randomness used in rules file
  jq -e '
    map(
      (.reads   // [] | index("time")   | not) and
      (.reads   // [] | index("random") | not) and
      (.writes  // [] | index("time")   | not) and
      (.writes  // [] | index("random") | not)
    ) | all
  ' "${RULES_FILE:-$rules}" >/dev/null
}

 



# --- deterministic env guard (read-only) ---
nondet_env_clean() { [[ "${TZ-UTC}" == "UTC" && "${LANG-}" =~ ^(C|C\.UTF-8|en_US\.UTF-8)$ ]]; }

# --- pre/post ---
pre() {
 

   if [[ -z "${rules:-}" ]]; then
    echo "ERROR: \$rules variable not set" >&2
    exit 90
  fi


  if [[ ! -r "$rules" ]]; then
    echo "ERROR: rules file not found or unreadable: $rules" >&2
    exit 91
  fi
	     
 
  [[ -f "$rules" ]]                       || { echo "missing rules"; exit 103; }
 
	rules_valid_json					|| exit 202
 
 
  rules_schema_valid  # require array root

 
  rules_have_unique_ids "$rules"                  || exit 100
 
 . ./queries/rules.sh
 
  rules_declare_reads_writes  "$rules"            || exit 101
 

 
 
  [[ -z "${ctx-}" ]] || { [[ -f "$ctx" ]] && ctx_schema_valid; } || exit 106
  nondet_env_clean                        || { echo "set TZ=UTC and LANG=C.UTF-8"; exit 107; }
 
 
}


 


post() {

 
  [[ "${status-0}" -eq 0 ]]                      || { echo "evaluator failed"; exit 109; }
  [[ -s "$findings" ]]                            || { echo "findings empty"; exit 114; }
 
  findings_valid_json        || exit 115

  pure_eval            || exit 110
  order_invariant      || exit 111
  hermetic             || exit 112
  findings_normalized "$findings" || exit 120


}
