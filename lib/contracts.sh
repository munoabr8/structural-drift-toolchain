
# shellcheck shell=bash 
nonblank() { [[ -n "${1//[[:space:]]/}" ]]; }
is_empty() { [[ -z $1 ]]; }
# shape
valid_mode_or_empty() { [[ -z $1 || $1 == literal || $1 == regex ]]; }
has_fields_between() {                      # Bash 3.2-safe
  local line=$1 min=$2 max=$3 count=1
  while [[ $line == *"|"* ]]; do line=${line#*"|"}; ((count++)); done
  (( count >= min && count <= max ))
}
 


args_le() { (( $1 <= $2 )); }


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

 
  
valid_mode_or_empty() { [[ -z $1 || $1 == literal || $1 == regex ]]; }
_die(){ printf 'contrac2t:%s:%s\n' "$1" "$2" >&2; exit "${3:-99}"; }

 
