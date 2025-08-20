#!/usr/bin/env bash
set -euo pipefail


[[ ${TEST_FAIL_P1:-0} -eq 1 ]] && exit 99

# repo root and transform shim
: "${CODE_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
: "${TRANSFORM_BIN:="$CODE_ROOT/lib/policy/transform_policy_rules_shim"}"


[[ -x "$TRANSFORM_BIN" ]] || { echo "missing transform shim: $TRANSFORM_BIN" >&2; exit 127; }



POLICY_FILE="${POLICY_FILE:-./../../config/policy.rules.yml}"


#run_cmd_yq seam; propagates yq's exit code
cmd_yq()   { yq eval -r "$1" -- "${2:--}"; }  # raw output
cmd_yq_e() { yq eval -e "$1" -- "${2:--}"; }  # exit status checks

# run yq without tripping set -e in callers
run_cmd_yq() { # args: expr src?
  local rc
  set +e
  cmd_yq "$1" "${2:--}"; rc=$?
  set -e
  return "$rc"
}


# enable with TRACE_PIPELINE=1
trace_on() { [[ "${TRACE_PIPELINE:-0}" -eq 1 ]]; }

# visualize tabs/newlines safely
 
vis() { sed -e $'s/\t/\\t/g' -e 's/$/$/'; }
# conditional tee to stderr with a label
tap() {
  local label="$1"
  if trace_on; then
    tee >(vis | sed "s/^/${label} | /" >&2)
  else
    cat
  fi
}



usage(){ echo "usage: $0 [--policy FILE] [--stdin] [--allow-empty]"; }

 
 

arg_parse() {
  READ_STDIN=0; ALLOW_EMPTY=0; FILE="$POLICY_FILE"
  #echo "Incoming args: $@"   # dump all arguments at start

  while (($#)); do
    echo "processing: $1"    # show each arg before case
    case "$1" in
      --policy) FILE="$2"; echo "set FILE=$FILE"; shift 2;;
      --stdin)  READ_STDIN=1; echo "set READ_STDIN=$READ_STDIN"; shift;;
      --allow-empty) ALLOW_EMPTY=1; echo "set ALLOW_EMPTY=$ALLOW_EMPTY"; shift;;
      -h|--help) echo "usage: $0 [--policy FILE] [--stdin] [--allow-empty]"; exit 0;;
      *) echo "usage: $0 [--policy FILE] [--stdin] [--allow-empty]"; exit 2;;
    esac
  done

  # final state dump
  #echo "Final: FILE=$FILE READ_STDIN=$READ_STDIN ALLOW_EMPTY=$ALLOW_EMPTY"
}


# Core: one resolver, two modes.
# Usage: resolve_input [FILE|-] [ALLOW_EMPTY=1] [MODE=stream|path]
# Env:   STRICT_SRC=1 forbids file+stdin
# Sets:  IN_SRC ('stdin' or 'file:<path>'), IN_TMP (tmp path or ''), IN_PATH (readable path in path mode)
resolve_input() {
  local arg="${1:-}" allow="${2:-1}" mode="${3:-stream}" strict="${STRICT_SRC:-0}"
  require "is_bool $allow"  "ALLOW_EMPTY must be 0|1"
  require "is_bool $strict" "STRICT_SRC must be 0|1"
  [[ "$mode" =~ ^(stream|path)$ ]] || _die pre "bad MODE" 97
  IN_SRC=""; IN_TMP=""; IN_PATH=""

  if [[ -z "$arg" || "$arg" == "-" ]]; then
    # stdin
    if (( allow == 0 || mode == "path" )); then
      IN_TMP="$(mktemp -t in.stdin.XXXXXX)" || _die pre "mktemp failed" 97
      cat >"$IN_TMP"
      (( allow == 0 )) && [[ ! -s "$IN_TMP" ]] && _die pre "stdin empty" 97
    else
      [[ -t 0 ]] && _die pre "no stdin and no file" 97
    fi
    IN_SRC="stdin"
    if [[ "$mode" == "stream" ]]; then
      [[ -n "$IN_TMP" ]] && exec <"$IN_TMP"
    else
      IN_PATH="${IN_TMP}"  # path mode guarantees a path
    fi
  else
    # file
    [[ -r "$arg" ]] || _die pre "unreadable: $arg" 97
    (( strict )) && [[ ! -t 0 ]] && _die pre "both file and stdin provided" 97
    (( allow == 0 )) && [[ ! -s "$arg" ]] && _die pre "file empty: $arg" 97
    IN_SRC="file:$arg"
    if [[ "$mode" == "stream" ]]; then exec <"$arg"; else IN_PATH="$arg"; fi
  fi
}

