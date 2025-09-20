#!/usr/bin/env bash

# CONTRACT-JSON-BEGIN
# {
#   "args": ["--env ENV","--show-env","-h|--help","--","[ENV]"],
#   "env": {
#     "GITHUB_REPOSITORY": "optional; used to derive REPO",
#     "GITHUB_SHA": "optional; overrides git rev-parse HEAD",
#     "GITHUB_REF": "optional; printed in env dump",
#     "PATH": "used for tools; printed in env dump"
#   },
#   "reads": "current git repo metadata (.git/config, HEAD); environment variables; no network",
#   "writes": [
#     "append 1 line to ./events.ndjson (creates if missing)",
#     "stderr: env summary (always at end; also before deploy when --show-env)",
#     "stdout: deploy progress lines"
#   ],
#   "tools": ["bash","jq","git","sed","date","printf"],
#   "exit": { "ok": 0, "help": 0, "cli_error": 2, "bad_env": 2, "missing_tool": 2, "other": "bubbled via set -e" },
#   "emits": {
#     "deployment_event": {
#       "schema": "events/v1",
#       "type": "deployment",
#       "fields": ["repo","sha","env","started_at","finished_at","status"]
#     }
#   },
#   "notes": "ENV is chosen via --env or positional [ENV] (production|staging|dev). REPO falls back to parsing remote.origin.url. SHA falls back to git rev-parse HEAD. Not idempotent: each run appends a new event."
# }
# CONTRACT-JSON-END



set -euo pipefail

die(){ echo "ERR:$*" >&2; exit 2; }
need(){ command -v "$1" >/dev/null || die "missing:$1"; }

usage() {
  cat <<'USAGE' >&2
Usage: deploy.sh [--env ENV] [--show-env] [--] [ENV]
ENV: production|staging|dev
USAGE
}

print_env() {
  {
    echo "## selected env"
    printf 'ENV=%s\n'                "${ENV-}"
    printf 'REPO=%s\n'               "${REPO-}"
    printf 'SHA=%s\n'                "${SHA-}"
    printf 'GITHUB_REPOSITORY=%s\n'  "${GITHUB_REPOSITORY-}"
    printf 'GITHUB_SHA=%s\n'         "${GITHUB_SHA-}"
    printf 'GITHUB_REF=%s\n'         "${GITHUB_REF-}"
    printf 'PATH=%s\n'               "$PATH"
  } >&2
}

# ---- options ----
SHOW_ENV=0
ENV_ARG=""

while (($#)); do
  case "$1" in
    -e|--env)   ENV_ARG="${2:-}"; shift 2 || { die "--env needs a value"; } ;;
    --show-env) SHOW_ENV=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    --)         shift; break ;;
    -*)         usage; die "unknown option:$1" ;;
    *)          if [[ -z "$ENV_ARG" ]]; then ENV_ARG="$1"; shift; else usage; die "extra arg:$1"; fi ;;
  esac
done

ENV="${ENV_ARG:-production}"
[[ "$ENV" =~ ^(production|staging|dev)$ ]] || die "bad ENV:$ENV"

need jq
command -v git >/dev/null || die "need git in PATH"

REPO="${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed -E 's#.*/([^/]+/[^/.]+)(\.git)?$#\1#')}"
SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# optional env print
if [[ "$SHOW_ENV" == "1" ]]; then
  print_env
fi

# ---- real deploy steps go here ----
echo "Deploying $ENV @ $SHA for $REPO"

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATUS="success"

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

print_env
echo "deploy_exec: appended deployment event for $SHA ($STATUS)"
