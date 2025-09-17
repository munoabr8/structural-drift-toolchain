#!/usr/bin/env bash
# ci/dora/health.sh — validate events.ndjson shape without false negatives
set -euo pipefail
E="${1:-events.ndjson}"
COVERAGE_MIN="${COVERAGE_MIN:-0.33}"
MAX_FALLBACK_RATIO="${MAX_FALLBACK_RATIO:-0.30}"
REQUIRE_DEPLOY_COVERAGE="${REQUIRE_DEPLOY_COVERAGE:-auto}"  # auto|true|false
DEPLOY_ENV="${DEPLOY_ENV:-}"

die(){ printf 'NEEDS_WORK:%s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing:$1"; }
need jq

# ---------- helpers ----------
iso_ok='((. | tostring) | fromdateiso8601?) != null'
hex40='test("^[0-9a-f]{40}$")'

# pr_sha := merge_commit_sha | sha | head_sha
read -r BAD_PR <<<"$(jq -s "
  [ .[]
    | select(.type==\"pr_merged\")
    | ( . as \$e
        | ( (\$e.merge_commit_sha // \$e.sha // \$e.head_sha) | tostring | $hex40 ) as \$sha_ok
        | ( (\$e.merged_at | $iso_ok) ) as \$ts_ok
        | select((\$sha_ok|not) or (\$ts_ok|not))
      )
  ] | length
" "$E")"
(( BAD_PR==0 )) || die "bad PR rows=$BAD_PR"

# ---------- deployments (accept finished_at or deploy_at; success|succeeded) ----------
read -r BAD_DEP <<<"$(jq -s "
  [ .[] | select(.type==\"deployment\")
    | ( .sha | tostring | $hex40 ) as \$sha_ok
    | ( ((.finished_at // .deploy_at) | $iso_ok) ) as \$ts_ok
    | ( ((.status // \"success\") | ascii_downcase) as \$s | (\$s==\"success\" or \$s==\"succeeded\") ) as \$ok
    | select((\$sha_ok|not) or (\$ts_ok|not) or (\$ok|not))
  ] | length
" "$E")"
(( BAD_DEP==0 )) || die "bad deploy rows=$BAD_DEP"

# ---------- coverage (only if we actually have deploys, or if forced) ----------
PRS=$(jq -r '
  select(.type=="pr_merged")
  | (.merge_commit_sha // .sha // .head_sha)
' "$E" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')

DEPS=$(jq -r '
  select(.type=="deployment")
  | ((.status // "success")|ascii_downcase) as $s
  | select($s=="success" or $s=="succeeded")
  | .sha
' "$E" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')

if { [[ "$REQUIRE_DEPLOY_COVERAGE" == "true" ]] || { [[ "$REQUIRE_DEPLOY_COVERAGE" == "auto" ]] && (( DEPS>0 )); }; }; then
  INT=$(
    comm -12 \
      <(jq -r 'select(.type=="pr_merged")|(.merge_commit_sha // .sha // .head_sha)' "$E" | sed '/^$/d' | sort -u) \
      <(jq -r 'select(.type=="deployment")|((.status//"success")|ascii_downcase) as $s|select($s=="success" or $s=="succeeded")|.sha' "$E" | sed '/^$/d' | sort -u) \
    | wc -l | tr -d ' '
  )
  if (( PRS>0 )); then
    awk -v i="$INT" -v p="$PRS" -v m="$COVERAGE_MIN" 'BEGIN{ if (i/p < m) exit 1 }' \
      || { PCT=$(awk -v m="$COVERAGE_MIN" 'BEGIN{printf "%.0f", m*100}'); die "coverage<${PCT}% (int=$INT prs=$PRS deps=$DEPS)"; }
  fi
fi

# ---------- optional: verify using GH Deployments API success timestamp ----------
if [[ -n "${GH_TOKEN:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "$DEPLOY_ENV" ]]; then
  need gh
  ID=$(gh api "/repos/$GITHUB_REPOSITORY/deployments?environment=$DEPLOY_ENV&per_page=1" -q '.[0].id' 2>/dev/null || true)
  if [[ -n "${ID:-}" && "$ID" != "null" ]]; then
    ST=$(gh api "/repos/$GITHUB_REPOSITORY/deployments/$ID/statuses?per_page=100" -q '[.[]|select(.state=="success")]|last.created_at' 2>/dev/null || true)
    if [[ -n "${ST:-}" && "$ST" != "null" ]]; then
      grep -qF "$ST" "$E" || die "not using deployment success status time ($ST)"
    fi
  fi
fi

# ---------- fallback ratio if CSV exists ----------
if [[ -f leadtime.csv ]]; then
  R=$(awk -F',' '
    NR==1{for(i=1;i<=NF;i++){h=tolower($i);gsub(/^[ \t"]+|[ \t"]+$/,"",h); if(h=="match") m=i} next}
    NR>1 && m>0{v=$m; gsub(/^[ \t"]+|[ \t"]+$/,"",v); v=tolower(v); if(v=="sha") s++; else if(v=="fallback") f++}
    END{n=s+f; if(n==0) print 0; else printf "%.2f", f/n}
  ' leadtime.csv)
  awk -v r="$R" -v maxr="$MAX_FALLBACK_RATIO" 'BEGIN{ if (r>maxr) exit 1 }' || die "fallback_ratio>$R (max=$MAX_FALLBACK_RATIO)"
fi

echo "HEALTH_OK"
