#!/usr/bin/env bats

setup() {
  mkdir -p tmp/testcase/logs
  touch tmp/testcase/logs/logfile.log
  cd tmp/testcase
}

teardown() {
  cd ../..
  rm -rf tmp/testcase
}

@test "Fallback raw path resolves correctly to existing file" {
  echo "./logs/logfile.log" > structure.spec

  echo "📂 Current dir: $(pwd)"
  echo "📄 structure.spec content:"
  cat structure.spec

  echo "📁 logs contents:"
  ls -l logs

  run bash ../../system/validate_structure.sh structure.spec

  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ File OK: ./logs/logfile.log" ]]
  [[ "$output" =~ "🎉 Structure validation passed" ]]
}
