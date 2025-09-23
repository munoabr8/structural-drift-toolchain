([.[] | select(.type=="deployment") | .sha] | unique) as $d
| ([.[] | select(.type=="pr_merged")  | .sha] | unique) as $p
| {missing: ($d - $p)}
