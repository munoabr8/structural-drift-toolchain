# scripts/roi/build_inputs.sh
#!/usr/bin/env bash
set -euo pipefail

out="${GITHUB_OUTPUT:?GITHUB_OUTPUT not set}"

# runs + avg duration (sec)
if [[ -f runs.json ]]; then
  RUNS=$(jq -r '(.workflow_runs // .runs // []) | length' runs.json)
  AVG_SEC=$(jq -r '(.workflow_runs // .runs // [])
                    | map(.run_duration_ms // 0)
                    | if length==0 then 0 else (add/length/1000) end' runs.json)
else
  if [[ -f workflow-stats.csv ]]; then
    read -r RUNS AVG_SEC <<EOF
$(awk -F, 'NR>1{runs+=$5; sum+=$2*$5} END{if(runs>0) printf "%d %.6f\n", runs, sum/runs; else print "0 0"}' workflow-stats.csv)
EOF
  else
    RUNS=0
    AVG_SEC=0
  fi
fi

# first-pass PR success
TOTAL=$(jq -r '.total' first_pass.json)
PASS=$(jq -r '.pass'  first_pass.json)
PA=$(awk -v p="${PASS:-0}" -v t="${TOTAL:-0}" 'BEGIN{print (t>0)? p/t : 0}')

# baseline + hours
TB=$(jq -r '.avg_duration_before_sec' baseline.json)
PB=$(jq -r '.p_before' baseline.json)
R=$(jq -r  '.rework_hours_per_failed_pr' baseline.json)
HOURS=$(awk -F, 'NR>1{sum+=$2} END{print sum+0}' ci-hours.csv)

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
