# shellcheck shell=bash 
# probes/tty.sh  (requires `script`)
#!/usr/bin/env bash
 
#!/usr/bin/env bash
set -euo pipefail
cmd='./cmd.sh'

if script -V 2>/dev/null | grep -qi util-linux; then
  # Linux: has -c
  out=$(script -qfc "$cmd" /dev/null </dev/null 2>&1)
else
  # macOS/BSD: no -c; run via bash -lc; feed EOF
  out=$(script -q /dev/null /usr/bin/env bash -lc "$cmd" </dev/null 2>&1)
fi

echo "$out" | grep -q '^FACT|stdin_kind=tty'
echo "$out" | grep -q '^DEC|should_read_stdin status=1'   # policy: no read on TTY
! echo "$out" | grep -qx 'hello'                           # no payload expected
