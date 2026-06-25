#!/usr/bin/env bash
###############################################################################
# NAME         : load_lib.bash
# DESCRIPTION  : BATS helper - sources lib/util.sh with logging silenced so
#                util_*.sh functions are available in test cases.
# AUTHOR       : Adam Compton
# DATE CREATED : 2026-06-25
###############################################################################
# USAGE (in a .bats file):
#   load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
###############################################################################

# Resolve project root from this helper's location:
# tests/helpers/load_lib.bash -> ../../
COMMON_CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMMON_CORE_ROOT

# Silence util.sh's startup chatter (warn is the default; force error so even
# warn messages stay out of bats output).
export UTIL_LOG_LEVEL="error"

# Pre-declare logging functions as no-ops so util.sh's fallback definitions
# (which return non-zero when filtered by log level) don't propagate failures
# under bats's `set -e`. Sourced functions inherit caller errexit semantics,
# and the lib's fallback `pass`/`fail` short-circuit via `&&` — that returns 1
# when filtered, which trips set -e in test bodies.
function info()  { :; }
function warn()  { :; }
function error() { :; }
function debug() { :; }
function pass()  { :; }
function fail()  { :; }

# shellcheck source=/dev/null
source "${COMMON_CORE_ROOT}/lib/util.sh"
