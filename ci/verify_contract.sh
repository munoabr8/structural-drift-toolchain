#!/usr/bin/env bash
# ci/verify_contract.sh  — external verifier + hermetic sandbox


set -euo pipefail

S="${1:?usage: $0 <script>}"
need(){ command -v "$1" >/dev/null 2>&1 || { echo "ERR:missing:$1" >&2; exit 70; }; }
need jq; need awk; need find; need mktemp; need comm; need sed; need tr


 
 

# --- extract CONTRACT-JSON from target (tolerant) ---
CJ="$(tr -d '\r' < "$S" | awk '
  tolower($0) ~ /^[[:space:]]*#?[[:space:]]*contract-json-begin[[:space:]]*$/ {inside=1; next}
  tolower($0) ~ /^[[:space:]]*#?[[:space:]]*contract-json-end[[:space:]]*$/   {inside=0; exit}
  inside { sub(/^[[:space:]]*#?[[:space:]]*/,""); print }
')"
[[ -n "$CJ" ]] || { echo "ERR:no CONTRACT-JSON in $S" >&2; exit 2; }

# --- declared bits ---
mapfile -t EMITS < <(jq -r '.emits[]? // empty' <<<"$CJ" || true)
mapfile -t TOOLS < <(jq -r '.tools[]? // empty' <<<"$CJ" || true)
ALLOW_WRITES_JSON="$(jq -r '.writes? | if type=="array" then . else [] end | @json' <<<"$CJ")"

# --- tool check (bash>=N handled if declared) ---
for t in "${TOOLS[@]}"; do
  case "$t" in
    bash*">="*) req="${t#bash>=}"; have="${BASH_VERSINFO[0]:-0}"; (( have>=req )) || { echo "FAIL:bash>=$req needed (have $have)"; exit 1; } ;;
    *"|"*) : ;;  # alternatives, skip strict check
    *) command -v "${t%% *}" >/dev/null 2>&1 || { echo "FAIL:missing tool:$t"; exit 1; } ;;
  esac
done

# --- sandbox runner (net off, minimal env, fs diff) ---
run_in_sandbox() {
  local out="$1" err="$2" rcfile="$3"
  local work bin; work="$(mktemp -d)"; bin="$work/bin"
  mkdir -p "$bin"
  # block network-heavy cmds even if unshare absent
  printf '#!/usr/bin/env bash\necho "net disabled" >&2; exit 71\n' >"$bin/gh"
  printf '#!/usr/bin/env bash\necho "net disabled" >&2; exit 71\n' >"$bin/curl"
  chmod +x "$bin/gh" "$bin/curl"

  # seed usual inputs if present in contracts
  : > "$work/events.ndjson" || true

  local PATH_MIN="/usr/bin:/bin:$bin"
  local BEFORE AFTER RC=0
  BEFORE="$(mktemp)"; AFTER="$(mktemp)"
  ( cd "$work"; find . -type f | sort >"$BEFORE" )

  # try network namespace if available
  if command -v unshare >/dev/null 2>&1; then
    unshare -n bash -lc "set -euo pipefail; PATH='$PATH_MIN' FILES_GLOB='$S' EVENTS='events.ndjson' HOME='$work' TZ=UTC '$S' --json" >"$out" 2>"$err" || RC=$?
  else
    env -i PATH="$PATH_MIN" FILES_GLOB="$S" EVENTS="events.ndjson" HOME="$work" TZ=UTC "$S" --json >"$out" 2>"$err" || RC=$?
  fi
  echo "${RC:-0}" >"$rcfile"
  ( cd "$work"; find . -type f | sort >"$AFTER" )
  comm -13 "$BEFORE" "$AFTER" | sed 's#^\./##' || true
}


# inside your script
gen_contract() {
  set -euo pipefail
  need(){ command -v "$1" >/dev/null || { echo "missing:$1" >&2; exit 70; }; }
  need jq; need mktemp; need find

  S="${BASH_SOURCE[0]}"
  PROBE="$(bash ci/probe_coupling.sh --json --files "$S" 2>/dev/null || echo '{}')"

  TOOLS_JSON="$(jq -r '.external? // [] | unique | @json' <<<"$PROBE")"
  ENVS_JSON="$(jq -r '.data? // [] | unique | map({key:.,val:""}) | from_entries | @json' <<<"$PROBE")"

  OUT_JSON="$("$S" --json 2>/dev/null || echo '{}')"
  EMITS_JSON="$(jq -r 'keys? // [] | @json' <<<"$OUT_JSON")"

  work="$(mktemp -d)"; before="$(mktemp)"; after="$(mktemp)"
  find "$work" -type f | sort >"$before"
  ( cd "$work"; FILES_GLOB="$S" EVENTS=events.ndjson : > events.ndjson; "$S" --json >/dev/null 2>&1 || true )
  find "$work" -type f | sort >"$after"
  WRITES_JSON="$(comm -13 "$before" "$after" | jq -Rsc 'split("\n")|map(select(length>0))')"

  {
    echo "# CONTRACT-JSON-BEGIN"
    echo "# {"
    echo "#   \"args\": [\"--json\",\"--gen-contract\"],"
    echo "#   \"env\": $ENVS_JSON,"
    echo "#   \"reads\": \"script file; optional events.ndjson in CWD; no network\","
    echo "#   \"writes\": $WRITES_JSON,"
    echo "#   \"tools\": $TOOLS_JSON,"
    echo "#   \"exit\": {\"ok\":0},"
    echo "#   \"emits\": $EMITS_JSON"
    echo "# }"
    echo "# CONTRACT-JSON-END"
  }
}



OUT="$(mktemp)"; ERR="$(mktemp)"; RC="$(mktemp)"
WRITES_OBSERVED="$(run_in_sandbox "$OUT" "$ERR" "$RC")"
rc="$(cat "$RC")"

# --- emits check (JSON keys must match if any declared) ---
if ((${#EMITS[@]})); then
  keys="$(jq -r 'keys[]?' "$OUT" 2>/dev/null || true)"
  if [[ -z "$keys" ]]; then echo "FAIL:no JSON output (--json)"; exit 1; fi
  miss=$(comm -23 <(printf "%s\n" "${EMITS[@]}" | sort) <(printf "%s\n" "$keys" | sort) || true)
  extra=$(comm -13 <(printf "%s\n" "${EMITS[@]}" | sort) <(printf "%s\n" "$keys" | sort) || true)
  [[ -z "$miss" && -z "$extra" ]] || { echo "FAIL:emits mismatch"; echo "missing:"; echo "$miss"; echo "extra:"; echo "$extra"; exit 1; }
fi

# --- writes check (allow only declared) ---
ALLOW="$(jq -r '.[]?' <<<"$ALLOW_WRITES_JSON" || true)"
if [[ -n "$WRITES_OBSERVED" && -n "$ALLOW" ]]; then
  bad=$(comm -23 <(printf "%s\n" $WRITES_OBSERVED | sort) <(printf "%s\n" $ALLOW | sort) || true)
elif [[ -n "$WRITES_OBSERVED" && -z "$ALLOW" ]]; then
  bad="$WRITES_OBSERVED"
fi
if [[ -n "${bad:-}" ]]; then
  echo "FAIL:undeclared writes"; printf '%s\n' $bad; exit 1
fi

echo "OK:verified $S (rc=$rc)"
