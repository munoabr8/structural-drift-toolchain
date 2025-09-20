#!/usr/bin/env python3
# ci/dora/test-lead.py
# Local tester: read events.ndjson, compute lead time samples, print summary.

import sys, os, json, datetime as dt
from collections import defaultdict
from statistics import median

def parse_ts(s: str):
    if not s:
        return None
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

# ---- input path ----
path = sys.argv[1] if len(sys.argv) > 1 else "events.ndjson"
if path != "-" and not os.path.exists(path):
    sys.exit(f"Missing input file: {path}")
fin = sys.stdin if path == "-" else open(path, "r", encoding="utf-8")

events = []
for line in fin:
    line = line.strip()
    if line:
        try:
            events.append(json.loads(line))
        except Exception:
            continue
if fin is not sys.stdin:
    fin.close()

# ---- build deploy success times ----
deploy_success_times = defaultdict(list)
for e in events:
    if e.get("type") == "deployment" and e.get("status") == "success":
        t = parse_ts(e.get("finished_at") or e.get("updated_at") or e.get("created_at"))
        if t:
            deploy_success_times[e["sha"]].append(t)

# ---- fixed compute_lead ----
from datetime import timedelta

def compute_lead(events, success_times_by_sha, max_fallback_hours=168.0,
                 allow_fallback=False, min_lead_seconds=60):
    norm = {k: sorted(set([t for t in v if t])) for k, v in success_times_by_sha.items()}
    any_times = sorted(t for lst in norm.values() for t in lst)
    lead, details = [], []
    for e in events:
        if e.get("type") != "pr_merged":
            continue
        sha = e.get("sha")
        m = parse_ts(e.get("merged_at"))
        if not sha or not m:
            continue
        exact = [t for t in norm.get(sha, []) if (t - m).total_seconds() > min_lead_seconds]
        times, match = exact, "sha"
        if not times and allow_fallback:
            upper = m + timedelta(hours=max_fallback_hours)
            times = [t for t in any_times
                     if m < t <= upper and (t - m).total_seconds() > min_lead_seconds]
            match = "fallback" if times else match
        if not times:
            continue
        first = min(times)
        delta_h = (first - m).total_seconds() / 3600.0
        if delta_h <= 0:
            continue
        lead.append(delta_h)
        details.append({
            "pr": e.get("pr"),
            "sha": sha,
            "merged_at": e.get("merged_at"),
            "deployed_at": first.isoformat().replace("+00:00", "Z"),
            "lead_hours": round(delta_h, 2),
            "match": match,
        })
    return lead, details

# ---- run ----

# in test_lead.py
lead_hours, details = compute_lead(events, deploy_success_times,
                                   allow_fallback=True, min_lead_seconds=400)


p90 = None
if lead_hours:
    sorted_leads = sorted(lead_hours)
    idx = int(0.9 * len(sorted_leads)) - 1
    if idx >= 0:
        p90 = sorted_leads[idx]

summary = {
    "samples": len(lead_hours),
    "median_h": (round(median(lead_hours), 2) if lead_hours else None),
    "p90_h": (round(p90, 2) if p90 else None),
}

print(json.dumps(summary, indent=2))
