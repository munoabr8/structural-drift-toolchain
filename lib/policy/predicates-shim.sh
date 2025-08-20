# predicates-shim.sh

# ---- Generic predicates ----
fn_defined() { declare -F "$1" >/dev/null 2>&1; }                 # fn exists in current shell
stdin_present() { [[ ! -t 0 ]]; }                                 # data is piped/redirected
args_eq() { (( $1 == $2 )); }                                     # args_eq "$#" N

_pre()  { local msg="${*: -1}"; "${@:1:$#-1}" || _die pre  "$msg" 97; }
_inv()  { local msg="${*: -1}"; "${@:1:$#-1}" || _die inv  "$msg" 96; }
_post() { local msg="${*: -1}"; "${@:1:$#-1}" || _die post "$msg" 95; }

# Predicates used
is_bool()           { [[ $1 == 0 || $1 == 1 ]]; }
matches()           { [[ $1 =~ $2 ]]; }
is_readable()       { [[ -r $1 ]]; }
is_nonempty()       { [[ -n $1 ]]; }
is_empty()          { [[ -z $1 ]]; }
is_nonempty_file()  { [[ -s $1 ]]; }
is_tty_stdin()      { [[ -t 0 ]]; }   # true if no piped stdin
stdin_ready() { read -t 0 -N 0; }   # success if data is available
stdin_present() { [[ ! -t 0 ]]; }

valid_mode_or_empty() { [[ -z $1 || $1 == literal || $1 == regex ]]; }
_die(){ printf 'contrac2t:%s:%s\n' "$1" "$2" >&2; exit "${3:-99}"; }


# ---- Shim-specific predicates (run shim in a clean shell) ----
# Returns 0 if shim can run with provided POLICY_SRC_TRANSFORM and consume stdin
shim_reads_stdin() {                                              # $1=shim $2=srcfile
  local shim=$1 src=$2; [[ -x $shim && -r $src ]] || return 2
  local out
  out="$(env -i LC_ALL=C PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin" \
          POLICY_SRC_TRANSFORM="$src" \
          "$shim" <<<"ping")" || return 1
  [[ -n $out ]]
}

# Probes which function the shim dispatches to by planting tagged impls.
# $3 must be the function name you expect the shim to call.
shim_uses_function() {                                            # $1=shim $2=srcdir $3=expected_fn
  local shim=$1 dir=$2 expected=$3; [[ -x $shim && -d $dir ]] || return 2
  local src="$dir/probe_transform.sh"
  cat >"$src" <<'EOF'
# probe script: define BOTH names with distinct tags
transform_policy_rules()  { while IFS= read -r l; do printf 'CALLED:TPR:%s\n'  "$l"; done; }
transform_policy_rules2() { while IFS= read -r l; do printf 'CALLED:TPR2:%s\n' "$l"; done; }
EOF
  chmod +r "$src"
  local out
  out="$(env -i LC_ALL=C PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin" \
          POLICY_SRC_TRANSFORM="$src" \
          "$shim" <<<"x")" || return 1
  case "$out" in
    CALLED:TPR:*)  [[ $expected == transform_policy_rules  ]];;
    CALLED:TPR2:*) [[ $expected == transform_policy_rules2 ]];;
    *) return 1;;
  esac
}


has_shebang() {  # $1=file $2=regex for interpreter (e.g., 'bash' or '/usr/bin/env bash')
  local file=$1 expected=$2 first
  [[ -f "$file" && -r "$file" ]] || { echo "not readable: $file"; return 1; }
  IFS= read -r first <"$file" || { echo "cannot read: $file"; return 1; }
  # strip possible UTF-8 BOM
  first="${first#$'\xEF\xBB\xBF'}"
  [[ $first =~ ^#! ]] || { echo "no shebang: <$first>"; return 1; }
  [[ $first =~ $expected ]] || { echo "shebang mismatch: <$first>"; return 1; }
}

 
 

# portable field counter
_field_count() {
  local s=$1 n=1
  s=${s%$'\r'}
  while [[ $s == *"|"* ]]; do s=${s#*"|"}; ((n++)); done
  printf '%s' "$n"
}

# 0=ok, 1=empty line, 2=>5 fields, 3=<4 or missing required, 4=bad mode
has_valid_shape() {
  local line=${1-} t p c a m extra
  [[ -n $line ]] || return 1
  line=${line%$'\r'}

  # hard gate on field count
  local f; f=$(_field_count "$line") || return 3
  (( f == 4 || f == 5 )) || return 3

  # parse
  local IFS='|'
  read -r t p c a m extra <<<"$line"

  # no extras
  [[ -z ${extra-} ]] || return 2

  # required fields must be nonempty (this is what fails "t|p|c|")
  [[ -n "$t" && -n "$p" && -n "$c" && -n "$a" ]] || return 3

  # mode ok if absent or literal|regex
  [[ -z ${m-} || $m == literal || $m == regex ]] || return 4
  return 0
}

# inside has_valid_shape, after parsing t p c a m extra:
 

assert_success() { [ "$status" -eq 0 ] || { echo "expected success, got $status"; return 1; }; }
assert_failure() { [ "$status" -ne 0 ] || { echo "expected failure, got 0"; return 1; }; }
assert_cmd()     { "$@"; rc=$?; [ $rc -eq 0 ] || { echo "assert_cmd failed: $* -> $rc"; return 1; }; }

assert_exe() { [[ -x "$1" ]] || { echo "not executable: $1"; return 1; }; }
# ---- Assertions (fail fast with message to stderr) ----

assert_fn_defined() { fn_defined "$1" || { echo "missing fn: $1"; return 1; }; }
