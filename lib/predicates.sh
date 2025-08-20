 # predicates are closed off to the enviorment. 

nonblank() { [[ -n "${1//[[:space:]]/}" ]]; }
is_empty() { [[ -z $1 ]]; }
# shape
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

# booleans
is_bool01()         { [[ ${1-} == 0 || ${1-} == 1 ]]; }

# combinators (predicate names as args)
notp()              { local p=$1; shift; "$p" "$@" && return 1 || return 0; }
anyp()              { local p=$1; shift; local v; for v in "$@"; do "$p" "$v" && return 0; done; return 1; }
allp()              { local p=$1; shift; local v; for v in "$@"; do "$p" "$v" || return 1; done; return 0; }

  
 








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

 
