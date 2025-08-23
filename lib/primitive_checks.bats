#!/usr/bin/env bats
# Minimal, no deps. Run: bats -r test
setup() {
  LIB="$BATS_TEST_DIRNAME/../lib"
  QP="$LIB/predicates.sh"
  QQ="$LIB/queries.sh"
  [[ -f "$QP" && -f "$QQ" ]] || skip "lib missing"
  TMPDIR="$BATS_TEST_TMPDIR"; export TMPDIR
  : >"$TMPDIR/empty"; printf 'x\n' >"$TMPDIR/nonempty"; mkdir -p "$TMPDIR/dir"


  source "$QP"
  source "$QQ"


}

teardown() { :; }
 
# ---------- Predicates (pure) ----------
@test "is_nonempty returns success for nonempty" {
  is_nonempty_str "x"
}

@test "is_nonempty returns failure for empty" {
  ! is_nonempty ""
}

# Add more pure predicates here as you write them.

# ---------- Queries (environment-facing) ----------
@test "path_is_file true on file, false on dir" {
  path_is_file "$TMPDIR/nonempty"
  ! path_is_file "$TMPDIR/dir"
}

@test "path_is_dir true on dir, false on file" {
  path_is_dir "$TMPDIR/dir"
  ! path_is_dir "$TMPDIR/nonempty"
}

@test "is_readable flips with chmod" {
  is_readable "$TMPDIR/nonempty"
  chmod 000 "$TMPDIR/nonempty"
  ! is_readable "$TMPDIR/nonempty"
  chmod 600 "$TMPDIR/nonempty"
}

@test "is_nonempty_file true on nonempty, false on empty" {
  is_nonempty_file "$TMPDIR/nonempty"
  ! is_nonempty_file "$TMPDIR/empty"
}

@test "stdin_present true when piped" {
  run bash -lc "source \"$QP\"; source \"$QQ\"; echo data | stdin_is_nontty"
  [ "$status" -eq 0 ]
}

@test "stdin_present false at TTY" {
  command -v script >/dev/null || skip "script not installed"
  run script -q /dev/null bash -lc "source \"$QP\"; source \"$QQ\"; stdin_is_nontty"
  [ "$status" -ne 0 ]
}


@test "is_tty_stdin true at TTY, false when piped" {
  # true at TTY
  command -v script >/dev/null || skip "script not installed"
  run script -q /dev/null bash -lc "source \"$QQ\"; is_tty_stdin"
  [ "$status" -eq 0 ]

  # false when piped
  run bash -lc "source \"$QQ\"; echo x | is_tty_stdin"
  [ "$status" -ne 0 ]
}

@test "stdin_ready detects available bytes (bash>=4)" {
  # skip on old macOS bash 3.x
  v="$(bash -lc 'echo ${BASH_VERSINFO[0]}')"
  [ "$v" -ge 4 ] || skip "needs Bash >= 4"

  run bash -lc "source \"$QQ\"; echo hi | stdin_ready"
  [ "$status" -eq 0 ]

  run bash -lc "source \"$QQ\"; stdin_ready"
  [ "$status" -ne 0 ]
}
@test "fn_defined sees functions in current shell" {
  run bash -lc "f(){ :; }; source \"$QQ\"; fn_defined f"
  [ "$status" -eq 0 ]

  run bash -lc "source \"$QQ\"; fn_defined no_such_fn"
  [ "$status" -ne 0 ]
}