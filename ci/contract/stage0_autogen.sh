#!/usr/bin/env bash
# CONTRACT-JSON-BEGIN
# {
#   "contract_schema": "contract/v1",
#   "args": [
#     "[S]"
#   ],
#   "env": {
#     "ARGS": null,
#     "ARGS_OVR": null,
#     "ENVJ": null,
#     "ENV_HINT": null,
#     "EXIT_OVR": null,
#     "HINTS": null,
#     "NO_RUN": null,
#     "OUTDIR": null,
#     "PATH_MIN": null,
#     "READS": null,
#     "RUN_ARGS": null,
#     "SCRAPE": null,
#     "SEED": null,
#     "TOOLS_OVR": null
#   },
#   "reads": "target script; optional hints; no network",
#   "writes": [],
#   "tools": [
#     "bash",
#     "jq",
#     "find",
#     "mktemp",
#     "comm",
#     "sed"
#   ],
#   "exit": {
#     "ok": 0
#   },
#   "emits": []
# }
# CONTRACT-JSON-END

# ci/contract/stage0_autogen.sh

set -euo pipefail
need(){ command -v "$1" >/dev/null || { echo "missing:$1" >&2; exit 70; }; }
need jq; need mktemp; need find; need sed; need comm
OUTDIR="${OUTDIR:-contracts-gen}"
HINTS="${HINTS:-ci/contract/hints.json}"
mkdir -p "$OUTDIR"

probe(){ # returns JSON or {}
  [[ -x ci/probe_coupling.sh ]] && bash ci/probe_coupling.sh --json --files "$1" 2>/dev/null || echo '{}'
}
# replace your hint() with this
key_for() {
  local s="$1"
  local rel
  rel="$(git ls-files --full-name "$s" 2>/dev/null || true)"
  printf '%s\n' "${rel:-${s#./}}"
}
hint() { # hint <script> <field>
  local k b
  k="$(key_for "$1")"; b="$(basename -- "$k")"
  [[ -f "$HINTS" ]] || { echo; return; }
  jq -r --arg k "$k" --arg b "$b" --arg p "$2" '
    ( .[$k][$p] ) // ( .[$b][$p] ) // empty
  ' "$HINTS"
}

# ############### helpers for sand box ######################
_new_workdir(){ mktemp -d; }
_stub_net(){ local d="$1"; printf '#!/usr/bin/env bash\necho net >&2; exit 71\n' >"$d/gh"; printf '#!/usr/bin/env bash\necho net >&2; exit 71\n' >"$d/curl"; chmod +x "$d/gh" "$d/curl"; }
_seed_fs(){ local d="$1" seed="$2"; ( cd "$d" || exit; jq -r '.[]? | select(length>0)' <<<"$seed" | while read -r p; do [[ "$p" == */ ]] && { mkdir -p -- "$p"; continue; }; mkdir -p -- "$(dirname -- "$p")"; : > "$p"; done ); }
_snapshot(){ local d="$1" out; out="$(mktemp)"; ( cd "$d"; find . -type f | sort >"$out" ); printf '%s\n' "$out"; }
_env_from_json(){ # prints array of KEY=VAL lines
  local envj="$1" d="$2" s="$3" path_min="$4"
  printf '%s\0%s\0%s\0%s\0%s\0' \
    "PATH=$path_min" "TZ=UTC" "HOME=$d" "FILES_GLOB=$s" "EVENTS=events.ndjson"
  jq -r 'to_entries[]? | "\(.key)=\(.value)"' <<<"$envj" 2>/dev/null | tr '\n' '\0'
}
_run(){ # out err rc
  local s="$1"; shift
  local out="$1" err="$2" timeout_s="${3:-10}"; shift 3
  set +e; timeout "$timeout_s" env -i "$@" "$s" >"$out" 2>"$err"; local rc=$?; set -e
  printf '%s\n' "$rc"
}
_writes_json(){ comm -13 "$1" "$2" | sed 's#^\./##' | jq -Rsc 'split("\n")|map(select(length>0))'; }
_emits_json(){ local out="$1" scrape="$2" s="$3"; shift 3
  if jq -e type >/dev/null 2>&1 <"$out"; then jq -r 'keys? // [] | @json' "$out"
  elif [[ "$scrape" == "1" ]]; then
    local t; t="$(env -i "$@" "$s" 2>/dev/null || true)"
    printf '%s\n' "$t" | grep -E '^## ' | sed 's/^## *//' | jq -Rsc 'split("\n")|map(select(length>0))'
  else echo '[]'; fi
}

