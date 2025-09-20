def lines_to_objs: split("\n") | map(select(length>0) | fromjson? // empty);
def objs: (fromjson? // lines_to_objs)
  | (if type=="array" then . else [.] end)
  | map(select(type=="object"));
def is_iso: (type=="string") and ((try fromdateiso8601 catch null) | type)=="number";
def is_sha40: (type=="string") and test("^[0-9a-f]{40}$");

(objs) as $o
| ($o|length) > 0
and all($o[];
  (
    (.type=="pr_merged")
    and (
      ((.merge_commit_sha|is_sha40) and (.merged_at|is_iso))
      or ((.sha|is_sha40) and (.merged_at|is_iso))
    )
    and ((.pr==null) or ((.pr|type)=="number"))
    and ((.head_sha==null) or (.head_sha|is_sha40))
    and ((.base_branch==null) or ((.base_branch|type)=="string"))
  )
  or
  (
    (.type=="deployment")
    and (.sha|is_sha40)
    and (((.finished_at // .deploy_at)|is_iso))
    and ((.status==null) or (.status|IN("success","failure","cancelled","canceled")))
    and ((.env==null) or ((.env|type)=="string"))
  )
  or
  (
    (.type=="pipeline_started")  and (.sha|is_sha40) and (.started_at|is_iso)
  )
  or
  (
    (.type=="pipeline_finished") and (.sha|is_sha40) and (.finished_at|is_iso)
  )
  or
  (
    (.type=="deploy_started")    and (.sha|is_sha40) and (.started_at|is_iso)
  )
)
