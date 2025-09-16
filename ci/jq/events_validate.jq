def lines_to_objs: split("\n") | map(fromjson? // empty);
def objs: (fromjson? // lines_to_objs)
  | (if type=="array" then . else [.] end)
  | map(select(type=="object"));
def is_iso: (type=="string") and ((fromdateiso8601? | type)=="number");

(objs) as $o
| ($o|length) > 0
  and all($o[]; (
      # PR merged
      (.type=="pr_merged")
      and ((.sha|type)=="string" and (.sha|length)>0)
      and ((.merged_at|is_iso))
      and ((.pr==null) or ((.pr|type)=="number"))
    ) or (
      # Deployment finished
      (.type=="deployment")
      and ((.sha|type)=="string" and (.sha|length)>0)
      and (((.finished_at // .deploy_at)|is_iso))
    ) or (
      # Pipeline started
      (.type=="pipeline_started")
      and ((.sha|type)=="string" and (.sha|length)>0)
      and ((.started_at|is_iso))
    ) or (
      # Pipeline finished
      (.type=="pipeline_finished")
      and ((.sha|type)=="string" and (.sha|length)>0)
      and ((.finished_at|is_iso))
    ) or (
      # Deploy started (optional)
      (.type=="deploy_started")
      and ((.sha|type)=="string" and (.sha|length)>0)
      and ((.started_at|is_iso))
    )
  )
