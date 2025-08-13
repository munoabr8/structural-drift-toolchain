#!/usr/bin/env bash
set -euo pipefail

P2="$PWD/transform_policy_p2.sh"
P3="$PWD/enforce_policy_p3.sh"
[[ -f "$P2" && -f "$P3" ]] || { echo "missing P2 or P3 in $PWD" >&2; exit 127; }

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX"

mkdir -p bin
: > README.md
cat > policy.tsv <<'TSV'
invariant	bin	must_exist	error
invariant	README.md	must_exist	error
TSV

# happy path
bash -o pipefail -c "cat policy.tsv | bash \"$P2\" | bash \"$P3\""
echo "OK:$?"

# failure path
rm -f README.md
set +e; bash -o pipefail -c "cat policy.tsv | bash \"$P2\" | bash \"$P3\""; rc=$?; set -e
echo "FAIL:$rc"
