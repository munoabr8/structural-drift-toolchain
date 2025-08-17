#!/usr/bin/env bash
# smoke_policy_query.sh
set -uo pipefail   # no -e here

SCRIPT="${SCRIPT:-./policy_query_p1.sh}"

# ------------ Harness ------------
pass=0 fail=0 EXIT=0
ok(){ echo "OK: $*";  ((pass++)); }
bad(){ echo "FAIL: $*" >&2; ((fail++)); EXIT=1; }
hdr(){ printf "\n=== %s ===\n" "$*"; }
#contains(){ [[ "$1" == *"$2"* ]]; }

# ------------ Shim utils ------------
make_yq_shim(){  # prints dir with yq shim
  local d; d="$(mktemp -d)"
  cat >"$d/yq" <<'SH'
#!/usr/bin/env bash
# Pass -e structural check, fail data query
if [[ "$1" == "-e" ]]; then exit 0; fi
exit 42
SH
  chmod +x "$d/yq"
  echo "$d"
}

# ------------ Cases ------------
case_happy_stdin(){
  hdr "Case 1: happy stdin"
  local rc out yaml
  yaml=$'- type: invariant\n  path: README.md\n  condition: must_exist\n  action: error\n'
  out="$(bash "$SCRIPT" --stdin <<<"$yaml" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then ok "happy stdin rc"; else bad "happy stdin rc (rc=$rc out=[$out])"; fi
  if [[ "$out" == $'invariant\tREADME.md\tmust_exist\terror' ]]; then
    ok "happy stdin output"
  else
    bad "happy stdin output (out=[$out])"
  fi
}

case_missing_file_error(){
  hdr "Case 2: missing file error"
  local rc out
  out="$(bash "$SCRIPT" --policy /no/such/file 2>&1)"; rc=$?
  if [[ $rc -ne 0 && "$out" == *"policy not found"* ]]; then
    ok "missing file fails with message"
  else
    bad "missing file check (rc=$rc out=[$out])"
  fi
}

case_nonseq_root_fails(){
  hdr "Case 3: non-sequence root fails"
  local rc out
  out="$(bash "$SCRIPT" --stdin <<< 'key: value' 2>&1)"; rc=$?
  if [[ $rc -ne 0 && "$out" == *"policy root must be a YAML sequence"* ]]; then
    ok "non-sequence root rejected"
  else
    bad "non-sequence root (rc=$rc out=[$out])"
  fi
}

case_yq_failure_propagates(){
  hdr "Case 4: yq failure propagates"
  local rc out shim
  shim="$(make_yq_shim)"
  out="$(env PATH="$shim:$PATH" bash "$SCRIPT" --stdin <<<'[]' 2>&1)"; rc=$?
  rm -rf "$shim"
  if [[ $rc -eq 42 ]]; then ok "yq nonzero propagated (42)"; else bad "yq propagation (rc=$rc out=[$out])"; fi
  if [[ -z "$out" ]]; then ok "no output on yq failure"; else bad "unexpected output on yq failure (out=[$out])"; fi
}

case_allow_empty_ok(){
  hdr "Case 5: allow-empty ok"
  local rc out
  out="$(bash "$SCRIPT" --policy /no/such/file --allow-empty 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then ok "allow-empty rc"; else bad "allow-empty rc (rc=$rc out=[$out])"; fi
  if [[ -z "$out" ]]; then ok "allow-empty output"; else bad "allow-empty output (out=[$out])"; fi
}

# ------------ Main ------------
echo "running smoke tests for: $SCRIPT"
case_happy_stdin
case_missing_file_error
case_nonseq_root_fails
case_yq_failure_propagates
case_allow_empty_ok

echo
echo "summary|cases=$((pass+fail))|pass=$pass|fail=$fail"
exit "$EXIT"
