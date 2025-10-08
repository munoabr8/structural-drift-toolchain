#!/usr/bin/env bash
# system/names.sh — common naming utilities

# Normalize a workflow/probe/vm/etc. name into a safe filename.
# Rules:
#   - replace '/' with '__'
#   - replace spaces with '_'
#   - prefix based on domain (wf/, probe/, iso/, …)
#   - default to wf__ if no known prefix
safe_name() {
  local s="$1"
  s="${s//\//__}"   # replace slashes with __
  s="${s// /_}"     # replace spaces
  case "$1" in
    wf/*)    s="wf__${s#wf__}" ;;
    probe/*) s="probe__${s#probe__}" ;;
    iso/*)   s="iso__${s#iso__}" ;;
    *)       s="wf__${s}" ;;
  esac
  printf '%s' "$s"
}
