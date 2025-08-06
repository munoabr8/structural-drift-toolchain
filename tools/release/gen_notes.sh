TAG="v2025.08.01"
# Previous tag (fallback to repo root if none)
PREV=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -1)

OUT="RELEASE_NOTES-${TAG}.md"

{
  echo "# ${TAG} — Release Notes"
  echo
  echo "**Range:** \`${PREV}..${TAG}\`"
  echo
  echo "## Highlights"
  echo "## Highlights"
git log --no-merges --pretty='- %s' "$PREV..$TAG" | head -n 12 || echo "_none_"
  echo
  echo "## Changes by type"
  for T in feat fix perf refactor docs test chore; do
    echo "### ${T^}"
    git log --no-merges --pretty='* %h %s (%an)' "${PREV}..${TAG}" \
      | grep -i "^* .*${T}:" || echo "_none_"
    echo
  done
  echo "### Other"
  git log --no-merges --pretty='* %h %s (%an)' "${PREV}..${TAG}" \
    | grep -viE ' (feat|fix|perf|refactor|docs|test|chore):' || echo "_none_"
  echo
  echo "## Diffstat"
  git diff --stat "${PREV}..${TAG}"
  echo
  echo "## Areas touched (top-level dirs)"
  git diff --name-only "${PREV}..${TAG}" \
    | awk -F/ 'NF==1{print "(root)"; next}{print $1}' \
    | sort | uniq -c | sort -nr
  echo
  echo "## Churn by folder (adds/removes)"
  git diff --numstat "${PREV}..${TAG}" \
    | awk -F'\t' '{split($3,a,"/"); d=(a[1]?a[1]:"(root)"); add[d]+=$1; del[d]+=$2} \
END{for (d in add) printf "%-20s +%6d  -%6d  (±%6d)\n", d, add[d], del[d], add[d]+del[d]}' \
    | sort -k4,4nr
  echo
  echo "## Contributors"
  git shortlog -sne "${PREV}..${TAG}"
} > "$OUT"

echo "Wrote $OUT"
