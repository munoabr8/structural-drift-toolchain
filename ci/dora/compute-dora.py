#!/usr/bin/env python3
# ci/dora/compute_dora.py

import os, sys, json, math, statistics, datetime as dt, csv
from collections import defaultdict
from datetime import timedelta
from json import JSONDecoder

# ---------- env config ----------
PCTL = int(os.environ.get("PCTL", "90"))                         # percentile to report
MIN_LEAD_SAMPLES = int(os.environ.get("MIN_LEAD_SAMPLES", "10")) # min PR→deploy pairs to report
MAX_FALLBACK_HOURS = float(os.environ.get("MAX_FALLBACK_HOURS", "168"))  # 7d
WINDOW_DAYS = int(os.environ.get("WINDOW_DAYS", "0"))            # 0 = no window filter
LT_ALLOW_FALLBACK = os.getenv("LT_ALLOW_FALLBACK", "false").lower() in {"1","true","yes","y"}
LT_MIN_LEAD_SECONDS = int(os.environ.get("LT_MIN_LEAD_SECONDS", "0"))    # min delta to count a pair
LEAD_UNIT = os.environ.get("LEAD_UNIT", "e").lower()       # hours|minutes|seconds

# ---------- IO: tolerant loader for NDJSON, multi-line objects, or a single top-level array ----------
def load_events(path: str):
    dec = JSONDecoder()
    with open(path, "r", encoding="utf-8") as f:
        s = f.read()
    out, i, n = [], 0, len(s)
    while True:
        while i < n and s[i].isspace():
            i += 1
        if i >= n:
            break
        obj, j = dec.raw_decode(s, i)
        out.append(obj)
        i = j
    return out[0] if (len(out) == 1 and isinstance(out[0], list)) else out

PATH = sys.argv[1] if len(sys.argv) > 1 else "events.ndjson"
events = load_events(PATH)

# ---------- helpers ----------
NOW = dt.datetime.now(dt.timezone.utc)

def parse_ts(s: str) -> dt.datetime | None:
    if not isinstance(s, str) or not s:
        return None
    s = s.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        return dt.datetime.fromisoformat(s)
    except Exception:
        return None

def in_window(ts: dt.datetime) -> bool:
    if not WINDOW_DAYS:
        return True
    return (NOW - ts).days < WINDOW_DAYS

def _ok_pr(e: dict) -> bool:
    return (
        isinstance(e, dict)
        and e.get("type") == "pr_merged"
        and isinstance(e.get("sha"), str) and bool(e["sha"])
        and isinstance(e.get("merged_at"), str)
    )

def _ok_dep(e: dict) -> bool:
    ts = e.get("finished_at") or e.get("deploy_at")
    return (
        isinstance(e, dict)
        and e.get("type") == "deployment"
        and isinstance(e.get("sha"), str) and bool(e["sha"])
        and isinstance(ts, str)
    )

# keep only recognized shapes
events = [e for e in events if _ok_pr(e) or _ok_dep(e)]

# ---------- deployments aggregation ----------
def aggregate_deployments(events):
    deploy_success_times = defaultdict(list)  # sha -> [times]
    per_day = defaultdict(lambda: {"succ": 0, "fail": 0})

    for e in events:
        if e.get("type") != "deployment":
            continue
        ts_str = e.get("finished_at") or e.get("deploy_at")
        t = parse_ts(ts_str)
        if not t or not in_window(t):
            continue

        status = (e.get("status") or "success").strip().lower()
        if status in {"success", "succeeded"}:
            sha = e.get("sha")
            if sha:
                deploy_success_times[sha].append(t)
            per_day[t.date()]["succ"] += 1
        elif status in {"failure", "failed", "cancelled", "timed_out", "neutral", "action_required"}:
            per_day[t.date()]["fail"] += 1

    deployments = sum(v["succ"] for v in per_day.values())
    failed = sum(v["fail"] for v in per_day.values())
    daily_df = {str(k): v["succ"] for k, v in sorted(per_day.items())}
    return deploy_success_times, daily_df, deployments, failed

deploy_success_times, daily_df, deployments, failed = aggregate_deployments(events)

# ---------- lead time ----------
import re

HEX40 = re.compile(r"^[0-9a-f]{40}$")

def compute_lead(events, success_times_by_sha, max_fallback_hours=168.0,
                 allow_fallback=False, min_lead_seconds=0):
    # normalize deploy keys to lowercase
    norm = {(k or "").lower(): sorted(set(t for t in v if t))
            for k, v in (success_times_by_sha or {}).items()}
    any_times = sorted(t for lst in norm.values() for t in lst)
    lead_seconds, details = [], []

    for e in events:
        if e.get("type") != "pr_merged":
            continue
        sha = (e.get("merge_commit_sha") or e.get("sha") or e.get("head_sha") or "").lower()
        m = parse_ts(e.get("merged_at"))
        if not sha or not m or not in_window(m) or not HEX40.fullmatch(sha):
            continue

        exact = [t for t in norm.get(sha, []) if (t - m).total_seconds() > min_lead_seconds]
        times, match = exact, "sha"
        if not times and allow_fallback:
            upper = m + timedelta(hours=max_fallback_hours)
            times = [t for t in any_times if m < t <= upper and (t - m).total_seconds() > min_lead_seconds]
            if times: match = "fallback"
        if not times:
            continue

        first = min(times)
        delta_s = (first - m).total_seconds()
        if delta_s <= 0:
            continue

        lead_seconds.append(delta_s)
        details.append({
            "pr": e.get("pr"),
            "sha": sha,
            "merged_at": e.get("merged_at"),
            "deployed_at": first.isoformat().replace("+00:00", "Z"),
            "lead_seconds": int(delta_s),
            "lead_minutes": round(delta_s / 60.0, 2),
            "lead_hours": round(delta_s / 3600.0, 4),
            "match": match,
        })
    return lead_seconds, details


