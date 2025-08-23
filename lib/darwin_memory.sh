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

