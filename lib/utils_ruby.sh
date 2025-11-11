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

    ###############################################################################
    # _install_ruby_gems
    #==============================
    # Install Ruby gems from a provided list or from the RUBY_GEMS array.
    #————————————————————
    # Usage:
    # _install_ruby_gems [gem-spec ...]
    #   Each gem-spec may include install options (for example: "nori -v 2.6.0"
    #   or "evil-winrm"). If no args provided, the function uses the
    #   RUBY_GEMS array.
    #
    # Return Values:
    # 0 on success (all gems installed or verified), non-zero otherwise.
    #————————————————————
    # Requirements:
    # - gem (RubyGems) in PATH
    # - Logging helpers: info, pass, fail
    # - Optional helper: show_spinner (if present)
    ###############################################################################
    function _install_ruby_gems() {
        local -a gems=("$@")
        local gem_spec name part ver_found ver_value
        local -a parts args
        local rc=0

        # If no parameters are passed, use the default RUBY_GEMS array
        if ((${#gems[@]} == 0)); then
            if [[ -z "${RUBY_GEMS+x}" ]]; then
                fail "ruby_gems array is not defined."
                return 1
            fi
            gems=("${RUBY_GEMS[@]}")
        fi

        # Ensure gem binary exists
        if ! command -v gem > /dev/null 2>&1; then
            fail "gem binary not found in PATH."
            return 2
        fi

        for gem_spec in "${gems[@]}"; do
            # Split the spec into words so we can separate name from flags
            # shellcheck disable=SC2206
            parts=(${gem_spec})
            name="${parts[0]}"
            args=("${parts[@]:1}")

            # find -v or --version value (if provided) for verification
            ver_found=""
            ver_value=""
            for ((i = 0; i < ${#args[@]}; i++)); do
                if [[ "${args[i]}" == "-v" || "${args[i]}" == "--version" ]]; then
                    ver_found="1"
                    # next element may be the version string
                    if ((i + 1 < ${#args[@]})); then
                        ver_value="${args[i + 1]}"
                    fi
                    break
                fi
            done

            info "Installing ${name} ${args[*]:-}(no extra flags)... This may take a while."

            # If PROXY is set as an env-assignment string (e.g. "http_proxy=..."), honor it.
            if [[ -n "${PROXY:-}" ]]; then
                if type show_spinner > /dev/null 2>&1; then
                    if show_spinner env "${PROXY}" gem install --no-document "${name}" "${args[@]}"; then
                        pass "Installed ${name}."
                    else
                        fail "Failed to install ${name} (with PROXY)."
                        rc=3
                    fi
                else
                    if env "${PROXY}" gem install --no-document "${name}" "${args[@]}"; then
                        pass "Installed ${name}."
                    else
                        fail "Failed to install ${name} (with PROXY)."
                        rc=3
                    fi
                fi
            else
                if type show_spinner > /dev/null 2>&1; then
                    if show_spinner gem install --no-document "${name}" "${args[@]}"; then
                        pass "Installed ${name}."
                    else
                        fail "Failed to install ${name}."
                        rc=3
                    fi
                else
                    if gem install --no-document "${name}" "${args[@]}"; then
                        pass "Installed ${name}."
                    else
                        fail "Failed to install ${name}."
                        rc=3
                    fi
                fi
            fi

            # Verification: use version-aware check when a -v/--version was supplied
            if [[ -n "${ver_found}" && -n "${ver_value}" ]]; then
                if gem list -i "${name}" -v "${ver_value}" > /dev/null 2>&1; then
                    pass "Verification OK: ${name} (${ver_value})."
                else
                    fail "Verification failed: ${name} (${ver_value}) not found."
                    rc=4
                fi
            else
                if gem list -i "${name}" > /dev/null 2>&1; then
                    pass "Verification OK: ${name}."
                else
                    fail "Verification failed: ${name} not found."
                    rc=4
                fi
            fi
        done

        return "${rc}"
    }
fi
