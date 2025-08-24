# shellcheck shell=bash   # tells ShellCheck the dialect 

 # predicates are closed off to the enviorment. 

nonblank() { [[ -n "${1//[[:space:]]/}" ]]; }
is_empty() { [[ -z $1 ]]; }

valid_mode_or_empty() { [[ -z $1 || $1 == literal || $1 == regex ]]; }
 
is_nonempty_str() { [[ -n ${1-} ]]; }
is_nonempty() { (( $1 > 0 )); }     # pure

args_le() { (( $1 <= $2 )); }
 
args_eq() { (( $1 == $2 )); }                                     # args_eq "$#" N
 
is_bool()           { [[ $1 == 0 || $1 == 1 ]]; }
matches()           { [[ $1 =~ $2 ]]; } 

has_ext()            { local f=${1-} ext=${2-}; [[ $f == *".$ext" ]]; }




 
# ---------- Pure predicate (args-only, no I/O)
# 0=ok, 1=no shebang, 2=mismatch
predicate_has_shebang_line() { # $1=line $2=expected-regex
  local line=$1 expected=$2
  # strip optional UTF-8 BOM then test
  line="${line#$'\xEF\xBB\xBF'}"
  [[ $line =~ ^#! ]] || return 1
  [[ $line =~ $expected ]] || return 2
}




# strings
is_nonempty_str()   { [[ -n ${1-} ]]; }
is_blank_str()      { [[ -z ${1//[[:space:]]/} ]]; }
equals_str()        { [[ ${1-} == ${2-} ]]; }
has_prefix()        { [[ ${1-} == ${2-}* ]]; }
has_suffix()        { [[ ${1-} == *${2-} ]]; }
contains_substr()   { [[ ${1-} == *${2-}* ]]; }
has_ext_str()       { [[ ${1-} == *".${2-}" ]]; }
len_ge()            { local n=${#1}; (( n >= ${2-0} )); }
len_le()            { local n=${#1}; (( n <= ${2-0} )); }

# numbers
is_uint()           { [[ ${1-} =~ ^[0-9]+$ ]]; }
is_int()            { [[ ${1-} =~ ^-?[0-9]+$ ]]; }
lt()                { (( ${1-0} <  ${2-0} )); }
le()                { (( ${1-0} <= ${2-0} )); }
gt()                { (( ${1-0} >  ${2-0} )); }
ge()                { (( ${1-0} >= ${2-0} )); }
between_inc()       { (( ${2-0} <= ${1-0} && ${1-0} <= ${3-0} )); }

# patterns (bash regex/glob only; still pure)
matches()           { [[ ${1-} =~ ${2-} ]]; }
matches_glob()      { [[ ${1-} == ${2-} ]]; }  # e.g., 'ab*cd'

# sets (strings)
in_set()            { local x=${1-}; shift; local a; for a in "$@"; do [[ $x == "$a" ]] && return 0; done; return 1; }
not_in_set()        { ! in_set "$@"; }

  
# combinators (predicate names as args)
notp()              { local p=$1; shift; "$p" "$@" && return 1 || return 0; }
anyp()              { local p=$1; shift; local v; for v in "$@"; do "$p" "$v" && return 0; done; return 1; }
allp()              { local p=$1; shift; local v; for v in "$@"; do "$p" "$v" || return 1; done; return 0; }

  
 

 . ./enums.sh

is_bool01()         { [[ ${1-} == 0 || ${1-} == 1 ]]; }

 #is_stdin_kind(){ [[ $1 == $STDIN_TTY || $1 == $STDIN_PIPE || $1 == $STDIN_FILE || $1 == $STDIN_UNKNOWN ]]; }

is_stdin_kind(){ local k=$1; [[ $k == $STDIN_TTY || $k == $STDIN_PIPE || $k == $STDIN_FILE || $k == $STDIN_UNKNOWN ]]; }

 

# Safe to echo prompts without corrupting a pipe/file consumer?
# $1=stdin_kind  $2=stdout_is_tty(0|1)
#safe_to_prompt(){ local sk=$1 out_tty=$2; is_bool01 "$out_tty" || return 2; [[ $sk == tty && $out_tty -eq 1 ]]; }
safe_to_prompt(){ local out=$1; is_bool01 "$out" || return 2; (( out )); }  # 0=yes, 1=no, 2=contract
safe_to_prompt(){ local t=$1; [[ $t == 0 || $t == 1 ]] || return 2; (( t )); }
trace_pred(){ local name=$1; shift; local s=0; "$name" "$@" || s=$?; printf 'dec|%s s=%d args="%s"\n' "$name" "$s" "$*" >&2; return $s; }
# $1=want $2=kind $3=ready $4=allow_block $5=allow_empty
should_read_stdin() {
  local w=$1 k=$2 r=$3 b=$4 e=$5
  is_bool01 "$w" && is_bool01 "$r" && is_bool01 "$b" && is_bool01 "$e" || return 2
  is_stdin_kind "$k" || return 2
  (( w )) || return 1
  case $k in
    tty)        (( r || b || e )) ;;
    pipe|file)  (( r || e )) ;;
    *)          return 1 ;;
  esac
}

# $1=file_arg $2=prefer(0|1) $3=kind enum $4=ready(0|1)
prefer_stdin(){
  local f=$1 p=$2 k=$3 r=$4
  is_bool01 "$p" && is_bool01 "$r" && is_stdin_kind "$k" || return 2
  [[ $f == "-" ]] && return 0
  (( p )) || return 1
  case $k in pipe|file) return 0;; tty) (( r )) && return 0 || return 1;; *) return 1;; esac
}



ids_unique() { declare -A s=(); for id in "$@"; do [[ ${s[$id]+x} ]] && return 1; s[$id]=1; done; }













 nonblank()                { [[ -n ${1//[[:space:]]/} ]]; }
is_empty()                { [[ -z ${1-} ]]; }

valid_mode_or_empty()     { [[ -z ${1-} || $1 == literal || $1 == regex ]]; }

# strings vs numbers split
is_nonempty_str()         { [[ -n ${1-} ]]; }
gt0()                     { (( ${1-0} > 0 )); }

args_le()                 { (( ${1-0} <= ${2-0} )); }
args_eq()                 { (( ${1-0} == ${2-0} )); }

is_bool01()               { [[ ${1-} == 0 || ${1-} == 1 ]]; }
matches()                 { [[ ${1-} =~ ${2-} ]]; }
has_ext()                 { [[ ${1-} == *".${2-}" ]]; }  # pick one name and stick with it







 
