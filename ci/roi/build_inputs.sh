#!/usr/bin/env bash
# ./ci/roi/build_inputs.sh
set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT not set}"

emit() { printf '%s\n' "$@" | tee -a "$GITHUB_OUTPUT" >/dev/null; }

# ---------- runs + avg duration (sec) ----------
RUNS=0 AVG_SEC=0

if [[ -f runs.json ]]; then
  jq_out="$(jq -r '
    def ms(r):
      if r.run_duration_ms != null then r.run_duration_ms
      elif r.duration_ms != null    then r.duration_ms
      elif (r.duration? != null)    then (r.duration * 1000)
      elif (r.run_started_at? and ((r.run_completed_at? // r.updated_at?) != null)) then
        (((r.run_completed_at // r.updated_at) | fromdateiso8601)
         - (r.run_started_at | fromdateiso8601)) * 1000
      elif (r.created_at? and r.updated_at?) then
        ((r.updated_at | fromdateiso8601) - (r.created_at | fromdateiso8601)) * 1000
      else 0 end;
    (.workflow_runs // .runs // []) as $rs
    | ($rs | map(select((.status=="completed") or (.conclusion!=null))) | length) as $runs
    | ($rs | [ .[] | ms(.) | select((type=="number") and (.>0)) ]
        | if length==0 then 0 else ((add/length)/1000) end) as $avg
    | [$runs, $avg] | @tsv
  ' runs.json || true)"
  if [[ -n "${jq_out//[$'\t\r\n ']/}" ]]; then
    # got something; assign safely
    IFS=$'\t' read -r RUNS AVG_SEC <<<"$jq_out"
  fi
fi

# Fallback to CSV if still empty or zero-ish
if [[ -z "${RUNS:-}" || -z "${AVG_SEC:-}" || "$RUNS" = "0" || "$AVG_SEC" = "0" || "$AVG_SEC" = "0.0" ]]; then
  if [[ -f workflow-stats.csv ]]; then
    awk_out="$(awk -F, 'NR>1 && $2 ~ /^[0-9.]+$/ && $5 ~ /^[0-9]+$/ {runs+=$5; sum+=$2*$5}
                       END{if(runs>0) printf "%d\t%.6f\n", runs, sum/runs}' workflow-stats.csv)"
    if [[ -n "${awk_out//[$'\t\r\n ']/}" ]]; then
      IFS=$'\t' read -r RUNS AVG_SEC <<<"$awk_out"
    else
      RUNS=0; AVG_SEC=0
    fi
  else
    RUNS=0; AVG_SEC=0
  fi
fi

# ---------- first-pass PR success ----------
if [[ -f first_pass.json ]]; then
  TOTAL="$(jq -r '.total // 0' first_pass.json || echo 0)"
  PASS="$( jq -r '.pass  // 0' first_pass.json || echo 0)"
else
  TOTAL=0; PASS=0
fi
PA="$(awk -v p="$PASS" -v t="$TOTAL" 'BEGIN{print (t>0)? p/t : 0}')"

# ---------- baseline + rework hours ----------
TB=0 PB=0 R=0
if [[ -f baseline.json ]]; then
  TB="$(jq -r '.avg_duration_before_sec // 0' baseline.json || echo 0)"
  PB="$(jq -r '.p_before // 0'                baseline.json || echo 0)"
  R="$( jq -r '.rework_hours_per_failed_pr // 0' baseline.json || echo 0)"
fi

# ---------- hours (from ci-hours.csv) ----------
if [[ -f ci-hours.csv ]]; then
  HOURS="$(awk -F, 'NR>1{h+=$2} END{printf "%.2f", h+0}' ci-hours.csv)"
else
  HOURS=0
fi

# ---------- emit outputs ----------
emit "runs=$RUNS" \
     "avg_sec=$AVG_SEC" \
     "total=$TOTAL" \
     "pa=$PA" \
     "tb=$TB" \
     "pb=$PB" \
     "r=$R" \
     "hours=$HOURS"
