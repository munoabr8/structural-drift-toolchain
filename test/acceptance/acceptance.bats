@test "empty log fails" {
  run ./test/acceptance/env_from_probe.sh --log /dev/null --keys USER -- true
  [ "$status" -ne 0 ]

}



@test "empty log fails2" {
  empty="$(mktemp)"; : > "$empty"
  run ./test/acceptance/env_from_probe.sh --log "$empty" --keys USER -- true
  [ "$status" -ne 0 ]
  [[ "$output" == *"probe log empty"* || "$stderr" == *"probe log empty"* ]]
  rm -f "$empty"
}
