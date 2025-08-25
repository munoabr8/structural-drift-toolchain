#!/usr/bin/env bash
set -euo pipefail
#./lib/policy/enforce_policy_p3.sh

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

normalize() { local p="$1"; printf '%s\n' "${p#./}"; }

 

q_literal_exists() {
  local p; p="$(normalize "$1")"
  [[ -e "$PROJECT_ROOT/$p" ]]
}

q_regex_any() {
  local pat; pat="$(normalize "$1")"
  while IFS= read -r cand; do
    [[ "$cand" =~ $pat ]] && return 0
  done < <(build_candidates)
  return 1
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



build_candidates() {
  if (( ${NO_GIT:-0} == 0 )) && command -v git >/dev/null 2>&1 \
     && git -C "$PROJECT_ROOT" rev-parse >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" ls-files
  else
    # BSD/POSIX: use -print and strip ROOT
    find "$PROJECT_ROOT" -mindepth 1 -maxdepth 25 -print \
      | sed -e "s|^$PROJECT_ROOT/||" -e 's|^\./||'
  fi
}

# 
# CHATGPT:
# Nobody calls this function.
# If this function were removed, 
# how would it affect the rest of the script.
check_rule() { # $1=path $2=cond $3=mode
  local path cand #norm 
  path="$(normalize "$1")"

  case "$2" in
    must_exist)
      if [[ "$3" == "literal" ]]; then
        [[ -e "$PROJECT_ROOT/$path" ]] && return 0 || return 1
      else
        # regex against RELATIVE candidates
        while IFS= read -r cand; do
          [[ "$cand" =~ $path ]] && return 0
        done < <(build_candidates)
        return 1
      fi
      ;;
    *) return 0 ;;
  esac
}

# 2) Normalize rule path and test
 
 # -------- Command logic --------
# expects helpers: emit, normalize, q_literal_exists, q_regex_any, now_ns
# env knobs: ENFORCE_LOG_LEVEL (silent|warn|info|debug), TRACE_ID, METRICS_FD
enforce_record() {
  rec="${1-}"   # safe under set -u
  #emit debug "rec_raw=$rec"
  # arg: single record line: type|path|condition|action|mode

local rec="$1" type path condition action mode
  IFS='|' read -r type path condition action mode <<<"$rec"
  [[ -z "${type:-}" ]] && return 0
  [[ -z "${mode:-}" ]] && { [[ $path =~ [][(){}^$*+?|\\] ]] && mode=regex || mode=literal; }


  local start_s outcome reason rc path_norm

  start_s="$(date +%s)"   # coarse timestamp, portable

  local IFS='|'
  read -r type path condition action mode <<<"$rec"
  [[ -z "${type:-}" ]] && return 0

  path_norm="$(normalize "$path")"

  emit check "trace_id=${TRACE_ID:-}" "type=$type" "path_raw=$path" "path=$path_norm" \
             "condition=$condition" "action=$action" "mode=$mode"

  case "$condition" in
    must_exist)
      if [[ "$mode" == "literal" ]]; then
        if q_literal_exists "$path"; then
          outcome=ok rc=0
        else
          outcome=violation reason=missing rc=1
        fi
      else
        if q_regex_any "$path"; then
          outcome=ok rc=0
        else
          outcome=violation reason=no_match rc=1
        fi
      fi
      ;;
    *)
      outcome=warn reason="unsupported_condition:$condition" rc=0
      ;;
  esac

  local end_s dur_ms
  end_s="$(date +%s)"
  dur_ms=$(( ( end_s - start_s ) * 1000 ))

  emit "$outcome" "trace_id=${TRACE_ID:-}" "type=$type" "path=$path_norm" \
       "condition=$condition" "action=$action" "mode=$mode" \
       "reason=${reason:-}" "duration_ms=$dur_ms"

  return "$rc"
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
      echo ""
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
