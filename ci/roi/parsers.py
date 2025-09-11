# roi/parsers.py
from __future__ import annotations
import csv
import json
from datetime import datetime, date, timedelta, timezone
from typing import Dict, List, Iterable, Optional
try:
    from zoneinfo import ZoneInfo  # py39+
except ImportError:  # pragma: no cover
    from backports.zoneinfo import ZoneInfo  # type: ignore


def _to_zone(dt: datetime, tz: str) -> datetime:
    """Return timezone-aware datetime in target tz. Treat naive as UTC."""
    z = ZoneInfo(tz)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(z)


def _bucket_hours_by_local_date(start: datetime, seconds: float, tz: str) -> Dict[date, float]:
    """
    Bucket a duration (in seconds) by LOCAL calendar day(s) in tz.
    Splits across midnight if needed. Returns {local_date: hours}.
    """
    if seconds <= 0:
        return {}
    start_local = _to_zone(start, tz)
    remaining = seconds
    out: Dict[date, float] = {}
    current = start_local
    while remaining > 0:
        # end of current local day
        day_end = datetime(
            year=current.year, month=current.month, day=current.day,
            hour=23, minute=59, second=59, tzinfo=current.tzinfo
        ) + timedelta(seconds=1)  # first second of next day
        slice_sec = min(remaining, (day_end - current).total_seconds())
        out.setdefault(current.date(), 0.0)
        out[current.date()] += slice_sec / 3600.0
        current += timedelta(seconds=slice_sec)
        remaining -= slice_sec
    return out


# --- Toggl CSV ---

def parse_toggl_csv(csv_text: str, tz: str) -> Dict[date, float]:
    """
    Parse a Toggl CSV export text and return daily totals in HOURS, keyed by local date in tz.
    Expects columns like: Start date, Start time, End date, End time, Duration.
    Ignores zero/negative durations.
    """
    reader = csv.DictReader(csv_text.splitlines())
    totals: Dict[date, float] = {}
    for row in reader:
        try:
            s_date = row.get("Start date") or row.get("Start Date")
            s_time = row.get("Start time") or row.get("Start Time")
            e_date = row.get("End date") or row.get("End Date")
            e_time = row.get("End time") or row.get("End Time")
            if not (s_date and s_time and e_date and e_time):
                continue
            # Treat CSV timestamps as UTC unless they carry TZ info.
            start = datetime.fromisoformat(f"{s_date}T{s_time}")
            end = datetime.fromisoformat(f"{e_date}T{e_time}")
            if start.tzinfo is None:
                start = start.replace(tzinfo=timezone.utc)
            if end.tzinfo is None:
                end = end.replace(tzinfo=timezone.utc)
            seconds = (end - start).total_seconds()
            if seconds <= 0:
                continue
            by_day = _bucket_hours_by_local_date(start, seconds, tz)
            for d, h in by_day.items():
                totals[d] = totals.get(d, 0.0) + h
        except Exception:
            # Robust to odd rows; skip
            continue
    return totals


# --- Toggl JSON (Reports API / detailed) ---

def parse_toggl_json(obj: dict, tz: str) -> Dict[date, float]:
    """
    Parse a Toggl JSON object with entries under obj['data'].
    Uses 'start', 'stop', 'dur' (seconds). Ignores running entries (dur < 0) and non-positive durations.
    Buckets by local date in tz. Splits across midnight when needed.
    """
    data = obj.get("data") or []
    totals: Dict[date, float] = {}
    for e in data:
        dur = e.get("dur")
        start_s = e.get("start")
        stop_s = e.get("stop")
        if dur is None or dur < 0:
            # running or invalid
            continue
        try:
            start = datetime.fromisoformat(start_s.replace("Z", "+00:00")) if start_s else None
            stop = datetime.fromisoformat(stop_s.replace("Z", "+00:00")) if stop_s else None
        except Exception:
            start = stop = None

        # Prefer provided positive 'dur'. If absent, compute from start/stop.
        seconds: Optional[float] = None
        if isinstance(dur, (int, float)) and dur > 0:
            seconds = float(dur) / 1000.0 
        elif start and stop:
            seconds = (stop - start).total_seconds()

        if not (start and seconds and seconds > 0):
            continue


        by_day = _bucket_hours_by_local_date(start, seconds, tz)
        for d, h in by_day.items():
            totals[d] = totals.get(d, 0.0) + h
    return totals


# --- GitHub run durations ---

def durations_from_github_runs(obj: dict) -> List[int]:
    """
    Extract completed run durations in SECONDS from a GitHub workflow_runs payload.
    Uses updated_at - run_started_at when status == 'completed' and both timestamps exist.
    Filters non-positive durations.
    """
    runs = obj.get("workflow_runs") or []
    out: List[int] = []
    for r in runs:
        if r.get("status") != "completed":
            continue
        start_s = r.get("run_started_at")
        end_s = r.get("updated_at")
        if not (start_s and end_s):
            continue
        try:
            start = datetime.fromisoformat(start_s.replace("Z", "+00:00"))
            end = datetime.fromisoformat(end_s.replace("Z", "+00:00"))
            sec = int((end - start).total_seconds())
            if sec > 0:
                out.append(sec)
        except Exception:
            continue
    return out


def daily_totals_from_durations(
    secs: Iterable[int],
    dates: Iterable[str],
    tz: str = "UTC",
) -> Dict[date, float]:
    """
    Map each duration (seconds) to its corresponding ISO date string in `dates`.
    Returns daily totals in HOURS keyed by date objects. Lengths must match.
    `tz` kept for API symmetry; dates are taken as local calendar labels already.
    """
    sec_list = list(secs)
    date_list = list(dates)
    if len(sec_list) != len(date_list):
        raise ValueError("secs and dates must be same length")
    totals: Dict[date, float] = {}
    for s, ds in zip(sec_list, date_list):
        if s <= 0:
            continue
        try:
            d = datetime.fromisoformat(ds).date()
        except ValueError:
            # accept bare YYYY-MM-DD
            d = date.fromisoformat(ds)
        totals[d] = totals.get(d, 0.0) + (s / 3600.0)
    return totals
