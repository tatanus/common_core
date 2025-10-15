#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_golang.sh
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
if [[ -z "${UTILS_GOLANG_SH_LOADED:-}" ]]; then
    declare -g UTILS_GOLANG_SH_LOADED=true

    # -----------------------------------------------------------------------------
    # ---------------------------------- GO FUNCTIONS -----------------------------
    # -----------------------------------------------------------------------------

    # Function to install and verify installation of Golang
    function _install_go() {
        # Navigate to /tmp directory for temporary file operations
        if _pushd /tmp; then
            info "Successfully changed directory to /tmp."
        else
            fail "Failed to change directory to /tmp."
            return "${FAIL}"
        fi

        # Check if Golang is already installed and purge it if present
        if apt list --installed 2> /dev/null | grep -q '^golang/'; then
            if ! sudo apt purge -y golang; then
                fail "Failed to purge existing Golang installation."
                _popd
                return "${FAIL}"
            fi
        fi

        # Retrieve the URL of the latest Golang tarball from the official site
        local go_version_url arch
        arch=$(_get_arch)
        go_version_url=$(${PROXY} curl -sL https://golang.org/dl/ | grep -oP "go[0-9\.]+\.linux-${arch}\.tar\.gz" | head -n 1)

        # Check if the Golang version URL was successfully retrieved
        if [[ -z "${go_version_url}" ]]; then
            fail "Failed to determine the latest Golang version."
            _popd
            return "${FAIL}"
        fi

        # Download the Golang tarball
        if ! ${PROXY} wget --no-check-certificate "https://golang.org/dl/${go_version_url}"; then
            fail "Failed to download Golang tarball."
            _popd
            return "${FAIL}"
        fi

        # Remove any existing Golang installation from /usr/local
        rm -rf /usr/local/go

        # Extract the downloaded Golang tarball to /usr/local
        if ! tar -C /usr/local -xzf "${go_version_url}"; then
            fail "Failed to install Golang."
            rm -f "${go_version_url}"  # Cleanup tarball if extraction fails
            _popd
            return "${FAIL}"
        fi

        # Clean up the downloaded tarball
        rm -f "${go_version_url}"

        # Add Golang binary path to the current session's PATH
        #export PATH=$PATH:/usr/local/go/bin
        source "${BASH_DIR}/bash.path.sh"

        # Verify that the Go command is available and print its version
        if command -v go > /dev/null 2>&1; then
            local go_version_installed
            go_version_installed=$(go version)
            pass "Golang installed successfully: ${go_version_installed}"
        else
            fail "Golang installation failed. The 'go' command is not available."
            _popd
            return "${FAIL}"
        fi

        # Return to the previous directory
        _popd
        return "${PASS}"
    }

    # Function to install Go packages from the list or provided parameter
    function _install_go_tools() {
        local tools=("$@")

        # If no parameters are passed, use the default go_tools array
        if [[ ${#tools[@]} -eq 0 ]]; then
            if [[ -z "${GO_TOOLS+x}" ]]; then
                fail "go_tools array is not defined."
                return "${FAIL}"
            fi
            tools=("${GO_TOOLS[@]}")
        fi

        # Install each tool in the list
        for tool in "${tools[@]}"; do
            info "Installing ${tool}...May take a while, be patient."

            # Install the package using Go
            if show_spinner "${PROXY} go install ${tool} > /dev/null 2>&1"; then
                pass "Successfully installed ${tool}."
            else
                fail "Failed to install ${tool}."
                #return "$FAIL"
            fi

            # Verify installation
            # Extract the base name of the tool and remove anything after "@"
            local tool_name
            tool_name=$(basename "${tool}" | cut -d '@' -f 1)

            if ! command -v "${tool_name}" > /dev/null 2>&1; then
                fail "Verification failed: ${tool_name} is not installed."
            fi
        done

        return "${PASS}"
    }
fi
