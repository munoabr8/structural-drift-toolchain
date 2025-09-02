#!/usr/bin/env bash
# ./tools/structure/structure_snapshot_gen.sh
set -euo pipefail

  ROOT=$(git rev-parse --show-toplevel)
declare -r IGNORE_FILE=${IGNORE_FILE:-"$ROOT/structure.ignore"}

# ---------- Args to be removed in future: ----------

OUT="${OUT:-}"
LEGACY=0

: "${SNAPSHOT_VALIDATE:=0}"      # 1 = schema-check stdout

if [[ -f "$ROOT/util/source_or_fail.sh" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/util/source_or_fail.sh"
fi
if [[ -f "$ROOT/util/logger.sh" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/util/logger.sh"
fi
if [[ -f "$ROOT/util/logger_wrapper.sh" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/util/logger_wrapper.sh"
fi
# degrade if logging unavailable
if ! type log_json >/dev/null 2>&1; then
  safe_log() { :; }
  cmd_log_info()  { :; }
  cmd_log_error() { :; }
fi

 
# ====================================================================================
# QUERIES: Read-only. They may read FS/env, print results to stdout, and return 0/!0.
# No mutations, no tempfile writes, no logging.
# ====================================================================================

# Query: absolute path to potential ignore file
query_ignore_file() { #
  printf '%s/.structure.ignore\n' "$ROOT"
}
 

# Query: list directories under root (current behavior preserved: ignores only .git)
query_list_dirs() { # $1=root

  find "$ROOT" -type d ! -name 'structure.spec' \
    | grep -vE '\.git' \
    | sort
}

# Query: list files under root (current behavior preserved; ignore plumbing stays inert)
query_list_files_raw() { # $1=root

  find "$ROOT" -type f \
      ! -name 'structure.spec' \
      ! -name '.structure.snapshot' \
      ! -name '*.log' \
      ! -name '*.tmp' \
      ! -name '.DS_Store' \
      ! -path "$ROOT/tmp/*" \
      ! -path "$ROOT/.git/*" \
      2>/dev/null \
      | sort
}

# Query: pass-through placeholder to keep behavior identical.
# In a later step we will apply ignore patterns here.
query_list_files_effective() { # $1=root
  query_list_files_raw "$1"
}

# Query: list symlinks (no effects)
query_list_symlinks() { 
  find "$ROOT" -type l ! -name 'structure.spec' \
    | grep -vE '\.git' \
    | sort
}

# ====================================================================================
# COMMANDS: Side-effects allowed (logging, exit codes, temp files). No schema changes.
# ====================================================================================

cmd_log_info()  { safe_log "INFO"  "$1" "" "0"; }
cmd_log_error() { safe_log "ERROR" "$1" "" "1"; }

# ====================================================================================
# generate_structure_snapshot (wired to use queries; output format unchanged)
# ====================================================================================
# simple, line-based patterns (no globs). comments/blank lines stripped.
 

# strip comments/blanks; literal lines
query_ignore_patterns_simple() {
  [[ -f "$IGNORE_FILE" ]] || return 1
  grep -vE '^\s*(#|$)' "$IGNORE_FILE" || true
}



apply_ignore_filter() {           # $1=root ; stdin=paths
  local pats
  pats="$(query_ignore_patterns_simple)" || { cat; return 0; }
  grep -vFf <(printf '%s\n' "$pats") || true
}

# use the filter for BOTH dirs and files BEFORE you add prefixes
query_list_dirs_effective()  { local r=${1:?}; query_list_dirs  "$r" | apply_ignore_filter "$r"; }
query_list_files_effective() { local r=${1:?}; query_list_files_raw "$r" | apply_ignore_filter "$r"; }


 
  # ---------- Help ----------
usage() {
  cat <<'EOF'
structure_snapshot_gen.sh
Generate a structure spec by listing dirs/files/symlinks.

USAGE
  structure_snapshot_gen.sh [ROOT]
  structure_snapshot_gen.sh --root ROOT [--out FILE]
  structure_snapshot_gen.sh generate_structure_snapshot [ROOT]   # legacy
  structure_snapshot_gen.sh -h|--help

OPTIONS
  --root ROOT   Directory to scan (default: ".")
  --out FILE    Write atomically to FILE (default: stdout)
  -h --help     Show this help

NOTES
  If OUT is set in env, it is used unless --out is given.
EOF
}

parse_args() {
  # legacy function-name first arg
  if [[ "${1-}" == "generate_structure_snapshot" ]]; then
    LEGACY=1; shift
  fi

  # positional ROOT
  if [[ "${1-}" != "" && "${1:0:1}" != "-" ]]; then
    ROOT="$1"; shift
  fi

  while (( $# )); do
    case "$1" in
      --root) ROOT="${2:-}"; shift 2 ;; 
      --out)  OUT="${2:-}";  shift 2 ;;
      -h|--help|-help|--h)  usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
  done


  root_is_valid "$ROOT" 

}

# ---------- Commands (logging ok) ----------
cmd_write_output() { # $1=outfile
  local outfile="$1"
  local tmp=""                         # initialize for set -u
  trap '[[ -n ${tmp:-} ]] && rm -f "$tmp"' EXIT
  tmp="$(mktemp)" || { echo "❌ mktemp failed" >&2; exit 1; }

  if !  generate_structure_snapshot "$ROOT" >"$tmp"; then
    echo "❌ snapshot generation failed for: $ROOT" >&2
    exit 1
  fi

  mv "$tmp" "$outfile"
  trap - EXIT                         # clear trap so we don’t remove the target
  tmp=""                              # avoid stale cleanup
}


validate_snapshot_stream(){ # passthru + schema check
  awk '
    {print}
    /^$/ || /^#/ {next}
    /^dir: .*\/$/ || /^file: .*/ || /^link: .+ -> .+/ {next}
    {print "ASSERT schema: " $0 >"/dev/stderr"; bad=1}
    END{ exit bad?91:0 }
  '
}


# Modes:
#   capture     - buffer outputs, then print (current behavior)
#   tee         - stream to console AND save to tmp (live view)
#   passthrough - run function normally, just print headers/exit (no tmp)
# Select via first arg: --mode=capture|tee|passthrough
# or env: QUERY_IO_MODE=tee

query_io() {
  local mode=${QUERY_IO_MODE:-capture}
  [[ ${1-} == --mode=* ]] && { mode="${1#*=}"; shift; }

 
  # require a target function name
  (( $# >= 1 )) || { echo "query_io: need a target function" >&2; return 64; }

  local func=$1; shift

  # refuse self-wrapping (prevents recursion)
  if [[ $func == query_io ]]; then
    echo "query_io: refusing to wrap itself" >&2
    return 2
  fi



  local  ec
  local tmp_in= tmp_out= tmp_err=   # init for set -u
 
  # always create tmp files you reference later, or guard their use
  tmp_in=$(mktemp)

  case "$mode" in
    capture|tee)
      tmp_out=$(mktemp)
      tmp_err=$(mktemp)
      ;;
    passthrough)
      : ;;
    *) echo "query_io: bad mode=$mode" >&2; return 2;;
  esac

  # safe trap with default expansion
  trap 'rm -f "${tmp_in-}" "${tmp_out-}" "${tmp_err-}"' RETURN

  # stdin buffer
  if [ -t 0 ]; then : >"$tmp_in"; else cat >"$tmp_in"; fi

  echo "--- CALL $func ---"
  printf 'ARGS: '; printf '%q ' "$@"; printf '\n'
  echo "--- STDIN ---"; cat "$tmp_in"

  case "$mode" in
    capture)
      set +e; "$func" "$@" <"$tmp_in" >"$tmp_out" 2>"$tmp_err"; ec=$?; set -e
      echo "--- STDOUT ---"; cat "$tmp_out"
      echo "--- STDERR ---"; cat "$tmp_err"
      ;;
    tee)
      set +e
      "$func" "$@" <"$tmp_in" \
        > >(tee "$tmp_out") \
        2> >(tee "$tmp_err" >&2)
      ec=$?
      set -e
      echo "--- STDOUT ---"; cat "$tmp_out"
      echo "--- STDERR ---"; cat "$tmp_err"
      ;;
    passthrough)
      set +e; "$func" "$@" <"$tmp_in"; ec=$?; set -e
      echo "--- STDOUT/STDERR shown live (no capture) ---"
      ;;
  esac

  echo "--- EXIT ---"; echo "$ec"
  echo "-------------"
  return "$ec"
}
 
generate_structure_snapshot() { # $1=root
   
  cmd_log_info "Entered structure snapshot function"
  local root="${1:-}"

  # Header
  echo "# Auto-generated structure.spec"
  echo ""

  # Directories
  echo " Scanning directories..." >&2

  if ! query_list_dirs_effective "$root" | sed 's|^|dir: |; s|$|/|'; then 
   
    echo "❌ Failed during directory scan" >&2
    return 1
  fi

  # Files
  echo " Scanning files in: $root" >&2
  if ! query_list_files_effective "$root" | sed 's|^|file: |'; then 
    echo "❌ Failed during file scan for module: $root" >&2
    return 1
  fi

  # Symlinks
  echo " Scanning symlinks..." >&2
  local fail_symlink=0
  while IFS= read -r link; do
    if target="$(readlink "$link" 2>/dev/null)"; then
      echo "link: $link -> $target"
    else
      echo "❌ readlink failed for: $link" >&2
      fail_symlink=1
    fi
  done < <(query_list_symlinks "$root")

  if (( fail_symlink )); then
    echo "❌ Failed during symlink scan" >&2
    return 1
  else
    echo "✅ Symlink scan completed successfully" >&2
  fi

  return 0
}

# Preconditions (documentation only)
# pre: ROOT is a dir; IGNORE_FILE exists and is readable
# inv: realpath(ROOT) stable; sha256(IGNORE_FILE) stable; IO under ROOT

hash_file() {
  # Preconditions: $1 provided, file readable
  [[ $# -ge 1 && -r $1 ]] || { printf '%s\n' "hash_file: need readable file" >&2; return 2; }

  set -o pipefail
  local out
  if command -v sha256sum >/dev/null; then
    out="$(sha256sum -- "$1" | awk '{print $1}')" || return $?
  elif command -v shasum >/dev/null; then
    out="$(shasum -a 256 -- "$1" | awk '{print $1}')" || return $?
  else
    printf '%s\n' "hash_file: no sha256 tool found" >&2
    return 127
  fi

  # Postconditions: 64-hex, newline, exit 0
  [[ $out =~ ^[0-9a-f]{64}$ ]] || { printf '%s\n' "hash_file: bad digest" >&2; return 3; }
  printf '%s\n' "$out"
}

observe_begin(){
  ROOT_REAL_START="$(cd "$ROOT" && pwd -P 2>/dev/null)"
  IGN_HASH_START="$(hash_file "$IGNORE_FILE" 2>/dev/null || true)"

}

observe_end(){

 
  ROOT_REAL_END="$(cd "$ROOT" && pwd -P 2>/dev/null)"



  IGN_HASH_END="$(hash_file "$IGNORE_FILE" 2>/dev/null || true)"


  [[ "$ROOT_REAL_START" != "$ROOT_REAL_END" ]] \
    && printf 'WARN: ROOT realpath changed: %s -> %s\n' "$ROOT_REAL_START" "$ROOT_REAL_END" >&2


 
  [[ -n "$IGN_HASH_START" && "$IGN_HASH_START" != "$IGN_HASH_END" ]] \
    && printf 'WARN: IGNORE_FILE content changed\n' >&2

 # 


}

pre(){

  # Root must:
     #    exist
     #    be a directory
     #    never change
     #    be a single path(?)
     #    valid

  # Ignore file must:
     #      exist
     #      never change
     #      be a readable file

    #Checks if the root is actually a directory.
    root_is_valid "$ROOT" 

}

root_is_valid(){ [[ -d ${1-} && -n ${1-} && ! -z ${1-} ]] || die "not a dir: ${1-}"; }

die(){ echo "❌ $*" >&2; exit 90; }

command(){

  if [[ -n "${OUT:-}" ]]; then
     cmd_write_output "$OUT"    # calls generate_structure_snapshot "$ROOT"
  else
    if (( SNAPSHOT_VALIDATE )); then
        generate_structure_snapshot "$ROOT" | validate_snapshot_stream
    else
            generate_structure_snapshot "$ROOT"
    fi
  fi

}

post(){

  if [[ -f "$IGNORE_FILE" ]]; then
    pats="$(grep -vE '^\s*(#|$)' "$IGNORE_FILE" || true)"
    if [[ -n "$pats" ]]; then
      out="$(generate_structure_snapshot "$ROOT")"
      if grep -Ff <(printf '%s\n' "$pats") <<<"$out" >/dev/null 2>&1; then
        die "ignore leak detected"
      fi
    fi
  fi

}

# Read root 
#  -> check ignore file exists
#     ->read ignore file <-> cache ignore file -> read FS -> enforce file.

# ---- main: top-down -----------------------------------------
main() {
 
    parse_args "$@" 
    
    pre
    
    observe_begin

    command

    observe_end

  # I don't know why an echo statement will not print after observe_end finishes executing.
  # It has something to do with the stdin/stdout.    
    # command
     #query_io --mode=capture command
 
  # POST (optional ignore leak check)

    #query_io --mode=capture post
 
}

# entrypoint
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    main "$@"
 fi
