[ .[] | select(type=="object") ] as $objs

 | ( $objs
    | [ .[] | select(.type=="deployment" and (.sha|type=="string")) | .sha ]
    | unique
  ) as $d

 | ( $objs
    | [ .[] | select(.type=="pr_merged" and (.sha|type=="string"))
        | {pr,sha,merged_at}
      ]
  ) as $p

 | {
    counts:  { pr_ok: ($p|length), dep_ok: ($d|length) },
    missing: [ $p[] | select( ($d | index(.sha)) == null ) ]
  }