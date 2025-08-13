#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: pipeline_runner.sh [--root DIR] [--fail-fast] [--no-git]
                          [--p1 PATH] [--p2 PATH] [--p3 PATH]
assumption: policy file is DIR/config/policy.rules.yml
USAGE
}

here="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

resolve_script() { # $1=name $2=optional explicit path
  local name="$1" p="${2:-}" cand
  if [[ -n "$p" ]]; then [[ -f "$p" ]] && { printf '%s\n' "$p"; return; }
    echo "missing $name: $p" >&2; exit 127; fi
  for cand in "$here/$name" "./$name"; do
    [[ -f "$cand" ]] && { printf '%s\n' "$cand"; return; }
  done
  echo "missing $name" >&2; exit 127
}

run_policy_pipeline() { # $1=root $2=p1 $3=p2 $4=p3 $5=ff(0/1) $6=nogit(0/1)
  local root="$1" p1="$2" p2="$3" p3="$4" ff="$5" nogit="$6"
  local policy="$root/config/policy.rules.yml"

  [[ -f "$policy" ]] || { echo "missing policy: $policy" >&2; return 64; }
  local envv=(POLICY_FILE="$policy" SDT_ROOT="$root")
  (( ff )) && envv+=(FAIL_FAST=1)
  (( nogit )) && envv+=(NO_GIT=1)
  env "${envv[@]}" bash -o pipefail -c "bash \"$p1\" | bash \"$p2\" | bash \"$p3\""
}

main() {
  local root="" 

  ff=0 nogit=0 P1="" P2="" P3=""
  while (($#)); do
    case "$1" in
      --root) root="$2"; shift 2;;
      --fail-fast) ff=1; shift;;
      --no-git) nogit=1; shift;;
      --p1) P1="$2"; shift 2;;
      --p2) P2="$2"; shift 2;;
      --p3) P3="$2"; shift 2;;
      -h|--help) usage; exit 0;;
      --) shift; break;;
      *) echo "unknown arg: $1" >&2; usage; exit 64;;
    esac
  done
  P1="$(resolve_script policy_query_p1.sh "$P1")"
  P2="$(resolve_script transform_policy_p2.sh "$P2")"
  P3="$(resolve_script enforce_policy_p3.sh "$P3")"

 if [[ -z "${root:-}" ]]; then
  if command -v git >/dev/null && git rev-parse --show-toplevel >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel)"
  else
    probe="$(pwd -P)"
    while [[ "$probe" != "/" ]]; do
      [[ -f "$probe/config/policy.rules.yml" ]] && { root="$probe"; break; }
      probe="$(dirname "$probe")"
    done
    : "${root:=$(pwd -P)}"
  fi
fi
echo "root=$root policy=$root/config/policy.rules.yml" >&2

  run_policy_pipeline "$root" "$P1" "$P2" "$P3" "$ff" "$nogit"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
