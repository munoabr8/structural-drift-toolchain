# probes/pipe.sh
#!/usr/bin/env bash
set -euo pipefail
out=$(printf "hello" | ./cmd.sh 2>&1)
echo "$out" | grep -q '^FACT|stdin_kind=pipe'
echo "$out" | grep -q '^DEC|should_read_stdin status=0'
echo "$out" | grep -qx 'hello'

