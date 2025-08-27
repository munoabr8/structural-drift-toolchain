#!/usr/bin/env bash
# cmd (wrapper)
set -euo pipefail

MODE=${MODE:-new}         # old|new|shadow|dry
TIMEOUT=${TIMEOUT:-30}    # seconds
LOG=${LOG:-/tmp/cmd.wrap.log}



SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLD="${SCRIPT_DIR}/structure_snapshot_gen.sh"
NEW="${SCRIPT_DIR}/structure_snapshot_gen.rf.sh"

die(){ printf '%s\n' "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

precheck(){
  [[ -x $OLD && -x $NEW ]] || die "implementations missing"
  [[ ${#@} -ge 0 ]] || die "args parse error"
}

run_with_timeout(){
  if have timeout; then timeout "$TIMEOUT" "$@"; else "$@"; fi
}

log(){ printf '%(%FT%T%z)T mode=%s ec=%s msg=%s\n' -1 "${1:-}" "${2:-}" "${3:-}" >>"$LOG"; }

postcheck(){
  local ec=$1
  (( ec==0 || ec==2 || ec==64 )) || die "unexpected exit=$ec"
}

usage() {
  cat <<'USAGE'
Usage: cmd [OPTIONS] -- [ARGS...]

Options:
  --mode {old|new|shadow|dry}   Select implementation (default: new)
  --timeout SECS                Max run time (default: 30)
  --log FILE                    Log file (default: /tmp/cmd.wrap.log)
  -h, --help                    Show this help

Modes:
  old      Run legacy implementation
  new      Run refactored implementation
  shadow   Run old, run new in background, compare outputs
  dry      Print what would run, no execution

Examples:
  cmd --mode=shadow -- foo bar
  MODE=old cmd -- baz qux
USAGE
}

parse_args() {
  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --mode=*) MODE="${1#*=}"; shift;;
      --mode)   MODE="$2"; shift 2;;
      --timeout=*) TIMEOUT="${1#*=}"; shift;;
      --timeout)   TIMEOUT="$2"; shift 2;;
      --log=*)  LOG="${1#*=}"; shift;;
      --log)    LOG="$2"; shift 2;;
      -h|--help|help) usage; exit 0;;
      --)
        shift
        (( $# )) && REMAINING_ARGS+=("$@")
        break
        ;;

      -*) die "unknown option: $1";;
      *)  REMAINING_ARGS+=("$1"); shift;;
    esac
  done
}


main(){
  parse_args "$@"
  set -- "${REMAINING_ARGS[@]}"
if (( $# == 1 )) && [[ -z ${1} ]]; then set --; fi
  precheck "$@"

  case "$MODE" in
      dry)
        cmd=( "$NEW" )
          (( $# )) && cmd+=( "$@" )
          printf '[dry-run]'
          for x in "${cmd[@]}"; do printf ' %q' "$x"; done
          printf '\n'
          exit 0
          ;;
 
    old)  run_with_timeout "$OLD" "$@"; ec=$?;;
    new)  run_with_timeout "$NEW" "$@"; ec=$?;;
    shadow)
      tmp_old=$(mktemp); tmp_new=$(mktemp)
      trap 'rm -f "$tmp_old" "$tmp_new"' EXIT
      run_with_timeout "$OLD" "$@" | tee "$tmp_old"; ec=$?
      ( run_with_timeout "$NEW" "$@" >"$tmp_new" 2>&1 || true ) &
      pid=$!; wait "$pid" || true
      if ! diff -u "$tmp_old" "$tmp_new" >/dev/null 2>&1; then
        log shadow 0 "divergence detected"
      fi
      rm -f "$tmp_old" "$tmp_new"; trap - EXIT
      ;;
    *) die "bad MODE=$MODE";;
  esac

  log "$MODE" "$ec" "done"
  postcheck "$ec"
  exit "$ec"
}
main "$@"


