. as $a
| ([ $a[] | type ] | all(. == "object")) as $all_objs
| ($a | map(select(type == "object"))) as $o
| $all_objs
  and ($o | length) > 0
  and all($o[]; (
      (.type == "pr_merged")
      and ((.pr | type) == "number")
      and ((.sha | type) == "string") and ((.sha | length) > 0)
      and ((.merged_at | type) == "string")
      and (((.merged_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime | type) == "number"))
    ) or (
      (.type == "deployment")
      and ((.sha | type) == "string") and ((.sha | length) > 0)
      and ((.finished_at | type) == "string")
      and (((.finished_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime | type) == "number"))
    )
  )
