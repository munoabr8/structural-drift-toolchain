#!/usr/bin/env bash
# session-query.sh
# Query processes by active login sessions (TTYs) from `who`.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./session.queries.sh list                 # show users, TTYs, login times, idle
  ./session.queries.sh procs [TTY...]       # ps for each TTY (from args or from `who`)
  ./session.queries.sh grep <PATTERN>       # grep commands across all TTYs
  ./session.queries.sh shells               # only interactive shells per TTY
  ./session.queries.sh tree [TTY]           # simple PID→PPID view for one/all TTYs
  ./session.queries.sh idle                 # show idle durations (who -u)
  ./session.queries.sh kill-tty <TTY>       # kill all PIDs on a TTY (asks confirm)

Notes: TTY examples: console, ttys000, pts/0, pts/1.
USAGE
}

ttys_from_who() { who | awk '{print $2}' | awk 'NF'; }

list() {
  who -u
}

procs() {
  local ttys=("$@")
  ((${#ttys[@]})) || mapfile -t ttys < <(ttys_from_who)
  for t in "${ttys[@]}"; do
    echo "=== $t ==="
    ps -t "$t" -o pid,ppid,tty,stat,etime,comm,args
  done
}

grep_cmds() {
  local pat=${1:?pattern required}
  mapfile -t ttys < <(ttys_from_who)
  for t in "${ttys[@]}"; do
    ps -t "$t" -o pid,tty,comm,args | grep -i -- "$pat" || true
  done
}

shells() {
  mapfile -t ttys < <(ttys_from_who)
  for t in "${ttys[@]}"; do
    ps -t "$t" -o pid,tty,comm,args | awk '/(bash|zsh|fish|sh)[[:space:]]/ || /(bash|zsh|fish|sh)$/'
  done
}

tree_one() {
  local t=$1
  echo "=== $t ==="
  ps -t "$t" -o pid=,ppid=,comm=,args= | sort -k2,2n -k1,1n |
  awk '{
    pid=$1; ppid=$2; $1=$2=""; sub(/^  */,""); cmd=$0;
    printf "PID=%s PPID=%s CMD=%s\n", pid, ppid, cmd
  }'
}

tree() {
  if [[ $# -gt 0 ]]; then
    tree_one "$1"
  else
    mapfile -t ttys < <(ttys_from_who)
    for t in "${ttys[@]}"; do tree_one "$t"; done
  fi
}

idle() {
  who -u
}

kill_tty() {
  local t=${1:?TTY required}
  echo "About to kill all processes on TTY: $t"
  procs "$t"
  read -r -p "Confirm? type YES: " ans
  [[ $ans == YES ]] || { echo "aborted"; return 1; }
  ps -t "$t" -o pid= | awk 'NF' | xargs -r kill
  echo "sent SIGTERM. If needed, rerun with: ps -t '$t' -o pid= | xargs -r kill -9"
}

cmd=${1:-}
case "$cmd" in
  list)      shift; list "$@" ;;
  procs)     shift; procs "$@" ;;
  grep)      shift; grep_cmds "$@" ;;
  shells)    shift; shells "$@" ;;
  tree)      shift; tree "$@" ;;
  idle)      shift; idle "$@" ;;
  kill-tty)  shift; kill_tty "$@" ;;
  ""|-h|--help|help) usage ;;
  *) echo "unknown subcommand: $cmd"; usage; exit 2 ;;
esac
