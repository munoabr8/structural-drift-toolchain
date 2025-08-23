parse_rule() {
  local line=$1 t p c a m extra
  IFS='|' read -r t p c a m extra <<<"$line"
  [[ -z ${extra+x} ]] || return 65
  [[ -n $t && -n $p && -n $c && -n $a ]] || return 65
  [[ -z $m || $m == literal || $m == regex ]] || return 65
  printf '%s|%s|%s|%s|%s\n' "$t" "$p" "$c" "$a" "${m:-}"
}