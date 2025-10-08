#!/usr/bin/env bash
# shellcheck shell=bash


set -euo pipefail

ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ASSERT_BOOTSTRAP="${ASSERT_BOOTSTRAP:-0}"

if [[ -z "${ENV_LOADED:-}" ]]; then
  if [[ "$ASSERT_BOOTSTRAP" = "1" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT/system/load.sh"
  else
    echo "ERR: env not loaded. Run: source system/load.sh" >&2
    echo "     or set ASSERT_BOOTSTRAP=1 to auto-load." >&2
    exit 69
  fi
fi

need()      { [[ -n "${!1-}" ]] || { echo "missing required var: $1" >&2; exit 64; }; }





ASSERT_TRACE="${ASSERT_TRACE:-0}"


 
 trace() { [ "${ASSERT_TRACE:-0}" = "1" ] && echo "[assert] $*"; :; }


REQ="${REQ:-$ROOT/config/env/required.env}"
SCH="${SCH:-$ROOT/config/env/required.schema.json}"
 
# precedence: explicit file > env-artdir > generic artdir > default
ASSERT_EVENT="${ASSERT_EVENT:-}"
if [[ -z "$ASSERT_EVENT" ]]; then
  ARTDIR_BASE="${ENV_ARTDIR:-${ARTDIR:-${ARTIFACTS:-"$ROOT/artifacts"}}}"
  ENV_ARTDIR_RES="${ENV_ARTDIR:-"$ARTDIR_BASE/env"}"
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  ASSERT_EVENT="$ENV_ARTDIR_RES/assert.$TS.json"
fi

mkdir -p "$(dirname "$ASSERT_EVENT")"

 
need_file_val() { local p="$1"; [[ -s "$p" ]] || { echo "missing/empty file: $p" >&2; exit 64; }; }
 
 
 
need_file_var() {

  local k="$1" v
  # check if var is set without tripping nounset
  if eval "[[ -z \${$k+x} ]]"; then
    echo "missing/empty file: $k (<unset>)" >&2; exit 64
  fi

  # read its value safely
  eval "v=\${$k}"
  [[ -n "$v" && -s "$v" ]] || { echo "missing/empty file: $k ($v)" >&2; exit 64; }
}
 
need_file_var EVENTS 

trace "EVENTS=${EVENTS-<unset>}"


#need_file() { [ -s "$1" ] || { echo "missing/empty file: $1" >&2; exit 64; }; }
need_int()  { [[ "${!1:-}" =~ ^[0-9]+$ && "${!1}" -gt 0 ]] || { echo "bad int $1=${!1:-}" >&2; exit 64; }; }
need_enum() { local k="$1" v="${!1:-}"; shift; [[ " $* " == *" $v "* ]] || { echo "bad $k=$v (allowed: $*)" >&2; exit 64; }; }





# 1) presence: drive from required.env if it exists, else fall back to hardcoded list
if [[ -f "$REQ" ]]; then
  while IFS= read -r k; do
    [[ -z "$k" || "$k" =~ ^# ]] && continue
    need "$k"
  done <"$REQ"
else
  need REPO
  need MAIN_BRANCH
  need GH_TOKEN
  need EVENTS
fi

# 2) shape checks you already have
#need_file EVENTS
need_int  WINDOW_DAYS
 




trace "REQ=$REQ  SCH=$SCH"
# Optional schema enforcement if jq present and schema found


if command -v jq >/dev/null 2>&1 && [[ -f "$SCH" ]]; then
  # type checks
  while IFS= read -r line; do
    key=${line%% *}; typ=${line#* }
    v="${!key-}"
    case "$typ" in
      int)   [[ "$v" =~ ^-?[0-9]+$ ]] || { echo "type:int $key=$v" >&2; exit 65; } ;;
      bool)  [[ "$v" =~ ^(true|false|0|1)$ ]] || { echo "type:bool $key=$v" >&2; exit 65; } ;;
      path)  [[ -e "$v" ]] || { echo "type:path missing $key=$v" >&2; exit 66; } ;;
      url)   [[ "$v" =~ ^https?:// ]] || { echo "type:url $key=$v" >&2; exit 65; } ;;
      enum)  allowed=$(jq -r ".keys.\"$key\".enum[]?" "$SCH" | paste -sd'|' -)
             [[ "$v" =~ ^($allowed)$ ]] || { echo "enum:$key=$v not in {$allowed}" >&2; exit 65; } ;;
      string) : ;;
      *) echo "unknown type $typ for $key" >&2; exit 70 ;;
    esac
    # numeric bounds if present
    min=$(jq -r ".keys.\"$key\".min//empty" "$SCH"); [[ -n "${min:-}" && "$typ" = int ]] && (( v < min )) && { echo "bound:$key < $min" >&2; exit 65; }
    max=$(jq -r ".keys.\"$key\".max//empty" "$SCH"); [[ -n "${max:-}" && "$typ" = int ]] && (( v > max )) && { echo "bound:$key > $max" >&2; exit 65; }
  done < <(jq -r '.keys|to_entries[]|"\(.key) \(.value.type//"string")"' "$SCH")
fi



jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg sch "${SCH:-}" --arg req "${REQ:-}" \
       '{schema:"ci/assert.v1",ts:$ts,req:$req,sch:$sch,status:"ok"}' >"$ASSERT_EVENT"
echo "[assert] wrote $ASSERT_EVENT"
