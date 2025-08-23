#!/usr/bin/env bash
# ./tools/structure/structure_snapshot_gen.sh


set -euo pipefail

 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

 
if [[ -f "$SCRIPT_DIR/util/source_or_fail.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/util/source_or_fail.sh"
fi
if [[ -f "$SCRIPT_DIR/util/logger.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/util/logger.sh"
fi
if [[ -f "$SCRIPT_DIR/util/logger_wrapper.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/util/logger_wrapper.sh"
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
query_ignore_file() { # $1=root
  local root=${1:-}
  [[ -n $root ]] || return 2
  printf '%s/.structure.ignore\n' "$root"
}

# Query: true if ignore file exists and is a regular file
query_has_ignore_file() { # $1=root
  local f; f="$(query_ignore_file "$1")" || return 2
  [[ -f "$f" ]]
}

# Query: stream of ignore patterns (no comments, no blank lines)
query_ignore_patterns() { # $1=root
  local f; f="$(query_ignore_file "$1")" || return 2
  [[ -f "$f" ]] || return 1
  # read-only normalization
  grep -vE '^\s*(#|$)' "$f" || true
}

# Query: list directories under root (current behavior preserved: ignores only .git)
query_list_dirs() { # $1=root
  local root=${1:-}
  [[ -n $root && -d $root ]] || return 2
  find "$root" -type d ! -name 'structure.spec' \
    | grep -vE '\.git' \
    | sort
}

# Query: list files under root (current behavior preserved; ignore plumbing stays inert)
query_list_files_raw() { # $1=root
  local root=${1:-}
  [[ -n $root && -d $root ]] || return 2
  find "$root" -type f \
      ! -name 'structure.spec' \
      ! -name '.structure.snapshot' \
      ! -name '*.log' \
      ! -name '*.tmp' \
      ! -name '.DS_Store' \
      ! -path "$root/tmp/*" \
      ! -path "$root/.git/*" \
      2>/dev/null \
      | sort
}

# Query: pass-through placeholder to keep behavior identical.
# In a later step we will apply ignore patterns here.
query_list_files_effective() { # $1=root
  query_list_files_raw "$1"
}

# Query: list symlinks (no effects)
query_list_symlinks() { # $1=root
  local root=${1:-}
  [[ -n $root && -d $root ]] || return 2
  find "$root" -type l ! -name 'structure.spec' \
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
query_ignore_patterns_simple() {  # $1=root
  local f="$1/.structure.ignore"
  [[ -f $f ]] || return 1
  grep -vE '^\s*(#|$)' "$f" || true
}

apply_ignore_filter() {           # $1=root ; stdin=paths
  local root="$1"
  local pats
  pats="$(query_ignore_patterns_simple "$root")" || { cat; return 0; }
  grep -vFf <(printf '%s\n' "$pats") || true
}

# use the filter for BOTH dirs and files BEFORE you add prefixes
query_list_dirs_effective()  { local r=${1:?}; query_list_dirs  "$r" | apply_ignore_filter "$r"; }
query_list_files_effective() { local r=${1:?}; query_list_files_raw "$r" | apply_ignore_filter "$r"; }


generate_structure_snapshot() { # $1=root

# dirs
   
  cmd_log_info "Entered structure snapshot function"
  local root="${1:-}"
  if [[ -z "$root" || ! -d "$root" ]]; then
    echo "❌ Invalid or missing root: '$root'" >&2
    return 1
  fi

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

# ---------- Args ----------
ROOT="."
OUT="${OUT:-}"
LEGACY=0

 
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
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  [[ -d "$ROOT" ]] || die "not a directory: $ROOT"
}

# ---------- Commands (logging ok) ----------
cmd_write_output() { # $1=outfile
  local outfile="$1"
  local tmp=""                         # initialize for set -u
  trap '[[ -n ${tmp:-} ]] && rm -f "$tmp"' EXIT
  tmp="$(mktemp)" || { echo "❌ mktemp failed" >&2; exit 1; }

  if ! generate_structure_snapshot "$ROOT" >"$tmp"; then
    echo "❌ snapshot generation failed for: $ROOT" >&2
    exit 1
  fi

  mv "$tmp" "$outfile"
  trap - EXIT                         # clear trap so we don’t remove the target
  tmp=""                              # avoid stale cleanup
}



# ---- toggles -------------------------------------------------
: "${ASSERT:=0}"                 # 1 = enforce pre/post checks
: "${SNAPSHOT_VALIDATE:=0}"      # 1 = schema-check stdout
# optional asserts
#   ASSERT_IGNORE_EXPECT="evidence"   -> require this exact line in .structure.ignore
#   ASSERT_NO_IGNORE_LEAK=1           -> fail if any ignored path appears in output

# ---- tiny helpers -------------------------------------------
die(){ echo "❌ $*" >&2; exit 90; }
require_dir(){ [[ -d ${1-} ]] || die "not a dir: ${1-}"; }

ignore_has_line(){ # $1=file $2=exact line
  [[ -f $1 ]] || return 1
  awk -v want="$2" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    { sub(/^[[:space:]]+/,""); sub(/[[:space:]]+$/,"") }
    $0 == want { found=1 }
    END{ exit found?0:1 }
  ' "$1"
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

# ---- main: top-down -----------------------------------------
main() {
  parse_args "$@" || return $?

  # PRE



  if (( ASSERT )); then
    require_dir "$ROOT"
    if [[ -n "${ASSERT_IGNORE_EXPECT:-}" && -f "$ROOT/.structure.ignore" ]]; then
      ignore_has_line "$ROOT/.structure.ignore" "$ASSERT_IGNORE_EXPECT" \
        || die "ignore missing exact line: $ASSERT_IGNORE_EXPECT"
    fi
  fi

  # EXEC
  if [[ -n "${OUT:-}" ]]; then
    cmd_write_output "$OUT"    # calls generate_structure_snapshot "$ROOT"
  else
    if (( SNAPSHOT_VALIDATE )); then
      generate_structure_snapshot "$ROOT" | validate_snapshot_stream
    else
      generate_structure_snapshot "$ROOT"
    fi
  fi

  # POST (optional ignore leak check)
  if (( ASSERT )) && [[ -n "${ASSERT_NO_IGNORE_LEAK:-}" ]] && [[ -f "$ROOT/.structure.ignore" ]]; then
    pats="$(grep -vE '^\s*(#|$)' "$ROOT/.structure.ignore" || true)"
    if [[ -n "$pats" ]]; then
      out="$(generate_structure_snapshot "$ROOT")"
      if grep -Ff <(printf '%s\n' "$pats") <<<"$out" >/dev/null 2>&1; then
        die "ignore leak detected"
      fi
    fi
  fi
}

# entrypoint
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  main "$@"
fi
