#!/usr/bin/env bash
# domain_probe.sh
# Observes the command domain: (argv, env, stdin)
# - Emits one JSON line on a side FD (default: 3)
# - Forwards stdin to stdout unchanged
# - Uses no temp files
#
# Usage:
#   exec 3>>domain.log.jsonl
#   cat file | ./domain_probe.sh --tag hash_stage | some_command
#
# Options:
#   --fd N        : emit JSON on file descriptor N (default 3)
#   --env K1,K2.. : comma-separated env keys to capture (default whitelist)
#   --tag STR     : arbitrary tag field to include
#   -h, --help    : show this help



set -euo pipefail

PROBE_FD=${DOMAIN_PROBE_FD:-3}
ENV_KEYS_DEFAULT="USER,LOGNAME,HOME,PWD,SHELL,PATH,LANG,LC_ALL,TERM,TZ,HOSTNAME"
ENV_KEYS="$ENV_KEYS_DEFAULT"
TAG=""
ORIG_ARGV=( "$@" )

help() {
  cat <<'EOF'
domain_probe.sh — observe (argv, env, stdin) for a command invocation.

Usage:
  exec 3>>domain.log.jsonl
  cat file | ./domain_probe.sh [options] --tag mytag | some_command

Options:
  --fd N        Emit JSON on file descriptor N (default: 3).
  --env K1,K2.. Comma-separated environment keys to capture
                (default: USER,LOGNAME,HOME,PWD,SHELL,PATH,LANG,LC_ALL,TERM,TZ,HOSTNAME).
  --tag STR     Arbitrary string tag to include in JSON.
  -h, --help    Show this help and exit.

Exit codes:
  0  success
  2  bad usage

Behavior:
  • Forwards stdin unchanged to stdout, so it fits inside pipelines.
  • Emits one JSON line per invocation on the chosen FD.
  • Does not create temp files or alter global env.
EOF
}

# --- parse args ---
while (($#)); do
  case $1 in
    --fd) PROBE_FD=${2:?}; shift 2;;
    --env) ENV_KEYS=${2:?}; shift 2;;
    --tag) TAG=${2:?}; shift 2;;
    -h|--help) help; exit 0;;
    --) shift; break;;
    *) break;;
  esac
done

