# keep: env-touching only
 
. ./predicates.sh
. ./enums.sh
 

fn_defined()         { declare -F "$1" >/dev/null 2>&1; }      # boolean-valued query (status only)
is_readable()        { [[ -r ${1-} ]]; }                       # boolean-valued query
is_nonempty_file()   { [[ -s ${1-} ]]; }                       # boolean-valued query
path_is_dir()        { [[ -d ${1-} ]]; }
path_is_file()       { [[ -f ${1-} ]]; }


is_tty_stdin()       { [[ -t 0 ]]; }

stdin_ready()        { read -t 0 -N 0; }                       # status conveys readiness

stdin_is_nontty() { [[ ! -t 0 ]]; }   # non-TTY detector
stdin_is_tty()   { [[ -t 0 ]]; }


stdin_is_pipe()  { [[ -p /dev/stdin ]]; }    # named pipe
stdin_is_file()  { [[ -f /dev/stdin ]]; }    # regular file/device (incl. /dev/null)

# readiness (non-blocking)
# Bash ≥4: true if data available without consuming
stdin_has_data_nb() { IFS= read -r -t 0 -N 0; }

# Bash 3 fallback (may consume 1 byte; restore via printf if needed)
stdin_has_data_nb_b3() {
  IFS= read -r -t 0 -n 1 ch || return 1
  printf '%s' "$ch"; cat    # put it back: echo the byte, then the rest
}


file_size()          { stat -c%s -- "$1" 2>/dev/null || stat -f%z -- "$1"; }
file_mtime_epoch()   { stat -c%Y -- "$1" 2>/dev/null || stat -f%m -- "$1"; }
file_mime()          { file -b --mime-type -- "$1"; }
symlink_target()     { readlink -- "$1" 2>/dev/null || readlink "$1"; }

# return status only; do NOT print 1/0
is_git_repo()        { [ -d "$1/.git" ]; }

list_files()         { find "$1" -maxdepth 1 -type f -print; }
list_dirs()          { find "$1" -maxdepth 1 -type d -print; }
list_tree()          { find "$1" -print; }

first_line()         { IFS= read -r line <"$1" && printf '%s' "$line"; }
line_count()         { wc -l <"$1" | tr -d '[:space:]'; }
count_matches()      { grep -c -- "$2" "$1" 2>/dev/null || printf 0; }

dir_size_bytes()     { du -sb -- "$1" 2>/dev/null | awk '{print $1}' \
                       || { du -sk -- "$1" | awk '{print $1*1024}'; }; }

cmd_path()           { command -v -- "$1" >/dev/null 2>&1; }     # status only
env_or_default()     { local n=$1 def=$2; printf '%s' "${!n:-$def}"; }
pid_alive()          { kill -0 "$1" 2>/dev/null; }               # status only

sha256_file()        { command -v sha256sum >/dev/null \
                         && sha256sum -- "$1" | awk '{print $1}' \
                         || shasum -a 256 -- "$1" | awk '{print $1}'; }

# boolean-valued, env-reading, composed with a predicate: OK
query_has_shebang() {
  local file=$1 expected=$2 first
  [[ -f $file && -r $file ]] || { printf 'not readable: %s\n' "$file" >&2; return 1; }
  IFS= read -r first <"$file" || { printf 'cannot read: %s\n' "$file" >&2; return 2; }
  predicate_has_shebang_line "$first" "$expected" || {
    case $? in
      1) printf 'no shebang: <%s>\n' "$first" >&2; return 3 ;;
      2) printf 'shebang mismatch: <%s>\n' "$first" >&2; return 4 ;;
    esac
  }
}


stdin_kind=$(
  stdin_is_tty   && echo "$STDIN_TTY"  || \
  stdin_is_pipe  && echo "$STDIN_PIPE" || \
  stdin_is_file  && echo "$STDIN_FILE" || echo "$STDIN_UNKNOWN"
)
stdout_tty=$([ -t 1 ] && echo 1 || echo 0)
stdin_ready=$({ stdin_has_data_nb && echo 1; } || echo 0)
  


emit_fact(){ declare -F fact >/dev/null && fact "$@"; }  # no-op if trace.sh not loaded

q_stdin_kind(){
  local k
  [[ -t 0 ]] && k=tty || [[ -p /dev/stdin ]] && k=pipe || [[ -f /dev/stdin ]] && k=file || k=unknown
  emit_fact stdin_kind "$k"; printf '%s\n' "$k"
}

q_stdin_ready(){
  case "$(q_stdin_kind)" in
    pipe|file) r=1 ;;
    tty)       IFS= read -r -t 0 _ && r=1 || r=0 ;;
    *)         r=0 ;;
  esac
  emit_fact stdin_ready "$r"; printf '%s\n' "$r"
}

q_stderr_is_tty(){ [ -t 2 ] && printf 1 || printf 0; }


 

fact(){ printf 'fact|%s=%s\n' "$1" "$2" >&2; }   # stderr only


q_stdin_kind2(){


  local k; [[ -t 0 ]] && k=tty || [[ -p /dev/stdin ]] && k=pipe || [[ -f /dev/stdin ]] && k=file || k=unknown
  fact stdin_kind "$k"
  printf '%s\n' "$k"
}

 

q_stdin_ready2() {
  local r
  IFS= read -r -t 0 -N 0 2>/dev/null && r=1 || r=0   # Bash≥4; OK, status-only
  fact stdin_ready "$r"
  printf '%s\n' "$r"
}




  q_stderr_is_tty(){ [ -t 2 ] && echo 1 || echo 0; }
  

q_stdout_is_tty(){ [[ -t 1 ]] && echo 1 || echo 0; }
# readiness (Bash ≥4: -N 0; Bash 3 fallback)
stdin_has_data_nb() {
  IFS= read -r -t 0 -N 0 2>/dev/null || { IFS= read -r -t 0 -n 1 ch || return 1; printf '%s' "$ch"; cat; }
}





# load the query functions (put these in lib/queries/memory.sh)
no_rwx_maps_darwin() { local f=$1; [[ -r $f ]] || return 2; ! grep -qE '\brwx\b' "$f"; }

heap_under_mb_darwin() {
  local f=$1 max=$2; [[ -r $f ]] || return 2
  awk '
    function mb(x,  n,u){u=substr(x,length(x),1); n=substr(x,1,length(x)-1);
      if(u=="G")return n*1024; if(u=="M")return n; if(u=="K")return n/1024; return n/1024 }
    /^REGION TYPE/ {in=1; next}
    in && NF==0 {in=0}
    in && $1=="MALLOC" {
      for(i=NF;i>=1;i--) if($i ~ /^[0-9.]+[GMK]$/){sum+=mb($i); break}
    }
    END{exit !(sum<=max)}
  ' max="$max" "$f"
}


 
