#!/usr/bin/env bash
# ./ci/roi/fetch_artifacts.sh
# Fetch required GitHub Actions artifacts into roi/artifacts, verify, and clean zips.

set -euo pipefail

: "${REPO:?REPO is required}"       # owner/repo, e.g. munoabr8/structural-drift-toolchain
MAX_PAGES="${MAX_PAGES:-10}"
ALLOW_SUFFIX="${ALLOW_SUFFIX:-0}"    # 1 => match "^name(-.*)?$"
REQUIRED=("workflow-stats" "pr-first-pass" "ci-hours" "roi-baseline")

# Resolve repo root
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ARTS_DIR="${ARTS_DIR:-$ROOT/ci/roi/artifacts}"
MISS_FILE="${MISS_FILE:-$ROOT/ci/roi/missing}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "ERR: missing dep: $1" >&2; exit 2; }; }
need gh; need jq; need unzip

mkdir -p "$ARTS_DIR"
: > "$MISS_FILE"   # clear stale state

list_all() {
  local page j out='{"artifacts":[],"total_count":0}'
  for page in $(seq 1 "$MAX_PAGES"); do
    j="$(gh api "/repos/$REPO/actions/artifacts?per_page=100&page=$page")" || break
    [[ "$(jq -r '.artifacts|length' <<<"$j")" == "0" ]] && break
    out="$(jq -s '{artifacts:(.[0].artifacts+.[1].artifacts), total_count:(.[0].total_count+.[1].total_count)}' \
            <(printf '%s' "$out") <(printf '%s' "$j"))"
  done
  printf '%s' "$out"
}

ALL_JSON="$(list_all)"

latest_id() {
  local name="$1" re
  if [[ "$ALLOW_SUFFIX" == "1" ]]; then
    re="^${name}(-.*)?$"
    jq -r --arg re "$re" '
      .artifacts
      | map(select(.expired==false and (.name|test($re))))
      | sort_by(.created_at) | last | .id // empty' <<<"$ALL_JSON"
  else
    jq -r --arg n "$name" '
      .artifacts
      | map(select(.expired==false and .name==$n))
      | sort_by(.created_at) | last | .id // empty' <<<"$ALL_JSON"
  fi
}

fetch_one() {
  local name="$1" id zip dst
  id="$(latest_id "$name")"
  if [[ -z "${id:-}" ]]; then
    echo "MISSING:$name" >> "$MISS_FILE"
    if ! grep -q '^KNOWN_NAMES$' "$MISS_FILE"; then
      { echo 'KNOWN_NAMES'; jq -r '.artifacts[].name' <<<"$ALL_JSON" | sort -u; } >> "$MISS_FILE"
    fi
    return 0
  fi

  dst="$ARTS_DIR/$name"
  mkdir -p "$dst"
  zip="$dst/$name.zip"

  gh api -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/actions/artifacts/$id/zip" > "$zip"

  unzip -o "$zip" -d "$dst" >/dev/null
  rm -f "$zip"

  case "$name" in
    workflow-stats)
      [[ -f "$dst/workflow-stats.csv" || -f "$dst/runs.json" ]] || echo "MISSING_FILE:$name" >> "$MISS_FILE"
      ;;
    pr-first-pass)
      [[ -f "$dst/first_pass.json" ]] || echo "MISSING_FILE:$name" >> "$MISS_FILE"
      ;;
    ci-hours)
      [[ -f "$dst/ci-hours.csv"   ]] || echo "MISSING_FILE:$name" >> "$MISS_FILE"
      ;;
    roi-baseline)
      [[ -f "$dst/baseline.json"  ]] || echo "MISSING_FILE:$name" >> "$MISS_FILE"
      ;;
  esac
}

for a in "${REQUIRED[@]}"; do
  fetch_one "$a"
done

if [[ -s "$MISS_FILE" ]]; then
  echo "Missing artifacts:"
  cat "$MISS_FILE"
  exit 78
fi

# Optional: flatten to repo root if some downstream still expects it
if [[ "${FLATTEN_TO_ROOT:-0}" == "1" ]]; then
  shopt -s nullglob
  mv "$ARTS_DIR"/**/*.{json,csv} "$ROOT"/ 2>/dev/null || true
fi
