#!/usr/bin/env bash
# ci/probe_coupling.sh — scan Bash scripts for coupling signals
set -euo pipefail

FILES_GLOB="${FILES_GLOB:-**/*.sh}"
EVENTS="${EVENTS:-events.ndjson}"
JSON=0

usage(){ echo "usage: $0 [--json] [--files GLOB] [--events PATH]"; }
while (($#)); do
  case "$1" in
    --json) JSON=1; shift ;;
    --files) FILES_GLOB="${2:-}"; shift 2 ;;
    --events) EVENTS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; echo "ERR: $1"; exit 2 ;;
  esac
done

shopt -s globstar nullglob

join_lines(){ awk 'BEGIN{first=1}{if(!first)printf "\\n"; printf "%s",$0; first=0}'; }
out_text(){
  local name="$1" ; shift
  echo "## $name"
  if [ $# -eq 0 ]; then echo "(none)"; else printf "%s\n" "$@"; fi
  echo
}
out_json(){
  local key="$1" ; shift
  printf '"%s":[' "$key"
  local first=1
  for x in "$@"; do
    [[ $first -eq 0 ]] && printf ','
    first=0
    printf '%s' "$(printf '%s' "$x" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().strip()))')"
  done
  printf ']'
}

# ---------- probes ----------
data_coupling(){
  grep -Rho '\$[A-Z][A-Z0-9_]+' $FILES_GLOB | sort -u | sed 's/^.*$//;s/^/\$/' | sort -u
}

stamp_coupling(){
  [[ -f "$EVENTS" ]] || return 0
  jq -sr '
    paths(scalars)
    | select(all(.[]; type=="string"))
    | join(".")
  ' "$EVENTS" | sort -u
}

control_coupling(){
  git grep -nE '\b(if|elif|case)\b.*\$[A-Z][A-Z0-9_]+' -- $FILES_GLOB || true
}

common_coupling(){
  git grep -nE '^(source|\. )|^[A-Z][A-Z0-9_]+=.+$' -- $FILES_GLOB || true
}

content_coupling(){
  git grep -nE '\b(tmp|\.cache|artifacts|events\.ndjson)\b' -- $FILES_GLOB || true
}

temporal_coupling(){
  git grep -nE '\b(date|gdate|sleep|since_ts|WINDOW_DAYS|MIN_LEAD_SECONDS)\b' -- $FILES_GLOB || true
}

external_coupling(){
  # first token per non-comment line, minus bash builtins
  mapfile -t cmds < <(awk '
    /^[[:space:]]*#/ {next}
    { sub(/#.*/,""); if (match($0,/^[[:space:]]*([A-Za-z0-9_.\/-]+)/,m)) print m[1]; }
  ' $FILES_GLOB | sort -u)
  mapfile -t builtins < <(compgen -b | sort -u)
  printf "%s\n" "${cmds[@]}" | comm -23 - <(printf "%s\n" "${builtins[@]}") || true
}

path_coupling(){
  git grep -nE '(^|[[:space:]])cd([[:space:]]|$)|(\./|(\.\./))' -- $FILES_GLOB || true
}

stream_coupling(){
  git grep -nE '>&2|1>&2|\btee\b|\bread -r\b' -- $FILES_GLOB || true
}

exitcode_coupling(){
  { git grep -nE '\|\s*(grep|jq|awk|sed)' -- $FILES_GLOB || true; echo '---'; git grep -nE '\|\|' -- $FILES_GLOB || true; } 
}

locale_coupling(){
  git grep -nE '\bgdate\b|date -d|-v[0-9]+d' -- $FILES_GLOB || true
}

# ---------- run ----------
sections=(
  "data:$(data_coupling | join_lines)"
  "stamp:$(stamp_coupling | join_lines)"
  "control:$(control_coupling | join_lines)"
  "common:$(common_coupling | join_lines)"
  "content:$(content_coupling | join_lines)"
  "temporal:$(temporal_coupling | join_lines)"
  "external:$(external_coupling | join_lines)"
  "path:$(path_coupling | join_lines)"
  "stream:$(stream_coupling | join_lines)"
  "exitcode:$(exitcode_coupling | join_lines)"
  "locale:$(locale_coupling | join_lines)"
)

if [[ $JSON -eq 0 ]]; then
  for s in "${sections[@]}"; do
    key="${s%%:*}"; val="${s#*:}"
    IFS=$'\n' read -r -d '' -a arr < <(printf '%s\0' "$val")
    out_text "$key coupling" "${arr[@]}"
  done
else
  echo '{'
  first=1
  for s in "${sections[@]}"; do
    key="${s%%:*}"; val="${s#*:}"
    IFS=$'\n' read -r -d '' -a arr < <(printf '%s\0' "$val")
    [[ $first -eq 0 ]] && echo ','
    first=0
    out_json "$key" "${arr[@]}"
  done
  echo
  echo '}'
fi
