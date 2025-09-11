#!/usr/bin/env bats

load 'test_helper/bats-support/load' 2>/dev/null || true
load 'test_helper/bats-assert/load'  2>/dev/null || true

setup() {
  # Ensure we can source logging
  source lib/logging.sh
}

@test "info logs with expected prefix" {
  run bash -lc 'source lib/logging.sh; info "hello world"'
  [[ "$output" == *"[* INFO  ] hello world"* ]]
  [ "$status" -eq 0 ]
}

@test "fail returns non-zero" {
  run bash -lc 'source lib/logging.sh; fail "something broke"'
  [ "$status" -ne 0 ]
}
