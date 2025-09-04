#!/usr/bin/env python3
# ci/dora/compute_dora.py
import os, sys, json, math, statistics, datetime as dt
from collections import defaultdict
from datetime import timedelta
import csv

# ---------- config (env) ----------
PCTL = int(os.environ.get("PCTL", "90"))                  # percentile to report
MIN_LEAD_SAMPLES = int(os.environ.get("MIN_LEAD_SAMPLES", "20"))
MAX_FALLBACK_HOURS = float(os.environ.get("MAX_FALLBACK_HOURS", "168"))  # 7d

# ---------- io ----------
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
            pass  # ignore bad lines

def parse_ts(s: str) -> dt.datetime | None:
    if not s:
        return None
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

# ---------- aggregate deployments ----------
deploy_success_times: dict[str, list[dt.datetime]] = defaultdict(list)  # sha -> times
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
    # else ignored (skipped, unknown)

deployments = sum(v["succ"] for v in deploy_all_by_day.values())
failed = sum(v["fail"] for v in deploy_all_by_day.values())
total_dep = deployments + failed
cfr = (failed / total_dep) if total_dep > 0 else None
daily_df = {str(k): v["succ"] for k, v in sorted(deploy_all_by_day.items())}

# ---------- lead time ----------
def compute_lead(evts, success_times_by_sha, max_fallback_hours=168.0):
    """Return (lead_hours:list[float], details:list[dict])."""
    any_times = sorted(t for lst in success_times_by_sha.values() for t in lst)
    lead_hours, details = [], []
    for e in evts:
        if e.get("type") != "pr_merged":
            continue
        sha = e.get("sha")
        merged_at = parse_ts(e.get("merged_at"))
        if not sha or not merged_at:
            continue

        exact = [t for t in success_times_by_sha.get(sha, []) if t >= merged_at]
        times = exact
        match = "sha" if exact else "fallback"

        if not times:
            upper = merged_at + timedelta(hours=max_fallback_hours)
            times = [t for t in any_times if merged_at <= t <= upper]

        if times:
            first = min(times)
            delta_h = (first - merged_at).total_seconds() / 3600.0
            if delta_h >= 0:
                lead_hours.append(delta_h)
                details.append({
                    "pr": e.get("pr"),
                    "sha": sha,
                    "merged_at": e.get("merged_at"),
                    "deployed_at": first.isoformat(),
                    "lead_hours": round(delta_h, 2),
                    "match": match
                })
    return lead_hours, details

lead_hours, details = compute_lead(events, deploy_success_times, MAX_FALLBACK_HOURS)

# ---------- percentile helper ----------
def percentile(data, p):  # p in [0,100]
    if not data:
        return None
    xs = sorted(data)
    if len(xs) == 1:
        return xs[0]
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

# ---------- report ----------
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

# ---------- optional detail export ----------
if details:
    with open("leadtime.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["pr","sha","merged_at","deployed_at","lead_hours","match"])
        w.writeheader()
        w.writerows(sorted(details, key=lambda r: r["lead_hours"], reverse=True))
    print("- Wrote leadtime.csv")
