#!/usr/bin/env python3
# ci/dora/compute_dora.py
import os, sys, json, math, statistics, datetime as dt
from collections import defaultdict

# --------- config (env) ---------
PCTL = int(os.environ.get("PCTL", "90"))              # percentile to report (e.g., 90/95)
MIN_LEAD_SAMPLES = int(os.environ.get("MIN_LEAD_SAMPLES", "20"))  # gate for pctl reporting

# --------- io ---------
PATH = sys.argv[1] if len(sys.argv) > 1 else "events.ndjson"
events = []
with open(PATH, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except Exception:
            continue

def parse_ts(s: str) -> dt.datetime:
    if not s:
        return None
    # GitHub ISO 8601, often with 'Z'
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

# --------- aggregate deployments ---------
deploy_success_times = defaultdict(list)  # sha -> [datetime]
deploy_all_by_day = defaultdict(lambda: {"succ": 0, "fail": 0})

for e in events:
    if e.get("type") != "deployment":
        continue
    t = parse_ts(e.get("finished_at"))
    if not t:
        continue
    day = t.date()
    status = (e.get("status") or "").lower()
    if status == "success":
        sha = e.get("sha")
        if sha:
            deploy_success_times[sha].append(t)
        deploy_all_by_day[day]["succ"] += 1
    elif status in {"failure", "cancelled", "timed_out", "neutral", "action_required"}:
        deploy_all_by_day[day]["fail"] += 1
    # other statuses (e.g., skipped) are ignored for CFR

deployments = sum(v["succ"] for v in deploy_all_by_day.values())
failed = sum(v["fail"] for v in deploy_all_by_day.values())
total_dep = deployments + failed
cfr = (failed / total_dep) if total_dep > 0 else None

daily_df = {str(k): v["succ"] for k, v in sorted(deploy_all_by_day.items())}

# after you build deploy_success_times
from datetime import timedelta
ANY_DEPLOY_TIMES = sorted(t for lst in deploy_success_times.values() for t in lst)
MAX_FALLBACK_HOURS = float(os.environ.get("MAX_FALLBACK_HOURS", "168"))  # 7d

# --------- lead time (PR merge -> first successful deploy of same SHA) ---------
lead_hours = []
for e in events:
    if e.get("type") != "pr_merged":
        continue
    sha = e.get("sha")
    merged_at = parse_ts(e.get("merged_at"))
    if not sha or not merged_at:
        continue

    # 1) exact SHA match
    times = [t for t in deploy_success_times.get(sha, []) if t >= merged_at]

    # 2) fallback: any success deploy after merge (bounded window)
    if not times:
        upper = merged_at + timedelta(hours=MAX_FALLBACK_HOURS)
        times = [t for t in ANY_DEPLOY_TIMES if merged_at <= t <= upper]

    if times:
        first = min(times)
        delta_h = (first - merged_at).total_seconds() / 3600.0
        if delta_h >= 0:
            lead_hours.append(delta_h)

# --------- percentile helper (stable for any N) ---------
def percentile(data, p):  # p in [0,100]
    if not data:
        return None
    xs = sorted(data)
    if len(xs) == 1:
        return xs[0]
    # linear interpolation between closest ranks
    k = (p / 100) * (len(xs) - 1)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return xs[f]
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def fmt(x):
    if x is None:
        return "NA"
    if isinstance(x, float):
        return f"{x:.2f}"
    return str(x)

# --------- report ---------
print("## DORA (basics)")
print(f"- Deployments (window): {deployments}")
print(f"- Daily deployment frequency: {json.dumps(daily_df)}")
print(f"- Change failure rate: {fmt(cfr)}")

n = len(lead_hours)
if n >= MIN_LEAD_SAMPLES:
    med = statistics.median(lead_hours)
    pval = percentile(lead_hours, PCTL)
    print(f"- Lead time (samples): {n}")
    print(f"- Lead time (median hours): {med:.2f}")
    print(f"- Lead time (p{PCTL} hours): {pval:.2f}")
else:
    print(f"- Lead time: NA (n={n} < {MIN_LEAD_SAMPLES}); collect more PR→deploy pairs")


 