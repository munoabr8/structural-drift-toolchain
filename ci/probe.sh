#!/usr/bin/env bash
# ci/probe.sh — assert artifact file properties
# Usage:
#   bash ci/probe.sh <file> [--kind <dora_lt|events|triage|result|json|ndjson>]
#   bash ci/probe.sh --kind=events events.ndjson

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

assert_dora_lt(){
  # NDJSON, schema dora/lead_time/*, minutes>=0, merged_at<=deploy_at (UTC)
  jq -s '
    def t: strptime("%Y-%m-%dT%H:%M:%SZ") | mktime;
    length>0 and
    all(.[]; (.schema|startswith("dora/lead_time/"))
         and (.minutes|type=="number" and .minutes>=0)
         and (.merged_at|type=="string")
         and (.deploy_at|type=="string")
         and ((.merged_at|t) <= (.deploy_at|t)))
  ' "$file" | grep -qx true || die "dora_lt_invalid"
}

assert_events(){
  # NDJSON with pr_merged/deployment shapes and ISO timestamps
  jq -s '
    def t: strptime("%Y-%m-%dT%H:%M:%SZ") | mktime;
    length>0 and
    all(.[]; 
      ( .type=="pr_merged"
        and (.pr|type=="number")
        and (.sha|type=="string" and (.sha|length)>0)
        and (.merged_at|type=="string") and ((.merged_at|t)|tonumber >= 0) )
      or
      ( .type=="deployment"
        and (.sha|type=="string" and (.sha|length)>0)
        and (.finished_at|type=="string") and ((.finished_at|t)|tonumber >= 0) )
    )
  ' "$file" | grep -qx true || die "events_invalid"
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
    events)   assert_ndjson; assert_events;;
    triage)   assert_json;   assert_triage;;
    result)   assert_json;   assert_result;;
    ndjson)   assert_ndjson;;
    json)     assert_json;;
    *)        die "unknown_kind:$kind";;
  esac

  # optional summaries
  case "$kind" in
    dora_lt)
      jq -s '[.[].minutes] | {samples:length, p50:(sort|.[(length*0.50|floor)]), p90:(sort|.[(length*0.90|floor)])}' "$file"
      ;;
    events)
      jq -s '{pr_merged: (map(select(.type=="pr_merged"))|length),
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
