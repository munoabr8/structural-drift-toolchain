

rules_rw_schema_violations() {
  local f=${1:-${RULES_FILE:?missing}}
  jq -c '
    def rows:
      if type=="array" then .
      elif (type=="object" and has("rules") and (.rules|type)=="array") then .rules
      else [] end;
    rows | to_entries
      | map(select((.value|has("reads")|not) or (.value.reads|type!="array")
                 or (.value|has("writes")|not) or (.value.writes|type!="array")))
  ' "$f"
}

rules_declare_reads_writes() { [[ -z $(rules_rw_schema_violations "$1") ]]; }
