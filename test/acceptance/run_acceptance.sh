#!/usr/bin/env bash

set -euo pipefail
set -E
trap 'rc=$?; echo "ERR ${BASH_SOURCE##*/}:${LINENO} rc=$rc"; exit $rc' ERR

need_bin(){ command -v "$1" >/dev/null || { echo "missing binary: $1"; exit 127; }; }
need_file(){ [[ -f "$1" ]] || { echo "missing file: $1"; exit 66; }; }


printf 'abc xyz 123\n' > foo.txt


# Preconditions
need_bin jq
need_file ./test/acceptance/domain_probe.sh
need_file ./test/acceptance/env_from_probe.sh
need_file ./test/acceptance/assert_upper.sh
#need_file ./foo.txt


: > domain.log.jsonl

# 1) open FD3 in APPEND mode (won’t clobber)
exec 3>>domain.log.jsonl

# 2) run the probe so it writes a JSON line to FD3
echo hi | ./test/acceptance/domain_probe.sh --env USER --tag t >/dev/null

 #tail -1 domain.log.jsonl | jq -e '.'

 
# AC1+AC2+AC4: happy path
# out1="$(
#   cat ./foo.txt \
#     | ./domain_probe.sh --env USER,HOME,LANG,PATH --tag accept \
#     | ./env_from_probe.sh --log domain.log.jsonl --keys "USER,HOME,LANG,PATH" --path -- \
#         tr 'a-z' 'A-Z' \
#     | ./assert_upper.sh
# )"

# printf '%s\n' "$out1"; grep -q "Q OK" <<<"$out1"
# echo "$out1" | grep -q "Q OK"

 
 
# get last line once
last="$(tail -n1 domain.log.jsonl)"

# 1) valid JSON
#printf '%s\n' "$last" | jq -e '.' >/dev/null

# 2) argv is an array
#printf '%s\n' "$last" | jq -e '(.argv|type)=="array"' >/dev/null

# 3) if argc exists, it matches argv length
#printf '%s\n' "$last" | jq -e 'if has("argc") then .argc == (.argv|length) else true end' >/dev/null

# 4) stdin_bytes exists and is numeric
#printf '%s\n' "$last" | jq -e 'has("stdin_bytes") and ((.stdin_bytes|type)=="number")' >/dev/null

# 5) optional: if tag exists, it is a string
#printf '%s\n' "$last" | jq -e 'if has("tag") then (.tag|type)=="string" else true end' >/dev/null



# AC1: probe wrote a valid JSON line
tail -n1 domain.log.jsonl | jq -e '.'

# Keep assertion but print OK/FAIL
tail -n1 domain.log.jsonl | jq -e '.' >/dev/null && echo "AC1 OK" || echo "AC1 FAIL"

tail -n1 domain.log.jsonl | jq -e '.argc==(.argv|length) and (.stdin_bytes|type)=="number"' >/dev/null \
  && echo "AC1 shape OK" || echo "AC1 shape FAIL"

# AC3: safety—empty log fails cleanly  (do NOT touch the real log)
empty_log=$(mktemp)
if ./test/acceptance/env_from_probe.sh --log "$empty_log" --keys USER -- true 1>out.txt 2>err.txt; then
  echo "AC3 FAIL: expected non-zero rc on empty log" >&2; exit 72
fi
grep -Fq "probe log empty" err.txt || { echo "AC3 FAIL: missing error text" >&2; exit 73; }
rm -f "$empty_log" out.txt err.txt

hash256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    echo "missing: sha256sum or shasum" >&2
    return 127
  fi
}

# AC5: idempotence—same inputs → same outputs
# h1="$(cat ./foo.txt \
#       | ./domain_probe.sh --env USER --tag id1 \
#       | ./env_from_probe.sh --log domain.log.jsonl --keys "USER" -- \
#           tr 'a-z' 'A-Z' | hash256)"

# h2="$(cat ./foo.txt \
#       | ./domain_probe.sh --env USER --tag id2 \
#       | ./env_from_probe.sh --log domain.log.jsonl --keys "USER" -- \
#           tr 'a-z' 'A-Z' | hash256)"
# test "$h1" = "$h2"

# echo "ACCEPT: all checks passed"

#If you must use a file:
# tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
# printf 'abc xyz 123\n' >"$tmp"
# cat "$tmp" | ... 

gen_input(){ printf 'abc xyz 123\n'; }  # test payload

# AC1+AC2+AC4
out1="$(
  gen_input \
  | ./test/acceptance/domain_probe.sh --env USER,HOME,LANG,PATH --tag accept \
  | ./test/acceptance/env_from_probe.sh --log domain.log.jsonl --keys "USER,HOME,LANG,PATH" --path -- \
      tr 'a-z' 'A-Z' \
  | ./test/acceptance/assert_upper.sh
)"
printf '%s\n' "$out1"; grep -q "Q OK" <<<"$out1"

# AC5
h1="$(gen_input | ./test/acceptance/domain_probe.sh --env USER --tag id1 \
      | ./test/acceptance/env_from_probe.sh --log domain.log.jsonl --keys "USER" -- \
          tr 'a-z' 'A-Z' | hash256)"
h2="$(gen_input | ./test/acceptance/domain_probe.sh --env USER --tag id2 \
      | ./test/acceptance/env_from_probe.sh --log domain.log.jsonl --keys "USER" -- \
          tr 'a-z' 'A-Z' | hash256)"
test "$h1" = "$h2"

echo "ACCEPT: all checks passed"

