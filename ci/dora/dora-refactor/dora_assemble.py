def assemble_dora(events, deploys, failed, daily, window_days, start, end,
                  pctl, min_sec, pair_mode, lt_change, lt_deploy):
    metrics={
      "deploys_total": len(deploys),
      "deploy_failures": failed,
      "days_with_deploys": sum(1 for v in daily.values() if v>0),
      "deploys_per_window_day": round(len(deploys)/max(window_days,1),4),
      "deploys_per_active_day": round(len(deploys)/max(sum(1 for v in daily.values() if v>0),1),4),
      "daily_histogram": daily,
    }
    out={"schema":"dora/v1","window":{"days":window_days,"start":start.isoformat(),"end":end.isoformat()},"metrics":metrics}
    if pair_mode in ("change","both"): out["lead_time_change"]=lt_change
    if pair_mode in ("deployment","both"): out["lead_time_deployment"]=lt_deploy
    return out
