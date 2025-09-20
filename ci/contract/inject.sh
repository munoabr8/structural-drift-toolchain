#!/usr/bin/env bash
# CONTRACT-JSON-BEGIN
# {
#   "contract_schema": "contract/v1",
#   "args": [
#     "<script>",
#     "<contract.json>"
#   ],
#   "env": {},
#   "reads": "target script + json; no network",
#   "writes": [],
#   "tools": [
#     "bash",
#     "sed",
#     "mktemp"
#   ],
#   "exit": {
#     "ok": 0
#   },
#   "emits": []
# }
# CONTRACT-JSON-END
# ci/contract/inject.sh

set -euo pipefail
mode="require"  # require|add
[[ "${1:-}" == "--add-shebang" ]] && { mode="add"; shift; }
S="${1:?usage: $0 [--add-shebang] <script> <contract.json>}"
J="${2:?}"

tmp="$(mktemp)"
stripped="$(mktemp)"
# drop any prior block
sed '/^# CONTRACT-JSON-BEGIN/,/^# CONTRACT-JSON-END/d' "$S" > "$stripped"

# build comment-prefixed block
blk="$(mktemp)"
{
  echo "# CONTRACT-JSON-BEGIN"
  sed 's/^/# /' "$J"
  echo "# CONTRACT-JSON-END"
} > "$blk"

first="$(head -n1 "$stripped" || true)"
if [[ "$first" =~ ^#! ]]; then
  { head -n1 "$stripped"; cat "$blk"; tail -n +2 "$stripped"; } > "$tmp"
else
  if [[ "$mode" == "require" ]]; then
    echo "ERR:no shebang on first line: $S" >&2; exit 2
  else
    { echo '#!/usr/bin/env bash'; cat "$blk"; cat "$stripped"; } > "$tmp"
  fi
fi

mv "$tmp" "$S"
rm -f "$stripped" "$blk"
chmod +x "$S"