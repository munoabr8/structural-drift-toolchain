#!/usr/bin/env python3
# ci/dora/compute-dora.rf.py
import os, sys, json, csv
from datetime import datetime, timedelta, timezone

from dora_io import load_ndjson, dump_json

from dora_validate import warn_shape, warn_timestamps, assert_ndjson

from dora_pair import lead_times_deployment, lead_times_change, to_dt

from dora_aggregate import deployments_in_window, daily_histogram, failure_count

from dora_assemble import assemble_dora


# This script must be given the path to events.ndjson.
# This script will does not search for it on its own.
# useage:
# python3 ci/dora/dora-refactor/main.py ci/dora/events.ndjson


def as_int(name, default):
    v = os.getenv(name, str(default))
    if not v.isdigit(): print(f"bad {name}={v}", file=sys.stderr); sys.exit(64)
    return int(v)

def now_utc():
    return datetime.now(timezone.utc)

def main():
    # ---- args ----
    if len(sys.argv) < 2:
        print("usage: compute-dora.py <events.ndjson>", file=sys.stderr); sys.exit(64)
    path = sys.argv[1]
    events = load_ndjson(path)

    # ---- env ----
    WINDOW_DAYS = as_int("WINDOW_DAYS", 14)
    PCTL = as_int("PCTL", 90)
    LT_MIN_LEAD_SECONDS = as_int("LT_MIN_LEAD_SECONDS", 300)

   # WINDOW_DAYS = int(os.getenv("WINDOW_DAYS", "14"))
   # PCTL        = int(os.getenv("PCTL", "90"))
   # LT_MIN_LEAD_SECONDS = int(os.getenv("LT_MIN_LEAD_SECONDS", "300"))


    PAIR_MODE = os.getenv("LT_PAIR_MODE", "change").lower()
    if PAIR_MODE not in {"change","deployment","both"}:
        print(f"bad LT_PAIR_MODE={PAIR_MODE}", file=sys.stderr); sys.exit(64)

    #PAIR_MODE   = os.getenv("LT_PAIR_MODE", "change")  # change|deployment|both
    STRICT      = int(os.getenv("STRICT", "0"))

    # ---- basic validation (non-fatal unless STRICT=1) ----
    try:
        assert_ndjson(events)
    except AssertionError as e:
        if STRICT: 
            print(f"ERR:{e}", file=sys.stderr); sys.exit(65)
    warn_shape(events)
    warn_timestamps(events)

    # ---- window ----
    end   = now_utc()
    start = end - timedelta(days=WINDOW_DAYS)

    # limit deploy-side metrics to window, allow PRs from all time for pairing
    deploys = deployments_in_window(events, start, end)
    daily   = daily_histogram(deploys)
    failed  = failure_count(deploys)

    # compose pairing input: all PRs + windowed deployments
    pr_all = [e for e in events if e.get("type") == "pr_merged"]
    ev_for_lt = pr_all + deploys

    # ---- lead times ----
    lt_change = lead_times_change(ev_for_lt, LT_MIN_LEAD_SECONDS, PCTL)
    lt_deploy = None
    if PAIR_MODE in ("deployment", "both"):
        lt_deploy = lead_times_deployment(ev_for_lt, LT_MIN_LEAD_SECONDS, PCTL)


   


    LEADTIME_CSV = os.getenv("LEADTIME_CSV", "")
    details = (isinstance(lt_change, dict) and lt_change.get("details")) or \
              (isinstance(lt_deploy, dict) and lt_deploy.get("details")) or []
    if LEADTIME_CSV and details:
        os.makedirs(os.path.dirname(LEADTIME_CSV) or ".", exist_ok=True)

        import csv
        fieldnames = ["pr","sha","merged_at","deployed_at","lead_seconds","lead_minutes","lead_hours","match"]
        def norm(r):
            pr, sha = r.get("pr"), r.get("sha")
            merged_at, deployed_at = r.get("merged_at"), r.get("deployed_at")
            lead_sec = r.get("lead_seconds") or r.get("lead_sec")
            if lead_sec is None and merged_at and deployed_at:
                t1, t2 = to_dt(merged_at), to_dt(deployed_at)
                lead_sec = int((t2 - t1).total_seconds())
            return {
                "pr": pr, "sha": sha,
                "merged_at": merged_at, "deployed_at": deployed_at,
                "lead_seconds": lead_sec,
                "lead_minutes": (lead_sec/60.0) if lead_sec is not None else None,
                "lead_hours": (lead_sec/3600.0) if lead_sec is not None else None,
                "match": r.get("match", True),
            }
        rows = [norm(r) for r in details]
        rows.sort(key=lambda x: (x["merged_at"] or "", x["deployed_at"] or ""))
        with open(LEADTIME_CSV, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames); w.writeheader(); w.writerows(rows)

    # --- always assemble + emit JSON ---
    dora = assemble_dora(
        events=ev_for_lt, deploys=deploys, failed=failed, daily=daily,
        window_days=WINDOW_DAYS, start=start, end=end, pctl=PCTL,
        min_sec=LT_MIN_LEAD_SECONDS, pair_mode=PAIR_MODE,
        lt_change=lt_change, lt_deploy=lt_deploy
    )
    dump_json(dora)

if __name__ == "__main__":
    main()




