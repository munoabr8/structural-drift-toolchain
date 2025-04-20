#!/usr/bin/env bash
set -euo pipefail

HOOK_PATH=".git/hooks/pre-push"
TEMPLATE_PATH="./tools/git-hooks/pre-push"

echo "🔧 Installing Git pre-push hook..."

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "❌ Missing hook template at: $TEMPLATE_PATH"
  exit 1
fi

cp "$TEMPLATE_PATH" "$HOOK_PATH"
chmod +x "$HOOK_PATH"

echo "✅ Git hook installed at $HOOK_PATH"