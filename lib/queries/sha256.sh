# shellcheck shell=bash 
# queries/sha256.sh  (source-only)

# Choose once, allow override, cache
_sha256_cmd() {
  if [ -n "${_SHA256_CMD:-}" ]; then printf '%s\n' "$_SHA256_CMD"; return 0; fi
  if [ -n "${SHA256_BACKEND:-}" ] && command -v ${SHA256_BACKEND%% *} >/dev/null 2>&1; then
    _SHA256_CMD="$SHA256_BACKEND"
  elif command -v sha256sum >/dev/null 2>&1; then
    _SHA256_CMD="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    _SHA256_CMD="shasum -a 256"
  elif command -v sha256 >/dev/null 2>&1; then
    _SHA256_CMD="sha256 -q"
  elif command -v openssl >/dev/null 2>&1; then
    _SHA256_CMD="openssl dgst -sha256 -r"
  elif command -v python3 >/dev/null 2>&1; then
    _SHA256_CMD="python3"
  else
    return 127
  fi
  printf '%s\n' "$_SHA256_CMD"
}

sha256_file() {
  local f=${1:?missing file}
  [ -r "$f" ] || { printf 'sha256_file: unreadable: %s\n' "$f" >&2; return 1; }
  local h; h=$(_sha256_cmd) || { printf 'sha256: tool not found\n' >&2; return 127; }
  LC_ALL=C case "$h" in
    "sha256 -q")                  $h -- "$f" ;;
    "openssl dgst -sha256 -r")    $h -- "$f" | awk '{print tolower($1)}' ;;
    python3)                      python3 -c 'import sys,hashlib;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$f" ;;
    *)                            $h -- "$f" | awk '{print tolower($1)}' ;;
  esac
}

sha256_stdin() {
  local h; h=$(_sha256_cmd) || { printf 'sha256: tool not found\n' >&2; return 127; }
  LC_ALL=C case "$h" in
    "sha256 -q")                  $h ;;
    "openssl dgst -sha256 -r")    $h | awk '{print tolower($1)}' ;;
    python3)                      python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())' ;;
    *)                            $h | awk '{print tolower($1)}' ;;
  esac
}

# Convenience: file if arg given, else stdin
sha256() { if [ $# -gt 0 ]; then sha256_file "$1"; else sha256_stdin; fi; }

# Verify a file against an expected hex digest (query + pure compare)
sha256_verify() {
  local f=${1:?file} expect=${2:?digest} got
  got=$(sha256_file "$f") || return
  # pure predicate-style comparison
  printf '%s' "$expect" | tr '[:upper:]' '[:lower:]' | cmp -s - <(printf '%s' "$got")
}

# Batch: print "hash  filename" lines like sha256sum
sha256_many() {
  local f d h=0
  for f in "$@"; do
    d=$(sha256_file "$f") || { h=1; printf '%s: FAILED\n' "$f" >&2; continue; }
    printf '%s  %s\n' "$d" "$f"
  done
  return "$h"
}

# Check file with lines "hash␠␠filename" or "hash␠filename"
sha256_check() {
  local list=${1:?list file} line hash file ok=0 bad=0 got
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue;; esac
    hash=${line%% *}; file=${line#*"  "}    # prefer two spaces; fallback next line
    [ "$file" = "$line" ] && { hash=${line%% *}; file=${line#* }; }
    got=$(sha256_file "$file") || { printf '%s: FAILED open or read\n' "$file"; bad=$((bad+1)); continue; }
    if printf '%s' "$hash" | tr '[:upper:]' '[:lower:]' | cmp -s - <(printf '%s' "$got"); then
      printf '%s: OK\n' "$file"; ok=$((ok+1))
    else
      printf '%s: FAILED\n' "$file"; bad=$((bad+1))
    fi
  done < "$list"
  [ "$bad" -eq 0 ]
}

# Cache: reuse .sha256 if newer than the file
sha256_cached() {
  local f=${1:?file} c="${f}.sha256" d
  if [ -f "$c" ] && [ "$c" -nt "$f" ]; then
    awk '{print tolower($1)}' -- "$c"; return
  fi
  d=$(sha256_file "$f") || return
  printf '%s  %s\n' "$d" "$f" >"$c"
  printf '%s\n' "$d"
}
