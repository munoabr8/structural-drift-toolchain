#!/usr/bin/env bash
# ci/roi/first-pass.sh
set -euo pipefail

# Inputs
REPO="${1:-${GITHUB_REPOSITORY:-}}"
SINCE_DAYS="${SINCE_DAYS:-14}"
REQUIRED_WORKFLOWS="${REQUIRED_WORKFLOWS:-}"  # comma list of names; optional

[[ -n "$REPO" ]] || { echo "usage: $0 owner/repo" >&2; exit 2; }

# Window
NOW="$(date -u +%FT%TZ)"
SINCE="$(date -u -d "${SINCE_DAYS} days ago" +%FT%TZ)"
echo "REPO=$REPO SINCE=$SINCE NOW=$NOW" >&2

# Sanity
gh api -X GET -i "repos/$REPO" -q .full_name >&2

tmp_dir="$(mktemp -d)"
raw="$tmp_dir/runs.raw.jsonl"
runs_json="$tmp_dir/runs.json"
: > "$raw"

# ---------- Actions API: per-workflow (preferred) ----------
echo "list workflows…" >&2
gh api -X GET "repos/$REPO/actions/workflows" \
  -q '.workflows[] | select(.state=="active") | "\(.id)|\(.name)"' > "$tmp_dir/wfs.list" || true

# Optional name filter (case-insensitive)
if [[ -s "$tmp_dir/wfs.list" && -n "$REQUIRED_WORKFLOWS" ]]; then
  awk -F'|' -v req="$REQUIRED_WORKFLOWS" 'BEGIN{IGNORECASE=1;n=split(req,a,/ *, */);for(i=1;i<=n;i++) want[a[i]]=1} ($2 in want)' \
    "$tmp_dir/wfs.list" > "$tmp_dir/wfs.sel" || true
else
  cp "$tmp_dir/wfs.list" "$tmp_dir/wfs.sel" || true
fi

if [[ -s "$tmp_dir/wfs.sel" ]]; then
  while IFS='|' read -r WID _; do
    [[ -n "$WID" ]] || continue
    if ! gh api -X GET --paginate "repos/$REPO/actions/workflows/$WID/runs" \
         -f status=completed -f per_page=100 -q '.workflow_runs[]' >> "$raw" 2>"$tmp_dir/err"; then
      if grep -q "404" "$tmp_dir/err"; then
        echo "skip workflow id=$WID (404)" >&2
      else
        cat "$tmp_dir/err" >&2
      fi
      : > "$tmp_dir/err"
    fi
  done < "$tmp_dir/wfs.sel"
fi

# ---------- Actions API: repo-level fallback ----------
have_runs() { [[ -s "$raw" ]] && jq -s 'length>0' "$raw" >/dev/null 2>&1; }
if ! have_runs; then
  echo "fallback: repo-level runs…" >&2
  gh api -X GET --paginate "repos/$REPO/actions/runs" \
    -f event=pull_request -f status=completed -f per_page=100 \
    -q '.workflow_runs[]' >> "$raw" 2>/dev/null || true
fi

# ---------- Window filter (if any) ----------
if have_runs; then
  jq -s --arg since "$SINCE" --arg now "$NOW" '
    map(select(.created_at? >= $since and .created_at? <= $now))
    | {workflow_runs:.}
  ' "$raw" > "$runs_json"
fi

# ---------- Checks API fallback (NDJSON PRs → suites) ----------
if [[ ! -s "$runs_json" || "$(jq -r '.workflow_runs|length' "$runs_json" 2>/dev/null || echo 0)" = "0" ]]; then
  echo "fallback: checks API…" >&2
  prs_nd="$tmp_dir/prs.ndjson"

  gh api -X GET --paginate "repos/$REPO/pulls?state=all&per_page=100" \
    -q '.[] | {number, head_sha: .head.sha, updated_at, created_at}' > "$prs_nd" 2>/dev/null || true

  # Ensure we have JSON objects
  if ! jq -rs 'length>0' "$prs_nd" >/dev/null 2>&1; then
    echo "checks fallback: no PR data; yielding zero PRS" >&2
    printf '{"window_days":%s,"prs":0,"pass":0,"pa":0.0}\n' "$SINCE_DAYS" > first_pass.json
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      printf 'prs=0\npa=0.0\n' >> "$GITHUB_OUTPUT"
    fi
    exit 0
  fi

  : > "$raw"
  while read -r n sha updated; do
    [[ -n "$n" && -n "$sha" ]] || continue
    gh api -X GET "repos/$REPO/commits/$sha/check-suites" -q '
      .check_suites | sort_by(.created_at) | .[0] // {} |
      {prn:'"$n"', created_at, conclusion: (.conclusion // "")}
    ' >> "$raw" 2>/dev/null || true
  done < <(jq -rs --arg since "$SINCE" --arg now "$NOW" '
           map(select(.updated_at >= $since and .updated_at <= $now))
           | .[] | [.number, .head_sha, .updated_at] | @tsv' "$prs_nd")

  jq -s '{workflow_runs:.}' "$raw" > "$runs_json"
fi

# ---------- Compute PR-level first-pass ----------
if [[ ! -s "$runs_json" ]]; then
  printf '{"window_days":%s,"prs":0,"pass":0,"pa":0.0}\n' "$SINCE_DAYS" > first_pass.json
else
  jq -r --argjson wd "$SINCE_DAYS" '
    [ .workflow_runs[]
      | select(((.run_attempt // 1)|tonumber) == 1)
      | {prn: (.prn // (.pull_requests[]?.number)), created_at, conclusion}
    ]
    | map(select(.prn != null))
    | group_by(.prn)
    | map(min_by(.created_at))
    | {window_days:$wd, prs:length,
       pass:(map(select(.conclusion=="success"))|length)}
    | .pa = (if .prs>0 then (.pass/.prs) else 0 end)
  ' "$runs_json" > first_pass.json
fi

# Outputs for Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  jq -r '"prs="+(.prs|tostring), "pa="+(.pa|tostring)' first_pass.json >> "$GITHUB_OUTPUT"
fi
