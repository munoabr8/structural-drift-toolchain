#!/usr/bin/env bash
# Usage: prepare-ref.sh <ref> <github_output_file>
set -euo pipefail

REF_RAW="${1:-main}"
OUT="${2:-$GITHUB_OUTPUT}"

git config --global --add safe.directory "$(pwd)"

trim_ref() {
  local r="$1"
  r="${r//[[:space:]]/}"                 # strip spaces
  case "$r" in
    refs/heads/*) echo "${r#refs/heads/}";;
    heads/*)      echo "${r#heads/}";;
    origin/*)     echo "${r#origin/}";;  # tolerate origin/foo
    *)            echo "$r";;
  esac
}

REF_CLEAN="$(trim_ref "$REF_RAW")"

# Branch on origin?
if git ls-remote --exit-code --heads origin "$REF_CLEAN" >/dev/null 2>&1; then
  git fetch origin "$REF_CLEAN" --prune
  git checkout -B "$REF_CLEAN" "origin/$REF_CLEAN"
  echo "branch=$REF_CLEAN" >> "$OUT"
  exit 0
fi

# PR ref (e.g., refs/pull/123/merge or exact remote ref)
if git ls-remote --exit-code origin "$REF_RAW" >/dev/null 2>&1; then
  git fetch origin "$REF_RAW" --prune
  git checkout --detach FETCH_HEAD
  echo "branch=" >> "$OUT"
  exit 0
fi

# Direct SHA
if git rev-parse --verify "$REF_CLEAN^{commit}" >/dev/null 2>&1; then
  git checkout --detach "$REF_CLEAN"
  echo "branch=" >> "$OUT"
  exit 0
fi

echo "ref not found: '$REF_RAW' (normalized: '$REF_CLEAN')" >&2
exit 65
