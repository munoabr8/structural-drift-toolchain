# probes/file.sh
#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp); trap 'rm -f "$tmp" "$tmp.out" "$tmp.err"' EXIT
printf "hello\n" > "$tmp"
out=$(./cmd.sh <"$tmp" >"$tmp.out" 2>"$tmp.err")
grep -q '^FACT|stdin_kind=file' "$tmp.err"
grep -q '^DEC|should_read_stdin status=0' "$tmp.err"
grep -qx 'hello' "$tmp.out"

