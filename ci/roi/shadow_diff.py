#!/usr/bin/env python3
import os, sys, json, math

def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def sgn(x): 
    return 0 if x == 0 else (1 if x > 0 else -1)

if len(sys.argv) != 3:
    sys.exit("usage: shadow_diff.py <old.json> <new.json>")

old = load(sys.argv[1])
new = load(sys.argv[2])

tol  = float(os.getenv("SHADOW_TOL", "0.05"))   # 5% default
mode = os.getenv("MODE", "warn")                # warn | fail

bo = float(old.get("benefit_hours", 0.0))
bn = float(new.get("benefit_hours", 0.0))
to = float(old.get("benefit_time_hours", 0.0))
tn = float(new.get("benefit_time_hours", 0.0))
po = float(old.get("benefit_pr_hours", 0.0))
pn = float(new.get("benefit_pr_hours", 0.0))

den = abs(bo) if abs(bo) > 1e-9 else 1.0
rel = abs(bn - bo) / den
ok  = (rel <= tol) and (sgn(to) == sgn(tn)) and (sgn(po) == sgn(pn))
verdict = "ACCEPT" if ok else "REVIEW"

print("### ROI shadow diff")
print(f"- benefit_hours old/new: {bo:.2f} → {bn:.2f} (Δ={bn-bo:.2f}, rel={rel:.2%}, tol={tol:.0%})")
print(f"- time term sign: {sgn(to)} → {sgn(tn)}")
print(f"- pr   term sign: {sgn(po)} → {sgn(pn)}")
print(f"- Verdict: {verdict} ({'non-blocking' if mode!='fail' else 'blocking'})")

# GitHub outputs
out = os.getenv("GITHUB_OUTPUT")
if out:
    with open(out, "a", encoding="utf-8") as fh:
        fh.write(f"verdict={verdict}\n")
        fh.write(f"rel_delta={rel:.6f}\n")

# Exit status
if mode == "fail" and not ok:
    sys.exit(2)
