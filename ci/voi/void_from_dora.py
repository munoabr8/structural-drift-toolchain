#!/usr/bin/env python3
"""
voi_from_dora.py
Compute a VOI ranking from DORA aggregates.

Pipeline intent:
  events.ndjson -> dora.json -> voi_items.json -> roi.json

Usage:
  python voi_from_dora.py <dora.json> <outdir>

Env knobs:
  VOI_RATE_PER_HOUR=50
  VOI_MONTHLY_DISCOUNT=0.05
  VOI_TARGET_DEP_PER_DAY=0.714     # ~5/week
  VOI_HORIZON_DAYS=30

  # CFR lever
  VOI_FAIL_HOURS_SAVED=3
  VOI_FAIL_COST_HOURS=6
  VOI_FAIL_P_CHANGE=0.55
  VOI_FAIL_CONF=0.65
  VOI_FAIL_DELAY_D=5

  # Lead-time lever
  VOI_LEAD_ALPHA=1.0               # fraction of (p90-p50) realized
  VOI_LEAD_HORIZON_DEPLOYS=0       # 0 → use expected deploys in horizon
  VOI_LEAD_COST_HOURS=4
  VOI_LEAD_P_CHANGE=0.5
  VOI_LEAD_CONF=0.6
  VOI_LEAD_DELAY_D=7

  # Frequency lever
  VOI_FREQ_COST_HOURS=4
  VOI_FREQ_P_CHANGE=0.5
  VOI_FREQ_CONF=0.6
  VOI_FREQ_DELAY_D=7
  VOI_FREQ_VALUE_PER_DEPLOY_H=0.25 # hours of value per added deploy

  # Optional instrumentation lever
  VOI_INSTR_ENABLE=1
  VOI_INSTR_COST_HOURS=2
  VOI_INSTR_P_CHANGE=0.8
  VOI_INSTR_CONF=0.7
  VOI_INSTR_DELAY_D=1
  VOI_INSTR_DELTA_USD_IF_FAILS=60
  VOI_INSTR_DELTA_USD_IF_ZERO_FAILS=100
"""
import os, sys, json
from pathlib import Path
from datetime import datetime, timezone

# ---------- helpers ----------
def die(msg, code=64):
    print(msg, file=sys.stderr); sys.exit(code)

def float_env(name, default):
    val = os.getenv(name, str(default))
    try:
        return float(val)
    except ValueError:
        die(f"bad env {name}={val!r}")

def clamp01(x): return max(0.0, min(1.0, float(x)))

def discount(days: float, monthly_rate: float) -> float:
    return 1.0 / ((1.0 + monthly_rate) ** (max(0.0, days) / 30.0))

def item(id, domain, delta_usd, cost_hours, p_change, conf, delay_d, rate_h, monthly_disc, note):
    p_eff = clamp01(p_change) * clamp01(conf)
    ev = p_eff * float(delta_usd) - float(cost_hours) * rate_h
    ev_adj = ev * discount(float(delay_d), monthly_disc)
    hrs = max(0.25, float(cost_hours))
    return {
        "id": id, "domain": domain,
        "delta_util": round(float(delta_usd), 2),
        "cost": round(float(cost_hours) * rate_h, 2),
        "duration_h": float(cost_hours),
        "p_change": float(p_change), "confidence": float(conf),
        "delay_days": float(delay_d),
        "VOI_raw": round(ev, 2),
        "VOI_adj": round(ev_adj, 2),
        "voi_per_hour": round(ev_adj / hrs, 2),
        "note": note,
    }

def read_json(path: Path):
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        die(f"failed to read {path}: {e}")

def need(d: dict, key: str):
    if key not in d:
        die(f"bad dora.json: missing '{key}'")

# ---------- main ----------
if len(sys.argv) < 3:
    die("usage: voi_from_dora.py <dora.json> <outdir>")

in_path = Path(sys.argv[1])
outdir = Path(sys.argv[2]); outdir.mkdir(parents=True, exist_ok=True)
dora = read_json(in_path)

# Strict schema (fail fast)
need(dora, "deploys"); need(dora, "lead_time")
need(dora["deploys"], "total"); need(dora["deploys"], "fail"); need(dora["deploys"], "per_day")
need(dora["lead_time"], "n"); need(dora["lead_time"], "p50"); need(dora["lead_time"], "p90")
window_days = float(dora.get("window_days", 14.0))

dep_total    = int(dora["deploys"]["total"])
dep_fail     = int(dora["deploys"]["fail"])
dep_per_day  = float(dora["deploys"]["per_day"])
lead_n       = int(dora["lead_time"]["n"])
lead_p50_min = float(dora["lead_time"]["p50"])
lead_p90_min = float(dora["lead_time"]["p90"])
cfr = (dep_fail / dep_total) if dep_total > 0 else 0.0

# Economics + horizon
RATE_H            = float_env("VOI_RATE_PER_HOUR", 50)
MONTHLY_DISCOUNT  = float_env("VOI_MONTHLY_DISCOUNT", 0.05)
TARGET_DEP_PD     = float_env("VOI_TARGET_DEP_PER_DAY", 5.0/7.0)
HORIZON_DAYS      = float_env("VOI_HORIZON_DAYS", 30)
exp_deploys       = dep_per_day * HORIZON_DAYS

