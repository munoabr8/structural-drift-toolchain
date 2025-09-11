#!/usr/bin/env bash
# bin/gen-scope
set -euo pipefail

# ---- defaults (resolve to repo root) ----
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPEC="$ROOT/structure.spec"
OUT="$ROOT/config/scope.yaml"
OVR="$ROOT/config/scope.overrides.yaml"
MODE="write"   # write|check
VERBOSE=${VERBOSE:-0}

usage() {
  cat <<EOF
gen-scope: generate scope.yaml from structure.spec (+ optional overrides)

Usage:
  bin/gen-scope [--spec <file>] [--out <file>] [--overrides <file>] [--check]
Options:
  --spec <file>        Source spec (default: structure.spec)
  --out <file>         Output scope YAML (default: config/scope.yaml)
  --overrides <file>   Overrides file (default: config/scope.overrides.yaml)
  --check              Do not write; fail if OUT would change (for CI)
  -h, --help           Show help
EOF
}

# ---- args ----
while (($#)); do
  case "$1" in
    --spec) SPEC="$(readlink -f "${2:?}")"; shift ;;
    --out) OUT="$(readlink -f "${2:?}")"; shift ;;
    --overrides) OVR="$(readlink -f "${2:?}")"; shift ;;
    --check) MODE="check" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac; shift
done

# ---- deps & inputs ----
command -v yq >/dev/null 2>&1 || { echo "error: yq v4 required"; exit 127; }
[[ -f "$SPEC" ]] || { echo "error: missing spec: $SPEC"; exit 66; }

# ---- helpers ----
read_list(){ [[ -f "$2" ]] || return 0; yq -r "$1 // [] | .[]" "$2" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
uniq_sort(){ sort -u | sed '/^$/d'; }

# ---- compute roots/sub_roots from structure.spec ----
mapfile -t roots < <(
  awk '/^dir:/{p=$2; sub("^\\./","",p); sub("/$","",p);
       split(p,a,"/"); if(a[1]!="") print a[1]}' "$SPEC" | uniq_sort
)
mapfile -t subs < <(
  awk '/^dir:/{p=$2; sub("^\\./","",p); sub("/$","",p);
       n=split(p,a,"/"); if(n>=2) print a[1]"/"a[2]}' "$SPEC" | uniq_sort
)

# ---- overrides ----
mapfile -t ign_roots < <(read_list '.ignore_roots' "$OVR" || true)
mapfile -t ign_subs  < <(read_list '.ignore_sub_roots' "$OVR" || true)
mapfile -t add_roots < <(read_list '.add_roots' "$OVR" || true)
mapfile -t add_subs  < <(read_list '.add_sub_roots' "$OVR" || true)

(( VERBOSE )) && {
  printf 'ign_roots=%q\n' "${ign_roots[@]:-}"; printf 'ign_subs=%q\n' "${ign_subs[@]:-}";
}

# 1) filter roots
if ((${#ign_roots[@]})); then
  roots=($(printf "%s\n" "${roots[@]}" | grep -vxF -f <(printf "%s\n" "${ign_roots[@]}") || true))
fi

# 2) filter sub_roots: exact ignores
if ((${#ign_subs[@]})); then
  subs=($(printf "%s\n" "${subs[@]}" | grep -vxF -f <(printf "%s\n" "${ign_subs[@]}") || true))
fi

# 3) filter sub_roots: by ignored root prefix
if ((${#ign_roots[@]})); then
  pat="$(printf "%s\n" "${ign_roots[@]}" | sed 's/[].[^$\\|]/\\&/g; s#^#^#; s#$#/#' | paste -sd'|' -)"
  [[ -n "$pat" ]] && subs=($(printf "%s\n" "${subs[@]}" | grep -Ev "$pat" || true))
fi

# 4) add and uniq
roots=($(printf "%s\n" "${roots[@]}" "${add_roots[@]:-}" | uniq_sort))
subs=($(printf "%s\n" "${subs[@]}"  "${add_subs[@]:-}"  | uniq_sort))

# ---- render to temp once ----
tmp="$(mktemp)"
{
  echo "roots:"
  if ((${#roots[@]})); then for r in "${roots[@]}"; do printf "  - %s\n" "$r"; done; fi
  echo
  echo "sub_roots:"
  if ((${#subs[@]})); then for s in "${subs[@]}";  do printf "  - %s\n" "$s"; done; fi
} > "$tmp"

# ---- write or check ----
mkdir -p "$(dirname "$OUT")"
if [[ "$MODE" == "check" ]]; then
  if [[ -f "$OUT" ]] && diff -u "$OUT" "$tmp" >/dev/null; then
    echo "OK: $OUT is up to date"
    rm -f "$tmp"; exit 0
  else
    echo "CHANGE NEEDED: $OUT differs" >&2
    diff -u "${OUT:-/dev/null}" "$tmp" || true
    rm -f "$tmp"; exit 1
  fi
else
  mv "$tmp" "$OUT"
  echo "wrote $OUT"
fi
