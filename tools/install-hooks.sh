#!/usr/bin/env bash
# ./tools/install-hooks.sh
# Install project hooks. Works in two modes:
# 1) core.hooksPath == tools/git-hooks  -> no copy; ensure exec bits.
# 2) default mirror (.git/hooks)        -> copy tracked hooks into runtime dir.

set -euo pipefail

# --- helpers ---------------------------------------------------------------
die(){ echo "error: $*" >&2; exit 1; }
note(){ printf '%s\n' "$*"; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"

ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/tools/git-hooks"
DST="$(git rev-parse --git-path hooks)"   # usually ROOT/.git/hooks

[[ -d "$SRC" ]] || die "missing $SRC"

# Map of tracked source files -> hook filenames
# Keep your existing pre-merge-check.sh but install as pre-merge-commit
declare -A MAP=(
  ["pre-push"]="pre-push"
  ["pre-commit"]="pre-commit"
  ["pre-merge-commit"]="pre-merge-commit"

  ["post-merge"]="post-merge"
  ["post-rewrite"]="post-rewrite"
  ["pre-rebase"]="pre-rebase"


)

# --- detect mode -----------------------------------------------------------
HOOKS_PATH="$(git config --local core.hooksPath || true)"

if [[ -n "$HOOKS_PATH" ]]; then
  # Using core.hooksPath
  # Normalize to absolute path if a relative path is used
  case "$HOOKS_PATH" in
    /*) TARGET="$HOOKS_PATH" ;;
    *)  TARGET="$ROOT/$HOOKS_PATH" ;;
  esac

  if [[ "$TARGET" != "$SRC" ]]; then
    note "config: core.hooksPath → $HOOKS_PATH"
    note "hint: set to tools/git-hooks for zero-copy installs:"
    note "      git config --local core.hooksPath tools/git-hooks"
  fi

  # Ensure all mapped sources exist and are executable
  for src in "${!MAP[@]}"; do
    [[ -f "$SRC/$src" ]] || die "missing: $SRC/$src"
    chmod +x "$SRC/$src" || true
    note "ready (core.hooksPath): $src"
  done

  # Optional: leave a notice in .git/hooks for humans/tools
  mkdir -p "$DST"
  cat >"$DST/README.mirrored" <<'TXT'
Never edit .git/hooks/ directly.
Hooks are versioned in tools/git-hooks/.
This repo prefers: git config --local core.hooksPath tools/git-hooks
TXT

  note "done: core.hooksPath mode (no copies performed)"
  exit 0
fi

# --- mirror mode (.git/hooks runtime copy) ---------------------------------
note "installing to runtime hooks dir: $DST"
mkdir -p "$DST"

for src in "${!MAP[@]}"; do
  from="$SRC/$src"
  to="$DST/${MAP[$src]}"
  [[ -f "$from" ]] || die "missing: $from"
  install -m 0755 "$from" "$to"
  note "installed: $to  ←  $src"
done

# Leave policy notice
cat >"$DST/README.mirrored" <<'TXT'
Never edit .git/hooks/ directly.
These files are copies from tools/git-hooks/.
Re-run tools/git-hooks/install.sh after updates.
TXT

note "done: mirror mode"
