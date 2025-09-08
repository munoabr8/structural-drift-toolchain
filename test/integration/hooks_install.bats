#!/usr/bin/env bash
# test/hooks_install.bats
setup() {
  set -euo pipefail
  ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
  DST="$(git rev-parse --git-path hooks)"
  SRC="$ROOT/tools/git-hooks"
  HOOKS=(pre-commit pre-push pre-merge-commit post-merge post-rewrite pre-rebase)
}

@test "core.hooksPath mode: zero-copy with executable sources" {
  for h in "${HOOKS[@]}"; do [[ -f "$SRC/$h" ]] || skip "missing $h"; done

  git config --local core.hooksPath tools/git-hooks
  bash ./tools/install-hooks.sh

  run git config --local core.hooksPath
  [ "$status" -eq 0 ]
  [ "$output" = "tools/git-hooks" ]

  for h in "${HOOKS[@]}"; do
    [ -x "$SRC/$h" ]
    [ ! -e "$DST/$h" ]
  done
}


@test "mirror mode: copies are executable and byte-equal" {
  for h in "${HOOKS[@]}"; do [[ -f "$SRC/$h" ]] || skip "missing $h"; done
  git config --local --unset core.hooksPath || true
  bash ./tools/install-hooks.sh
  for h in "${HOOKS[@]}"; do [ -x "$DST/$h" ]; cmp "$SRC/$h" "$DST/$h"; done
  [ -f "$DST/README.mirrored" ]
}