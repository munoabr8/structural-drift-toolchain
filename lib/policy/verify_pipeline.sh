#!/usr/bin/env bash
# verify_pipeline.sh
set -euo pipefail

# Config (override via env)
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)}"
POLICY="${POLICY:-$ROOT/config/policy.rules.yml}"
S1="${S1:-$ROOT/lib/policy/policy_query_p1.sh}"          # section 1 runner
S2="${S2:-$ROOT/lib/policy/transform_policy_rules_shim}"              # section 2 shim

die(){ echo "ERR: $*" >&2; exit 1; }

[[ -r "$POLICY" ]] || die "policy not readable: $POLICY"
[[ -x "$S1" ]]     || die "S1 not executable: $S1"
[[ -x "$S2" ]]     || die "S2 not executable: $S2"

# --- Run Section 1 (YAML -> TSV). Keep stderr separate (events live there).
s1_out="$(bash --noprofile --norc "$S1" --stdin < "$POLICY")" || die "S1 failed"
[[ -n "$s1_out" ]] || die "S1 produced no TSV"
grep -q $'\t' <<<"$s1_out" || die "S1 output lacks tab separators"
grep -q '^Usage:' <<<"$s1_out" && die "S1 leaked yq usage to stdout"

# --- Run Section 2 (TSV -> pipe5)
s2_out="$(printf '%s\n' "$s1_out" | "$S2")" || die "S2 failed"
[[ -n "$s2_out" ]] || die "S2 produced no records"

# Invariant 1: same number of rows
n1="$(printf '%s\n' "$s1_out" | wc -l | tr -d '[:space:]')"
n2="$(printf '%s\n' "$s2_out" | wc -l | tr -d '[:space:]')"
[[ "$n1" = "$n2" ]] || die "row count mismatch: S1=$n1 S2=$n2"
echo "OK: row counts match ($n1)"

# Invariant 2: S2 rows are 5-field pipes and mode ∈ {literal,regex}
printf '%s\n' "$s2_out" | grep -Eq '^[^|]+\|[^|]+\|[^|]+\|[^|]+\|(literal|regex)$' \
  || die "S2 rows not 5-field pipe with valid mode"
echo "OK: S2 rows shape and mode set"

# Inference check on first row
IFS=$'\t' read -r _ path _ _ <<<"$(printf '%s\n' "$s1_out" | head -n1)"
first_s2="$(printf '%s\n' "$s1_out" | head -n1 | "$S2" | head -n1)"
mode_actual="${first_s2##*|}"  # 5th field
if [[ $path =~ [][\(\){}^$*+?\|\\] ]]; then
  [[ "$mode_actual" = "regex" ]] || die "mode inference wrong: expected regex, got $mode_actual (path=$path)"
else
  [[ "$mode_actual" = "literal" ]] || die "mode inference wrong: expected literal, got $mode_actual (path=$path)"
fi
echo "OK: mode inference on first row ($mode_actual) is correct"

echo "All checks passed."
