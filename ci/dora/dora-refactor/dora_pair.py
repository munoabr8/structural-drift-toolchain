from datetime import datetime, timezone
import statistics as stats


def to_dt(s): return datetime.strptime(s,"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

def percentile(xs,p):
    if not xs: return None
    xs=sorted(xs); k=(len(xs)-1)*p/100; i=int(k); j=min(i+1,len(xs)-1)
    return xs[i]+(xs[j]-xs[i])*(k-i)


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


 
def normalize_deploy_sha(events):
    """
    Returns a dict mapping deploy SHA -> normalized SHA (merge SHA if known).
    Uses PR rows present in 'events' (head_sha -> merge_commit_sha).
    """
    head_to_merge = {
        e["head_sha"]: e["merge_commit_sha"]
        for e in events if e.get("type") == "pr_merged"
    }
    norm = {}
    for d in (e for e in events if e.get("type") == "deployment"):
        sha = d["sha"]
        norm[sha] = head_to_merge.get(sha, sha)
    return norm



def lead_times_change(events, min_sec=0, pctl=90):
    norm = normalize_deploy_sha(events)

    # PR merge time by merge SHA
    pr_at = {
        e["merge_commit_sha"]: to_dt(e["merged_at"])
        for e in events if e.get("type") == "pr_merged"
    }

    earliest_dep_at = {}
    for d in (e for e in events if e.get("type") == "deployment"):
        msha = norm.get(d["sha"], d["sha"])  # normalize
        m_at = pr_at.get(msha)
        if not m_at:
            continue
        f_at = to_dt(d["finished_at"])
        if f_at < m_at:
            continue
        prev = earliest_dep_at.get(msha)
        if prev is None or f_at < prev:
            earliest_dep_at[msha] = f_at

    hours = []
    for msha, f_at in earliest_dep_at.items():
        dt = (f_at - pr_at[msha]).total_seconds()
        if dt >= min_sec:
            hours.append(dt/3600.0)

    return {
        "samples": len(hours),
        "median_h": round(stats.median(hours), 4) if hours else None,
        f"p{pctl}_h": round(percentile(hours, pctl), 4) if hours else None,
    }


