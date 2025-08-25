#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SNAPSHOT_GEN="${SNAPSHOT_GEN:-$REPO_ROOT/structure/structure_snapshot_gen.rf.sh}"

  TMPROOT="$(mktemp -d)"
  cd "$TMPROOT"

  # stub logging expected by the script
  mkdir -p util
  cat > util/source_or_fail.sh <<'SH'
source_or_fail() { [ -f "$1" ] && . "$1" || return 0; }
SH
  cat > util/logger.sh <<'SH'
log_json() { :; }
SH
  cat > util/logger_wrapper.sh <<'SH'
safe_log() { :; }
SH

  # test fixtures
  mkdir -p a b evidence/sub
  touch keep.dat evidence.txt b/keep2.log evidence/sub/inner.dat
  printf '%s\n' 'evidence' '.txt' > .structure.ignore
}


# @test ".structure.ignore NOT applied by legacy script" {
#   run bash "$SNAPSHOT_GEN" generate_structure_snapshot .

#   # Script runs "successfully"
#   [ "$status" -eq 0 ]

#   # Failure we want to demonstrate: ignored entries still appear

#   [[ "$output" == *"dir: "*"evidence/"* ]]   # directory under ignore pattern "evidence"
# }


@test "pre: .structure.ignore must contain 'evidence'" {

  printf '%s\n' 'evidence' > .structure.ignore

  run env ASSERT=1 ASSERT_IGNORE_EXPECT=evidence bash "$SNAPSHOT_GEN" --root .
    [ "$status" -eq 0 ]
}

@test "pre: missing expected line fails" {

  printf '%s\n' '.txt' > .structure.ignore
  run env ASSERT=1 ASSERT_IGNORE_EXPECT=evidence bash "$SNAPSHOT_GEN" --root .


  [ "$status" -ne 0 ]
}

