#!/usr/bin/env bash
set -euo pipefail

die(){ echo "ERR:$*" >&2; exit 2; }
need(){ command -v "$1" >/dev/null || die "missing:$1"; }

ENV="${1:-production}"
[[ "$ENV" =~ ^(production|staging|dev)$ ]] || die "bad ENV:$ENV"

need jq
command -v git >/dev/null || die "need git in PATH"

REPO="${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed -E 's#.*/([^/]+/[^/.]+)(\.git)?$#\1#')}"
SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- real deploy steps go here ----
# Replace the echo with your deployment commands. Failures must exit non-zero.
echo "Deploying $ENV @ $SHA for $REPO"
# example: ./infrastructure/apply.sh "$ENV"

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATUS="success"  # set to "failure" if your steps failed before

# emit one NDJSON line
jq -c -n \
  --arg schema "events/v1" \
  --arg repo "$REPO" \
  --arg sha "$SHA" \
  --arg env "$ENV" \
  --arg started "$STARTED_AT" \
  --arg finished "$FINISHED_AT" \
  --arg status "$STATUS" \
  '{schema:$schema,type:"deployment",repo:$repo,sha:$sha,env:$env,
    started_at:$started,finished_at:$finished,status:$status}' \
  >> events.ndjson

echo "deploy_exec: appended deployment event for $SHA ($STATUS)"
