#!/usr/bin/env bats

normalize() { ( cd "$1" >/dev/null 2>&1 && pwd -P ) || printf '%s\n' "$1"; }
mk_repo()    { repo="$(mktemp -d "${BATS_TMPDIR}/repo.XXXXXX")"; mkdir -p "$repo/bin" "$repo/config"; }
min_policy() { cat >"$repo/config/policy.rules.yml" <<'YAML'
- type: invariant
  path: main.sh
  condition: must_exist
  action: error
YAML
}

setup() {
  runner="$BATS_TEST_DIRNAME/runner.sh"
  [ -x "$runner" ] || { echo "runner not executable: $runner"; false; }

  mk_repo; : >"$repo/main.sh"; min_policy

  p1="$BATS_TMPDIR/p1.sh"; p2="$BATS_TMPDIR/p2.sh"; p3="$BATS_TMPDIR/p3.sh"; p3fail="$BATS_TMPDIR/p_3fail.sh"

  cat >"$p1" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '{"id":"r1","type":"invariant","path":"main.sh","condition":"must_exist","action":"error"}'
SH
  cat >"$p2" <<'SH'
#!/usr/bin/env bash
cat
SH
  cat >"$p3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "p3:SDT_ROOT=${SDT_ROOT:-}" >&2
while IFS= read -r line; do
  path=$(sed -n 's/.*"path":"\([^"]*\)".*/\1/p' <<<"$line"); abs="$SDT_ROOT/$path"
  [ -d "$abs" ] && { echo "violation reason=type=directory path=$path" >&2; exit 1; }
  [ -L "$abs" ] && [ ! -e "$abs" ] && { echo "violation reason=broken-symlink path=$path" >&2; exit 1; }
  [ -e "$abs" ] || { echo "violation reason=not-found path=$path" >&2; exit 1; }
done
echo "ok" >&2
SH
  cat >"$p3fail" <<'SH'
#!/usr/bin/env bash
exit 42
SH
  chmod +x "$p1" "$p2" "$p3" "$p3fail"
}

teardown() { rm -rf "$repo"; }

run_runner() { cd "$repo/bin"; run "$runner" --no-git --p1 "$p1" --p2 "$p2" --p3 "$p3" 2>&1; }

@test "root detection from subdir" {
  run_runner
  [ "$status" -eq 0 ]
  want="$(normalize "$repo")"
  got_root="$(grep -oE 'root=[^[:space:]]+' <<<"$output" | cut -d= -f2-)"
  pol="$(grep -oE 'policy=[^[:space:]]+' <<<"$output" | cut -d= -f2-)"
  p3r="$(grep -oE 'p3:SDT_ROOT=[^[:space:]]+' <<<"$output" | cut -d= -f2-)"
  [ "$(normalize "$got_root")" = "$want" ]
  [[ "$pol" = "$got_root"/config/policy.rules.yml ]]
  [ "$(normalize "$p3r")" = "$want" ]
}

@test "missing main.sh fails with reason" {
  rm -f "$repo/main.sh"
  run_runner
  [ "$status" -ne 0 ]
  [[ "$output" == *"reason=not-found"* ]]
}

@test "directory main.sh fails with reason" {
  rm -f "$repo/main.sh"; mkdir -p "$repo/main.sh"
  run_runner
  [ "$status" -ne 0 ]
  [[ "$output" == *"reason=type=directory"* ]]
}

@test "p3 exit code propagates" {
  cd "$repo/bin"
  run "$runner" --no-git --p1 "$p1" --p2 "$p2" --p3 "$p3fail" 2>&1
  [ "$status" -eq 42 ]
}
