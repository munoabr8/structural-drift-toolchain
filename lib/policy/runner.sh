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

  env "${envv[@]}" bash -o pipefail -c "bash \"$p1\"  | bash \"$p2\" " #| bash \"$p3\""

}

#inputQuery_pipelineRunner(){}
# displayInputs_runnerscipt(){

# echo "Number of inputs:  $#"
# echo "All inputs: $@"
# echo "Inputs: $*"
# i=1
# for arg in "$@"; do
#   echo "Arg $i: $arg" 
#   i=$((i+1))
#  done 
# }


# #inputQuery_perStep(){}
# displayInput_eachPipelineStep(){




# }

# #outputQuery_perStep(){}
# displayOutput_eachPipelineStep(){




# }


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
   
_die(){ printf 'contract:%s:%s\n' "$1" "$2" >&2; exit "${3:-99}"; }
require(){ eval "$1" || _die pre  "$2" 97; }
invariant(){ eval "$1" || _die inv  "$2" 96; }
ensure(){ eval "$1" || _die post "$2" 98; }

is_bool(){ case "$1" in 0|1) return 0;; *) return 1;; esac; }
is_exec(){ [[ -f "$1" && -x "$1" ]]; }
is_abs(){ [[ "$1" = /* ]]; }

# after you compute: root, P1, P2, P3, ff, nogit, and POLICY_FILE under root
# No behavior changes. Only guards.

# 1) Flags are booleans
require "is_bool $ff"           "ff must be 0|1"
require "is_bool $nogit"        "nogit must be 0|1"

# 2) Root exists and is absolute
require "[[ -n \"$root\" ]]"     "root must be set"
invariant "[[ -d \"$root\" ]]"   "root must exist"
invariant "is_abs \"$root\""     "root must be absolute"

# 3) Policy file presence (keep your current allow-empty policy logic; here strict)
require "[[ -f \"$root/config/policy.rules.yml\" ]]" "missing policy.rules.yml"

# 4) Stage scripts resolved and executable
require "is_exec \"$P1\""       "P1 not executable: $P1"
require "is_exec \"$P2\""       "P2 not executable: $P2"
require "is_exec \"$P3\""       "P3 not executable: $P3"

# 5) Stage paths absolute (prevents CWD surprises)
invariant "is_abs \"$P1\""      "P1 must be absolute"
invariant "is_abs \"$P2\""      "P2 must be absolute"
invariant "is_abs \"$P3\""      "P3 must be absolute"

# Optional: quick context line (stderr only; no stdout changes)
printf 'run ctx: root=%s policy=%s ff=%s no_git=%s\n' \
  "$root" "$root/config/policy.rules.yml" "$ff" "$nogit" >&2

   run_policy_pipeline "$root" "$P1" "$P2" "$P3" "$ff" "$nogit"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
