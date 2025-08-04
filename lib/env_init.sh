# lib/env_init.sh
# Responsibility: detect/validate/export core env vars for the toolchain.
# Usage (from bin/*):  source "$PROJECT_ROOT/lib/env_init.sh"; env_init --dotenv ".env" --path
# Return codes: 0 OK, 65 = precondition/env failure, 66 = deps missing, 67 = dotenv parse error

# Guard against double-loading
if [[ -n "${__ENV_INIT_SH__:-}" ]]; then
  return 0
fi
__ENV_INIT_SH__=1

# ---------- lightweight logging (no hard dependency on logger) ----------
_env_log() { [[ "${QUIET:-false}" == "true" ]] && return 0; printf '%s\n' "$*"; }
_env_err() { printf '%s\n' "$*" >&2; }



env_usage() {
  cat <<'EOF'
env_init.sh — initialize and validate core environment for the toolchain.

USAGE
  # from a caller (recommended)
  source "$PROJECT_ROOT/lib/env_init.sh"
  env_init [--dotenv FILE] [--path|--no-path] [--require "cmds"] [--verbose] [--help]

FLAGS
  --dotenv FILE     Load simple KEY=VAL pairs before finalizing.
  --path            Prepend BIN_DIR to PATH (idempotent).
  --no-path         Do not modify PATH (overrides --path).
  --require "cmds"  Space-separated list of extra commands to require.
  --verbose         Print informational lines (ignores QUIET=true).
  --help, -h        Show this help and return 0.

ENV VARS (inputs / outputs)
  INPUT  : PROJECT_ROOT (optional; auto-detected if unset)
  OUTPUT : PROJECT_ROOT, BIN_DIR, LIB_DIR, SYSTEM_DIR, LOG_DIR (exported)

EXIT CODES (returned by env_init)
  0  OK
  65 Precondition / env failure (missing dirs/files)
  66 Dependencies missing (required commands not found)
  67 Dotenv parse/read issue

EXAMPLES
  source "$PROJECT_ROOT/lib/env_init.sh"
  env_init --dotenv ".env" --path --require "jq git"
  env_show            # print resolved paths (respects QUIET)
EOF
}


# ---------- helpers ----------
_env_has() { command -v "$1" >/dev/null 2>&1; }

# Detect project root:
# 1) Explicit PROJECT_ROOT
# 2) Git repo root
# 3) Fallback: 2-levels up from this file (…/project-root/lib/env_init.sh)
_env_detect_project_root() {
  if [[ -n "${PROJECT_ROOT:-}" && -d "$PROJECT_ROOT" ]]; then
    printf '%s' "$PROJECT_ROOT"; return 0
  fi
  if _env_has git; then
    local git_root
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$git_root" && -d "$git_root" ]]; then
      printf '%s' "$git_root"; return 0
    fi
  fi
  # derive from this file's location
  local here file_dir root_guess

    here="${BASH_SOURCE[0]}"

  file_dir="$(cd -- "$(dirname -- "$here")" && pwd -P)"
  root_guess="$(cd -- "$file_dir/.." && pwd -P)"   # assumes lib/ under root


  printf '%s' "$root_guess"
}

# Add a dir to PATH if not already present
_env_path_add_once() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  case ":$PATH:" in *":$d:"*) return 0;; esac
  PATH="$d:$PATH"; export PATH
}

# Parse simple KEY=VAL lines from a dotenv file (no shell eval)
_env_load_dotenv() {
  local file="$1"
  [[ -n "$file" ]] || return 0
  [[ -r "$file" ]] || { _env_err "dotenv not readable: $file"; return 67; }
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip comments/blank
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      # remove surrounding quotes if present
      val="${val%\"}"; val="${val#\"}"
      val="${val%\'}"; val="${val#\'}"
      export "$key=$val"
    else
      _env_err "dotenv parse warning (ignored): $line"
    fi
  done < "$file"
  return 0
}

