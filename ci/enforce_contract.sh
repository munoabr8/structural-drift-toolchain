#!/usr/bin/env bash

# CONTRACT-JSON-BEGIN
# {
#   "args": ["<script>"],
#   "env": {},
#   "reads": "the target script file passed as <script>; parses its CONTRACT-JSON; no network",
#   "writes": "stdout status lines; stderr for errors; no files",
#   "tools": ["bash>=4","awk","grep","sed","sort","comm","jq","tr"],
#   "exit": { "ok": 0, "enforcement_failed": 1, "missing_contract_or_cli": 2 },
#   "emits": ["OK:*","FAIL:*","ENFORCED:*"],
#   "notes": "Executes the target script during checks with FILES_GLOB=<script> and EVENTS=/dev/null; any side effects come from the target."
# }
# CONTRACT-JSON-END


# ci/enforce_contract.sh <script>
set -euo pipefail
S="${1:?usage: $0 <script>}"

# --- extract CONTRACT-JSON ---
CJ="$(tr -d '\r' < "$S" | awk '
  tolower($0) ~ /^[[:space:]]*#?[[:space:]]*contract-json-begin[[:space:]]*$/ {inside=1; next}
  tolower($0) ~ /^[[:space:]]*#?[[:space:]]*contract-json-end[[:space:]]*$/   {inside=0; exit}
  inside { sub(/^[[:space:]]*#?[[:space:]]*/,""); print }
')"
[[ -n "$CJ" ]] || { echo "ERR:no CONTRACT-JSON block in $S" >&2; exit 2; }

# --- parse contract ---
args=($(jq -r '.args[]?'    <<<"$CJ" || true))
emits=($(jq -r '.emits[]?'  <<<"$CJ" || true))
tools=($(jq -r '.tools[]?'  <<<"$CJ" || true))
mapfile -t env_keys < <(jq -r '.env|keys[]?' <<<"$CJ" || true)

fail(){ echo "FAIL:$*"; exit 1; }
note(){ echo "OK:$*"; }

# --- tools check ---
for t in "${tools[@]}"; do
  case "$t" in
    bash*">="*) req="${t#bash>=}"; v="${BASH_VERSINFO[0]:-0}"; (( v >= req )) || fail "need $t, have $v";;
    *) command -v "$t" >/dev/null 2>&1 || fail "missing tool:$t";;
  esac
done
note "tools present"

# --- env dependency check (shell scripts) ---
# external env deps = reads – defs
env_reads(){ grep -ohE '\$[A-Z][A-Z0-9_]*|\$\{[A-Z][A-Z0-9_:-]*\}' -- "$S" 2>/dev/null \
  | sed -E 's/^\$\{?([A-Z][A-Z0-9_]*)[^}]*\}?$/\1/' | sort -u; }
defined_vars(){ grep -ohE '(^|[[:space:]])(local[[:space:]]+)?([A-Z][A-Z0-9_]*)=' -- "$S" 2>/dev/null \
  | sed -E 's/.*(local[[:space:]]+)?([A-Z][A-Z0-9_]*)=.*/\2/' | sort -u; }

mapfile -t R < <(env_reads || true)
mapfile -t D < <(defined_vars || true)
viol=$(comm -23 <(printf "%s\n" "${R[@]}") <(printf "%s\n" "${D[@]}") | grep -vxF -e "$(printf "%s\n" "${env_keys[@]}")" || true)
if [[ -n "${viol:-}" ]]; then
  echo "FAIL: undeclared env deps:"
  printf '  %s\n' $viol
  exit 1
fi
note "env deps ⊆ contract.env"

# --- args smoke tests (accept listed flags) ---
# Try known flags if present in contract
run_ok(){ "$S" "$@" >/dev/null 2>&1; }
[[ " ${args[*]} " == *"--help"* ]] && run_ok --help || true

# Provide minimal values for placeholders
FILES_GLOB="$S" EVENTS="/dev/null" export FILES_GLOB EVENTS

# Require --json to work and emit expected keys
out_json="$("$S" --json 2>/dev/null || true)"
[[ -n "$out_json" ]] || fail "--json produced no output"
missing=$(jq -r 'keys[]' <<<"$out_json" | sort | comm -23 <(printf "%s\n" "${emits[@]}" | sort) - || true)
extra=$(jq -r 'keys[]' <<<"$out_json" | sort | comm -13 - <(printf "%s\n" "${emits[@]}" | sort) || true)
[[ -z "$missing" && -z "$extra" ]] || {
  echo "FAIL: emits mismatch"
  echo "  missing: $(printf '%s ' $missing)"
  echo "  extra:   $(printf '%s ' $extra)"
  exit 1
}
note "emits match"

# --- exit code contract: unknown flag → 2 (if specified) ---
if jq -e '.exit | type=="object" and .cli==2' >/dev/null <<<"$CJ"; then
  set +e; "$S" --def-not-a-flag >/dev/null 2>&1; rc=$?; set -e
  (( rc == 2 )) || fail "expected exit 2 on bad flag, got $rc"
  note "exit(2) on CLI error"
fi

echo "ENFORCED: $S"
