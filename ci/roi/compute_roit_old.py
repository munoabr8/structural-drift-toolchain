# ./ci/roi/compute_roit.py
import os, math

wd = os.environ.get('WINDOW_DAYS', '')
tb = float(os.environ['TB']); ta = float(os.environ['TA']); runs = int(float(os.environ['RUNS']))
pb = float(os.environ['PB']); pa = float(os.environ['PA']); prs  = int(float(os.environ['PRS']))
R  = float(os.environ['R']);  H  = float(os.environ['H'])

pb = max(0.0, min(1.0, pb))
pa = max(0.0, min(1.0, pa))

time_benefit_hours = (tb - ta) * runs / 3600.0
pr_benefit_hours   = (pa - pb) * prs * R
benefit_hours      = time_benefit_hours + pr_benefit_hours
roit = (benefit_hours / H) if H > 0 else float('nan')

print("## ROI (artifacts only)")
if wd: print(f"- Window (days): {wd}")
print(f"- Runs: {runs} | Avg now: {ta:.2f}s | Baseline: {tb:.2f}s")
print(f"- PRs: {prs} | First-pass now: {pa:.3f} | Baseline: {pb:.3f}")
print(f"- Rework hrs/failed PR (R): {R} | Hours logged: {H:.2f}")
print(f"- Benefit (hours): {benefit_hours:.2f}  [time={time_benefit_hours:.2f}, pr={pr_benefit_hours:.2f}]")
print(f"- ROIT: **{roit:.2f} benefit-hours/hour**" if not math.isnan(roit)
      else "- ROIT: **NA** (no hours logged)")
