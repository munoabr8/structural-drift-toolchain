#!/usr/bin/env bash


# CONTRACT-JSON-BEGIN
# {
#   "args": ["--json","--files GLOB","--events PATH"],
#   "env":  {"FILES_GLOB":"**/*.sh","EVENTS":"events.ndjson"},
#   "reads": "files matched by FILES_GLOB; optional EVENTS; git tree; no network",
#   "writes":"stdout report; stderr errors; no files",
#   "tools":["bash>=4","grep","sed","awk","sort","comm","git","jq","python3"],
#   "exit": {"ok":0,"cli":2,"other":"bubbled"},
#   "emits":["data","stamp","control","common","content","temporal","external","path","stream","exitcode","locale"]
# }
# CONTRACT-JSON-END


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
# --- replace these functions ---

# vars defined in the file (global or local)
defined_vars(){
  grep -RhoE '(^|[[:space:]])(local[[:space:]]+)?([A-Z][A-Z0-9_]*)=' -- $FILES_GLOB 2>/dev/null \
  | sed -E 's/.*(local[[:space:]]+)?([A-Z][A-Z0-9_]*)=.*/\2/' \
  | sort -u
}

# env-style reads: $VAR or ${VAR...}
env_reads(){
  grep -RohE '\$[A-Z][A-Z0-9_]*|\$\{[A-Z][A-Z0-9_:-]*\}' -- $FILES_GLOB 2>/dev/null \
  | sed -E 's/^\$\{?([A-Z][A-Z0-9_]*)[^}]*\}?$/\1/' \
  | sort -u
}

# external env deps = reads – defs
data_coupling(){
  comm -23 <(env_reads) <(defined_vars) || true
}

data_coupling2(){
  # $VAR or ${VAR} or ${VAR:-...} → VAR
  grep -RohE '\$[A-Z][A-Z0-9_]*|\$\{[A-Z][A-Z0-9_:-]*\}' -- $FILES_GLOB 2>/dev/null \
  | sed -E 's/^\$\{?([A-Z][A-Z0-9_]*)[^}]*\}?$/\1/' \
  | sort -u
}

stamp_coupling(){
  [[ -f "$EVENTS" ]] || { echo "(no events: $EVENTS)"; return 0; }
  jq -sr '
    paths(scalars) | select(all(.[]; type=="string")) | join(".")
  ' "$EVENTS" | sort -u
}

# print section lines directly; no "\n" joining
out_text(){
  local name="$1"; shift
  echo "## $name"
  if [[ $# -eq 0 ]]; then
    echo "(none)"
  else
    printf '%s\n' "$@"
  fi
  echo
}


control_coupling(){
  git grep -nE '\b(if|elif|case)\b.*\$(\{)?[A-Z][A-Z0-9_]+' -- $FILES_GLOB 2>/dev/null \
  | sed -E 's/.*\$(\{)?([A-Z][A-Z0-9_]+).*/\2/' | sort -u
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
  # first token per non-comment line, minus bash builtins (portable awk)
  mapfile -t cmds < <(
    awk '
      /^[[:space:]]*#/ { next }        # skip comments
      { sub(/#.*/,"") }                # strip trailing comments
      {
        if (match($0,/^[[:space:]]*([A-Za-z0-9_.\/-]+)/)) {
          s = substr($0, RSTART, RLENGTH)
          sub(/^[[:space:]]+/,"", s)
          print s
        }
      }
    ' $FILES_GLOB | sort -u
  )
  mapfile -t builtins < <(compgen -b | sort -u)
  printf "%s\n" "${cmds[@]}" | comm -23 - <(printf "%s\n" "${builtins[@]}")
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


# ---------- emit ----------


emit_section(){ local title="$1" fn="$2"; mapfile -t L < <($fn || true); out_text "$title" "${L[@]}"; }

if [[ $JSON -eq 0 ]]; then
  emit_section "data coupling"     data_coupling
  emit_section "stamp coupling"    stamp_coupling
  emit_section "control coupling"  control_coupling
  emit_section "common coupling"   common_coupling
  emit_section "content coupling"  content_coupling
  emit_section "temporal coupling" temporal_coupling
  emit_section "external coupling" external_coupling
  emit_section "path coupling"     path_coupling
  emit_section "stream coupling"   stream_coupling
  emit_section "exitcode coupling" exitcode_coupling
  emit_section "locale coupling"   locale_coupling
else
  printf '{'
  first=1
  keys=(data stamp control common content temporal external path stream exitcode locale)
  fns=( data_coupling stamp_coupling control_coupling common_coupling content_coupling temporal_coupling external_coupling path_coupling stream_coupling exitcode_coupling locale_coupling )
  for i in "${!keys[@]}"; do
    mapfile -t L < <("${fns[$i]}" || true)
    [[ $first -eq 0 ]] && printf ','
    first=0
    printf '"%s":[' "${keys[$i]}"
    for j in "${!L[@]}"; do
      [[ $j -gt 0 ]] && printf ','
      printf '%s' "$(printf '%s' "${L[$j]}" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().rstrip("\n")))')"
    done
    printf ']'
  done
  printf '}\n'
fi

