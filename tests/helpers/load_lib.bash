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

# shellcheck source=/dev/null
source "${COMMON_CORE_ROOT}/lib/util.sh"
