# ci/roi/run_stats.jq
# args: --arg b <HEAD_BRANCH> --arg re <RUN_NAME_REGEX>

def safe_diff_ms:
  ( (.updated_at // .run_completed_at) as $end
  | (.run_started_at // .created_at)  as $start
  | if ($end|type)=="string" and ($start|type)=="string"
    then (( ($end|fromdateiso8601) - ($start|fromdateiso8601) ) * 1000)
    else null end);

def ms:
  ( .run_duration_ms
  // .duration_ms
  // ((.duration?|numbers) * 1000)
  // safe_diff_ms );

def base:
  select((.status=="completed") or (.conclusion!=null))
  | (if ($b|length)>0 then select(.head_branch==$b) else . end)
  | (if ($re|length)>0 then select(.name|test($re;"i")) else . end);

def durations:
  ((.workflow_runs // .runs // .) // [])
  | [ .[] | base | ms | select(type=="number" and .>0) ];

def mean($xs): ($xs|length) as $n | if $n==0 then 0 else (($xs|add)/$n) end;
def p50($xs):
  ($xs|length) as $n
  | if $n==0 then 0
    else ($xs|sort) as $s
      | if ($n%2==1) then $s[($n/2|floor)] else (($s[$n/2-1]+$s[$n/2])/2) end
    end;

(durations) as $d
| ($d|length) as $n
| (mean($d)) as $mean_ms
| (p50($d)) as $p50_ms
| "\($n) \($mean_ms/1000) \($p50_ms/1000)"
