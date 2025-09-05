#!/usr/bin/env python3
# ci/roi/compute_roit.py
import os, math, json

def _f(name, default=None, required=True):
    v = os.environ.get(name)
    if v is None:
        if required and default is None:
            raise SystemExit(f"Missing env: {name}")
        v = default
    try:
        return float(v)
    except Exception:
        raise SystemExit(f"Bad float for {name}: {v!r}")

def _i(name, default=None, required=True):
    v = os.environ.get(name)
    if v is None:
        if required and default is None:
            raise SystemExit(f"Missing env: {name}")
        v = default
    try:
        return int(float(v))
    except Exception:
        raise SystemExit(f"Bad int for {name}: {v!r}")

# Inputs
wd = os.environ.get("WINDOW_DAYS", "")
tb = _f("TB")                     # baseline avg sec
ta = _f("TA")                     # current avg sec
runs = _i("RUNS")
pb = _f("PB"); pa = _f("PA")
prs = _i("PRS")
R   = _f("R")
H   = _f("H")

# Knobs
FLOOR_TA_SEC = _f("FLOOR_TA_SEC", 1.0, required=False)   # avoid 0-sec artifacts
ROI_JSON_PATH = os.environ.get("ROI_JSON_PATH", "roit.json")

# Sanity
pb = max(0.0, min(1.0, pb))
pa = max(0.0, min(1.0, pa))
ta = max(ta, FLOOR_TA_SEC)

# Benefit components (hours)
time_benefit_hours = (tb - ta) * runs / 3600.0
pr_benefit_hours   = (pa - pb) * prs * R
benefit_hours      = time_benefit_hours + pr_benefit_hours
roit               = (benefit_hours / H) if H > 0 else math.nan

# Human summary
print("## ROI (artifacts only)")
if wd: print(f"- Window (days): {wd}")
print(f"- Runs: {runs} | Avg now: {ta:.2f}s | Baseline: {tb:.2f}s")
print(f"- PRs: {prs} | First-pass now: {pa:.3f} | Baseline: {pb:.3f}")
print(f"- Rework hrs/failed PR (R): {R} | Hours logged: {H:.2f}")
print(f"- Benefit (hours): {benefit_hours:.2f}  [time={time_benefit_hours:.2f}, pr={pr_benefit_hours:.2f}]")
if math.isnan(roit):
    print("- ROIT: **NA** (no hours logged)")
else:
    print(f"- ROIT: **{roit:.2f} benefit-hours/hour**")

# Machine output
out = {
    "window_days": int(float(wd)) if (wd and wd.replace(".","",1).isdigit()) else wd or None,
    "runs": runs, "ta_sec": ta, "tb_sec": tb,
    "prs": prs, "pa": pa, "pb": pb, "R": R, "hours": H,
    "benefit_hours": round(benefit_hours, 4),
    "benefit_time_hours": round(time_benefit_hours, 4),
    "benefit_pr_hours": round(pr_benefit_hours, 4),
    "roit": None if math.isnan(roit) else round(roit, 4),
    "floor_ta_sec": FLOOR_TA_SEC,
}
with open(ROI_JSON_PATH, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)
print(f"- Wrote {ROI_JSON_PATH}")
