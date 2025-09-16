#!/usr/bin/env bash
# ci/probe.sh — assert artifact file properties
# Usage:
#   bash ci/probe.sh <file> [--kind <dora_lt|events|triage|result|json|ndjson>]
#   bash ci/probe.sh --kind=events events.ndjson

#echo "PROBE_VERSION=events-slurp-guard" >&2git rev-parse HEAD && md5sum ../probe.sh
set -euo pipefail
export LC_ALL=C
trap 'echo "FAIL: $0 line $LINENO" >&2' ERR

# ---------- utils ----------
die(){ echo "ERR:$*" >&2; exit "${2:-1}"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing:$1"; }
usage(){ echo "usage: $0 <file> [--kind <dora_lt|events|triage|result|json|ndjson>]"; }

# ---------- arg parsing ----------
file=""
kind=""

guess_kind(){
  case "$(basename "$file")" in
    dora_lt.ndjson) echo dora_lt;;
    events.ndjson)  echo events;;
    triage.json)    echo triage;;
    result.json)    echo result;;
    *.ndjson)       echo ndjson;;
    *.json)         echo json;;
    *)              echo json;;
  esac
}

parse_args(){
  file=""; kind=""
  while (($#)); do
    case "$1" in
      --kind|-k) kind="${2:-}"; shift 2;;
      --kind=*)  kind="${1#*=}"; shift;;
      -h|--help) usage; exit 0;;
      -*)        die "unknown_option:$1" 2;;
      *)  if [[ -z "$file" ]]; then file="$1"
          elif [[ -z "$kind" ]]; then kind="$1"
          else die "extra_arg:$1" 2
          fi
          shift;;
    esac
  done
  [[ -n "$file" ]] || die "file_required" 2
  [[ -r "$file"  ]] || die "unreadable:$file" 2
  [[ -n "$kind"  ]] || kind="$(guess_kind)"
}


# ---------- assertions ----------
assert_json(){ jq -e . "$file" >/dev/null; }

assert_ndjson(){
  # every non-empty line must be valid JSON
  nl -ba "$file" | while read -r ln line; do
    [[ -z "${line// }" ]] && continue
    printf '%s\n' "$line" | jq -e . >/dev/null \
      || { echo "bad_json_line:$ln" >&2; exit 1; }
  done
}

 

assert_dora_lt() {
  local jf="${DORA_LT_VALIDATOR_JQ:-../jq/dora_lt_validate.jq}"

  [[ -s "$file" ]] || die "empty_file:$file"
  jq -c . "$file" >/dev/null || die "bad_json_line"

  # fail if any line is not an object
  if jq -s 'any(.[]; type!="object")' "$file" | grep -qx true; then
    die "non_object_line"
  fi

  [[ -r "$jf" ]] || die "missing_validator:$jf"
  jq -e -s -f "$jf" "$file" >/dev/null || die "dora_lt_invalid"
}

 
 

assert_events() {
  local file="${1:?events_file_required}"
  local SCRIPT_DIR REPO_ROOT DEFAULT_JQ jf
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  REPO_ROOT="${SCRIPT_DIR%/ci}"
  DEFAULT_JQ="${REPO_ROOT}/ci/jq/events_validate.jq"   # expects PARSED array, no split()
  jf="${EVENTS_VALIDATOR_JQ:-$DEFAULT_JQ}"
  [[ -r "$jf" ]] || die "missing_validator:$jf"
  jq -R -s -f "$jf" "$file" | grep -qx true || die "events_invalid"
}

# ---------- normalize: path -> compact NDJSON on stdout ----------
normalize_events() {
  local path="${1:?path_required}"
  jq -R -s '
    def lines_to_objs: split("\n") | map(fromjson? // empty);
    (fromjson? // lines_to_objs)
    | (if type=="array" then . else [.] end)
    | map(select(type=="object"))[]
  ' "$path"
}

 


assert_triage(){
  jq -e '
    .schema=="ci/triage/v1" and
    (.code|type=="string" and (.code|length)>0) and
    (.sha|type=="string")
  ' "$file" >/dev/null || die "triage_invalid"
}

assert_result(){
  jq -e '
    .schema=="ci/test/v1" and
    (.ok|type=="boolean") and
    (.sha|type=="string")
  ' "$file" >/dev/null || die "result_invalid"
}

# ---------- runner ----------
 

probe(){
  case "$kind" in
    dora_lt)  assert_ndjson; assert_dora_lt;;
    events)   assert_events "$file";;
    triage)   assert_json;   assert_triage;;
    result)   assert_json;   assert_result;;
    ndjson)   assert_ndjson;;
    json)     assert_json;;
    *)        die "unknown_kind:$kind";;
  esac

  case "$kind" in
   events)
  jq -s '{pr_merged:(map(select(.type=="pr_merged"))|length),
          deployments:(map(select(.type=="deployment"))|length)}' "$file"
  ;;
    *) :;;
  esac
}

# ---------- main ----------
main(){
  need jq
  parse_args "$@"
  probe
}

main "$@"
