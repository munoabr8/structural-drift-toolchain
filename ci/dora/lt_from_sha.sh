#!/usr/bin/env bash
# ci/dora/lt_from_sha.sh
# Emit DORA lead time JSON for a deployed SHA.
# Behavior is encapsulated in small functions for clarity and testability.

set -euo pipefail
export LC_ALL=C

# ---------- config ----------
BASE_BRANCH="${HEAD_BRANCH:-main}"     # expected prod branch (override via env)
SCHEMA="dora/lead_time/v1"

# ---------- utils ----------
die()  { echo "ERR:$*" >&2; exit "${2:-1}"; }
warn() { echo "WARN:$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing:$1" 70; }
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
to_epoch() { date -u -d "$1" +%s 2>/dev/null || echo 0; }

api() { gh api "$@" 2>/dev/null; }               # quiet gh wrapper
jget() { jq -r "$1 // empty"; }                   # jq helper

# ---------- assertions ----------
assert_sha_exists() {
  local repo="$1" sha="$2"
  gh api -X GET "repos/$repo/commits/$sha" -q .sha >/dev/null \
    || { echo "ERR:bad_sha:$sha" >&2; exit 64; }
}

# ---------- PR discovery ----------
pr_by_merge_commit() {
  local repo="$1" sha="$2" base="$3"
  gh api -X GET \
    "repos/$repo/pulls?state=closed&base=$base&per_page=100" \
    -q "[.[] | select(.merge_commit_sha==\"$sha\")][0]"
}

pr_by_commit_assoc() {
  local repo="$1" sha="$2"
  gh api -X GET -H 'Accept: application/vnd.github.groot-preview+json' \
     "repos/$repo/commits/$sha/pulls" -q '.[0]'
}

extract_pr_fields() {
  # stdin = PR JSON or null; outputs 3 lines: pr_number, merged_at, base_ref
  local pr_json; pr_json="$(cat)"
  echo "$pr_json" | jget '.number'
  echo "$pr_json" | jget '.merged_at'
  echo "$pr_json" | jget '.base.ref'
}

# ---------- time math ----------
compute_minutes() {
  # args: merged_at deploy_at  -> echo non-negative minutes
  local m="$1" d="$2"
  local mt dt
  mt="$(to_epoch "$m")"; dt="$(to_epoch "$d")"
  (( mt == 0 )) && die "bad_merged_at:$m" 65
  (( mt > dt )) && warn "merged_after_deploy merged_at=$m deploy_at=$d"
  local mins=$(( (dt - mt) / 60 ))
  (( mins < 0 )) && mins=0
  echo "$mins"
}

# ---------- emit ----------
emit_json() {
  local repo="$1" sha="$2" base="$3" src="$4" prn="$5" pr_base="$6" merged_at="$7" deploy_at="$8" code="$9" mins="${10}"
  jq -n --arg schema "$SCHEMA" \
        --arg repo "$repo" --arg sha "$sha" --arg base "$base" \
        --arg src "$src" --arg prn "$prn" --arg pr_base "$pr_base" \
        --arg merged_at "$merged_at" --arg deploy_at "$deploy_at" \
        --arg code "$code" --argjson minutes "$mins" '
    { schema:$schema, repo:$repo, sha:$sha, base:$base,
      pr: ( ($prn|length>0) ? ($prn|tonumber) : null ),
      pr_base: ($pr_base // null),
      merged_at:$merged_at, deploy_at:$deploy_at,
      minutes:$minutes, code:$code, source:$src }'
}

# ---------- main ----------
main() {
  need gh; need jq; need date
  local repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY missing}"
  local sha="${1:?pass deployed SHA}"

# before
# sha="${1:?pass deployed SHA}"

# after
sha="${1:-${GITHUB_SHA:-}}"
if [[ -z "$sha" ]]; then
  sha="$(git rev-parse HEAD 2>/dev/null || true)"
fi
[[ -n "$sha" ]] || { echo "ERR:usage: $0 <sha> or set GITHUB_SHA" >&2; exit 2; }



  assert_sha_exists "$repo" "$sha"

  local src pr_json prn merged_at pr_base
  src="merge_commit_sha"
  pr_json="$(pr_by_merge_commit "$repo" "$sha" "$BASE_BRANCH" || true)"

  if [[ -z "$pr_json" || "$pr_json" == "null" ]]; then
    src="commit_pulls"
    pr_json="$(pr_by_commit_assoc "$repo" "$sha" || true)"
  fi

  read -r prn merged_at pr_base < <(echo "${pr_json:-null}" | extract_pr_fields)

  [[ -n "$prn" && -n "$pr_base" && "$pr_base" != "$BASE_BRANCH" ]] \
    && warn "pr_base_mismatch pr#$prn base_ref=$pr_base expected=$BASE_BRANCH"

  local code deploy_at minutes
  deploy_at="$(now_utc)"
  if [[ -z "$merged_at" ]]; then
    code="NO_PR"
    warn "no_pr_or_merged_at sha=$sha base=$BASE_BRANCH src=$src"
    merged_at="$(api "repos/$repo/commits/$sha" -q '.commit.author.date' || true)"
  else
    code="PR_FOUND"
  fi

  minutes="$(compute_minutes "$merged_at" "$deploy_at")"
  emit_json "$repo" "$sha" "$BASE_BRANCH" "$src" "${prn:-}" "${pr_base:-}" "$merged_at" "$deploy_at" "$code" "$minutes"
}

main "$@"
