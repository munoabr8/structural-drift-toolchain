#!/usr/bin/env python3
# Usage:
#   python roi/emit_ci_hours.py toggl toggl_report.json > ci-hours.csv
#   python roi/emit_ci_hours.py github runs.json > ci-hours.csv
import sys, json
from datetime import date
from parsers import parse_toggl_json, durations_from_github_runs, daily_totals_from_durations

def emit(totals):
    print("date,hours")
    for d in sorted(totals):
        print(f"{d.isoformat()},{totals[d]}")

if __name__ == "__main__":
    if len(sys.argv) != 3: sys.exit("usage: emit_ci_hours.py <toggl|github> <input.json>")
    mode, path = sys.argv[1], sys.argv[2]
    obj = json.load(open(path))
    if mode == "toggl":
        totals = parse_toggl_json(obj, tz="America/New_York")
        emit(totals)
    elif mode == "github":
        runs = obj.get("workflow_runs") or []
        dates = [(r.get("run_started_at") or r.get("created_at") or "")[:10] for r in runs]
        secs = durations_from_github_runs(obj)
        totals = daily_totals_from_durations(secs, dates, tz="UTC")
        emit(totals)
    else:
        sys.exit("mode must be toggl or github")
