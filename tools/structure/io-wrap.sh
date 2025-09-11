#!/usr/bin/env bash
# io-wrapper.sh — print IO of a script
set -euo pipefail

usage(){ cat <<'H'
Usage:
  io-wrapper.sh -- <CMD> [ARGS...]
Examples:
  echo "hello" | ./io-wrapper.sh -- ./myscript --flag x
H
}

[[ ${1-} == "--" ]] || { usage; exit 2; }
shift
[[ $# -ge 1 ]] || { usage; exit 2; }

CMD=$1; shift
ARGS=( "$@" )

tmp_in=$(mktemp) ; tmp_out=$(mktemp) ; tmp_err=$(mktemp)
trap 'rm -f "$tmp_in" "$tmp_out" "$tmp_err"' EXIT

# Buffer stdin so we can both show it and feed it to the command.
cat >"$tmp_in"

start_ns=$(date +%s%N || true)

# Run and tee outputs (preserve command's stdout/stderr to console).
set +e
bash -c '"$@"' _ "$CMD" "${ARGS[@]}" <"$tmp_in" \
  > >(tee "$tmp_out") \
  2> >(tee "$tmp_err" >&2)
ec=$?
set -e

end_ns=$(date +%s%N || true)
dur_ms=0
if [[ $start_ns =~ ^[0-9]+$ && $end_ns =~ ^[0-9]+$ ]]; then
  dur_ms=$(( (end_ns - start_ns)/1000000 ))
fi

printf '--- CMD ---\n%s' "$CMD"
printf '\n--- ARGS ---\n'
printf '%q ' "${ARGS[@]:-}"; printf '\n'
printf '--- STDIN ---\n';  cat "$tmp_in"  || true
printf '\n--- STDOUT ---\n'; cat "$tmp_out" || true
printf '\n--- STDERR ---\n'; cat "$tmp_err" || true
printf '\n--- EXIT ---\n%d\n' "$ec"
printf '--- DURATION_MS ---\n%d\n' "$dur_ms"

exit "$ec"

