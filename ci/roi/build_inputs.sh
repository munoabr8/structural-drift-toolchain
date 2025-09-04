#!/usr/bin/env bash
# ./ci/roi/build_inputs.sh
set -euo pipefail

out="${GITHUB_OUTPUT:?GITHUB_OUTPUT not set}"

# ---------- runs + avg duration (sec) ----------

RUNS=0
AVG_SEC=0

if [[ -f runs.json ]]; then
  read -r RUNS AVG_SEC <<EOF
$(jq -r '
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
  | ($rs
     | [ .[] | ms(.) | select((type=="number") and (.>0)) ]
     | if length==0 then 0 else ((add/length)/1000) end) as $avg
  | [$runs, $avg] | @tsv
' runs.json)
EOF
fi




# Fallback to CSV if JSON missing/zero
if [[ "$RUNS" = "0" || "$AVG_SEC" = "0" || "$AVG_SEC" = "0.0" ]]; then
  if [[ -f workflow-stats.csv ]]; then
    read -r RUNS AVG_SEC <<'EOF'
'"$(awk -F, 'NR>1 && $2 ~ /^[0-9.]+$/ && $5 ~ /^[0-9]+$/ {runs+=$5; sum+=$2*$5} END{if(runs>0) printf "%d %.6f\n", runs, sum/runs; else print "0 0"}' workflow-stats.csv)"'
EOF
  else
    RUNS=0
    AVG_SEC=0
  fi
fi

# ---------- first-pass PR success ----------
if [[ -f first_pass.json ]]; then
  TOTAL=$(jq -r '.total // 0' first_pass.json)
  PASS=$(jq -r  '.pass  // 0' first_pass.json)
else
  TOTAL=0
  PASS=0
fi
PA=$(awk -v p="$PASS" -v t="$TOTAL" 'BEGIN{print (t>0)? p/t : 0}')

# ---------- baseline + rework hours ----------
TB=$(jq -r '.avg_duration_before_sec // 0' baseline.json)
PB=$(jq -r '.p_before // 0' baseline.json)
R=$(jq -r  '.rework_hours_per_failed_pr // 0' baseline.json)

# ---------- hours (from ci-hours.csv) ----------
if [[ -f ci-hours.csv ]]; then
  HOURS=$(awk -F, 'NR>1{h+=$2} END{printf "%.2f", h+0}' ci-hours.csv)
else
  HOURS=0
fi

# ---------- emit outputs ----------
{
  echo "runs=$RUNS"
  echo "avg_sec=$AVG_SEC"
  echo "total=$TOTAL"
  echo "pa=$PA"
  echo "tb=$TB"
  echo "pb=$PB"
  echo "r=$R"
  echo "hours=$HOURS"
} >> "$out"
