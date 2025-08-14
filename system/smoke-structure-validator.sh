#!/usr/bin/env bash
set -euo pipefail

# Default to your validator path if not provided
VALIDATOR="${VALIDATOR:-./structure_validator.rf.sh}"
# If a CLI arg is given, override
if [[ $# -ge 1 ]]; then VALIDATOR="$1"; fi
# Make absolute so it works after cd into sandbox
VALIDATOR="$(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"




SPEC_OK="ok.spec"

# ---------- framework ----------
_pass=0; _fail=0; _tmp=""
_cleanup(){ [[ -n "$_tmp" && -d "$_tmp" ]] && rm -rf "$_tmp"; }
trap _cleanup EXIT

new_sandbox() {
  _tmp="$(mktemp -d)"
  cd "$_tmp"
}

print_rc(){ printf "rc=%s\n" "${1}" >&2; }

run_case() {
  local name="$1"; shift
  echo "[$name]"
  set +e
  "$@"; rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "  PASS"; _pass=$((_pass+1))
  else
    echo "  FAIL"; print_rc "$rc"; _fail=$((_fail+1))
  fi
}

expect_rc() {
  local expect="$1"; shift
  set +e; "$@"; rc=$?; set -e
  if [[ $rc -eq "$expect" ]]; then return 0; else return 1; fi
}

# ---------- fixtures ----------
make_ok_spec() {
  cat > "$SPEC_OK" <<'EOF'
# minimal good spec
dir: a
file: a/hello.txt
link: a/ln -> hello.txt
EOF
  mkdir -p a
  echo hi > a/hello.txt
  ln -s hello.txt a/ln
}

# ---------- behaviors ----------
  
test_help() {
  new_sandbox
  expect_rc 0 "$VALIDATOR" --help
}



test_missing_spec() {
  new_sandbox
  # absent spec -> expect your EXIT_MISSING_SPEC (default 2 in the minimal script)
  expect_rc 2 "$VALIDATOR" validate does-not-exist.spec

}


test_valid_spec() {
  new_sandbox
  make_ok_spec
  expect_rc 0 "$VALIDATOR" --spec "$SPEC_OK"
}

test_bad_dir() {
  new_sandbox
  make_ok_spec
  sed -i.bak 's/^dir: a$/dir: z/' "$SPEC_OK"
  expect_rc 3 "$VALIDATOR" --spec "$SPEC_OK"
}

test_bad_file() {
  new_sandbox
  make_ok_spec
  sed -i.bak 's#^file: a/hello.txt$#file: a/nope.txt#' "$SPEC_OK"
  expect_rc 3 "$VALIDATOR" --spec "$SPEC_OK"
}

test_bad_link_target() {
  new_sandbox
  make_ok_spec
  sed -i.bak 's#-> hello.txt#-> not.txt#' "$SPEC_OK"
  expect_rc 4 "$VALIDATOR" --spec "$SPEC_OK"
}

# ---------- runner ----------
main() {
  # allow overriding validator path when invoking
  if [[ $# -ge 1 ]]; then VALIDATOR="$1"; fi
  command -v "$VALIDATOR" >/dev/null || { echo "validator not found: $VALIDATOR" >&2; exit 1; }
  chmod +x "$VALIDATOR" || true

  run_case "help"              test_help

  run_case "missing-spec"      test_missing_spec
  run_case "valid-spec"        test_valid_spec
  run_case "bad-dir"           test_bad_dir
  run_case "bad-file"          test_bad_file
  run_case "bad-link-target"   test_bad_link_target

  echo "---"
  echo "passed: $_pass  failed: $_fail"
  [[ $_fail -eq 0 ]]
}

main "$@"

