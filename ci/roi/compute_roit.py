#!/usr/bin/env python3
import os, math, json

SCHEMA = "roit/v1"

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

# ---- inputs ----
wd  = os.environ.get("WINDOW_DAYS", "")
tb  = _f("TB")                      # sec/run baseline
ta  = _f("TA")                      # sec/run now
runs= _i("RUNS")
pb  = _f("PB"); pa = _f("PA")       # first-pass rates
prs = _i("PRS")
R   = _f("R")                       # hours/failed PR
H   = _f("H")                       # human CI/gates hours (Toggl)
mode= os.getenv("ROIT_MODE","human")# human|mixed|dual|legacy

# knobs
FLOOR_TA_SEC = _f("FLOOR_TA_SEC", 1.0, required=False)
B = _f("BLOCKING_FACTOR", 1.0, required=False)   # 0..1 human wait fraction
C = max(_f("PARALLELISM", 1.0, required=False), 1.0)
H_COMPUTE = _f("H_COMPUTE", 0.0, required=False) # CI compute hours
ROI_JSON_PATH = os.environ.get("ROI_JSON_PATH", "roit.json")

# ---- sanitize ----
pb = max(0.0, min(1.0, pb)); pa = max(0.0, min(1.0, pa))
ta = max(ta, FLOOR_TA_SEC)

# ---- components (shared) ----
delta_t_sec = tb - ta                         # + saves, - penalty
time_delta_hours = (delta_t_sec * runs) / 3600.0
time_savings_hours = max(time_delta_hours, 0.0)
time_penalty_hours = max(-time_delta_hours, 0.0)
pr_benefit_hours   = (pa - pb) * prs * R

# ---- strategies ----
def compute_human():
    benefit_hours = pr_benefit_hours
    roit = (benefit_hours / H) if H > 0 else math.nan
    return benefit_hours, roit, None

def compute_mixed():
    time_benefit_hours = (B / C) * time_delta_hours
    benefit_hours = time_benefit_hours + pr_benefit_hours
    roit = (benefit_hours / H) if H > 0 else math.nan
    return benefit_hours, roit, None

def compute_dual():
    roit_human   = (pr_benefit_hours / H) if H > 0 else math.nan
    roit_runtime = (time_delta_hours / H_COMPUTE) if H_COMPUTE > 0 else math.nan
    # primary roit remains human-focused for backward compatibility
    return pr_benefit_hours, roit_human, roit_runtime

def compute_legacy():
    benefit_hours = time_delta_hours + pr_benefit_hours
    roit = (benefit_hours / H) if H > 0 else math.nan
    return benefit_hours, roit, None

dispatch = {
    "human":  compute_human,
    "mixed":  compute_mixed,
    "dual":   compute_dual,
    "legacy": compute_legacy,
}
if mode not in dispatch:
    raise SystemExit(f"Unknown ROIT_MODE: {mode}")

benefit_hours, roit, roit_runtime = dispatch[mode]()

# ---- summary ----
print("## ROI (artifacts only)")
if wd: print(f"- Window (days): {wd}")
print(f"- Runs: {runs} | Avg now: {ta:.2f}s | Baseline: {tb:.2f}s")
print(f"- PRs: {prs} | First-pass now: {pa:.3f} | Baseline: {pb:.3f}")
print(f"- Rework hrs/failed PR (R): {R} | Hours logged: {H:.2f}")
print(f"- Runtime drift: {delta_t_sec:.2f}s/run × {runs} = {time_delta_hours:+.2f} h "
      f"(savings={time_savings_hours:.2f}, penalty={time_penalty_hours:.2f})")
print(f"- Mode: {mode}")
if math.isnan(roit):
    print("- ROIT: **NA**")
else:
    print(f"- ROIT: **{roit:.2f} benefit-hours/hour**")
if roit_runtime is not None:
    print(f"- ROIT(runtime): {('NA' if math.isnan(roit_runtime) else f'{roit_runtime:.2f}')}")
print(f"- Benefit (hours): {benefit_hours:.2f}  [pr={pr_benefit_hours:.2f}]")

# ---- JSON ----
out = {
  "schema": SCHEMA,
  "mode": mode,
  "window_days": int(float(wd)) if (wd and wd.replace(".","",1).isdigit()) else wd or None,
  "runs": runs, "ta_sec": ta, "tb_sec": tb,
  "prs": prs, "pa": pa, "pb": pb, "R": R,
  "hours": H, "h_compute": H_COMPUTE,
  "blocking_factor": B, "parallelism": C,
  "time_delta_hours": round(time_delta_hours, 4),
  "time_savings_hours": round(time_savings_hours, 4),
  "time_penalty_hours": round(time_penalty_hours, 4),
  "benefit_pr_hours": round(pr_benefit_hours, 4),
  "benefit_hours": round(benefit_hours, 4),
  "roit": None if math.isnan(roit) else round(roit, 4),
  "roit_runtime": None if (roit_runtime is None or math.isnan(roit_runtime)) else round(roit_runtime, 4),
  "floor_ta_sec": FLOOR_TA_SEC,
}
with open(ROI_JSON_PATH, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)
print(f"- Wrote {ROI_JSON_PATH}")
