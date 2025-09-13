def t: strptime("%Y-%m-%dT%H:%M:%SZ") | mktime;

length > 0 and
all(.[] | select(type=="object");
  (.schema | type=="string" and startswith("dora/lead_time/")) and
  ((.minutes|type)=="number" and (.minutes>=0)) and
  ((.merged_at|t) <= (.deploy_at|t))
)
and ( [ .[] | select(type!="object") ] | length == 0 )
