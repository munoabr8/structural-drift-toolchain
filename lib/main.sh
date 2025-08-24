#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_DIR="${EVIDENCE_DIR:-.evidence}"
MAX_HEAP_MB="${MAX_HEAP_MB:-256}"

#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Fail if any CURRENT perms == rwx (ignore max perms after slash)
no_rwx_maps_darwin() {
  local f=$1; [[ -s $f ]] || return 2
  ! sed -n 's/.*] \([rwx-][rwx-][rwx-]\)\/[rwx-][rwx-][rwx-].*/\1/p' "$f" | grep -qx 'rwx'
}

# Sum MALLOC column chosen via header (default VIRTUAL). Units → MB.
heap_under_mb_darwin() {
  local f=$1 cap_mb=$2 col_name=${3:-VIRTUAL}; [[ -s $f ]] || return 2
  awk -v cap="$cap_mb" -v want="$col_name" '
    function to_mb(s, n, u){u=substr(s,length(s),1); n=s; sub(/[KMG]$/,"",n);
      return u=="G"?n*1024:u=="M"?n+0:u=="K"?n/1024:n/1024}
    /^REGION TYPE/ && !hdr_done {
      for(i=1;i<=NF;i++) if($i==want) col=i; hdr_done=1; next
    }
    hdr_done && NF==0 {in=0}
    hdr_done && !in {in=1; next}
    in && $1 ~ /^MALLOC/ && col>0 {
      v=$col; if(v ~ /^[0-9.]+[KMG]$/) sum+=to_mb(v)
    }
    END { exit (sum<=cap)?0:1 }
  ' "$f"
}


main() {
  [[ "$(uname -s)" == "Darwin" ]] || { echo "This wrapper targets macOS vmmap."; exit 2; }
  mkdir -p "$EVIDENCE_DIR"

  # 1) Launch target; $! is the PID
  ( exec env rules=rules.json findings=findings.json \
      ./with_contracts.sh --frame ./evaluate.frame.sh \
                          --contract ./evaluate.contract.sh \
                          ./evaluate.sh ) & PID=$!

  # 2) Snapshot vmmap while alive (retry briefly)
  VMMAP=.evidence/vmmap.$PID.txt

  for i in {1..50}; do
    if vmmap "$PID" >"$VMMAP" 2>/dev/null; then break; fi
    kill -0 "$PID" 2>/dev/null || { echo "process exited before snapshot"; break; }
    usleep 20000 2>/dev/null || sleep 0.02
  done

  # 3) Wait for child
  wait "$PID" || true
  echo "PID=$PID  vmmap=$VMMAP"

  # 4) Run queries (0=pass,1=fail,2=indeterminate)
  fails=0
  no_rwx_maps_darwin "$VMMAP" && echo PASS || echo FAIL

grep -E ']\s*rwx/' .evidence/vmmap.$PID.txt && echo "DISPROVEN" || echo "No RWX"

  heap_under_mb_darwin "$VMMAP" "$MAX_HEAP_MB" || { echo "heap_under_mb<=$MAX_HEAP_MB: FAIL"; ((fails++)); }

  (( fails == 0 )) && echo "contracts: PASS" || { echo "contracts: FAIL ($fails)"; exit 1; }
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