sandbox(){ # -> {"writes":[],"emits":[],"rc":0}
  local S="$1" ARGS="$2" ENVJ="$3" SEED="$4" SCRAPE="$5"

  local work; work="$(_new_workdir)"; _stub_net "$work"
  local PATH_MIN="/usr/bin:/bin:$work"
  local KEEP="${SANDBOX_KEEP:-0}"
  local KEEP_ON_FAIL="${SANDBOX_KEEP_ON_FAIL:-0}"
  local RUN_RC=-1
  local before='' after=''   # set later

  cleanup() {
    # decide using RUN_RC, not $?
    if (( KEEP==1 || (KEEP_ON_FAIL==1 && RUN_RC!=0) )); then
      printf '[sandbox] kept: %s\n' "$work" >&2
    else
      [[ -n "$before" ]] && rm -f -- "$before" "$after" 2>/dev/null || true
      [[ -d "$work"   ]] && rm -rf -- "$work" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT INT TERM

  _seed_fs "$work" "$SEED"
  before="$(_snapshot "$work")"

  mapfile -d '' kv < <(_env_from_json "$ENVJ" "$work" "$S" "$PATH_MIN")
  mapfile -t argv < <(jq -r '.[]?' <<<"$ARGS" 2>/dev/null || true)

  local out="$work/out.json" err="$work/err.txt"
  RUN_RC="$(_run "$S" "$out" "$err" 10 "${kv[@]}" "${argv[@]}")"

  after="$(_snapshot "$work")"
  local writes; writes="$(_writes_json "$before" "$after")"
  local emits;  emits="$(_emits_json "$out" "$SCRAPE" "$S" "${kv[@]}")"

  jq -n --argjson w "$writes" --argjson e "$emits" --arg rc "$RUN_RC" \
        '{writes:$w,emits:$e,rc:($rc|tonumber)}'
}



gen_one(){  # emits contract/v1 for one script
  local S="$1"; echo "gen $S"

  local pj tools envs
  pj="$(probe "$S")"
  tools="$(jq -r '.external? // [] | unique | @json' <<<"$pj")"
  envs="$(jq -r '.data? // [] | unique | map({key:.,val:""}) | from_entries | @json' <<<"$pj")"

  local NO_RUN RUN_ARGS ENV_HINT SEED SCRAPE
  NO_RUN="$(hint "$S" no_run)"
  RUN_ARGS="$(hint "$S" run)";             [[ -z "$RUN_ARGS" ]] && RUN_ARGS='["--json"]'
  ENV_HINT="$(hint "$S" env)";             [[ -z "$ENV_HINT" ]] && ENV_HINT='{}'
  SEED="$(hint "$S" seed_files)";          [[ -z "$SEED" ]] && SEED='["events.ndjson"]'
  SCRAPE="$(hint "$S" scrape_headings)";   [[ -z "$SCRAPE" ]] && SCRAPE="0"

  local writes emits rc triple
  if [[ "$NO_RUN" == "true" ]]; then
    writes='[]'; emits='[]'; rc=0
  else
    triple="$(sandbox "$S" "$RUN_ARGS" "$ENV_HINT" "$SEED" "$SCRAPE")"
    writes="$(jq -r '.writes' <<<"$triple")"
    emits="$(jq -r '.emits'  <<<"$triple")"
    rc="$(jq -r '.rc'       <<<"$triple")"
  fi

  local READS TOOLS_OVR ARGS_OVR EXIT_OVR
  READS="$(hint "$S" contract_reads)";     [[ -z "$READS" ]] && READS='"script; optional events.ndjson; no network"'
  TOOLS_OVR="$(hint "$S" contract_tools)"; [[ -z "$TOOLS_OVR" ]] && TOOLS_OVR="$tools"
  ARGS_OVR="$(hint "$S" contract_args)";   [[ -z "$ARGS_OVR" ]] && ARGS_OVR='["…"]'
  EXIT_OVR="$(hint "$S" contract_exit)";   [[ -z "$EXIT_OVR" ]] && EXIT_OVR='{ "ok": 0 }'

  jq -n --argjson env "$envs" --argjson tools "$TOOLS_OVR" --argjson emits "$emits" \
        --argjson writes "$writes" --argjson exit "$EXIT_OVR" --argjson args "$ARGS_OVR" \
        --arg reads "$READS" '
  {
    contract_schema:"contract/v1",
    args:$args, env:$env, reads:$reads, writes:$writes,
    tools:$tools, exit:$exit, emits:$emits
  }' > "$OUTDIR/${S//\//_}.json"
}

if (($#)); then for s in "$@"; do gen_one "$s"; done
else while IFS= read -r s; do gen_one "$s"; done < <(git ls-files '*.sh' '*.py'); fi