# Adapter 2: path+stdout interface (drop-in for fetch_src)
# Usage: fetch_src_compat READ_STDIN ALLOW_EMPTY FILE
# Prints two lines: PATH and TMP ('' if none)
fetch_src_compat() {
  local read_stdin="$1" allow_empty="$2" file="$3" arg=""
  require "is_bool $read_stdin"  "read_stdin must be 0|1"
  require "is_bool $allow_empty" "allow_empty must be 0|1"
  (( read_stdin || allow_empty )) || require "[[ -n \"$file\" ]]" "file required"

  (( read_stdin )) && arg="-" || arg="$file"
  if [[ -z "$arg" && "$allow_empty" -eq 1 ]]; then
    printf '%s\n%s\n' "" ""; return 0
  fi

  resolve_input "$arg" "$allow_empty" path
  printf '%s\n%s\n' "$IN_PATH" "$IN_TMP"
}


# --- NEW: validate both invariants without side effects ---
validate_policy() {
  local src="$1"
  enforce_single_doc "$src" || return 1
  ensure_root_seq "$src" || { echo "policy root must be a YAML sequence" >&2; return 1; }
}

ensure_root_seq() {
  # exit nonzero unless YAML root is a sequence (array)
  cmd_yq_e 'type == "!!seq"' "$1" >/dev/null
}

 
# --- NEW: reintroduced query function; pure w.r.t. inputs/outputs ---
 
query_policy_rules2() {
  local src="$1" rc out
  { emit start; } 1>&2
 

 if trace_on; then
    echo "S1 IN YAML | src=${src}" >&2
    [[ "$src" = "-" ]] && cat | vis >&2 || vis <"$src" >&2
    if [[ "$src" = "-" ]]; then
      head -n "${TRACE_HEAD:-40}" | sed -n 'l' >&2
    else
      head -n "${TRACE_HEAD:-40}" <"$src" | sed -n 'l' >&2
fi

  fi

  # run producer; keep its stderr separate
  if ! out="$(emit_tsv "$src" 2> >(sed 's/^/yq: /' >&2))"; then
    { emit end; } 1>&2; return 65
  fi

  # normalize: drop blanks
  out="$(printf '%s\n' "$out" | sed '/^[[:space:]]*$/d')"

  # reject usage/help or non-TSV
  if grep -qE '^(Usage:|yq: )' <<<"$out" || ! grep -q $'\t' <<<"$out"; then
    printf '%s\n' "$out" >&2
    { emit end; } 1>&2; return 65
  fi

  # hand off to §2 via shim; only TSV on stdout
  printf '%s\n' "$out" | "$TRANSFORM_BIN"; rc=${PIPESTATUS[1]}
  { emit end; } 1>&2
  return "$rc"
}


query_policy_rules() {
  local src="$1" rc
  { emit start; } 1>&2

  # trace input (file, so no stdin consumption)
  if [[ "${TRACE_PIPELINE:-0}" -eq 1 ]]; then
    echo "S1 IN YAML | src=${src}" >&2
    vis <"$src" >&2
  fi

  # TSV to stdout; mirror to stderr when tracing
  if [[ "${TRACE_PIPELINE:-0}" -eq 1 ]]; then
    emit_tsv "$src" | tee >(vis | sed 's/^/S1 OUT TSV | /' >&2)
    rc=${PIPESTATUS[0]}
  else
    emit_tsv "$src"; rc=$?
  fi

  { emit end; } 1>&2
  return "$rc"
}
  


# Observability toggles:
#   OBS=1 enable logs, OBS_JSON=1 for JSON, OBS_FD=<n> target FD (default 2)
#   OBS_SAMPLE=64 bytes to preview (default 64)
#   OBS_TAG free-form tag to attach to log lines
obs_log() {

  OBS="${OBS:-1}"
  [[ -n "$OBS" ]] || return 0
  local fd="${OBS_FD:-2}" tag="${OBS_TAG:-fetch_src}" msg="$*"

  OBS_JSON="${OBS_JSON:-0}"
  if [[ -n "$OBS_JSON" ]]; then
    printf '{"at":"%s","t":"%s","msg":%q}\n' "$tag" "$(date -u +%FT%TZ)" "$msg" >&"$fd"
  else
    printf '[%s %s] %s\n' "$tag" "$(date -u +%FT%TZ)" "$msg" >&"$fd"
  fi
}

obs_stats() {
  local p="$1" b l mt bin n="${OBS_SAMPLE:-64}" sha=""
  b=$(wc -c <"$p" 2>/dev/null || echo '?')
  l=$(wc -l <"$p" 2>/dev/null || echo '?')
  mt=$(command -v file >/dev/null && file -b --mime-type "$p" || echo "unknown/unknown")
  if command -v shasum >/dev/null 2>&1; then sha=$(shasum -a 256 "$p" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then sha=$(sha256sum "$p" | awk '{print $1}')
  else sha="n/a"; fi
  bin=$(LC_ALL=C grep -qU $'\x00' "$p" && echo 1 || echo 0)
  obs_log "path=$p bytes=$b lines=$l mime=$mt sha256=$sha binary=$bin"
  # safe sample (printable only)
  local sample; sample=$(LC_ALL=C head -c "$n" "$p" | tr -c '[:print:]\n\t' '?')
  obs_log "head_sample[${n}]=${sample}"
}

# ---- contracts ----
_die()       { obs_log "contract-$1:$2"; printf 'contract:%s:%s\n' "$1" "$2" >&2; exit "${3:-99}"; }
require()    { eval "$1" || _die pre  "$2" 97; }
ensure()     { eval "$1" || _die post "$2" 98; }
invariant()  { eval "$1" || _die inv  "$2" 96; }
is_bool()    { case "$1" in 0|1) return 0;; *) return 1;; esac; }
is_file_r()  { [[ -f "$1" && -r "$1" ]]; }

