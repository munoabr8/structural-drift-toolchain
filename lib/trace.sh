fact(){ printf 'FACT|%s=%s\n' "$1" "$2" >&2; }
dec(){  printf 'DEC|%s status=%d args="%s"\n' "$1" "$2" "$3" >&2; }
