#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_apt.sh
# DESCRIPTION : Utility functions for managing apt packages.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 20:11:12
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 20:11:12  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${UTILS_APT_SH_LOADED:-}" ]]; then
    declare -g UTILS_APT_SH_LOADED=true

    # -----------------------------------------------------------------------------
    # ---------------------------------- APT-GET FUNCTIONS ------------------------
    # -----------------------------------------------------------------------------

    # Install a package using apt if it's not already installed
    function _apt_install_missing_dependencies() {
        info "Installing Missing Dependencies via apt..."

        if ${PROXY} sudo apt update -qq > /dev/null 2>&1 && ${PROXY} sudo apt install -y -f > /dev/null 2>&1; then
            pass "Installed missing dependencies using apt."
            return "${PASS}"
        else
            fail "Could not install missing dependencies using apt."
            return "${FAIL}"
        fi
    }

    # Install a package using apt if it's not already installed
    function _apt_install() {
        local package="$1"

        # Verify that package name is not empty
        if [[ -z "${package}" ]]; then
            fail "Package name cannot be empty."
            return "${FAIL}"
        fi

        # Check if the package is already installed
        if ! dpkg -s "${package}" > /dev/null 2>&1; then
            info "Installing ${package} using apt..."
            if { ${PROXY} sudo apt update -qq > /dev/null 2>&1 && ${PROXY} sudo apt install -y "${package}" > /dev/null 2>&1; }; then

                pass "Installed ${package} using apt."
                return "${PASS}"
            else
                fail "Could not install ${package} using apt."
                return "${FAIL}"
            fi
        else
            pass "${package} is already installed."
            return "${PASS}"
        fi
    }

    # Install all missing apt packages from the apt_packages array
    function _install_missing_apt_packages() {
        # Ensure the apt_packages array is defined
        if [[ -z "${APT_PACKAGES+x}" ]]; then
            fail "APT_PACKAGES array is not defined."
            return "${FAIL}"
        fi

        # Check if the array is empty
        if [[ "${#APT_PACKAGES[@]}" -eq 0 ]]; then
            fail "APT_PACKAGES array is empty."
            return "${FAIL}"
        fi

        local apt_packages_valid=()
        local skipped_packages=()

        # Validate each package and add to the valid list if it exists
        for package in "${APT_PACKAGES[@]}"; do
            # Get policy information for the package
            local policy_output
            policy_output=$(apt-cache policy "${package}" 2> /dev/null)

            # Check if package exists in apt cache
            if [[ -z "${policy_output}" ]]; then
                info "${package} does not exist in apt cache and will be skipped."
                skipped_packages+=("${package}")
                continue
            fi

            # Check if package has an installable candidate
            local candidate
            candidate=$(echo "${policy_output}" | awk '/Candidate:/ {print $2}')

            if [[ -z "${candidate}" || "${candidate}" == "(none)" ]]; then
                info "${package} has no installable candidate and will be skipped."
                skipped_packages+=("${package}")
                continue
            fi

            # Passed all checks
            apt_packages_valid+=("${package}")
        done

        # Summarize skipped packages
        if [[ "${#skipped_packages[@]}" -gt 0 ]]; then
            info "Skipped packages: ${skipped_packages[*]}"
        fi

        # Check if there are valid packages to install
        if [[ "${#apt_packages_valid[@]}" -eq 0 ]]; then
            info "No valid packages to install."
            return 0
        fi

        # Install valid packages
        info "Installing packages: ${apt_packages_valid[*]}"

        # Build and execute the install command
        local install_result
        if [[ -n "${PROXY}" ]]; then
            # With proxy
            if ! show_spinner ${PROXY} apt -qq -y install "${apt_packages_valid[@]}"; then
                fail "Failed to install one or more packages."
                return "${FAIL}"
            fi
        else
            # Without proxy
            if ! show_spinner apt -qq -y install "${apt_packages_valid[@]}"; then
                fail "Failed to install one or more packages."
                return "${FAIL}"
            fi
        fi

        # Verify that each package is properly installed
        local overall_status=0
        for package in "${apt_packages_valid[@]}"; do
            if ! dpkg -s "${package}" > /dev/null 2>&1; then
                fail "${package} is not installed."
                overall_status=1
            else
                pass "${package} is installed."
            fi
        done

        return "${overall_status}"
    }
    # Perform a full apt update, autoremove, clean, and upgrade
    function _apt_update() {
        # Update package list
        if ! show_spinner "${PROXY} apt -qq -y update --fix-missing > /dev/null 2>&1"; then
            fail "Failed to update package list."
            return "${FAIL}"
        fi
        _wait_pid
        pass "Package list updated successfully."

        # Remove unnecessary packages
        if ! show_spinner "${PROXY} apt -qq -y autoremove > /dev/null 2>&1"; then
            fail "Failed to remove unnecessary packages."
            return "${FAIL}"
        fi
        _wait_pid
        pass "Unnecessary packages removed successfully."

        # Clean up the package cache
        if ! show_spinner "${PROXY} apt -qq -y clean > /dev/null 2>&1"; then
            fail "Failed to clean package cache."
            return "${FAIL}"
        fi
        _wait_pid
        pass "Package cache cleaned successfully."

        # Upgrade installed packages
        if ! show_spinner "${PROXY} apt -qq -y upgrade > /dev/null 2>&1"; then
            fail "Failed to upgrade packages."
            return "${FAIL}"
        fi
        _wait_pid
        pass "Packages upgraded successfully."

        return "${PASS}"
    }
fi