# ---- instrumented fetch_src ----
fetch_src() { # args: READ_STDIN ALLOW_EMPTY FILE
  local read_stdin="$1" allow_empty="$2" file="$3"
  local src="" tmp="" t0 t1
  t0=$(date +%s%N)

  obs_log "pre: read_stdin=$read_stdin allow_empty=$allow_empty file=$file"

  require "is_bool $read_stdin"  "read_stdin must be 0|1"
  require "is_bool $allow_empty" "allow_empty must be 0|1"
  (( read_stdin || allow_empty )) || require "[[ -n \"$file\" ]]" "file required"

  if (( read_stdin )); then
    tmp="$(mktemp -t policy.XXXXXX)"
    obs_log "stdin->tmp=$tmp"
    cat >"$tmp"
    (( allow_empty )) || require "[[ -s \"$tmp\" ]]" "stdin must be non-empty"
    src="$tmp"
    obs_stats "$src"
  else
    obs_log "file mode: file=$file"
    if [[ -f "$file" ]]; then
      src="$file"
      obs_stats "$src"
    else
      if (( allow_empty )); then
        obs_log "file missing but allow_empty=1"
        printf '%s\n%s\n' "" ""
        return 0
      fi
      _die pre "policy not found: $file" 97
    fi
  fi

  invariant "[[ -n \"$src\" ]]"             "src must be set"
  invariant "is_file_r \"$src\""            "src must exist+readable"
  [[ -n "$tmp" ]] && invariant "(( read_stdin )) && [[ \"$src\" == \"$tmp\" ]]" "tmp implies stdin"
  (( read_stdin )) || invariant "[[ -z \"$tmp\" ]]" "no tmp when file mode"

  printf '%s\n%s\n' "$src" "$tmp"

  if [[ -n "$OBS" ]]; then
    # post timing + contract echo check
    local lc; lc="$(printf '%s\n%s\n' "$src" "$tmp" | wc -l | tr -d ' ')"
    ensure "[[ $lc -eq 2 ]]" "stdout must be two lines"
    t1=$(date +%s%N)
    # duration in ms
    #local dur_ms=$(( (t1 - t0)/1000000 ))
    obs_log "post: src=$src tmp=$tmp dur_ms= NEEDS WORK"
  fi
}


emit_tsv() {
  run_cmd_yq  '.[] | [.type,.path,.condition,.action, (.mode // "")] | @tsv' "$1" \
  | sed -E 's/\t$//'
}


 
emit(){ printf 'event|%s' "$1" >&2; shift||:; for kv in "$@"; do printf '|%s' "$kv" >&2; done; printf '\n' >&2; }

 

# --- YAML -> TSV producer; mode is optional ---
 
 
 
emit_tsv() {
  # src: file path or "-" for STDIN
  local src="${1:--}"
  run_cmd_yq '.[] | [.type, .path, .condition, .action, (.mode // "")] | @tsv' "$src" \
  | sed -E 's/\t$//'   # remove trailing tab when mode is absent
}

 
# cheap invariant: allow at most one '---' separator
enforce_single_doc() { #updated
  local src="$1" seps
  seps=$(grep -cE '^---[[:space:]]*$' "$src" || true)
  (( seps <= 1 )) || { echo "multiple YAML documents not supported" >&2; return 1; }
}


displayInputs(){

echo "Number of inputs:  $#"
echo "All inputs: $@"
echo "Inputs: $*"
i=1
for arg in "$@"; do
  echo "Arg $i: $arg" 
  i=$((i+1))
 done 
}



main() {

 #displayInputs 

  arg_parse "$@"



  local SRC TMP rc
  local outf; 
  outf="$(mktemp)"

#arg_parse
#Final: FILE=/Users/abrahammunoz/git/structural-drift-toolchain/config/policy.rules.yml READ_STDIN=0 ALLOW_EMPTY=0
  if fetch_src_compat "$READ_STDIN" "$ALLOW_EMPTY" "$FILE" >"$outf"; then
    IFS=$'\n' read -r SRC TMP <"$outf"
  else
    rc=$?
    rm -f "$outf"
    exit "$rc"
  fi
  rm -f "$outf"

  # allow-empty: empty SRC means nothing to do
  if [[ -z "$SRC" ]]; then
    exit 0
  fi





  validate_policy "$SRC" || { [[ -n "$TMP" ]] && rm -f "$TMP"; exit 1; }


  query_policy_rules "$SRC"; rc=$?

  [[ -n "$TMP" ]] && rm -f "$TMP"

  exit "$rc"
}

 

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
