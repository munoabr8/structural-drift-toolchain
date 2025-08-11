#!/usr/bin/env bash
set -euo pipefail


POLICY_FILE="${POLICY_FILE:-./config/policy.rules.yml}"


#run_cmd_yq seam; propagates yq's exit code
run_cmd_yq() { # args: expr src
  local rc
  set +e
  cmd_yq "$1" "$2"; rc=$?
  set -e
  return "$rc"
}

cmd_yq()   { yq -r "$@"; }   # seam
cmd_yq_e() { yq -e "$@"; }   # seam for boolean checks



usage(){ echo "usage: $0 [--policy FILE] [--stdin] [--allow-empty]"; }

 
 
arg_parse() {
  READ_STDIN=0; ALLOW_EMPTY=0; FILE="$POLICY_FILE"
  while (($#)); do
    case "$1" in
      --policy) FILE="$2"; shift 2;;
      --stdin)  READ_STDIN=1; shift;;
      --allow-empty) ALLOW_EMPTY=1; shift;;
      -h|--help) echo "usage: $0 [--policy FILE] [--stdin] [--allow-empty]"; exit 0;;
      *) echo "usage: $0 [--policy FILE] [--stdin] [--allow-empty]"; exit 2;;
    esac
  done
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
query_policy_rules() {
  local src="$1"
  emit_tsv "$src"   
}


fetch_src() {
  # args: READ_STDIN ALLOW_EMPTY FILE
  local read_stdin="$1" allow_empty="$2" file="$3"
  local src tmp=""
  if (( read_stdin )); then
    tmp="$(mktemp)"
    cat >"$tmp"
    src="$tmp"
  else
    if [[ -f "$file" ]]; then
      src="$file"
    else
      (( allow_empty )) && { printf '%s\n%s\n' "" ""; return 0; }
      echo "policy not found: $file" >&2
      return 1
    fi
  fi
  printf '%s\n%s\n' "$src" "$tmp"
}

	
 emit_tsv()    { run_cmd_yq '.[] | [.type,.path,.condition,.action] | @tsv' "$1"; }

# cheap invariant: allow at most one '---' separator
enforce_single_doc() { #updated
  local src="$1" seps
  seps=$(grep -cE '^---[[:space:]]*$' "$src" || true)
  (( seps <= 1 )) || { echo "multiple YAML documents not supported" >&2; return 1; }
}



main() {
  arg_parse "$@"

  local SRC TMP rc
  local outf; 
  outf="$(mktemp)"

  if fetch_src "$READ_STDIN" "$ALLOW_EMPTY" "$FILE" >"$outf"; then
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
