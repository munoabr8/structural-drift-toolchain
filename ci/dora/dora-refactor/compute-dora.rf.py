#!/usr/bin/env python3
# ci/dora/compute-dora.py

import os, sys, json
from datetime import datetime, timedelta, timezone

from dora_io import load_ndjson, dump_json
from dora_validate import warn_shape, warn_timestamps, assert_ndjson
from dora_pair import lead_times_deployment, lead_times_change, to_dt
from dora_aggregate import deployments_in_window, daily_histogram, failure_count
from dora_assemble import assemble_dora

def now_utc():
    return datetime.now(timezone.utc)

def main():
    # ---- args ----
    if len(sys.argv) < 2:
        print("usage: compute-dora.py <events.ndjson>", file=sys.stderr); sys.exit(64)
    path = sys.argv[1]
    events = load_ndjson(path)

    # ---- env ----
    WINDOW_DAYS = int(os.getenv("WINDOW_DAYS", "14"))
    PCTL        = int(os.getenv("PCTL", "90"))
    LT_MIN_LEAD_SECONDS = int(os.getenv("LT_MIN_LEAD_SECONDS", "300"))
    PAIR_MODE   = os.getenv("LT_PAIR_MODE", "change")  # change|deployment|both
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

    # ---- assemble ----
    dora = assemble_dora(
        events=ev_for_lt,
        deploys=deploys,
        failed=failed,
        daily=daily,
        window_days=WINDOW_DAYS,
        start=start, end=end,
        pctl=PCTL,
        min_sec=LT_MIN_LEAD_SECONDS,
        pair_mode=PAIR_MODE,
        lt_change=lt_change,
        lt_deploy=lt_deploy
    )

    dump_json(dora)

if __name__ == "__main__":
    main()
