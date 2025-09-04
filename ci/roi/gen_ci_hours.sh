#!/usr/bin/env bash
# ci/roi/gen_ci_hours.sh
#
# Generate a ci-hours.csv file based on the chosen data source.
# Usage: gen_ci_hours.sh <source>
# <source> can be:
#   github – derive hours from GitHub Actions run durations
#   toggl  – pull hours from Toggl’s Reports API (requires implementation)
#   manual – copy a checked-in ci-hours.csv file from the repository
#
# The output file will be written to ci-hours.csv in the current directory.

set -euo pipefail

SOURCE=${1:-github}

case "$SOURCE" in
  github)
    # Ensure GH_TOKEN and GITHUB_REPOSITORY are available
    : "${GH_TOKEN:?GH_TOKEN environment variable must be set}"
    : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY environment variable must be set}"

    # Define the time window (last 14 days)
    SINCE=$(date -u -d "14 days ago" +%FT%TZ)

    # Fetch workflow runs from GitHub Actions API via gh cli
    # Note: we request 100 runs; adjust per_page if your repo has more daily runs
    gh api \
      "/repos/${GITHUB_REPOSITORY}/actions/runs?per_page=100&created>=$SINCE" \
      > runs.json

    # Convert the runs into a date,hours CSV
    # Each run’s duration is in milliseconds; convert to hours
    jq -r '
      (.workflow_runs // .runs // [])
      | map({
          d: (.run_started_at // .created_at)[0:10],
          h: ((.run_duration_ms // 0) / 3600000)
        })
      | group_by(.d)
      | map({date: .[0].d, hours: (map(.h) | add)})
      | (["date","hours"], (.[] | [.date, (.hours // 0)]))
      | @csv
    ' runs.json > ci-hours.csv
    ;;

#   toggl)
#   # Ensure the required variables are available
#   : "${TOGGL_API_TOKEN:?TOGGL_API_TOKEN must be set}"
#   : "${TOGGL_WORKSPACE_ID:?TOGGL_WORKSPACE_ID must be set}"
#   : "${TOGGL_USER_AGENT_EMAIL:?TOGGL_USER_AGENT_EMAIL must be set}"

#   SINCE=$(date -u -d "14 days ago" +%F)
#   UNTIL=$(date -u +%F)

#   # Call the Toggl details report. The API token is the username and 'api_token'
#   # is the password:contentReference[oaicite:3]{index=3}.
#  curl -s -u "${TOGGL_API_TOKEN}:api_token" \
#   "https://api.track.toggl.com/reports/api/v2/details?workspace_id=${TOGGL_WORKSPACE_ID}&since=${SINCE}&until=${UNTIL}&user_agent=${TOGGL_USER_AGENT_EMAIL}" \
#   > toggl_report.json

# jq -r -f /dev/stdin toggl_report.json > ci-hours.csv <<'JQ'
# (.data // [])
# | group_by(.start[0:10])
# | map({date: (.[0].start[0:10]), hours: ((map(.dur) | add) / 3600000)})
# | (["date","hours"], (.[] | [.date, (.hours // 0)]))
# | @csv
# JQ

#     ;;

toggl)
  : "${TOGGL_API_TOKEN:?TOGGL_API_TOKEN must be set}"
  : "${TOGGL_WORKSPACE_ID:?TOGGL_WORKSPACE_ID must be set}"
  : "${TOGGL_USER_AGENT_EMAIL:?TOGGL_USER_AGENT_EMAIL must be set}"

  SINCE=$(date -u -d "14 days ago" +%F)
  UNTIL=$(date -u +%F)

  curl -s -u "${TOGGL_API_TOKEN}:api_token" --get \
    'https://api.track.toggl.com/reports/api/v2/details' \
    --data-urlencode "workspace_id=${TOGGL_WORKSPACE_ID}" \
    --data-urlencode "since=${SINCE}" \
    --data-urlencode "until=${UNTIL}" \
    --data-urlencode "user_agent=${TOGGL_USER_AGENT_EMAIL}" \
    > toggl_report.json

 
jq -r '.data[0]?' toggl_report.json | head -c 400 >&2

  # Debug
  echo "SINCE=$SINCE UNTIL=$UNTIL WS=$TOGGL_WORKSPACE_ID" >&2
  jq '{count: (.data|length // 0), total_count: (.total_count // null), error: (.error // null)}' toggl_report.json >&2

  # Build CSV
  {
    echo "date,hours"
    jq -r '
      (.data // []) 
      | group_by(.start[0:10])
      | map({date: (.[0].start[0:10]), hours: ((map(.dur) | add) / 3600000)})
      | .[] | "\(.date),\(.hours)"
    ' toggl_report.json
  } > ci-hours.csv
  ;;


  manual)
    # Placeholder: copy manual ci-hours.csv from repo
    # Adjust the path as needed; e.g. configs/roi/ci-hours.csv
    MANUAL_PATH="configs/roi/ci-hours.csv"
    if [[ -f "$MANUAL_PATH" ]]; then
      cp "$MANUAL_PATH" ci-hours.csv
    else
      echo "Manual CI hours file not found at $MANUAL_PATH" >&2
      exit 1
    fi
    ;;

  *)
    echo "Unknown source: $SOURCE" >&2
    echo "Usage: $0 <github|toggl|manual>" >&2
    exit 1
    ;;
esac

