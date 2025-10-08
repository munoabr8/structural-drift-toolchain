#!/usr/bin/env bash
#./system/exec_isolated.sh
set -euo pipefail

usage(){ echo "usage: $(basename "$0") --mode {local|vm} --repo <abs_repo> --makefile <path> --target <wf> [--vm-name iso] [--allow \"PATH HOME\"] [--timeout 900] [--stdout p] [--stderr p] [--logs p] [-- KV=VAL...]"; exit 64; }

MODE="" REPO="" MK="" TARGET="" VM="iso"
ALLOW="" TIMEOUT="" OUT="" ERR="" LOG=""
FORWARDED=()

while (($#)); do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2;;
    --repo) REPO="${2:-}"; shift 2;;
    --makefile) MK="${2:-}"; shift 2;;
    --target) TARGET="${2:-}"; shift 2;;
    --vm-name) VM="${2:-}"; shift 2;;
    --allow) ALLOW="${2:-}"; shift 2;;
    --timeout) TIMEOUT="${2:-}"; shift 2;;
    --stdout) OUT="${2:-}"; shift 2;;
    --stderr) ERR="${2:-}"; shift 2;;
    --logs) LOG="${2:-}"; shift 2;;
    --) shift; FORWARDED=("$@"); break;;
    -h|--help) usage;;
    *) FORWARDED+=("$1"); shift;;
  esac
done

[[ -n "$MODE"   ]] || { echo "ERR: --mode required" >&2; exit 64; }
[[ -n "$REPO"   ]] || { echo "ERR: --repo required" >&2; exit 64; }
[[ -n "$MK"     ]] || { echo "ERR: --makefile required" >&2; exit 64; }
[[ -n "$TARGET" ]] || { echo "ERR: --target required" >&2; exit 64; }

command -v make >/dev/null || { echo "ERR: need make" >&2; exit 69; }
[[ "$MODE" != "vm" ]] || command -v multipass >/dev/null || { echo "ERR: need multipass" >&2; exit 69; }

# build env allowlist → KEY=VAL (always include PATH)
build_env_kv(){ local allow="${1:-}" safe_path="${2:-$PATH}"; local -a kv=("PATH=$safe_path"); local v; read -r -a _v <<<"$(printf '%s' "$allow" | tr ',\t' '  ' | tr -s ' ')"; for v in "${_v[@]}"; do [[ -z "$v" || "$v" == PATH ]] && continue; kv+=("$v=${!v-}"); done; printf '%s\0' "${kv[@]}"; }

# wrappers for timeout + tee
run_with_wrappers(){ local -a CMD=( "$@" ); [[ -n "$OUT" ]] && mkdir -p "$(dirname "$OUT")"; [[ -n "$ERR" ]] && mkdir -p "$(dirname "$ERR")"; [[ -n "$LOG" ]] && mkdir -p "$(dirname "$LOG")" 2>/dev/null || true; if [[ -n "${TIMEOUT:-}" ]] && command -v timeout >/dev/null; then CMD=( timeout --preserve-status "$TIMEOUT" "${CMD[@]}" ); fi; if [[ -n "$OUT" || -n "$ERR" ]]; then : "${OUT:=/dev/stdout}"; : "${ERR:=/dev/stderr}"; if [[ "$OUT" != "/dev/stdout" ]]; then exec 3> >(tee -a "$OUT" >&1); else exec 3>&1; fi; if [[ "$ERR" != "/dev/stderr" ]]; then exec 4> >(tee -a "$ERR" >&2); else exec 4>&2; fi; if [[ -n "$LOG" ]]; then ( "${CMD[@]}" 1>&3 2>&4 ) 2>&1 | tee -a "$LOG" >/dev/null; return "${PIPESTATUS[0]}"; else "${CMD[@]}" 1>&3 2>&4; return $?; fi; elif [[ -n "$LOG" ]]; then ( "${CMD[@]}" 2>&1 | tee -a "$LOG" ); return "${PIPESTATUS[0]}"; else "${CMD[@]}"; return $?; fi; }

# compose make commands
MK_VM="$MK"
if [[ "$MODE" == "vm" ]]; then
  case "$MK" in
    "$REPO"/*) MK_VM="/repo/${MK#"$REPO/"}" ;;
    /*)        MK_VM="/repo/${MK#/}" ;;
    *)         MK_VM="/repo/$MK" ;;
  esac
fi

MAKE_CMD_LOCAL=( make -f "$MK"    "$TARGET" )
MAKE_CMD_VM=( make -f "$MK_VM" "$TARGET" )
((${#FORWARDED[@]})) && { MAKE_CMD_LOCAL+=( "${FORWARDED[@]}" ); MAKE_CMD_VM+=( "${FORWARDED[@]}" ); }

if [[ "${DEBUG:-0}" = 1 ]]; then
  printf 'DEBUG MODE=%q VM=%q\n' "$MODE" "$VM" >&2
  printf 'DEBUG REPO=%q MK=%q MK_VM=%q TARGET=%q\n' "$REPO" "$MK" "$MK_VM" "$TARGET" >&2
  printf 'DEBUG CMD_LOCAL:' >&2; printf ' %q' "${MAKE_CMD_LOCAL[@]}"; printf '\n' >&2
  printf 'DEBUG CMD_VM:'    >&2; printf ' %q' "${MAKE_CMD_VM[@]}";    printf '\n' >&2
fi

case "$MODE" in
  local)
    IFS= read -r -d '' -a ENV_KV < <(build_env_kv "$ALLOW" "$PATH")
    run_with_wrappers env -i "${ENV_KV[@]}" "${MAKE_CMD_LOCAL[@]}"; exit $?;;
  vm)
    multipass info "$VM" >/dev/null 2>&1 || multipass launch -n "$VM"
    multipass mount "$REPO:/repo" "$VM" >/dev/null 2>&1 || true
    SAFE_VM_PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    IFS= read -r -d '' -a ENV_KV < <(build_env_kv "$ALLOW" "$SAFE_VM_PATH")
    run_with_wrappers multipass exec "$VM" -- bash -c \
      "set -euo pipefail; cd /repo; env -i $(printf '%q ' "${ENV_KV[@]}") $(printf '%q ' "${MAKE_CMD_VM[@]}")"
    exit $?;;
  *) echo "ERR: unknown mode '$MODE'" >&2; exit 64;;
esac
