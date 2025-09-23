# ci/dora/dora-refactor/dora_validate.py

import re

HEX40 = re.compile(r"^[0-9a-f]{40}$")

def _is_iso_z(s: str) -> bool:
    return isinstance(s, str) and s.endswith("Z") and "T" in s and len(s) >= 20

def assert_ndjson(events):
    """
    Hard assertions. Raise AssertionError on first violation.
    """
    for i, e in enumerate(events):
        if e.get("schema") != "events/v1":
            raise AssertionError(f"[{i}] schema!=events/v1")
        t = e.get("type")
        if t not in {"pr_merged", "deployment"}:
            raise AssertionError(f"[{i}] bad type:{t}")

        if t == "pr_merged":
            if not isinstance(e.get("pr"), int):
                raise AssertionError(f"[{i}] pr not int")
            if not (isinstance(e.get("merge_commit_sha"), str) and HEX40.match(e["merge_commit_sha"])):
                raise AssertionError(f"[{i}] bad merge_commit_sha")
            if not (isinstance(e.get("head_sha"), str) and HEX40.match(e["head_sha"])):
                raise AssertionError(f"[{i}] bad head_sha")
            if not (isinstance(e.get("sha"), str) and HEX40.match(e["sha"])):
                raise AssertionError(f"[{i}] bad sha (copy of merge)")
            if not _is_iso_z(e.get("merged_at", "")):
                raise AssertionError(f"[{i}] bad merged_at")

        elif t == "deployment":
            if not (isinstance(e.get("sha"), str) and HEX40.match(e["sha"])):
                raise AssertionError(f"[{i}] bad sha")
            st = str(e.get("status", "")).lower()
            if st not in {"success", "failure", "failed", "cancelled", "canceled"}:
                raise AssertionError(f"[{i}] bad status:{st}")
            if not _is_iso_z(e.get("finished_at", "")):
                raise AssertionError(f"[{i}] bad finished_at")

def warn_shape(events):
    """
    Soft checks. Print counts; do not raise.
    """
    bad_schema = sum(1 for e in events if e.get("schema") != "events/v1")
    bad_type   = sum(1 for e in events if e.get("type") not in {"pr_merged", "deployment"})
    if bad_schema: print(f"WARN: bad schema rows: {bad_schema}")
    if bad_type:   print(f"WARN: bad type rows: {bad_type}")

def warn_timestamps(events):
    bad_merge = sum(1 for e in events if e.get("type")=="pr_merged" and not _is_iso_z(e.get("merged_at","")))
    bad_fin   = sum(1 for e in events if e.get("type")=="deployment" and not _is_iso_z(e.get("finished_at","")))
    if bad_merge: print(f"WARN: bad merged_at rows: {bad_merge}")
    if bad_fin:   print(f"WARN: bad finished_at rows: {bad_fin}")
