set -euo pipefail

need_file_var() {
  local k="$1" v
  # check if var is set without tripping nounset
  if eval "[[ -z \${$k+x} ]]"; then
    echo "missing/empty file: $k (<unset>)" >&2; exit 64
  fi
  # read its value safely
  eval "v=\${$k}"
  [[ -n "$v" && -s "$v" ]] || { echo "missing/empty file: $k ($v)" >&2; exit 64; }
}


json_ok()   { jq -e . "$1" >/dev/null || { echo "post: invalid JSON $1" >&2; exit 69; }; }

# examples
need_file_var EVENTS 

#need_file "${EVENTS:?unset EVENTS}"
json_ok "$EVENTS"
# add others, e.g., need_file "$ARTDIR/dora.json"; json_ok "$ARTDIR/dora.json"