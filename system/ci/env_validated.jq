
{
  schema:"ci/env.validated.v1",
  ts:$ts,
  env:$env,
  repo:$repo,
  branch:$branch,
  events:$events,
  keys: ($sch[0].keys | keys)
}