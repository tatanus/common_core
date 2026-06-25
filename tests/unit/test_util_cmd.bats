#!/usr/bin/env bats
###############################################################################
# test_util_cmd.bats - Unit tests for lib/utils/util_cmd.sh (+ cmd::exists
# which lives in lib/util.sh).
###############################################################################

setup() {
    load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
}

#===============================================================================
# cmd::exists (defined in lib/util.sh)
#===============================================================================

@test "cmd::exists true for ubiquitous command (bash)" {
    run cmd::exists "bash"
    [[ "${status}" -eq 0 ]]
}

@test "cmd::exists false for nonsense command" {
    run cmd::exists "this_command_definitely_does_not_exist_42"
    [[ "${status}" -ne 0 ]]
}

@test "cmd::exists false with empty argument" {
    run cmd::exists ""
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# cmd::build
#===============================================================================

@test "cmd::build populates array via nameref" {
    local -a built=()
    cmd::build built echo "hello" "world"
    [[ "${#built[@]}" -eq 3 ]]
    [[ "${built[0]}" == "echo" ]]
    [[ "${built[1]}" == "hello" ]]
    [[ "${built[2]}" == "world" ]]
}

@test "cmd::build fails with empty array name" {
    run cmd::build "" echo hi
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# cmd::run / cmd::run_silent
#===============================================================================

@test "cmd::run succeeds for true" {
    run cmd::run true
    [[ "${status}" -eq 0 ]]
}

@test "cmd::run fails for false" {
    run cmd::run false
    [[ "${status}" -ne 0 ]]
}

@test "cmd::run fails with no arguments" {
    run cmd::run
    [[ "${status}" -ne 0 ]]
}

@test "cmd::run_silent succeeds for true" {
    run cmd::run_silent true
    [[ "${status}" -eq 0 ]]
}

@test "cmd::run_silent fails for false" {
    run cmd::run_silent false
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# cmd::run_with_env
#===============================================================================

@test "cmd::run_with_env passes env var to command" {
    run cmd::run_with_env "FOO=bar" -- bash -c 'printf %s "${FOO}"'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"bar"* ]]
}

@test "cmd::run_with_env fails with no command after --" {
    run cmd::run_with_env "FOO=bar" --
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# cmd::timeout (only if timeout binary is available)
#===============================================================================

@test "cmd::timeout returns timeout exit code on long command" {
    if ! command -v timeout > /dev/null 2>&1 && ! command -v gtimeout > /dev/null 2>&1; then
        skip "timeout(1) not installed"
    fi
    run cmd::timeout 1 sleep 5
    [[ "${status}" -ne 0 ]]
}

@test "cmd::timeout succeeds on fast command" {
    if ! command -v timeout > /dev/null 2>&1 && ! command -v gtimeout > /dev/null 2>&1; then
        skip "timeout(1) not installed"
    fi
    run cmd::timeout 5 true
    [[ "${status}" -eq 0 ]]
}

#===============================================================================
# cmd::retry
#===============================================================================

@test "cmd::retry succeeds on first try" {
    run cmd::retry 3 1 true
    [[ "${status}" -eq 0 ]]
}

@test "cmd::retry fails after exhausting retries" {
    run cmd::retry 2 0 false
    [[ "${status}" -ne 0 ]]
}
