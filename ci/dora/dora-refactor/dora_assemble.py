from invariants import (
    assert_window, assert_metrics_consistency, assert_lead_section
)


def assemble_dora(*, events, deploys, failed, daily, window_days,
                  start, end, pctl, min_sec, pair_mode,
                  lt_change=None, lt_deploy=None):
    # ----- build -----
    metrics = {
        "deploys_total": len(deploys),
        "deploy_failures": failed,
        "days_with_deploys": sum(1 for v in daily.values() if v > 0),
        "deploys_per_window_day": round(len(deploys) / max(window_days, 1), 4),
        "deploys_per_active_day": round(len(deploys) / max(sum(1 for v in daily.values() if v > 0), 1), 4),
        "daily_histogram": dict(sorted(daily.items())),
    }
    out = {
        "schema": "dora/v1",
        "window": {
            "days": window_days,
            "start": start.isoformat(),
            "end": end.isoformat(),
        },
        "metrics": metrics,
    }
    if lt_change is not None:
        out["lead_time_change"] = lt_change
    if lt_deploy is not None:
        out["lead_time_deployment"] = lt_deploy

    # ----- invariants (assembly) -----
    assert_window(out["window"])
    # pass window_days into metrics check if you want strict float equality
    m = dict(metrics)
    m["window_days"] = window_days
    assert_metrics_consistency(m, out["metrics"]["daily_histogram"],
                               deploys_total=len(deploys), failed=failed)
    if "lead_time_change" in out:
        assert_lead_section(out["lead_time_change"], pctl)
    if "lead_time_deployment" in out:
        assert_lead_section(out["lead_time_deployment"], pctl)

    return out