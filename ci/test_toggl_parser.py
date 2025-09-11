import json
from datetime import date
import pytest
from roi.parsers import parse_toggl_csv, parse_toggl_json

CSV = """\
"User","Email","Client","Project","Description","Billable","Start date","Start time","End date","End time","Duration","Tags","Amount ()"
"Abe","abe@example.com","CI","Gates","PR triage","No","2025-09-03","08:00:00","2025-09-03","08:05:38","0:05:38","ci", ""
"Abe","abe@example.com","CI","Gates","Debug","No","2025-09-04","10:00:00","2025-09-04","19:00:00","9:00:00","ci", ""
"""

JSON = {
  "data": [
    # 5m38s on 2025-09-03 UTC
    {"start": "2025-09-03T08:00:00Z", "stop": "2025-09-03T08:05:38Z", "dur": 338, "wid": 123, "pid": 1, "description": "PR triage"},
    # 9h on 2025-09-04 UTC
    {"start": "2025-09-04T10:00:00Z", "stop": "2025-09-04T19:00:00Z", "dur": 32400, "wid": 123, "pid": 1, "description": "Debug"}
  ]
}

def test_toggl_csv_daily_totals_utc():
    totals = parse_toggl_csv(CSV, tz="UTC")  # returns {date: hours}
    assert totals[date(2025, 9, 3)] == pytest.approx(338/3600, rel=1e-6)
    assert totals[date(2025, 9, 4)] == pytest.approx(9.0, rel=1e-6)
    assert sum(totals.values()) == pytest.approx(9 + 338/3600, rel=1e-9)

def test_toggl_json_daily_totals_utc():
    totals = parse_toggl_json(JSON, tz="UTC")
    assert totals[date(2025, 9, 3)] == pytest.approx(338/3600, rel=1e-6)
    assert totals[date(2025, 9, 4)] == pytest.approx(9.0, rel=1e-6)

def test_toggl_json_ignores_running_entries():
    data = {"data": [{"start":"2025-09-04T10:00:00Z","dur":-1,"description":"running"}]}
    totals = parse_toggl_json(data, tz="UTC")
    assert totals == {}

def test_toggl_csv_timezone_bucket_to_americas():
    # Entry spans UTC day boundary. In America/New_York it should count on previous local date.
    csv = '"User","Email","Client","Project","Description","Billable","Start date","Start time","End date","End time","Duration","Tags","Amount ()"\n' \
          '"Abe","abe@example.com","CI","Gates","Late","No","2025-09-04","00:30:00","2025-09-04","01:00:00","0:30:00","ci",""'
    # UTC 00:30 is 20:30 previous day in ET (assuming DST, UTC-4)
    totals = parse_toggl_csv(csv, tz="America/New_York")
    assert totals[date(2025, 9, 3)] == pytest.approx(0.5, rel=1e-6)
    assert date(2025, 9, 4) not in totals

def test_toggl_csv_filters_negative_and_zero():
    bad = '"User","Email","Client","Project","Description","Billable","Start date","Start time","End date","End time","Duration","Tags","Amount ()"\n' \
          '"Abe","abe@example.com","CI","Gates","Zero","No","2025-09-03","08:00:00","2025-09-03","08:00:00","0:00:00","ci",""\n' \
          '"Abe","abe@example.com","CI","Gates","Negative","No","2025-09-03","08:00:00","2025-09-03","07:59:00","-0:01:00","ci",""'
    totals = parse_toggl_csv(bad, tz="UTC")
    assert totals == {}
