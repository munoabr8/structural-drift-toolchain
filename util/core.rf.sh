#!/usr/bin/env bash
# util/core.rf.sh — determine/export ROOT_BOOT (project root)

[[ -n ${__CORE_RF_SH__:-} ]] && return 0
__CORE_RF_SH__=1

core_usage() {
  cat <<'EOF'
core.rf.sh — minimal bootstrap

PURPOSE
  Determine the project root and export it as ROOT_BOOT.

USAGE
  source "util/core.rf.sh"    # sets ROOT_BOOT if unset
  bash util/core.rf.sh        # prints ROOT_BOOT=<path>
  CORE_DEBUG=true bash util/core.rf.sh  # debug

BEHAVIOR
  • Honors pre-set ROOT_BOOT (if it points to a directory).
  • Else tries: (1) Git toplevel from this script's dir
                (2) Walk up for markers: policy.rules.yml or bin+lib
                (3) Fallback: parent of this file's dir
  • No shell options mutated; no other files sourced.
EOF
}

core__dbg(){ [[ "${CORE_DEBUG:-false}" == "true" ]] && printf 'DBG %s\n' "$*" >&2; }

core__abs_script_path() {
  local p="${BASH_SOURCE[0]}"
  if command -v realpath >/dev/null 2>&1; then
    realpath -P -- "$p"
  else
    local d="${p%/*}"; d="${d:-.}"
    d="$(cd -- "$d" && pwd -P)" || return 1
    printf '%s/%s' "$d" "${p##*/}"
  fi
}

core__git_toplevel() {
  local start="$1"
  command -v git >/dev/null 2>&1 || { printf '\n'; return 0; }
  git -C "$start" rev-parse --show-toplevel 2>/dev/null || printf '\n'
}

core__find_root_by_markers() {
  local d="$1" max=12
  while ((max-- > 0)); do
    if [[ -f "$d/policy.rules.yml" || ( -d "$d/bin" && -d "$d/lib" ) ]]; then
      printf '%s\n' "$d"; return 0
    fi
    [[ "$d" == "/" ]] && break
    d="$(cd -- "$d/.." && pwd -P)" || break
  done
  printf '\n'
}

core__derive_root() {
  # 0) Respect preset if valid
  if [[ -n ${ROOT_BOOT:-} && -d ${ROOT_BOOT:-/dev/null} ]]; then
    core__dbg "preset ROOT_BOOT=$ROOT_BOOT"
    printf '%s\n' "$ROOT_BOOT"; return 0
  fi

  # 1) Base on this script's absolute path
  local script_path core_dir git_top mark_root parent
  script_path="$(core__abs_script_path)" || return 1
  core_dir="$(cd -- "$(dirname -- "$script_path")" && pwd -P)" || return 1
  core__dbg "script_path=$script_path"
  core__dbg "core_dir=$core_dir"

  # 2) Prefer Git repo toplevel
  git_top="$(core__git_toplevel "$core_dir")"
  if [[ -n "$git_top" && -d "$git_top" ]]; then
    core__dbg "git_top=$git_top"
    printf '%s\n' "$git_top"; return 0
  fi

  # 3) Marker walk (no git required)
  mark_root="$(core__find_root_by_markers "$core_dir")"
  if [[ -n "$mark_root" ]]; then
    core__dbg "mark_root=$mark_root"
    printf '%s\n' "$mark_root"; return 0
  fi

  # 4) Last resort: parent of this file's dir
  parent="$(cd -- "$core_dir/.." && pwd -P)" || return 1
  core__dbg "fallback parent=$parent"
  printf '%s\n' "$parent"
}

core_init() {
	if [[ -z ${ROOT_BOOT:-} || "$ROOT_BOOT" = "/" || ! -d ${ROOT_BOOT:-/dev/null} ]]; then
    local root; root="$(core__derive_root)" || return 1
    ROOT_BOOT="$root"; export ROOT_BOOT
  fi
  return 0
}

# Entry points
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    -h|--help|help) core_usage; exit 0 ;;
    *) root="$(core__derive_root)" || exit 1
       printf 'ROOT_BOOT=%s\n' "$root" ;;
  esac
else
  core_init || return 1
fi




# tests/core.bats
#!/usr/bin/env bats
# setup() { cd "$BATS_TEST_DIRNAME/.." || exit 1; }
# @test "core sets ROOT_BOOT" {
#   run bash -c 'unset ROOT_BOOT; source util/core.sh; echo "$ROOT_BOOT"'
#   [ "$status" -eq 0 ]
#   [[ "$output" = /* ]]
# }
# @test "core ignores bad preset '/'" {
#   run bash -c 'ROOT_BOOT=/ source util/core.sh; echo "$ROOT_BOOT"'
#   [ "$status" -eq 0 ]
#   [[ "$output" != "/" ]]
# }

#USEAGE:
# bootstrap
#source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/../util/core.rf.sh"
# then your existing loader/logger, then env_init, policy, self-tests…


