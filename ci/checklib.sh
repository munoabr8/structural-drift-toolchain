# shellcheck shell=bash
# ci/checklib.sh  (lean)
# Helpers
strip()      { sed -e 's/#.*$//' -e 's/[[:space:]]\+/ /g'; }
pre_none()   { cat; }
pre_frame()  { awk 'p||$0=="--"{p=1;print;next}{print}' | sed '1,/^--$/!d'; }
tok()        { tr -c '[:alnum:]_-' ' ' | tr ' ' '\n' | sed '/^$/d'; }

# run_check NEED_REGEX BAN_REGEX PRE_FN FILES...
run_check() {
  local need="$1" ban="$2" pre="$3"; shift 3
  local rc=0 t f
  for f in "$@"; do
    # preprocess → tokens → space-joined
    if ! t="$("$pre" <"$f" | strip | tok | tr '\n' ' ')"; then
      echo "[check] $f: preprocess error"; rc=1; continue
    fi
    if ! grep -Eq "$need" <<<"$t"; then
      echo "[check] $f: missing required"; rc=1; continue
    fi
    if grep -Eq "$ban" <<<"$t"; then
      echo "[check] $f: forbidden"; rc=1
    else
      echo "[check] $f: OK"
    fi
  done
  return "$rc"
}
