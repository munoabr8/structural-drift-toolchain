 #!/usr/bin/env bash
set -euo pipefail

# Install locations inside .git/hooks
PRE_PUSH_DEST="../.git/hooks/pre-push"
PRE_COMMIT_DEST="../.git/hooks/pre-commit"

# Version‑controlled templates
PRE_PUSH_TEMPLATE="../tools/git-hooks/pre-push"
PRE_COMMIT_TEMPLATE="../tools/git-hooks/pre-commit"

echo "🔧 Installing Git pre‑push hook…"
if [ ! -f "$PRE_PUSH_TEMPLATE" ]; then
  echo "❌ Missing hook template at: $PRE_PUSH_TEMPLATE"
  exit 1
fi
cp "$PRE_PUSH_TEMPLATE" "$PRE_PUSH_DEST"
chmod +x "$PRE_PUSH_DEST"
echo "✅ Pre‑push hook installed at $PRE_PUSH_DEST"

echo "🔧 Installing Git pre‑commit hook…"
if [ ! -f "$PRE_COMMIT_TEMPLATE" ]; then
  echo "❌ Missing hook template at: $PRE_COMMIT_TEMPLATE"
  exit 1
fi
cp "$PRE_COMMIT_TEMPLATE" "$PRE_COMMIT_DEST"
chmod +x "$PRE_COMMIT_DEST"
echo "✅ Pre‑commit hook installed at $PRE_COMMIT_DEST"
