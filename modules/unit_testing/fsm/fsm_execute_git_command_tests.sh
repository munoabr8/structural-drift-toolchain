#!/usr/bin/env bats
    
setup() {
 
    
    script_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    source "$script_dir/fsm_git_handler.sh"
    export json_object="$(pwd)/truths_fsm_handler.json"
    
    MOCK_BIN="${BATS_TEST_DIR:-$PWD/mock_bin}"
    mkdir -p "$MOCK_BIN"

    echo -e '#!/bin/bash\necho "Mock git command"; exit 0' > "$MOCK_BIN/git"
    chmod +x "$MOCK_BIN/git"

    alias git="$MOCK_BIN/git"

    echo "$git"

    PATH="$MOCK_BIN:$PATH"

}
    
    @test "1. mock git command" {
    run execute_git_command clone
    [ "$output" = "Mock git command" ]


    }