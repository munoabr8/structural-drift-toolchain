#!/usr/bin/env bash
set -euo pipefail

die(){ echo "ERR:$*" >&2; exit 2; }
need(){ command -v "$1" >/dev/null || die "missing:$1"; }

need gh; need jq; command -v uuidgen >/dev/null || uuidgen(){ cat /proc/sys/kernel/random/uuid; }

ENV="${1:-production}"
[[ "$ENV" =~ ^(production|staging|dev)$ ]] || die "bad ENV:$ENV"

REPO="${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed -E 's#.*/([^/]+/[^/.]+)(\.git)?$#\1#')}"
SHA="$(git rev-parse HEAD)"
DEPLOY_ID="$(uuidgen)"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# kick off workflow

gh workflow run deploy.yml --ref main -f env="$ENV" -f sha="$SHA"
# find the run for this SHA+env
deadline=$((SECONDS+1800))
RUN_ID=""
while (( SECONDS < deadline )); do
  RUN_ID="$(gh run list --json databaseId,headSha,displayTitle,status,conclusion \
    | jq -r --arg sha "$SHA" --arg env "$ENV" '
        .[] | select(.headSha==$sha and (.displayTitle|test($env;"i")))
        | .databaseId' | head -n1)"
  [[ -n "$RUN_ID" ]] && break
  sleep 5
done
[[ -n "$RUN_ID" ]] || die "no run found for sha=$SHA env=$ENV"

# wait and fetch final status
gh run watch "$RUN_ID" >/dev/null || true
read -r STATUS CONCLUSION URL < <(gh run view "$RUN_ID" \
  --json status,conclusion,htmlURL -q '[.status,.conclusion,.htmlURL]|@tsv')

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# only emit on completed runs
[[ "${STATUS,,}" == "completed" ]] || die "run not completed: $STATUS"
STATUS_NORM="$(tr '[:upper:]' '[:lower:]' <<<"${CONCLUSION:-unknown}")"
[[ "$STATUS_NORM" == "success" ]] || die "deploy failed: $STATUS_NORM"

# append NDJSON event
jq -c -n \
  --arg schema "events/v1" \
  --arg repo "$REPO" \
  --arg deploy_id "$DEPLOY_ID" \
  --arg sha "$SHA" \
  --arg env "$ENV" \
  --arg started "$STARTED_AT" \
  --arg finished "$FINISHED_AT" \
  --arg status "$STATUS_NORM" \
  '{schema:$schema,type:"deployment",repo:$repo,deploy_id:$deploy_id,sha:$sha,env:$env,
    started_at:$started,finished_at:$finished,status:$status}' >> events.ndjson
