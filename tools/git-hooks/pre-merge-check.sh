#!/usr/bin/env bash
# ./tools/pre-merge-check.sh

# Get current branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Smart default: if current branch is not main, assume main is target
DEFAULT_TARGET_BRANCH="main"
[[ "$CURRENT_BRANCH" == "$DEFAULT_TARGET_BRANCH" ]] && DEFAULT_TARGET_BRANCH="dev"

# Use provided arg or fallback to inferred target
TARGET_BRANCH="${1:-$DEFAULT_TARGET_BRANCH}"


if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
  echo "⚠️ You're trying to merge a branch into itself. Check your arguments."
  exit 1
fi


REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "🔁 Pre-merge check against $TARGET_BRANCH"
git fetch origin "$TARGET_BRANCH"


if ! git diff --quiet; then
  echo "⚠️ Uncommitted changes detected. Please stash or commit before running pre-merge check."
  exit 1
fi

if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
  echo "⚠️ Staged changes exist. Please commit or stash them first."
  exit 1
fi

# Dry-run merge
echo "🔍 Simulating merge..."
git merge --no-commit --no-ff "$TARGET_BRANCH" || {
  echo "❌ Merge conflict detected."
  afplay /System/Library/Sounds/Basso.aiff
  git merge --abort
  exit 1
}

# Run preflight checks
make preflight

# Optional: confirm structure post-merge
make validate

# Abort merge — this is a dry run
git merge --abort
echo "✅ Merge would succeed with all checks passing."
afplay /System/Library/Sounds/Glass.aiff
