# shellcheck shell=bash
strip_case_labels() { awk '
  BEGIN{c=0}
  /^[[:space:]]*case[[:space:]]/{c=1}
  /^[[:space:]]*esac([[:space:];]|$)/{c=0}
  { if(c) sub(/^[[:space:]]*[^)]*\)[[:space:]]*/,""); print }'
}
strip_comments() { sed -E 's/[[:space:]]+#.*$//'; }

tok_grep() { grep -nE '(^|[;&|(){}[:space:]])('"$1"')([[:space:]]|$)'; }  # usage: tok_grep 'cmd1|cmd2'



 