# Verify required commands exist
_env_require_bins() {
  local missing=()
  for c in "$@"; do _env_has "$c" || missing+=("$c"); done
  if ((${#missing[@]})); then
    _env_err "Missing required tools: ${missing[*]}"
    return 66
  fi
  return 0
}

# Verify dirs exist/readability
_env_require_dirs() {
  local d; for d in "$@"; do
    [[ -d "$d" ]] || { _env_err "Required directory missing: $d"; return 65; }
  done
  return 0
}

# Public: show current env (human output; safe for --verbose)
env_show() {
  _env_log "PROJECT_ROOT=${PROJECT_ROOT:-}"
  _env_log "BIN_DIR=${BIN_DIR:-}"
  _env_log "LIB_DIR=${LIB_DIR:-}"
  _env_log "SYSTEM_DIR=${SYSTEM_DIR:-}"
  _env_log "LOG_DIR=${LOG_DIR:-}"
  _env_log "TOOLS_DIR=${TOOLS_DIR:-}"
  _env_log "PATH contains BIN_DIR? $([[ ":$PATH:" == *":${BIN_DIR:-}:"* ]] && echo yes || echo no)"
}

# Public: assert invariants (no mutation)
env_assert() {
  _env_require_dirs "${PROJECT_ROOT:-}" "${LIB_DIR:-}" || return 65
  [[ -r "${LIB_DIR}/env_init.sh" ]] || { _env_err "Cannot read ${LIB_DIR}/env_init.sh"; return 65; }
  return 0
}

# Public: initialize env (idempotent)
# Flags:
#   --dotenv FILE  : load simple KEY=VAL file before finalizing
#   --path         : add BIN_DIR to PATH
#   --no-path      : do not touch PATH (overrides --path)
#   --verbose      : ignore QUIET for this call
#   --require "git jq" : extra tools to require
env_init() {
  local want_path=false no_path=false dotenv="" extra_require=() verbose=false
  while (($#)); do
    case "$1" in
      --dotenv) dotenv="$2"; shift;;
      --path) want_path=true;;
      --no-path) no_path=true;;
      --require) IFS=' ' read -r -a extra_require <<< "$2"; shift;;
      --verbose) verbose=true;;
    esac
    shift || true
  done
  $verbose && QUIET=false

  # 1) Detect/derive directories
  PROJECT_ROOT="${PROJECT_ROOT:-$(_env_detect_project_root)}"
  BIN_DIR="${BIN_DIR:-$PROJECT_ROOT/bin}"
  LIB_DIR="${LIB_DIR:-$PROJECT_ROOT/lib}"
  TOOLS_DIR="${TOOLS_DIR:-$PROJECT_ROOT/tools}" #This may need to deleted.
  SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
  LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/.logs}"
  UTIL_DIR="${UTIL_DIR:-$PROJECT_ROOT/util}";  

  export PROJECT_ROOT BIN_DIR LIB_DIR SYSTEM_DIR LOG_DIR UTIL_DIR TOOLS_DIR

  # 2) Optional dotenv
  [[ -n "$dotenv" ]] && _env_load_dotenv "$dotenv" || true

  # 3) Base requirements
  _env_require_bins bash git awk sed || return $?
  _env_require_dirs "$PROJECT_ROOT" "$LIB_DIR" || return $?

  # 4) Optional tool requirements
  ((${#extra_require[@]})) && _env_require_bins "${extra_require[@]}" || true

  # 5) PATH management
  if $want_path && ! $no_path; then
    _env_path_add_once "$BIN_DIR"
  fi

  # 6) Final assertion
  env_assert || return $?

  return 0
}

# Optional: if this file is executed directly, show help or run a quick check.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    -h|--help|"") env_usage; exit 0 ;;
    --check)      shift; source "${BASH_SOURCE[0]}" >/dev/null 2>&1
                   env_init "$@" --verbose; exit $? ;;
    *)            env_usage; exit 2 ;;
  esac
fi

