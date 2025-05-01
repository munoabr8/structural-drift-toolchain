#!/usr/bin/env bash
set -euo pipefail

echo "🧰 Setting up structure enforcement system..."

# Step 1: Ensure core files exist
REQUIRED_FILES=(
  "./../system/structure.spec"
  "./../system/validate_structure.sh"
  "./../Makefile"
  "../../debugtools/structureDebugging.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "❌ Required file missing: $file"
    exit 1
  fi
done

# Step 2: Ensure validate_structure.sh is executable
chmod +x ./../system/validate_structure.sh
chmod +x ../../debugtools/structureDebugging.sh

# Step 3: Offer to install Git hook
HOOK_PATH=".git/hooks/pre-commit"
HOOK_SOURCE="tools/hooks/pre-commit.structure"

if [ -f "$HOOK_SOURCE" ]; then
  if [ ! -f "$HOOK_PATH" ]; then
    echo "🪝 Installing pre-commit hook..."
    cp "$HOOK_SOURCE" "$HOOK_PATH"
    chmod +x "$HOOK_PATH"
    echo "✅ Pre-commit hook installed."
  else
    echo "⚠️  Pre-commit hook already exists. Skipping install."
  fi
else
  echo "⚠️  No pre-commit hook found at $HOOK_SOURCE. Skipping hook setup."
fi

# Step 4: Generate snapshot if not present
if [ ! -f .structure.snapshot ]; then
  echo "📸 Generating initial structure snapshot..."
  bash ../../debugtools/structureDebugging.sh generate_structure_spec > .structure.snapshot
  echo "✅ .structure.snapshot created."
else
  echo "ℹ️  .structure.snapshot already exists. Skipping generation."
fi

echo "✅ Setup complete."
echo ""
echo "Next steps:"
echo "  • make diff-structure"
echo "  • make check-structure-drift"
echo "  • make health"

if ! grep -q "alias diffspec=" ~/.bashrc; then
  echo "alias diffspec='make diff-structure'" >> ~/.bashrc
  echo "✅ Added 'diffspec' alias to ~/.bashrc"
else
  echo "ℹ️  Alias 'diffspec' already present in ~/.bashrc"
fi


echo "🔗 Adding useful developer aliases..."

# Safe for repeat calls
if ! grep -q "alias diffspec=" ~/.bashrc ~/.zshrc 2>/dev/null; then
  echo "alias diffspec='make diff-structure'" >> ~/.bashrc 2>/dev/null || true
  echo "alias diffspec='make diff-structure'" >> ~/.zshrc 2>/dev/null || true
  echo "✅ Alias added to shell profile. Reload your terminal to use 'diffspec'."
else
  echo "ℹ️  Alias 'diffspec' already present."
fi
