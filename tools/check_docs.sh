#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

###############################################################################
# NAME         : check_docs.sh
# DESCRIPTION  : Detect drift between docs/util_*.md and lib/utils/util_*.sh.
#                For each pair, verifies that every same-module symbol
#                (e.g. `apt::foo` in docs/util_apt.md) is actually defined in
#                lib/utils/util_apt.sh.
# AUTHOR       : Adam Compton
# DATE CREATED : 2026-06-25
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly PASS=0
readonly FAIL=1

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

function info() { printf '[INFO] %s\n' "$*"; }
function pass_msg() { printf '%b✓%b %s\n' "${GREEN}" "${NC}" "$*"; }
function error_msg() { printf '%b✗%b %s\n' "${RED}" "${NC}" "$*" >&2; }

###############################################################################
# check_pair
#------------------------------------------------------------------------------
# Purpose  : Diff one doc file against its source file. Reports same-module
#            functions referenced in the doc but not defined in the source.
# Arguments:
#   $1 : Doc file path
#   $2 : Source file path
# Returns  : PASS if in sync, FAIL on drift
###############################################################################
function check_pair() {
    local doc="$1"
    local src="$2"
    local base module doc_fns src_fns missing
    base="$(basename "${doc}" .md)"
    module="${base#util_}"

    doc_fns="$(grep -oE "${module}::[a-zA-Z_]+" "${doc}" 2> /dev/null | sort -u)"
    # A few symbols (e.g. cmd::exists) live in lib/util.sh proper, not in a
    # dedicated module file. Search both locations so docs can reference them.
    src_fns="$(grep -hoE "^function ${module}::[a-zA-Z_]+" "${src}" "${PROJECT_ROOT}/lib/util.sh" 2> /dev/null | awk '{print $2}' | sort -u)"
    missing="$(comm -23 <(printf '%s\n' "${doc_fns}") <(printf '%s\n' "${src_fns}"))"

    if [[ -n "${missing}" ]]; then
        error_msg "Drift in ${doc#"${PROJECT_ROOT}"/}: references functions not in ${src#"${PROJECT_ROOT}"/}:"
        printf '%s\n' "${missing}" | sed 's/^/    - /' >&2
        return "${FAIL}"
    fi
    return "${PASS}"
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Walk every docs/util_*.md and compare to its lib/utils/util_*.sh.
###############################################################################
function main() {
    local doc src base exit_code="${PASS}"

    info "Checking documentation drift..."

    for doc in "${PROJECT_ROOT}/docs/"util_*.md; do
        [[ -f "${doc}" ]] || continue
        base="$(basename "${doc}" .md)"
        src="${PROJECT_ROOT}/lib/utils/${base}.sh"

        if [[ ! -f "${src}" ]]; then
            error_msg "${doc#"${PROJECT_ROOT}"/}: no matching source file (${src#"${PROJECT_ROOT}"/})"
            exit_code="${FAIL}"
            continue
        fi

        if ! check_pair "${doc}" "${src}"; then
            exit_code="${FAIL}"
        fi
    done

    if [[ "${exit_code}" -eq "${PASS}" ]]; then
        pass_msg "All docs in sync with sources"
    else
        error_msg "Documentation drift detected"
    fi

    return "${exit_code}"
}

main "$@"
exit $?
