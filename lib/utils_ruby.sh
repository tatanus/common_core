#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_ruby.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-09 20:28:40
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-09 20:28:40  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${UTILS_RUBY_SH_LOADED:-}" ]]; then
    declare -g UTILS_RUBY_SH_LOADED=true

    # -----------------------------------------------------------------------------
    # ---------------------------------- RUBY FUNCTIONS ---------------------------
    # -----------------------------------------------------------------------------

    # Function to install Ruby packages from the list or a provided parameter
    function _install_ruby_gems() {
        local gems=("$@")

        # If no parameters are passed, use the default ruby_gems array
        if [[ ${#gems[@]} -eq 0 ]]; then
            if [[ -z "${RUBY_GEMS+x}" ]]; then
                fail "ruby_gems array is not defined."
                return "${_FAIL}"
            fi
            gems=("${RUBY_GEMS[@]}")
        fi

        # Install each gem in the list
        for gem in "${gems[@]}"; do
            info "Installing ${gem}...May take a while, be patient."

            # Install the package using Ruby Gem
            # shellcheck disable=SC2086 # this breaks if you put quotes around ${gem}
            if show_spinner "${PROXY} gem install ${gem} > /dev/null 2>&1"; then
                pass "Successfully installed ${gem}."
            else
                fail "Failed to install ${gem}."
            #    return "$_FAIL"
            fi

            # Verify installation
            # shellcheck disable=SC2086 # this breaks if you put quotes around ${gem}
            if ! gem list -i ${gem} > /dev/null 2>&1; then
                fail "Verification failed: ${gem} is not installed."
            fi
        done

        return "${_PASS}"
    }
fi
