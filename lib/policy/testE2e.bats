# testE2e.bats
setup() {
  export here="$BATS_TEST_DIRNAME"
  export runner="$here/runner.sh"   # adjust if needed
  mkdir -p "$BATS_TMPDIR/repo/config" "$BATS_TMPDIR/repo/bin"
  # Minimal policy: only main.sh
  cat >"$BATS_TMPDIR/repo/config/policy.rules.yml" <<'YAML'
- type: invariant
  path: main.sh
  condition: must_exist
  action: error
YAML
  # Create file to satisfy policy
  : >"$BATS_TMPDIR/repo/main.sh"

  # Mock p1/p2/p3 so the test isolates root anchoring
  cat >"$BATS_TMPDIR/p1.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Emit a single canonical rule for main.sh
printf '%s\n' '{"id":"r1","type":"invariant","path":"main.sh","condition":"must_exist","action":"error"}'
SH
  cat >"$BATS_TMPDIR/p2.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat    # identity transform
SH
  cat >"$BATS_TMPDIR/p3.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
ok=0
while IFS= read -r line; do
  path=$(printf '%s' "$line" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')
  [[ -n "${SDT_ROOT:-}" ]] || { echo "no SDT_ROOT" >&2; exit 70; }
  if [[ -f "$SDT_ROOT/$path" ]]; then : ; else ok=1; fi
done
exit $ok
SH
  chmod +x "$BATS_TMPDIR"/p{1,2,3}.sh
}

@test "E2E anchors to repo root from subdir" {
  cd "$BATS_TMPDIR/repo/bin"
  run "$runner" --no-git --p1 "$BATS_TMPDIR/p1.sh" --p2 "$BATS_TMPDIR/p2.sh" --p3 "$BATS_TMPDIR/p3.sh"
  echo "$output" >&2
  [ "$status" -eq 0 ]
  [[ "$output" =~ root= ]]  # runner prints root and policy path
  [[ "$output" =~ root=/$BATS_TMPDIR/repo($|[[:space:]]) ]]
  [[ "$output" =~ policy=.*/repo/config/policy\.rules\.yml ]]
  
}


