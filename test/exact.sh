#!/usr/bin/env bash
# Hermetic test: exact SHA pairing (no fallback)
set -euo pipefail

# repo root
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PY=python3
SCRIPT_REL="ci/dora/compute-dora.py"   # you said this is the correct path
SCRIPT="$ROOT/$SCRIPT_REL"

# deps
command -v jq >/dev/null || { echo "jq required"; exit 70; }
command -v "$PY" >/dev/null || { echo "python3 required"; exit 70; }
[ -f "$SCRIPT" ] || { echo "missing $SCRIPT_REL"; exit 66; }

# tmp workspace
TMPROOT="$ROOT/.tmp.dora"
mkdir -p "$TMPROOT"
TMPDIR="$(mktemp -d "$TMPROOT/run.XXXXXX")"
cd "$TMPDIR"

# fixture
FIX="$TMPDIR/exact.ndjson"
cat >"$FIX" <<'JSON'
{"type":"pr_merged","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","merged_at":"2025-01-01T00:00:00Z","pr":1}
{"type":"deployment","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","status":"success","finished_at":"2025-01-01T00:10:00Z"}
{"type":"deployment","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","status":"success","finished_at":"2025-01-01T00:12:00Z"}
{"type":"deployment","sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","status":"success","finished_at":"2025-01-01T00:20:00Z"}
JSON

# run hermetically
if ! env -i PATH="$PATH" TZ=UTC LC_ALL=C \
  LT_ALLOW_FALLBACK=false LT_MIN_LEAD_SECONDS=60 WINDOW_DAYS=0 MIN_LEAD_SAMPLES=1 \
  "$PY" "$SCRIPT" "$FIX" > run.out 2>&1; then
  cat run.out
  exit 1
fi

# assertions
test -f dora.json && test -f leadtime.csv

jq -e '.schema=="dora/v1"' dora.json >/dev/null
jq -e '.lead_time.samples==1' dora.json >/dev/null

# header presence (order-agnostic); 'match' optional
HDR="$(head -n1 leadtime.csv)"
echo "CSV header: $HDR"
for col in pr sha merged_at deployed_at lead_seconds lead_minutes lead_hours; do
  printf '%s\n' "$HDR" | tr ',' '\n' | grep -qx "$col" || { echo "missing column: $col"; exit 1; }
done

# row checks by column name (robust to order)
"$PY" - <<'PY'
import csv, re, sys
with open('leadtime.csv', newline='') as f:
    r = csv.DictReader(f)
    rows = list(r)
assert rows, "no data rows"
for row in rows:
    assert re.fullmatch(r"[0-9a-f]{40}", row["sha"]), f"bad sha: {row['sha']}"
    assert float(row["lead_seconds"]) > 60, f"lead_seconds <= 60: {row['lead_seconds']}"
print("rows ok")
PY

echo "ok: exact pairing (isolated) in $TMPDIR"
