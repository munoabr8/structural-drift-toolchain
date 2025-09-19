#!/usr/bin/env bash
# read_contract.sh FILE
set -euo pipefail
f="${1:?usage: $0 <file>}"

awk '
BEGIN{in=0; last=""}
# start when we hit the marker
/^# CONTRACT:/ {in=1; next}
# stop when the block ends
in && $0 !~ /^#/ {in=0}
in {
  s=$0
  sub(/^# */,"",s)
  # new key: "key: value"
  if (s ~ /^[A-Za-z_]+:[[:space:]]*/) {
    split(s, a, ":")
    key=a[1]
    sub(/^[A-Za-z_]+:[[:space:]]*/,"",s)
    data[key]=s
    order[++n]=key
    last=key
  }
  # continuation line -> append to last key
  else if (last!="") {
    if (length(data[last])>0) data[last]=data[last]" "
    data[last]=data[last] s
  }
}
END{
  if (n==0) { print "{}"; exit 0 }
  printf("{"); first=1
  for (i=1;i<=n;i++){
    k=order[i]; v=data[k]
    gsub(/\\/,"\\\\",v); gsub(/\"/,"\\\"",v)
    if(!first) printf(","); first=0
    printf("\"%s\":\"%s\"", k, v)
  }
  printf("}\n")
}
' "$f"

