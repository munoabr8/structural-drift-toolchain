from datetime import datetime, timezone
import statistics as stats
def to_dt(s): return datetime.strptime(s,"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
def percentile(xs,p):
    if not xs: return None
    xs=sorted(xs); k=(len(xs)-1)*p/100; i=int(k); j=min(i+1,len(xs)-1)
    return xs[i]+(xs[j]-xs[i])*(k-i)

def lead_times_change(events, min_sec, pctl):
    prs={e["sha"]:e for e in events if e.get("type")=="pr_merged"}
    seen=set(); hours=[]
    for d in (e for e in events if e.get("type")=="deployment"):
        s=d["sha"]
        if s in seen: continue
        seen.add(s)
        p=prs.get(s); 
        if not p: continue
        dt=(to_dt(d["finished_at"])-to_dt(p["merged_at"])).total_seconds()
        if dt>=min_sec: hours.append(dt/3600.0)
    return {"samples":len(hours),
            "median_h": round(stats.median(hours),4) if hours else None,
            f"p{pctl}_h": round(percentile(hours,pctl),4) if hours else None}

def lead_times_deployment(events, min_sec, pctl):
    prs={e["sha"]:e for e in events if e.get("type")=="pr_merged"}
    hours=[]
    for d in (e for e in events if e.get("type")=="deployment"):
        p=prs.get(d["sha"]); 
        if not p: continue
        dt=(to_dt(d["finished_at"])-to_dt(p["merged_at"])).total_seconds()
        if dt>=min_sec: hours.append(dt/3600.0)
    return {"samples":len(hours),
            "median_h": round(stats.median(hours),4) if hours else None,
            f"p{pctl}_h": round(percentile(hours,pctl),4) if hours else None}
