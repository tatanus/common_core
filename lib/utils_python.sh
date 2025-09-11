#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_python.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-09 20:51:59
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-09 20:51:59  | Adam Compton | Initial creation.
# 2025-07-08           | Adam COmpton      | Improved multi-version support, pipx logic.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${UTILS_PYTHON_SH_LOADED:-}" ]]; then
    declare -g UTILS_PYTHON_SH_LOADED=true

    ###############################################################################
    # _Find_Latest_Python
    #==============================
    # Determines the latest Python version from the PYTHON_VERSIONS list.
    # This does NOT scan binaries on disk.
    #
    # Usage:
    #   latest=$(_Find_Latest_Python)
    #
    # Returns:
    #   Prints the highest version string (e.g. "3.13")
    #   Returns 0 if found, 1 if PYTHON_VERSIONS is empty
    ###############################################################################
    function _find_latest_python() {
        if [[ -z "${PYTHON_VERSIONS[*]:-}" ]]; then
            echo ""
            return 1
        fi

        local latest
        latest=$(printf "%s\n" "${PYTHON_VERSIONS[@]}" | sort -V | tail -n 1)

        echo "${latest}"
        return 0
    }

    # -----------------------------------------------------------------------------
    # INITIALIZE PYTHON VARIABLES
    # -----------------------------------------------------------------------------

    # Default to highest configured version if none explicitly set
    if [[ -z "${PYTHON_VERSION:-}" || -z "${PYTHON:-}" ]]; then
        if [[ -n "${PYTHON_VERSIONS[*]:-}" ]]; then
            LATEST_PYTHON_VERSION=$(_find_latest_python)
            export PYTHON_VERSION="${LATEST_PYTHON_VERSION}"
            export PYTHON="python${PYTHON_VERSION}"
            pass "Defaulting PYTHON to version from PYTHON_VERSIONS list: ${PYTHON}"
        else
            fail "No Python versions configured. Exiting."
            exit 1
        fi
    fi

    # Default pip arguments
    PIP_ARGS="install --quiet --upgrade"
    export PIP_ARGS

    # -----------------------------------------------------------------------------
    # ---------------------------------- PYTHON FUNCTIONS -------------------------
    # -----------------------------------------------------------------------------

    # -----------------------------------------------------------------------------
    # Check if pip supports --break-system-packages
    # -----------------------------------------------------------------------------
    function check_pip_break_system_packages() {
        if python"${PYTHON_VERSION}" -m pip help install 2>&1 | grep -q "break-system-packages"; then
            echo "--break-system-packages"
        else
            echo ""
        fi
    }

    break_system_packages_option=$(check_pip_break_system_packages)
    export break_system_packages_option

    # -----------------------------------------------------------------------------
    # Function to fix old Python issues
    # -----------------------------------------------------------------------------
    function _fix_old_python() {
        if find /usr/local/lib -name "__init__.py" \
            -path "/usr/local/lib/*/pyreadline/keysyms/*" \
            -exec sed -i \
            's/raise ImportError("Could not import keysym for local pythonversion", x)/raise ImportError("Could not import keysym for local pythonversion")/g' \
            {} \;; then
            pass "Successfully fixed pyreadline issue."
            return "${_PASS}"
        else
            fail "Failed to fix pyreadline issue."
            return "${_FAIL}"
        fi
    }

    # -----------------------------------------------------------------------------
    # Install Python versions
    # -----------------------------------------------------------------------------
    function _install_python() {
        ERROR_FLAG=false
        for version in "${PYTHON_VERSIONS[@]}"; do
            export PYTHON_VERSION="${version}"
            export PYTHON="python${PYTHON_VERSION}"

            if [[ "${COMPILE_PYTHON}" == "true" && "${INSTALL_PYTHON}" == "true" ]]; then
                warn "Both COMPILE_PYTHON and INSTALL_PYTHON are true. Will attempt apt install, then compile if needed."
            fi

            # Ensure version variable is set
            if [[ -z "${PYTHON}" ]]; then
                fail "Python version (${PYTHON_VERSION}) is not specified."
                return "${_FAIL}"
            fi

            # Install Python 3
            if _install_python3; then
                pass "Python ${PYTHON_VERSION} installed successfully."
            else
                fail "Failed to install Python ${PYTHON_VERSION}."
                return "${_FAIL}"
            fi
            _wait_pid

            # Install Pip for python3.x
            if _install_pip "${PYTHON}"; then
                pass "pip was installed successfully."
            else
                fail "Failed to install pip."
                ERROR_FLAG=true
                #return "$_FAIL"
            fi
            _wait_pid

            # Only install pip for Python 2.7 if needed
            if command -v python2.7 > /dev/null 2>&1; then
                if _install_pip "python2.7"; then
                    pass "pip was installed successfully."
                else
                    fail "Failed to install pip for python2.7."
                    ERROR_FLAG=true
                fi
                _wait_pid
            fi
        done

        # After all installs, set to the newest version
        LATEST_PYTHON_VERSION=$(_find_latest_python)
        if [[ -n "${LATEST_PYTHON_VERSION}" ]]; then
            export PYTHON_VERSION="${LATEST_PYTHON_VERSION}"
            export PYTHON="python${PYTHON_VERSION}"
            pass "Set PYTHON to newest installed version: ${PYTHON}"
        else
            fail "No installed Python versions found after install."
            return "${_FAIL}"
        fi

        # Ensure pipx installed once
        if command -v pipx > /dev/null 2>&1; then
            pass "pipx already installed. Skipping reinstallation."
        else
            if ! _install_pipx "${PYTHON}"; then
                fail "Failed to install pipx."
                ERROR_FLAG=true
            fi
            _wait_pid
        fi

        if [[ "${ERROR_FLAG}" = true ]]; then
            fail "Failed to install Python, pip, and/or pipx."
            return "${_FAIL}"
        fi

        info "Final Python version in use: ${PYTHON}"
        return "${_PASS}"
    }

    # -----------------------------------------------------------------------------
    # Install Python3 version (via apt or compile)
    # -----------------------------------------------------------------------------
    function _install_python3() {
        _pushd "${TOOLS_DIR}" || {
            fail "Failed to change directory to ${TOOLS_DIR}."
            return "${_FAIL}"
        }

        UBUNTU_VER=$(_get_ubuntu_version)

        # Install Python if requested
        if ${INSTALL_PYTHON}; then
            case "${UBUNTU_VER}" in
                "22.04" | "24.04" | "24.10")
                    if _apt_install "${PYTHON}"; then
                        pass "Python ${PYTHON_VERSION} installed successfully."
                        _popd
                        return "${_PASS}"
                    else
                        fail "Failed to install Python ${PYTHON_VERSION} via apt install."
                    fi
                    ;;
                *)
                    fail "Unsupported Ubuntu version: ${UBUNTU_VER} fot apt install."
                    ;;
            esac
        fi

        if ${COMPILE_PYTHON}; then
            local LATEST_VER
            # Fetch the response from the Python FTP server
            local ftp_response
            ftp_response=$(${PROXY} curl -s https://www.python.org/ftp/python/)

            # Extract and process the latest version
            local version_links
            version_links=$(echo "${ftp_response}" | grep -oP "href=\"${PYTHON_VERSION}\.[0-9]+/")

            local sorted_versions
            sorted_versions=$(echo "${version_links}" | sort -u -V)

            # Extract the latest version
            LATEST_VER=$(echo "${sorted_versions}" | awk -F'"' '{print $2}' | awk -F"/" '{print $1}' | tail -n 1)

            # Check if version URL was retrieved
            if [[ -z "${LATEST_VER}" ]]; then
                fail "Failed to determine the latest Python version."
                _popd
                return "${_FAIL}"
            fi

            # Download, extract, and install Python
            if ! ${PROXY} wget --no-check-certificate "https://www.python.org/ftp/python/${LATEST_VER}/Python-${LATEST_VER}.tgz"; then
                fail "Failed to download Python ${LATEST_VER}."
                _popd
                return "${_FAIL}"
            fi

            if ! tar -xvf "Python-${LATEST_VER}.tgz"; then
                fail "Failed to extract Python ${LATEST_VER}."
                rm "Python-${LATEST_VER}.tgz"
                _popd
                return "${_FAIL}"
            fi

            cd "Python-${LATEST_VER}" || {
                fail "Failed to change directory to Python-${LATEST_VER}."
                _popd
                return "${_FAIL}"
            }
            if ! ./configure --enable-optimizations; then
                fail "Configuration of Python ${LATEST_VER} failed."
                cd "${TOOLS_DIR}" || return "${_FAIL}"
                rm -rf "Python-${LATEST_VER}" "Python-${LATEST_VER}.tgz"
                _popd
                return "${_FAIL}"
            fi

            if ! make -j "$(nproc)"; then
                fail "Build of Python ${LATEST_VER} failed."
                cd "${TOOLS_DIR}" || return "${_FAIL}"
                rm -rf "Python-${LATEST_VER}" "Python-${LATEST_VER}.tgz"
                _popd
                return "${_FAIL}"
            fi

            if ! make altinstall; then
                fail "Installation of Python ${LATEST_VER} failed."
                cd "${TOOLS_DIR}" || return "${_FAIL}"
                rm -rf "Python-${LATEST_VER}" "Python-${LATEST_VER}.tgz"
                _popd
                return "${_FAIL}"
            fi

            cd "${TOOLS_DIR}" || return "${_FAIL}"
            rm -rf "Python-${LATEST_VER}" "Python-${LATEST_VER}.tgz"
            pass "Python ${LATEST_VER} installed successfully."
        fi

        _popd
        return "${_PASS}"
    }

    # -----------------------------------------------------------------------------
    # Install pip for a specific Python version
    # -----------------------------------------------------------------------------
    function _install_pip() {
        local python_cmd="${1:-${PYTHON}}"
        local python_version

        # Check if the specified Python command is available
        if ! command -v "${python_cmd}" > /dev/null 2>&1; then
            fail "Python command '${python_cmd}' is not found. Ensure that the specified Python version is installed."
            return "${_FAIL}"
        fi

        # Determine Python version
        python_version=$("${python_cmd}" -c "import sys; print('{}.{}'.format(*sys.version_info[:2]))" 2> /dev/null)
        if [[ -z "${python_version}" ]]; then
            fail "Failed to determine Python version for '${python_cmd}'."
            return "${_FAIL}"
        fi

        # Check if pip is already installed
        if "${python_cmd}" -m pip --version > /dev/null 2>&1; then
            pass "pip is already installed for Python ${python_version}."
            return "${_PASS}"
        fi

        info "Installing pip for Python ${python_version} using apt..."

        # Attempt to install pip using apt
        if [[ "${python_version}" == 2.7* ]]; then
            info "Installing pip for Python 2.7 using apt..."
            if ! _apt_install "python-pip"; then
                fail "Failed to install pip for Python 2.7 using apt."
            fi
        else
            info "Installing pip for Python ${python_version} using apt..."
            if ! _apt_install "python3-pip"; then
                fail "Failed to install pip for Python ${python_version} using apt."
            fi
        fi

        # Verify pip installation
        if "${python_cmd}" -m pip --version > /dev/null 2>&1; then
            pass "pip installed successfully for Python ${python_version} using apt."
            return "${_PASS}"
        fi

        warn "Falling back to get-pip.py..."

        # Fallback: Install pip using get-pip.py
        local get_pip_url="https://bootstrap.pypa.io/get-pip.py"
        local get_pip_file="get-pip.py"

        # Download get-pip.py
        if ! ${PROXY} _CURL "${get_pip_url}" "${get_pip_file}"; then
            fail "Failed to download get-pip.py for Python ${python_version}."
            return "${_FAIL}"
        fi
        pass "Downloaded get-pip.py for Python ${python_version}."

        # Install pip using get-pip.py
        if ! ${PROXY} "${python_cmd}" "${get_pip_file}"; then
            rm -f "${get_pip_file}"
            fail "Failed to install pip for Python ${python_version} using get-pip.py."
            return "${_FAIL}"
        fi

        # Cleanup and final verification
        rm -f "${get_pip_file}"
        pass "Installed pip for Python ${python_version} using get-pip.py."

        if "${python_cmd}" -m pip --version > /dev/null 2>&1; then
            pass "pip installed successfully for Python ${python_version}."
            return "${_PASS}"
        else
            fail "pip installation for Python ${python_version} failed after using get-pip.py."
            return "${_FAIL}"
        fi
    }

    # -----------------------------------------------------------------------------
    # Install pipx (globally, once)
    # -----------------------------------------------------------------------------
    function _install_pipx() {
        local python_cmd="${1:-${PYTHON}}"

        if ! command -v "${python_cmd}" > /dev/null 2>&1; then
            fail "Python command '${python_cmd}' not found."
            return "${_FAIL}"
        fi

        if command -v pipx > /dev/null 2>&1; then
            pass "pipx is already installed."
            return "${_PASS}"
        fi

        info "Installing pipx..."

        if _apt_install "pipx"; then
            pipx ensurepath --force || {
                fail "Failed to ensure pipx path."
                return "${_FAIL}"
            }
        else
            info "apt install failed, trying pip install of pipx..."
            if ! "${python_cmd}" -m pip install --user pipx; then
                fail "Failed to install pipx using pip."
                return "${_FAIL}"
            fi

            pipx ensurepath --force || {
                fail "Failed to ensure pipx path after pip install."
                return "${_FAIL}"
            }
        fi

        if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
            export PATH="${PATH}:${HOME}/.local/bin"
            pass "Added ${HOME}/.local/bin to PATH."
        fi

        # pipx completions bash >> ~/.bashrc # only in pipx < 1.2.x
        eval "$(register-python-argcomplete pipx)"

        if command -v pipx > /dev/null 2>&1; then
            pass "pipx installed successfully."
            return "${_PASS}"
        else
            fail "pipx installation failed."
            return "${_FAIL}"
        fi
    }

    # -----------------------------------------------------------------------------
    # Install Python packages via pip
    # -----------------------------------------------------------------------------
    function _pip_install() {
        local lib="$1"
        local USE_PIP_ARGS="${2:-"true"}"

        local tmp_PIP_ARGS
        if [[ "${USE_PIP_ARGS}" = "true" ]]; then
            tmp_PIP_ARGS="${PIP_ARGS} ${break_system_packages_option} "
        else
            tmp_PIP_ARGS="install ${break_system_packages_option} "
        fi

        # Verify that the library name is provided
        if [[ -z "${lib}" ]]; then
            fail "Library name must be provided."
            return "${_FAIL}"
        fi

        # Call _PipInstallVer with the global python version
        _pip_install_ver "${PYTHON_VERSION}" "${lib}" "${tmp_PIP_ARGS}"
        return $?
    }

    # Function to install Python libraries for a particular version of python
    function _pip_install_ver() {
        local python_version="$1"
        local lib="$2"
        local local_PIP_ARGS="$3"

        # Verify that both parameters are provided
        if [[ -z "${python_version}" ]] || [[ -z "${lib}" ]]; then
            fail "Both python_version and library name must be provided."
            return "${_FAIL}"
        fi

        info "Installing ${lib} using python${python_version}..."

        # Attempt to install the library using pip
        # shellcheck disable=SC2086 # this breaks if you put quotes around ${local_PIP_ARGS}
        if ! PIP_ROOT_USER_ACTION=ignore ${PROXY} python"${python_version}" -m pip ${local_PIP_ARGS} "${lib}" > /dev/null 2>&1; then
            fail "Failed to install ${lib} using python${python_version} -m pip."
            return "${_FAIL}"
        fi

        pass "Successfully installed ${lib} using python${python_version}."
        return "${_PASS}"
    }

    # Function to install Python libraries from a requirements file
    function _pip_install_requirements() {
        local file="$1"
        local USE_PIP_ARGS="${2:-"true"}"

        if [[ "${USE_PIP_ARGS}" = "true" ]]; then
            tmp_PIP_ARGS="${PIP_ARGS} ${break_system_packages_option} "
        else
            tmp_PIP_ARGS="install ${break_system_packages_option} "
        fi

        # Verify that a file name is provided
        if [[ -z "${file}" ]]; then
            fail "Filename name must be provided."
            return "${_FAIL}"
        fi

        # Call _PipInstallRequirementsVer with the global python version
        # shellcheck disable=SC2086 # this breaks if you put quotes around ${tmp_PIP_ARGS}
        _pip_install_requirements_ver "${PYTHON_VERSION}" "${file}" ${tmp_PIP_ARGS}
        return "${_PASS}"
    }

    # Function to install Python libraries from a requirements file for a particular version of python
    function _pip_install_requirements_ver() {
        local python_version="$1"
        local file="$2"
        local local_PIP_ARGS="$3"

        # Verify that both parameters are provided
        if [[ -z "${python_version}" ]] || [[ -z "${file}" ]]; then
            fail "Both python_version and filename must be provided."
            return "${_FAIL}"
        fi

        info "Installing Python packages from ${file} using python${python_version}..."

        # Attempt to install the libraries using pip
        if ! PIP_ROOT_USER_ACTION=ignore ${PROXY} python"${python_version}" -m pip "${local_PIP_ARGS}" -r "${file}" > /dev/null 2>&1; then
            fail "Failed to install packages from ${file} using python${python_version} -m pip."
            return "${_FAIL}"
        fi

        # Verify installation of each package listed in the requirements file
        while IFS= read -r package; do
            # Skip comments and empty lines
            [[ "${package}" =~ ^\s*# ]] || [[ -z "${package}" ]] && continue

            # Extract package name (strip version if present)
            local package_name
            package_name=$(echo "${package}" | awk -F'[>=<]' '{print $1}' | xargs)

            # Check if the package is installed
            if ! PIP_ROOT_USER_ACTION=ignore ${PROXY} python"${python_version}" -m pip show "${package_name}" > /dev/null 2>&1; then
                fail "${package_name} from ${file} is not installed for python${python_version}. Verification failed."
                return "${_FAIL}"
            fi
        done < "${file}"

        pass "Successfully installed packages from ${file} using python${python_version}."
        return "${_PASS}"
    }

    # -----------------------------------------------------------------------------
    # Function to install Python libraries for all Python versions
    # -----------------------------------------------------------------------------
    function _install_python_libs() {
        local libs=("${1:-${PIP_PACKAGES[@]}}")  # Use provided parameter or fallback to pip_packages

        # Ensure at least one library is provided
        if [[ ${#libs[@]} -eq 0 ]]; then
            fail "No Python libraries provided for installation."
            ERROR_FLAG=true
        fi

        source "${HOME}/.bashrc"

        ERROR_FLAG=false

        for version in "${PYTHON_VERSIONS[@]}"; do
            local python_cmd="python${version}"

            if ! command -v "${python_cmd}" > /dev/null 2>&1; then
                warn "Python version ${version} is not installed. Skipping."
                continue
            fi

            info "Installing Python libraries for ${python_cmd}..."

            # Install each library
            for lib in "${libs[@]}"; do
                info "Installing ${lib} for ${python_cmd}..."

                local tmp_PIP_ARGS
                tmp_PIP_ARGS="install ${break_system_packages_option} "

                if ! _pip_install_ver "${version}" "${lib}" "${tmp_PIP_ARGS}"; then
                    fail "Failed to install ${lib} for ${python_cmd}."
                    ERROR_FLAG=true
                    continue
                fi

                # Verify installation
                if ! ${python_cmd} -m pip show "${lib}" > /dev/null 2>&1; then
                    fail "${lib} is not installed for ${python_cmd}. Verification failed."
                    ERROR_FLAG=true
                else
                    pass "${lib} successfully installed for ${python_cmd}."
                fi
            done
        done

        # Remove old or unnecessary packages
        if ! ${PROXY} apt remove -y python3-blinker > /dev/null 2>&1; then
            warn "Failed to remove python3-blinker."
        fi

        if [[ "${ERROR_FLAG}" = true ]]; then
            fail "Failed to install all Python Libraries."
            return "${_FAIL}"
        fi
        pass "Successfully installed all Python libraries."
        return "${_PASS}"
    }

    # -----------------------------------------------------------------------------
    # Install Python pipx package
    # -----------------------------------------------------------------------------
    function _pipx_install() {
        local package="$1"
        local python_cmd="${2:-${PYTHON}}"

        # Ensure package name is provided
        if [[ -z "${package}" ]]; then
            fail "Package name is required for pipx install."
            return "${_FAIL}"
        fi

        info "Installing ${package} using pipx with Python ${python_cmd}..."
        if ! show_spinner "${PROXY} pipx install ${package} --force --python ${python_cmd} > /dev/null 2>&1"; then
            fail "Failed to install ${package} with pipx."
            return "${_FAIL}"
        fi

        pass "Successfully installed ${package} with pipx."
        return "${_PASS}"
    }

    function _install_pipx_tools() {
        local packages=("${1:-${PIPX_PACKAGES[@]}}")

        if [[ ${#packages[@]} -eq 0 ]]; then
            fail "No pipx packages provided for installation."
            return "${_FAIL}"
        fi

        local ERROR_FLAG=false

        for item in "${packages[@]}"; do
            local package_spec python_version python_cmd

            # Split on |
            package_spec="${item%%|*}"
            python_version="${item#*|}"

            # If there's no |, python_version will equal the whole string, so check:
            if [[ "${package_spec}" == "${python_version}" ]]; then
                python_version=""
            fi

            # Decide which Python executable to use
            if [[ -n "${python_version}" ]]; then
                python_cmd="python${python_version}"
            else
                python_cmd="${PYTHON}"
            fi

            if ! _pipx_install "${package_spec}" "${python_cmd}"; then
                fail "Failed to install ${package_spec} with pipx."
                ERROR_FLAG=true
            fi
        done

        if [[ "${ERROR_FLAG}" == "true" ]]; then
            fail "Failed to install all pipx tools."
            return "${_FAIL}"
        fi

        pass "Successfully installed all pipx tools."
        return "${_PASS}"
    }
fi
