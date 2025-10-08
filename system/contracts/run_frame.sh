#!/usr/bin/env bash
# system/contracts/run_frame.sh

begin_frame() {
  ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  FRAME_TS="$(mktemp)"; date -u +%s >"$FRAME_TS"; export FRAME_TS
  SNAP_KEYS="${SNAP_KEYS:-MAIN_BRANCH EVENTS}"
  ENV_BEFORE="$(env | grep -E "^($(echo "$SNAP_KEYS" | sed 's/ /|/g'))=" | sort)"
  # do NOT: export ENV_BEFORE or SNAP_KEYS
}
end_frame() {
  env_after="$(env | grep -E "^($(echo "$SNAP_KEYS" | sed 's/ /|/g'))=" | sort)"
  if ! diff -u <(printf "%s\n" "$ENV_BEFORE") <(printf "%s\n" "$env_after") >/dev/null; then
    echo "invariant: env mutated"
    diff -u <(printf "%s\n" "$ENV_BEFORE") <(printf "%s\n" "$env_after") || true
    exit 67
  fi
  bad=$(find "$ROOT" -type f -newer "$FRAME_TS" ! -path "$ROOT/artifacts/*" 2>/dev/null | sed "s|$ROOT/||")
  [ -z "$bad" ] || { printf "invariant: writes outside artifacts:\n%s\n" "$bad" >&2; exit 68; }
  rm -f "$FRAME_TS"
}