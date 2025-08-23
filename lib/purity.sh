# lib/purity.sh
enforce_contract_purity() { # $1=contract file
  local f="$1"
  [[ -r "$f" ]] || { echo "Purity: missing $f" >&2; return 2; }

  # forbid writes/mutation and side-effects
  local 
forbid_re='\b(>[^>]|>>|rm|mv|cp|chmod|chown|mkdir|rmdir|ln|tee|truncate|sed[[:space:]]+-i|perl[[:space:]]+-i|ed\b|curl\b|wget\b|nc\b|ssh\b)\b'
  if grep -nE "$forbid_re" "$f"; then
    echo "Purity: forbidden ops in $f" >&2
    return 1
  fi

  # optional: allowlist external cmds the contract may use (read-only)
  local allow_re='\b(jq|grep|awk|sed|cut|sort|uniq|head|tail|printf|echo)\b'
  if grep -nE '\b([a-zA-Z0-9_\-]+)\b' "$f" \
     | grep -vE "$allow_re|function|^[0-9]+:" >/dev/null; then
    : # keep simple now; tighten later if needed
  fi
}

# CI helper
check_all_contracts() {
  local ok=1
  while IFS= read -r c; do
    enforce_contract_purity "$c" || ok=0
  done < <(git ls-files '*/*.contract.sh' 2>/dev/null || printf '%s\n' ./*.contract.sh)
  return $ok
}