lead, details = compute_lead(
    events, deploy_success_times, MAX_FALLBACK_HOURS,
    allow_fallback=LT_ALLOW_FALLBACK, min_lead_seconds=LT_MIN_LEAD_SECONDS
)

# ---------- percentile ----------
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

def _unitify(seconds_list):
    if LEAD_UNIT == "hours":
        return [s/3600.0 for s in seconds_list], "hours", "{:.4f}"
    if LEAD_UNIT == "minutes":
        return [s/60.0 for s in seconds_list], "minutes", "{:.2f}"
    return seconds_list, "seconds", "{:.0f}"

# ---------- report ----------
print("## DORA (basics)")
print(f"- Deployments (window): {deployments}")
print(f"- Daily deployment frequency: {json.dumps(daily_df)}")

total_attempts = deployments + failed
if total_attempts >= 5:
    cfr_val = failed / total_attempts
    print(f"- Change failure rate: {cfr_val:.2f}")
else:
    print(f"- Change failure rate: NA (deploys<5)")

n = len(lead)
if n >= MIN_LEAD_SAMPLES:
    series, unit, fmt = _unitify(lead)
    med = statistics.median(series)
    pval = percentile(series, PCTL)
    print(f"- Lead time (samples): {n}")
    print(f"- Lead time (median {unit}): " + fmt.format(med))
    print(f"- Lead time (p{PCTL} {unit}): " + fmt.format(pval))
else:
    print(f"- Lead time: NA (n={n} < {MIN_LEAD_SAMPLES}); collect more PR→deploy pairs")

 #-----------------------
# per-SHA timeline index
idx = defaultdict(dict)

for e in events:
    t = e.get("type"); sha = e.get("sha")
    if not sha: 
        continue
    if t == "pr_merged":
        ts = parse_ts(e.get("merged_at"))
        if ts and in_window(ts): idx[sha]["merge"] = ts
    elif t == "pipeline_started":
        ts = parse_ts(e.get("started_at"))
        if ts and in_window(ts): idx[sha]["ps"] = ts
    elif t == "pipeline_finished":
        ts = parse_ts(e.get("finished_at"))
        if ts and in_window(ts): idx[sha]["pf"] = ts
    elif t == "deployment":
        ts = parse_ts(e.get("finished_at") or e.get("deploy_at"))
        if ts and in_window(ts): idx[sha]["df"] = ts

def _pos_s(a, b):
    if a is None or b is None: return None
    d = (b - a).total_seconds()
    return d if d >= 0 else None

# components in seconds
comp = {"merge→pipeline_start": [], "pipeline_runtime": [], "pipeline→deploy": []}
for sha, times in idx.items():
    d1 = _pos_s(times.get("merge"), times.get("ps"))
    d2 = _pos_s(times.get("ps"),    times.get("pf"))
    d3 = _pos_s(times.get("pf"),    times.get("df"))
    if d1 is not None: comp["merge→pipeline_start"].append(d1)
    if d2 is not None: comp["pipeline_runtime"].append(d2)
    if d3 is not None: comp["pipeline→deploy"].append(d3)

print("## DORA (orthogonal)")
have_components = any(len(v) > 0 for v in comp.values())
if not have_components:
    total_pairs = len(lead)  # aggregate merge→deploy already computed (seconds)
    print(f"- merge→deploy (samples): {total_pairs}")
    if total_pairs:
        ys, unit, fmt = _unitify(lead)
        med = statistics.median(ys)
        pval = percentile(ys, PCTL)
        print(f"- merge→deploy (median {unit}): " + fmt.format(med))
        print(f"- merge→deploy (p{PCTL} {unit}): " + fmt.format(pval))
else:
    for name, xs in comp.items():
        print(f"- {name} (samples): {len(xs)}")
        if xs:
            ys, unit, fmt = _unitify(xs)
            print(f"  median {unit}=" + fmt.format(statistics.median(ys)) +
                  f", p{PCTL}=" + fmt.format(percentile(ys, PCTL)))



# --- assemble dora.json ---
def safe_p50(xs):
    if not xs: return None
    xs = sorted(xs); n=len(xs)
    return xs[n//2] if n%2 else 0.5*(xs[n//2-1]+xs[n//2])

lead_hours = [s/3600.0 for s in lead]  # 'lead' is seconds list from your code
dora = {
  "schema": "dora/v1",
  "window_days": WINDOW_DAYS or None,
  "metrics": {
    "deploys_total": deployments,
    "deploy_failures": failed,
    "deploys_per_day": round(sum(daily_df.values())/max(len(daily_df),1), 4),
    "daily_histogram": daily_df
  },
  "lead_time": {
    "samples": len(lead_hours),
    "median_h": round(statistics.median(lead_hours), 4) if lead_hours else None,
    "pctl_h": round(percentile(lead_hours, PCTL), 4) if lead_hours else None,
    "pctl": PCTL
  }
}
with open("dora.json","w",encoding="utf-8") as f:
    json.dump(dora, f, indent=2)
print("- Wrote dora.json")


# ---------- CSV ----------
if details:
    with open("leadtime.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=[
            "pr","sha","merged_at","deployed_at","lead_seconds","lead_minutes","lead_hours","match"
        ])
        w.writeheader()
        details_sorted = sorted(details, key=lambda r: (r["merged_at"], r["deployed_at"]))
        w.writerows(details_sorted)
    print("- Wrote leadtime.csv")
