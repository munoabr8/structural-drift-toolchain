#!/usr/bin/env bash
# Smoke test for tools/scope_guard.sh
set -euo pipefail

need(){ command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 4; }; }
need bash; need git; need yq

# Locate repo root and guard
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
GUARD="$REPO_ROOT/tools/scope-guard.sh"
[[ -x "$GUARD" ]] || { echo "guard not executable: $GUARD" >&2; exit 4; }

# Temp repo
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q
git config user.email a@b.c
git config user.name t

# Minimal tree + scope
mkdir -p bin lib util tools .github/workflows
cat > scope.yaml <<'YAML'
in_scope:
  - structure.spec
  - bin/**
  - lib/**
  - util/**
YAML
printf '# spec\n' > structure.spec
install -m 0755 "$GUARD" ./scope-guard.sh
git add .
git commit -q -m init

echo "[1/2] Expect PASS on in-scope change"
echo "echo hi" > bin/x.sh
git add bin/x.sh
# Check staged vs HEAD only
if BASE=HEAD bash ./scope-guard.sh | tee /dev/stderr | grep -q "scope_guard: ok"; then
  echo "PASS: in-scope"
else
  echo "FAIL: in-scope should pass" >&2; exit 1
fi
git reset -q --hard

echo "[2/2] Expect FAIL on UNMAPPED path"
mkdir -p scripts
echo "echo hi" > scripts/y.sh
git add scripts/y.sh
set +e
BASE=HEAD bash ./scope-guard.sh >out.txt 2>&1
rc=$?
set -e
if [[ $rc -eq 3 ]] && grep -q "UNMAPPED: scripts/y.sh" out.txt; then
  echo "PASS: unmapped fail (rc=3)"
else
  echo "FAIL: unmapped should fail with rc=3"; cat out.txt; exit 1
fi

echo "SMOKE: OK"

