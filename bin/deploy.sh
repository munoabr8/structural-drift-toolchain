#!/usr/bin/env bash
set -euo pipefail

die(){ echo "ERR:$*" >&2; exit 2; }
need(){ command -v "$1" >/dev/null || die "missing:$1"; }

need gh
ENV="${1:-production}"
[[ "$ENV" =~ ^(production|staging|dev)$ ]] || die "bad ENV:$ENV"

SHA="$(git rev-parse HEAD)"

# kick off the Deploy workflow on main, pass env and sha
gh workflow run deploy.yml --ref main -f env="$ENV" -f sha="$SHA"

# find the run and wait
echo "Waiting for run of deploy.yml for $SHA ($ENV)…"
RID=""
deadline=$((SECONDS+1800))
while (( SECONDS < deadline )); do
  RID="$(gh run list --workflow deploy.yml --json databaseId,headSha,status,conclusion \
        -q "[.[]|select(.headSha==\"$SHA\")][0].databaseId" || true)"
  [[ -n "${RID:-}" ]] && break
  sleep 3
done
[[ -n "$RID" ]] || die "no run found for sha=$SHA"

gh run watch "$RID" || true
gh run view "$RID" --json status,conclusion,htmlURL

# optional local emission if you want a local record too (off by default)
if [[ "${LOCAL_EMIT:-0}" == "1" ]]; then
  command -v jq >/dev/null || die "need jq for LOCAL_EMIT"
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -c -n --arg schema "events/v1" --arg sha "$SHA" --arg status "success" --arg fin "$TS" \
    '{schema:$schema,type:"deployment",sha:$sha,status:$status,finished_at:$fin}' >> events.ndjson
fi
