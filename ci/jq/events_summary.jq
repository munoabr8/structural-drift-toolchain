def lines_to_objs: split("\n") | map(select(length>0) | fromjson? // empty);
def objs: (fromjson? // lines_to_objs)
  | (if type=="array" then . else [.] end)
  | map(select(type=="object"));
def is_iso: (type=="string") and ((try fromdateiso8601 catch null) | type)=="number";

# ---------- load + normalize ----------
(objs) as $all
| ($all
   # normalize PRs missing merge_commit_sha
   | map(if .type=="pr_merged" and .merge_commit_sha==null and (.sha|type)=="string"
         then .merge_commit_sha=.sha | del(.sha) else . end)
   # dedupe records conservatively across common keys
   | unique_by([.type,
                (.merge_commit_sha // .sha // ""),
                (.merged_at // .finished_at // .deploy_at // ""),
                (.status // ""), (.env // "")])
  ) as $norm

# ---------- counts by type ----------
| ($norm
   | group_by(.type)
   | map({(.[0].type // "null"): length})
   | add // {}
  ) as $by_type

# ---------- schemas present ----------
| ($norm
   | map(.schema // "none")
   | group_by(.)
   | map({(.[0]): length})
   | add // {}
  ) as $schemas

# ---------- PR and deploy sets ----------
| ($norm | map(select(.type=="pr_merged") | .merge_commit_sha) | unique) as $prs
| ($norm | map(select(.type=="deployment") | .sha) | unique)             as $deps

# ---------- matching ----------
| ($prs - ($prs - $deps)) as $matched
| ($prs - $deps)          as $unmatched_pr
| ($deps - $prs)          as $unmatched_dep

# ---------- duplicate estimate (pre-dedupe vs post) ----------
| ($all  | length) as $total_all
| ($norm | length) as $uniq
| ($total_all - $uniq) as $dups

# ---------- histograms (use {key,value} so from_entries emits ints) ----------
| ($norm
   | map(select(.type=="pr_merged") | .merged_at)
   | map(select(is_iso)) | map(.[:10])
   | group_by(.)
   | map({key:.[0], value:length})
   | from_entries
  ) as $pr_per_day
| ($norm
   | map(select(.type=="deployment") | (.finished_at // .deploy_at))
   | map(select(is_iso)) | map(.[:10])
   | group_by(.)
   | map({key:.[0], value:length})
   | from_entries
  ) as $dep_per_day

# ---------- recent sample (last 5) ----------
| ($norm
   | map(. + {ts:(.merged_at // .finished_at // .deploy_at)})
   | map(select(.ts|is_iso))
   | sort_by(.ts) | reverse | .[:5]
  ) as $recent

# ---------- output + coalesce + KPIs ----------
| {
    totals: { all:$total_all, unique:$uniq, duplicates:$dups },
    by_type: $by_type,
    schemas: $schemas,
    matches: {
      prs: ($prs|length),
      deployments: ($deps|length),
      matched: ($matched|length),
      unmatched_pr: ($unmatched_pr|length),
      unmatched_deploy: ($unmatched_dep|length)
    },
    per_day: { pr_merged:$pr_per_day, deployments:$dep_per_day },
    recent: $recent
  }
| .per_day.pr_merged   |= with_entries(.value |= (. // 0))
| .per_day.deployments |= with_entries(.value |= (. // 0))
| .kpi = {
    pr_to_deploy_ratio: ((.by_type.pr_merged // 0) / ((.by_type.deployment // 0) + 1)),
    match_rate:         ((.matches.matched // 0) / ((.matches.prs // 0) + 1)),
    unmatched_pr:        (.matches.unmatched_pr // 0)

}