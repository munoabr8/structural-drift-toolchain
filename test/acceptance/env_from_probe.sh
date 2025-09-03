#!/usr/bin/env bash
# morph_standalone.sh — probe→env morph without env_init.sh
# Requires: jq
# Exit codes: 0 ok, 65 precondition, 66 missing deps, 67 probe/log parse

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  morph_standalone.sh --log domain.log.jsonl --keys "USER,HOME,LANG,PATH" [--path] [--require "jq git"] -- CMD [ARGS...]

Flags:
  --log FILE       JSONL written by domain_probe (FD 3).
  --keys "CSV"     Whitelist of env keys to import from .env in last JSON line.
  --path           Prepend BIN_DIR to PATH (idempotent).
  --require "L"    Space-separated tools to require (optional).
  -h|--help        Show help.

Bootstraps (without env_init.sh):
  PROJECT_ROOT (explicit > git root > parent of this script)
  BIN_DIR, LIB_DIR, SYSTEM_DIR, LOG_DIR, UTIL_DIR
USAGE
}

# --- args ---
LOG=""; KEYS=""; WANT_PATH=false; EXTRA_REQ=()
while (($#)); do
  case "${1:-}" in
    --log) LOG=${2:?}; shift 2;;
    --keys) KEYS=${2:?}; shift 2;;
    --path) WANT_PATH=true; shift;;
    --require) read -r -a EXTRA_REQ <<< "${2:?}"; shift 2;;
    -h|--help) usage; exit 0;;
    --) shift; break;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done
(( $# > 0 )) || { echo "missing CMD after --" >&2; usage; exit 2; }
[[ -n "$LOG" && -n "$KEYS" ]] || { usage; exit 2; }

# --- deps ---
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 66; }
for c in "${EXTRA_REQ[@]}"; do command -v "$c" >/dev/null 2>&1 || { echo "missing: $c" >&2; exit 66; }; done

# --- import env from probe log (last line only) ---
[[ -r "$LOG" ]] || { echo "probe log not readable: $LOG" >&2; exit 65; }
last="$(tail -n1 -- "$LOG" || true)"
[[ -n "$last" ]] || { echo "probe log empty: $LOG" >&2; exit 67; }

IFS=, read -r -a _K <<< "$KEYS"
jq_keys="$(printf '"%s",' "${_K[@]}")"; jq_keys="[${jq_keys%,}]"

# Export only allowlisted keys (shell-escaped)

if [[ ! -s "$LOG" ]]; then
  echo "probe log empty" >&2
  exit 67
fi

last_line=$(tail -n1 "$LOG")
if [[ -z "$last_line" ]] || ! jq -e 'has("env")' <<<"$last_line" >/dev/null; then
  echo "probe log empty" >&2
  exit 67
fi



eval "$(
  jq -r --argjson KS "$jq_keys" '
    .env
    | to_entries
    | map(select(.key as $k | $KS | index($k)))
    | .[] | "export \(.key)=\(.value|@sh)"
  ' <<<"$last"
)"

# --- bootstrap project env (stand-alone) ---
has() { command -v "$1" >/dev/null 2>&1; }
detect_root() {
  # 1) Explicit PROJECT_ROOT wins
  if [[ -n "${PROJECT_ROOT:-}" && -d "$PROJECT_ROOT" ]]; then printf '%s' "$PROJECT_ROOT"; return; fi
  # 2) Git root
  if has git; then
    r="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$r" && -d "$r" ]] && { printf '%s' "$r"; return; }
  fi
  # 3) Parent of this script
  here="${BASH_SOURCE[0]}"; dir="$(cd -- "$(dirname -- "$here")" && pwd -P)"
  printf '%s' "$(cd -- "$dir/.." && pwd -P)"
}
PROJECT_ROOT="${PROJECT_ROOT:-"$(detect_root)"}"
BIN_DIR="${BIN_DIR:-$PROJECT_ROOT/bin}"
LIB_DIR="${LIB_DIR:-$PROJECT_ROOT/lib}"
SYSTEM_DIR="${SYSTEM_DIR:-$PROJECT_ROOT/system}"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/.logs}"
UTIL_DIR="${UTIL_DIR:-$PROJECT_ROOT/util}"

export PROJECT_ROOT BIN_DIR LIB_DIR SYSTEM_DIR LOG_DIR UTIL_DIR

# basic sanity (don’t be strict about existence beyond root/lib)
[[ -d "$PROJECT_ROOT" ]] || { echo "missing PROJECT_ROOT: $PROJECT_ROOT" >&2; exit 65; }
[[ -d "$LIB_DIR" ]] || true

# idempotent PATH add
if $WANT_PATH && [[ -d "$BIN_DIR" ]]; then
  case ":$PATH:" in *":$BIN_DIR:"*) : ;; *) PATH="$BIN_DIR:$PATH";; esac
  export PATH
fi

# --- exec the target command in this environment ---
exec "$@"
