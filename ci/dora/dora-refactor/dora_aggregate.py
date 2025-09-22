from collections import Counter
from dora_pair import to_dt

def deployments_in_window(events, start, end):
    return [e for e in events if e.get("type")=="deployment" and start<=to_dt(e["finished_at"])<=end]

def daily_histogram(deploys):
    c=Counter(d["finished_at"][:10] for d in deploys)
    return dict(sorted(c.items()))
    
def failure_count(deploys):
    bad={"failure","failed","cancelled","canceled"}
    return sum(1 for d in deploys if str(d.get("status","")).lower() in bad)
