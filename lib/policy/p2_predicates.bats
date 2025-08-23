setup() {
  # resolve repo root
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"

  # normalize env (avoid host leakage)
  export LC_ALL=C PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
  export CODE_ROOT="$REPO_DIR"
  : "${POLICY_SRC_TRANSFORM:="$REPO_DIR/policy/transform_policy_p2.sh"}"
  TRANSFORM="$REPO_DIR/policy/transform_policy_rules"   # shim

  # per-test sandbox
  TMPROOT="$BATS_TEST_TMPDIR/$BATS_TEST_NAME"
  mkdir -p "$TMPROOT"
  cd "$TMPROOT" || exit 1

  # assertions (fail fast with clear messages)
  [[ -x "$TRANSFORM" ]]        || { echo "missing or not executable: $TRANSFORM"; return 1; }
  [[ -r "$POLICY_SRC_TRANSFORM" ]] || { echo "missing or unreadable: $POLICY_SRC_TRANSFORM"; return 1; }

  # verify we can source the real script in a clean bash
  run env -i LC_ALL=C PATH="$PATH" CODE_ROOT="$REPO_DIR" POLICY_SRC_TRANSFORM="$POLICY_SRC_TRANSFORM" \
    bash --noprofile --norc -lc 'source "$POLICY_SRC_TRANSFORM"'
  [ "$status" -eq 0 ] || { echo "source failed: $POLICY_SRC_TRANSFORM"; return 1; }

  # helper: ensure bash is available (macOS may have old bash)
  BASH_BIN="$(command -v bash)"
  [[ -x "$BASH_BIN" ]] || { echo "bash not found in PATH"; return 1; }
}

teardown() {
  # leave artifacts for debugging only on failure
  if [[ "$BATS_TEST_COMPLETED" != "1" ]]; then
    echo "kept sandbox: $TMPROOT"
  else
    rm -rf "$TMPROOT"
  fi
}

# optional helpers
assert_status() { [ "$status" -eq "${1:-0}" ]; }
run_transform_stdin() {  # usage: run_transform_stdin $'line\n...'
  run "$TRANSFORM" <<<"$1"
}