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
    # Accepts RUBY_GEMS entries written as quoted strings, e.g.:
    #   RUBY_GEMS=( "nori -v 2.6.0" "evil-winrm" )
    #————————————————————
    # Usage:
    # _install_ruby_gems [gem-spec ...]
    #
    # Return Values:
    # 0 = all OK
    # 1 = one or more install/verify failures
    # 2 = gem binary missing
    # 3 = RUBY_GEMS missing
    ###############################################################################
    function _install_ruby_gems() {
        local -a gems=("$@")
        local gem_spec name args parts
        local ver_value ver_found rc=0
        local proxy_env cmd_ok

        # If no parameters are passed, use the default RUBY_GEMS array
        if ((${#gems[@]} == 0)); then
            if [[ -z "${RUBY_GEMS+x}" ]]; then
                fail "RUBY_GEMS array is not defined."
                return 3
            fi
            gems=("${RUBY_GEMS[@]}")
        fi

        # Ensure gem binary exists
        if ! command -v gem > /dev/null 2>&1; then
            fail "gem binary not found in PATH."
            return 2
        fi

        for gem_spec in "${gems[@]}"; do
            # Safely split the spec string into words (preserves quoted words inside spec if present)
            # Example: "nori -v 2.6.0" -> parts=(nori -v 2.6.0)
            IFS=' ' read -r -a parts <<< "${gem_spec}"

            name="${parts[0]}"
            args=("${parts[@]:1}")

            # Detect version flags in multiple forms:
            # -v 2.6.0   -> args contains "-v" then "2.6.0"
            # -v2.6.0    -> args contains "-v2.6.0"
            # --version=2.6.0
            ver_found=""
            ver_value=""
            for ((i = 0; i < ${#args[@]}; i++)); do
                local a="${args[i]}"
                if [[ "${a}" == "-v" || "${a}" == "--version" ]]; then
                    ver_found=1
                    if ((i + 1 < ${#args[@]})); then
                        ver_value="${args[i + 1]}"
                    fi
                    break
                elif [[ "${a}" == -v* && "${a}" != "-v" ]]; then
                    # -v2.6.0
                    ver_found=1
                    ver_value="${a:2}"
                    break
                elif [[ "${a}" == --version=* ]]; then
                    ver_found=1
                    ver_value="${a#*=}"
                    break
                fi
            done

            info "Installing ${name} ${args[*]:-}(no extra flags)... This may take a while."

            # Build install command wrapper depending on PROXY format
            # If PROXY looks like "VAR=value" (contains '='), use env $PROXY ...
            # Otherwise treat PROXY as a URL and export http_proxy/https_proxy for the install.
            if [[ -n "${PROXY:-}" ]]; then
                if [[ "${PROXY}" == *"="* ]]; then
                    proxy_env=("env" "${PROXY}")
                else
                    proxy_env=("env" "http_proxy=${PROXY}" "https_proxy=${PROXY}")
                fi
            else
                proxy_env=()
            fi

            # Run install (use show_spinner if available)
            if type show_spinner > /dev/null 2>&1; then
                if "${proxy_env[@]}" gem install --no-document "${name}" "${args[@]}"; then
                    cmd_ok=0
                    pass "Installed ${name}."
                else
                    cmd_ok=1
                    fail "Failed to install ${name}."
                fi
            else
                if "${proxy_env[@]}" gem install --no-document "${name}" "${args[@]}"; then
                    cmd_ok=0
                    pass "Installed ${name}."
                else
                    cmd_ok=1
                    fail "Failed to install ${name}."
                fi
            fi

            # Verification
            if ((cmd_ok == 0)); then
                if [[ -n "${ver_found}" && -n "${ver_value}" ]]; then
                    if gem list -i --version "${ver_value}" "${name}" > /dev/null 2>&1; then
                        pass "Verification OK: ${name} (${ver_value})."
                    else
                        fail "Verification failed: ${name} (${ver_value}) not found."
                        ((rc++))
                    fi
                else
                    if gem list -i "${name}" > /dev/null 2>&1; then
                        pass "Verification OK: ${name}."
                    else
                        fail "Verification failed: ${name} not found."
                        ((rc++))
                    fi
                fi
            else
                # install failed: count as one failure (verification skipped)
                ((rc++))
            fi
        done

        if ((rc > 0)); then
            fail "One or more Ruby gems failed to install or verify (${rc} failures)."
            return 1
        fi

        pass "All Ruby gems installed and verified successfully."
        return 0
    }
fi
