#!/usr/bin/env bash
set -euo pipefail

# -------- Init --------
_project_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}
PROJECT_ROOT="$(_project_root)"

# -------- Query predicates --------
_fs_list_rel() {
  ( cd "$PROJECT_ROOT" &&
    find . -mindepth 1 \( -type f -o -type d -o -type l \) -print |
    sed 's|^\./||' )
}

q_literal_exists() {  # arg: path relative to PROJECT_ROOT
  [[ -e "$PROJECT_ROOT/$1" ]]
}

q_regex_any() {       # arg: ERE pattern over relative paths
  _fs_list_rel | grep -Eq "$1"
}

# -------- Event emitter --------
emit() {
  # usage: emit <type> [k=v]...
  printf 'event|%s' "$1"
  shift || true
  local kv
  for kv in "$@"; do printf '|%s' "$kv"; done
  printf '\n'
}

# -------- Command logic --------
enforce_record() {
  # arg: single record line: type|path|condition|action|mode
  local rec="$1" type path condition action mode
  IFS='|' read -r type path condition action mode <<<"$rec"
  [[ -z "${type:-}" ]] && return 0

  emit check "path=$path" "mode=$mode" "condition=$condition"

  case "$condition" in
    must_exist)
      if [[ "$mode" == "literal" ]]; then
        if q_literal_exists "$path"; then
          emit ok "path=$path"
          return 0
        else
          emit violation "action=$action" "path=$path" "reason=missing"
          return 1
        fi
      else
        if q_regex_any "$path"; then
          emit ok "path~=$path"
          return 0
        else
          emit violation "action=$action" "path~=$path" "reason=no_match"
          return 1
        fi
      fi
      ;;
    *)
      emit warn "path=$path" "reason=unsupported_condition:$condition"
      return 0
      ;;
  esac
}

enforce_stream() {
  # reads records from STDIN; FAIL_FAST=1 to stop on first violation
  local fail=0 line
  emit start
  while IFS= read -r line; do
    [[ -z "${line:-}" ]] && continue
    if ! enforce_record "$line"; then
      fail=1
      [[ "${FAIL_FAST:-0}" == "1" ]] && break
    fi
  done
  emit end
  return "$fail"
}

main() {
  if enforce_stream; then
    exit 0
  else
    exit 1
  fi
}

# -------- Entry point --------
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main
