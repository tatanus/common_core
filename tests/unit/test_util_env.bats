#!/usr/bin/env bats
###############################################################################
# test_util_env.bats - Unit tests for lib/utils/util_env.sh
###############################################################################

setup() {
    load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
}

teardown() {
    unset BATS_TEST_ENV_VAR_PRESENT BATS_TEST_ENV_VAR_EMPTY 2> /dev/null || true
}

#===============================================================================
# exists / check
#===============================================================================

@test "env::exists true for defined variable (even when empty)" {
    export BATS_TEST_ENV_VAR_EMPTY=""
    run env::exists "BATS_TEST_ENV_VAR_EMPTY"
    [[ "${status}" -eq 0 ]]
}

@test "env::exists false for undefined variable" {
    unset BATS_TEST_ENV_VAR_NEVER_SET 2> /dev/null || true
    run env::exists "BATS_TEST_ENV_VAR_NEVER_SET"
    [[ "${status}" -ne 0 ]]
}

@test "env::exists fails with no argument" {
    run env::exists ""
    [[ "${status}" -ne 0 ]]
}

@test "env::check false when variable defined but empty" {
    export BATS_TEST_ENV_VAR_EMPTY=""
    run env::check "BATS_TEST_ENV_VAR_EMPTY"
    [[ "${status}" -ne 0 ]]
}

@test "env::check true when variable defined and non-empty" {
    export BATS_TEST_ENV_VAR_PRESENT="value"
    run env::check "BATS_TEST_ENV_VAR_PRESENT"
    [[ "${status}" -eq 0 ]]
}

#===============================================================================
# get / set / unset
#===============================================================================

@test "env::get returns value of defined variable" {
    export BATS_TEST_ENV_VAR_PRESENT="hello"
    run env::get "BATS_TEST_ENV_VAR_PRESENT"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "hello" ]]
}

@test "env::get returns default when variable undefined" {
    unset BATS_TEST_ENV_VAR_NEVER_SET 2> /dev/null || true
    run env::get "BATS_TEST_ENV_VAR_NEVER_SET" "fallback"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "fallback" ]]
}

@test "env::set exports variable visible to caller" {
    env::set "BATS_TEST_ENV_VAR_PRESENT" "world" > /dev/null
    [[ "${BATS_TEST_ENV_VAR_PRESENT}" == "world" ]]
}

@test "env::unset removes variable" {
    export BATS_TEST_ENV_VAR_PRESENT="x"
    env::unset "BATS_TEST_ENV_VAR_PRESENT" > /dev/null
    [[ -z "${BATS_TEST_ENV_VAR_PRESENT:-}" ]]
    [[ ! -v BATS_TEST_ENV_VAR_PRESENT ]]
}

#===============================================================================
# Identity / runtime
#===============================================================================

@test "env::get_user returns non-empty string" {
    run env::get_user
    [[ "${status}" -eq 0 ]]
    [[ -n "${output}" ]]
}

@test "env::get_home returns existing directory" {
    run env::get_home
    [[ "${status}" -eq 0 ]]
    [[ -d "${output}" ]]
}

@test "env::get_temp_dir returns existing directory" {
    run env::get_temp_dir
    [[ "${status}" -eq 0 ]]
    [[ -d "${output}" ]]
}

@test "env::is_ci respects CI=true" {
    CI=true run env::is_ci
    [[ "${status}" -eq 0 ]]
}

@test "env::is_ci false when no CI vars set" {
    local rc=0
    (
        unset CI GITHUB_ACTIONS GITLAB_CI JENKINS_HOME CIRCLECI TRAVIS 2> /dev/null
        env::is_ci
    ) || rc=$?
    [[ "${rc}" -ne 0 ]]
}

#===============================================================================
# XDG
#===============================================================================

@test "env::get_xdg_config_home falls back to ~/.config when unset" {
    (unset XDG_CONFIG_HOME 2> /dev/null
        out=$(env::get_xdg_config_home)
        [[ "${out}" == "${HOME}/.config" ]])
}

@test "env::get_xdg_config_home returns XDG_CONFIG_HOME when set" {
    XDG_CONFIG_HOME="/tmp/xdg_test_config" run env::get_xdg_config_home
    [[ "${output}" == "/tmp/xdg_test_config" ]]
}
