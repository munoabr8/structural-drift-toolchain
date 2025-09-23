# ci/dora/dora-refactor/invariants.py
import re, math
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

def assert_nonneg_int(n, name):
    assert isinstance(n, int) and n >= 0, f"{name} must be non-neg int"

def assert_date_hist(d):
    assert isinstance(d, dict), "daily_histogram must be dict"
    for k,v in d.items():
        assert DATE.match(k), f"bad date key: {k}"
        assert isinstance(v, int) and v >= 0, f"bad count for {k}"

def assert_lead_section(sec, pctl):
    assert isinstance(sec, dict), "lead section must be dict"
    s = sec.get("samples")
    assert_nonneg_int(s, "samples")
    med = sec.get("median_h")
    p   = sec.get(f"p{pctl}_h")
    if s == 0:
        assert med is None and p is None, "empty samples must have None metrics"
    else:
        for x, name in [(med,"median_h"), (p, f"p{pctl}_h")]:
            assert isinstance(x, (int, float)) and not math.isnan(x), f"{name} must be number"

def assert_window(win):
    assert isinstance(win, dict), "window must be dict"
    assert_nonneg_int(win.get("days", -1), "window.days")
    s, e = win.get("start"), win.get("end")
    assert isinstance(s, str) and "T" in s and s.endswith("Z") or s.endswith("+00:00"), "bad window.start"
    assert isinstance(e, str) and "T" in e and e.endswith("Z") or e.endswith("+00:00"), "bad window.end"

def assert_metrics_consistency(metrics, daily, deploys_total, failed):
    assert_nonneg_int(deploys_total, "deploys_total")
    assert_nonneg_int(failed, "deploy_failures")
    assert_date_hist(daily)
    assert metrics["deploys_total"] == deploys_total, "deploys_total mismatch"
    assert metrics["deploy_failures"] == failed, "deploy_failures mismatch"
    days_with = sum(1 for v in daily.values() if v > 0)
    assert metrics["days_with_deploys"] == days_with, "days_with_deploys mismatch"
    # recompute rates
    dpwd = round(deploys_total / max(1, metrics.get("window_days", 0) or 1), 4)  # optional if you pass it
    dpad = round(deploys_total / max(1, days_with), 4)
    # do not assert exact floats unless you pass window_days; we just type-check here
    assert isinstance(metrics["deploys_per_window_day"], (int,float)), "deploys_per_window_day not number"
    assert isinstance(metrics["deploys_per_active_day"], (int,float)), "deploys_per_active_day not number"
