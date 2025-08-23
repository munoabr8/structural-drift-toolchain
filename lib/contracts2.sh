#!/usr/bin/env bash
# contracts.sh: declare reads/writes and enforce frame rules
READS=()
WRITES=()
FRAMES=()

declare_read()   { READS+=("$@"); }
declare_write()  { WRITES+=("$@"); }
declare_frame()  { FRAMES+=("$@"); }

frame_snapshot() {
  # snapshot only the framed environment and FS
  {
    env -0 | grep -zvE '^(PATH=|TMPDIR=)' | sha256sum
    for f in "${FRAMES[@]}"; do
      [[ -e $f ]] && sha256sum "$f"
    done
  } | sha256sum
}



