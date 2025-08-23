#!/usr/bin/env bash

#

 #===================================
# FS CONTRACT (your logic, tightened)
# ===================================
FRAME_ROOT="" M0="" M1="" WRITES=()

_norm(){ python - "$1" <<'PY'
import os,sys; print(os.path.realpath(sys.argv[1]))
PY
}
_is_repo(){ git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

_manifest_git(){ git -C "$1" ls-files -z | tr '\0' '\n' | LC_ALL=C sort; }
_manifest_find(){
  ( cd "$1" || return 1
    find . -xdev \( -path ./.git -o -path ./tmp \) -prune -o -print \
    | sed 's#^\./##' | LC_ALL=C sort
  )
}
_manifest(){ _is_repo "$1" && _manifest_git "$1" || _manifest_find "$1"; }

begin_fs_frame(){
  FRAME_ROOT=$(_norm "${1:-$PWD}")
  M0="$(mktemp)"; _manifest "$FRAME_ROOT" >"$M0"
  WRITES=()
}
declare_write(){ WRITES+=("$(_norm "$1")"); }
check_fs_frame(){
  M1="$(mktemp)"; _manifest "$FRAME_ROOT" >"$M1"
  mapfile -t CHANGES < <(diff -u "$M0" "$M1" | awk '/^[+-][^+-]/ {print substr($0,2)}')
  ((${#CHANGES[@]}==0)) && { rm -f "$M0" "$M1"; return 0; }
  for rel in "${CHANGES[@]}"; do
    local abs="$FRAME_ROOT/$rel" allowed=0
    for w in "${WRITES[@]}"; do case "$abs" in "$w"|"$w"/*) allowed=1; break;; esac; done
    (( allowed )) || { printf 'fs: drift %s\n' "$abs" >&2; rm -f "$M0" "$M1"; return 200; }
  done
  rm -f "$M0" "$M1"
}


######################

 
FS_PATHS=()
contracts_reset_fs(){ FS_PATHS=(); }
declare_frame(){ FS_PATHS+=("$@"); }

# Optional ignore regex can be set by wrapper/env: FRAME_IGNORE_DIR_RE
_cf_snapshot(){
  (( ${#FS_PATHS[@]} )) || { echo 0; return; }
  LC_ALL=C find "${FS_PATHS[@]}" -xdev -print0 2>/dev/null \
    | tr '\0' '\n' \
    | { [[ -n "${FRAME_IGNORE_DIR_RE-}" ]] && grep -Ev "$FRAME_IGNORE_DIR_RE" || cat; } \
    | sort \
    | xargs -0 -I{} printf '%s\0' 2>/dev/null | tr -d '\000' >/dev/null  # keep pipeline NUL-safe
  LC_ALL=C find "${FS_PATHS[@]}" -xdev -type f -print0 2>/dev/null \
    | sort -z \
    | xargs -0 stat -c 'P:%n M:%f S:%s T:%Y U:%U G:%G' 2>/dev/null \
    | sha256sum | awk '{print $1}'
}

_cf_dump(){
  (( ${#FS_PATHS[@]} )) || { echo "<no-fs-frame>"; return; }
  LC_ALL=C find "${FS_PATHS[@]}" -xdev -type f -print0 2>/dev/null \
    | sort -z \
    | xargs -0 stat -c 'P:%n M:%f S:%s T:%Y U:%U G:%G' 2>/dev/null \
    | sort
}



 