items = []

# A) Reduce change failure rate
H_FAIL_SAVED = float_env("VOI_FAIL_HOURS_SAVED", 3.0)
C_FAIL_H     = float_env("VOI_FAIL_COST_HOURS", 6.0)
P_FAIL       = float_env("VOI_FAIL_P_CHANGE", 0.55)
CONF_FAIL    = float_env("VOI_FAIL_CONF", 0.65)
DELAY_FAIL_D = float_env("VOI_FAIL_DELAY_D", 5.0)
avoided_fails = cfr * exp_deploys  # potential avoided failures if CFR→0
delta_fail_usd = avoided_fails * H_FAIL_SAVED * RATE_H
items.append(item("reduce_change_failure","release",delta_fail_usd,C_FAIL_H,P_FAIL,CONF_FAIL,DELAY_FAIL_D,RATE_H,MONTHLY_DISCOUNT,"CFR↓ over horizon"))

# B) Trim lead-time tail (p90→p50)
LEAD_ALPHA   = float_env("VOI_LEAD_ALPHA", 1.0)
H_DEPLOY     = float_env("VOI_LEAD_HORIZON_DEPLOYS", 0.0)  # if 0, use exp_deploys
C_LEAD_H     = float_env("VOI_LEAD_COST_HOURS", 4.0)
P_LEAD       = float_env("VOI_LEAD_P_CHANGE", 0.5)
CONF_LEAD    = float_env("VOI_LEAD_CONF", 0.6)
DELAY_LEAD_D = float_env("VOI_LEAD_DELAY_D", 7.0)
deploy_count = exp_deploys if H_DEPLOY <= 0 else H_DEPLOY
gap_min = max(0.0, lead_p90_min - lead_p50_min)
delta_lead_usd = (gap_min/60.0) * RATE_H * deploy_count * LEAD_ALPHA
if gap_min > 0 and deploy_count > 0:
    items.append(item("trim_p90_lead_time","delivery",delta_lead_usd,C_LEAD_H,P_LEAD,CONF_LEAD,DELAY_LEAD_D,RATE_H,MONTHLY_DISCOUNT,"p90→p50 over horizon"))

# C) Increase deploy frequency toward target
C_FREQ_H     = float_env("VOI_FREQ_COST_HOURS", 4.0)
P_FREQ       = float_env("VOI_FREQ_P_CHANGE", 0.5)
CONF_FREQ    = float_env("VOI_FREQ_CONF", 0.6)
DELAY_FREQ_D = float_env("VOI_FREQ_DELAY_D", 7.0)
VAL_PER_DEPLOY_H = float_env("VOI_FREQ_VALUE_PER_DEPLOY_H", 0.25)
gap_pd = max(0.0, TARGET_DEP_PD - dep_per_day)
added_deploys = gap_pd * HORIZON_DAYS
delta_freq_usd = added_deploys * VAL_PER_DEPLOY_H * RATE_H
if added_deploys > 0:
    items.append(item("increase_deploy_frequency","release",delta_freq_usd,C_FREQ_H,P_FREQ,CONF_FREQ,DELAY_FREQ_D,RATE_H,MONTHLY_DISCOUNT,"deploy/day↑ to target"))

# D) Optional instrumentation
if int(float_env("VOI_INSTR_ENABLE", 1)) == 1:
    C_INSTR_H   = float_env("VOI_INSTR_COST_HOURS", 2.0)
    P_INSTR     = float_env("VOI_INSTR_P_CHANGE", 0.8)
    CONF_INSTR  = float_env("VOI_INSTR_CONF", 0.7)
    DELAY_INSTR = float_env("VOI_INSTR_DELAY_D", 1.0)
    DELTA_IF_F  = float_env("VOI_INSTR_DELTA_USD_IF_FAILS", 60.0)
    DELTA_IF_Z  = float_env("VOI_INSTR_DELTA_USD_IF_ZERO_FAILS", 100.0)
    delta_instr = DELTA_IF_F if dep_fail > 0 else DELTA_IF_Z
    items.append(item("instrument_deploy_events","release",delta_instr,C_INSTR_H,P_INSTR,CONF_INSTR,DELAY_INSTR,RATE_H,MONTHLY_DISCOUNT,"observability enablement"))

# Rank
items.sort(key=lambda r: (r["voi_per_hour"], r["VOI_adj"]), reverse=True)

# Output
out = {
    "meta": {
        "schema": "voi/v1",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": str(in_path),
        "horizon_days": HORIZON_DAYS,
        "rate_per_hour": RATE_H,
        "discount_monthly": MONTHLY_DISCOUNT,
        "target_dep_per_day": TARGET_DEP_PD,
        "window_days_observed": window_days,
        "observed": {
            "deploys_total": dep_total,
            "deploys_fail": dep_fail,
            "deploys_per_day": dep_per_day,
            "lead_n": lead_n,
            "lead_p50_min": lead_p50_min,
            "lead_p90_min": lead_p90_min,
            "cfr": round(cfr, 4),
            "expected_deploys_in_horizon": round(exp_deploys, 2),
        },
    },
    "items": items,
}

out_path = outdir / "voi_items.json"
with out_path.open("w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)

print(str(out_path))
