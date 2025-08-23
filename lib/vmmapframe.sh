#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
EVIDENCE_DIR="${EVIDENCE_DIR:-.evidence}"
MAX_HEAP_MB="${MAX_HEAP_MB:-256}"
mkdir -p "$EVIDENCE_DIR"
source ./queries/darwin_memory.sh

snap_vmmap(){ local pid=$1 tag=$2; vmmap "$pid" >"$EVIDENCE_DIR/vmmap.$pid.$tag.txt" 2>/dev/null || true; }



# launch target
( exec env rules=rules.json findings=findings.json \
    ./with_contracts.sh --frame ./evaluate.frame.sh \
                        --contract ./evaluate.contract.sh \
                        ./evaluate.sh ) & PID=$!

# first snapshot + children
for i in {1..50}; do snap_vmmap "$PID" first; [[ -s "$EVIDENCE_DIR/vmmap.$PID.first.txt" ]] && break; kill -0 "$PID" 
2>/dev/null || break; sleep 0.02; done
for c in $(pgrep -P "$PID" 2>/dev/null || true); do snap_vmmap "$c" first; done

# wait then last snapshot
wait "$PID" || true
snap_vmmap "$PID" last

VMMAP="$EVIDENCE_DIR/vmmap.$PID.last.txt"
[[ -s "$VMMAP" ]] || VMMAP="$EVIDENCE_DIR/vmmap.$PID.first.txt"   # fallback

# checks
fails=0
no_rwx_maps_darwin "$VMMAP" || { echo "no_rwx_maps: FAIL"; ((fails++)); }
heap_under_mb_darwin "$VMMAP" "$MAX_HEAP_MB" || { echo "heap<=${MAX_HEAP_MB}MB: FAIL"; ((fails++)); }
((fails==0)) && echo "contracts: PASS" || { echo "contracts: FAIL ($fails)"; exit 1; }