# --- helpers ---
_json_escape() { # $1 -> escaped JSON string (no outer quotes)
  # escape backslash and quote, then common control chars
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

argv_json() {
  local out="[" first=1 a
  for a in "$@"; do
    if (( first )); then first=0; else out+=", "; fi
    out+="\"$(_json_escape "$a")\""
  done
  out+="]"
  printf '%s' "$out"
}

env_json() {
  local out="{" first=1 key val IFS=,
  for key in $ENV_KEYS; do
    val=${!key-}
    if (( first )); then first=0; else out+=", "; fi
    out+="\"$key\":\"$(_json_escape "${val}")\""
  done
  out+="}"
  printf '%s' "$out"
}

emit_json2() { # $1=stdin_bytes
  local stdin_bytes=$1
  local ts pid ppid cwd host
  ts=$(date -u +%FT%TZ)        # ISO-8601 UTC
  pid=$$
  ppid=$PPID
  cwd=$PWD
  host=${HOSTNAME-}
  local stdin_tty=true
  [ -t 0 ] || stdin_tty=false

  # Build JSON
  {
    printf '{'
    printf '"ts":"%s",'   "$ts"
    printf '"pid":%d,'    "$pid"
    printf '"ppid":%d,'   "$ppid"
    printf '"host":"%s",' "$(_json_escape "$host")"
    printf '"cwd":"%s",'  "$(_json_escape "$cwd")"
    printf '"argv":%s,'   "$(argv_json "$@")"
    printf '"argc":%d,'   "$#"
    printf '"stdin_tty":%s,' "$stdin_tty"
    printf '"stdin_bytes":%s,' "$stdin_bytes"
    printf '"env":%s'     "$(env_json)"
    if [[ -n $TAG ]]; then
      printf ', "tag":"%s"' "$(_json_escape "$TAG")"
    fi
    printf '}\n'
  } >&"$PROBE_FD"
}


emit_json1() { # $1=stdin_bytes; $2..=argv
  local stdin_bytes=$1; shift
  local -a argv=( "$@" )

  local ts pid ppid cwd host stdin_tty
  ts=$(date -u +%FT%TZ)
  pid=$$
  ppid=$PPID
  cwd=$PWD
  host=${HOSTNAME-}
  stdin_tty=true; [ -t 0 ] || stdin_tty=false

  : "${PROBE_FD:=3}"             # default FD if unset

  {
    printf '{'
    printf '"ts":"%s",'   "$ts"
    printf '"pid":%d,'    "$pid"
    printf '"ppid":%d,'   "$ppid"
    printf '"host":"%s",' "$(_json_escape "$host")"
    printf '"cwd":"%s",'  "$(_json_escape "$cwd")"
    printf '"argv":%s,'   "$(argv_json "${argv[@]}")"
    printf '"argc":%d,'   "${#argv[@]}"
    printf '"stdin_tty":%s,' "$stdin_tty"
    printf '"stdin_bytes":%s,' "$stdin_bytes"
    printf '"env":%s'     "$(env_json)"
    if [[ -n ${TAG-} ]]; then
      printf ', "tag":"%s"' "$(_json_escape "$TAG")"
    fi
    printf '}\n'
  } >&"$PROBE_FD"
}


 
 
emit_json0() { # $1=stdin_bytes; $2..=argv
  local stdin_bytes=$1; shift
  local -a argv=( "$@" )

  : "${PROBE_FD:=3}"
  local ts pid ppid cwd host stdin_tty
  ts=$(date -u +%FT%TZ); pid=$$; ppid=$PPID; cwd=$PWD; host=${HOSTNAME-}
  stdin_tty=true; [ -t 0 ] || stdin_tty=false

  {
    printf '{'
    printf '"ts":"%s",'      "$ts"
    printf '"pid":%d,'       "$pid"
    printf '"ppid":%d,'      "$ppid"
    printf '"host":"%s",'    "$(_json_escape "$host")"
    printf '"cwd":"%s",'     "$(_json_escape "$cwd")"
    printf '"argv":%s,'      "$(argv_json "${argv[@]}")"
    printf '"argc":%d,'      "${#argv[@]}"
    printf '"stdin_tty":%s,' "$stdin_tty"
    printf '"stdin_bytes":%s,' "$stdin_bytes"
    printf '"env":%s'        "$(env_json)"
    if [[ -n ${TAG-} ]]; then
      printf ', "tag":"%s"' "$(_json_escape "$TAG")"
    fi
    printf '}\n'
  } >&"$PROBE_FD"
}


 emit_json() { # $1=stdin_bytes; $2..=argv
  local stdin_bytes=$1; shift
  : "${PROBE_FD:=3}"

  # build JSON in a single variable
  local json
  json=$(
    ts=$(date -u +%FT%TZ)
    pid=$$ ppid=$PPID cwd=$PWD host=${HOSTNAME-}
    stdin_tty=true; [ -t 0 ] || stdin_tty=false
    printf '{'
    printf '"ts":"%s",'      "$ts"
    printf '"pid":%d,'       "$pid"
    printf '"ppid":%d,'      "$ppid"
    printf '"host":"%s",'    "$(_json_escape "$host")"
    printf '"cwd":"%s",'     "$(_json_escape "$cwd")"
    printf '"argv":%s,'      "$(argv_json "$@")"
    printf '"argc":%d,'      "$#"
    printf '"stdin_tty":%s,' "$stdin_tty"
    printf '"stdin_bytes":%s,' "$stdin_bytes"
    printf '"env":%s'        "$(env_json)"
    [[ -n ${TAG-} ]] && printf ', "tag":"%s"' "$(_json_escape "$TAG")"
    printf '}\n'
  )
  printf '%s' "$json" >&"$PROBE_FD"   # single write
}

if [ -t 0 ]; then
  emit_json 0 "${ORIG_ARGV[@]}"
  exit 0
fi

tmp=$(mktemp)
bytes=$(tee "$tmp" | wc -c)   # stream to tmp and count
cat "$tmp"                    # forward original stdin
rm -f "$tmp"
emit_json "$bytes" "${ORIG_ARGV[@]}"
 
# # --- main ---
# if [ -t 0 ]; then
#   # no stdin -> 0 bytes; pass original argv
#   emit_json 0 "${ORIG_ARGV[@]}"
#   exit 0
# fi

# # stdin present: forward to stdout, and in the side process compute bytes then emit
# tee >(
#   bytes=$(wc -c | tr -d '[:space:]')
#   emit_json "$bytes" "${ORIG_ARGV[@]}"
# ) 1>&1

 

