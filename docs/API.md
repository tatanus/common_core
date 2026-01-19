# common_core API Reference

Complete API reference for all public functions in the common_core library. For detailed documentation with examples, see the individual `util_*.md` files.

## Conventions

- **Returns:** `PASS` (0) for success, `FAIL` (1) for failure unless otherwise noted
- **Outputs:** Data written to stdout; logging to stderr
- **Optional args:** Shown in `[brackets]`

---

## util_apt

APT package management for Debian/Ubuntu systems.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `apt::is_available` | — | 0/1 | — |
| `apt::update` | — | 0/1 | — |
| `apt::upgrade` | — | 0/1 | — |
| `apt::install` | `packages...` | 0/1 | — |
| `apt::is_installed` | `package` | 0/1 | — |
| `apt::ensure_installed` | `packages...` | 0/1 | — |
| `apt::install_from_array` | `array_name` | 0/1 | — |
| `apt::add_repository` | `repo_url` | 0/1 | — |
| `apt::repair` | — | 0/1 | — |
| `apt::clean` | — | 0/1 | — |
| `apt::autoremove` | — | 0/1 | — |
| `apt::maintain` | — | 0/1 | — |
| `apt::get_version` | `package` | 0/1 | version string |
| `apt::self_test` | — | 0/1 | — |

---

## util_brew

Homebrew package management for macOS.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `brew::is_available` | — | 0/1 | — |
| `brew::install_self` | — | 0/1 | — |
| `brew::tap` | `repo` | 0/1 | — |
| `brew::install` | `packages...` | 0/1 | — |
| `brew::install_cask` | `packages...` | 0/1 | — |
| `brew::is_installed` | `package` | 0/1 | — |
| `brew::ensure_installed` | `packages...` | 0/1 | — |
| `brew::install_from_array` | `array_name` | 0/1 | — |
| `brew::uninstall` | `packages...` | 0/1 | — |
| `brew::update` | — | 0/1 | — |
| `brew::upgrade` | `[packages...]` | 0/1 | — |
| `brew::cleanup` | — | 0/1 | — |
| `brew::get_version` | `package` | 0/1 | version string |
| `brew::list` | — | 0 | package list |
| `brew::rosetta_available` | — | 0/1 | — |
| `brew::self_test` | — | 0/1 | — |

---

## util_cmd

Command execution and validation utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `cmd::run` | `command...` | cmd exit | command output |
| `cmd::run_silent` | `command...` | cmd exit | — |
| `cmd::run_with_env` | `"VAR=val..." command...` | cmd exit | command output |
| `cmd::run_as_user` | `user command...` | cmd exit | command output |
| `cmd::build` | `parts...` | 0 | command string |
| `cmd::test` | `command...` | cmd exit | — |
| `cmd::test_tool` | `tool_name` | 0/1 | — |
| `cmd::test_batch` | `array_name` | 0/1 | status report |
| `cmd::require` | `command [msg]` | 0/exit | — |
| `cmd::ensure` | `command [package]` | 0/1 | — |
| `cmd::ensure_all` | `commands...` | 0/1 | — |
| `cmd::install_package` | `package` | 0/1 | — |
| `cmd::retry` | `max_attempts command...` | cmd exit | command output |
| `cmd::timeout` | `seconds command...` | cmd exit | command output |
| `cmd::parallel` | `commands...` | 0/1 | command outputs |
| `cmd::parallel_array` | `array_name` | 0/1 | command outputs |
| `cmd::elevate` | `command...` | cmd exit | command output |
| `cmd::sudo_available` | — | 0/1 | — |
| `cmd::ensure_sudo_cached` | — | 0/1 | — |
| `cmd::get_exit_code` | — | 0 | last exit code |
| `cmd::self_test` | — | 0/1 | — |

---

## util_config

Configuration management with validation.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `config::init` | — | 0 | — |
| `config::set` | `key value` | 0/1 | — |
| `config::get` | `key [default]` | 0/1 | value |
| `config::get_bool` | `key [default]` | 0/1 | — |
| `config::get_int` | `key [default]` | 0/1 | integer |
| `config::register` | `key type default desc` | 0/1 | — |
| `config::validate` | — | 0/1 | — |
| `config::list` | — | 0 | key list |
| `config::count` | — | 0 | count |
| `config::show` | — | 0 | key=value pairs |
| `config::reset` | — | 0 | — |
| `config::lock` | — | 0 | — |
| `config::unlock` | — | 0 | — |
| `config::load_from_env` | `[prefix]` | 0/1 | — |
| `config::load_from_file` | `filepath` | 0/1 | — |
| `config::load_from_files` | `files...` | 0/1 | — |
| `config::save_to_file` | `filepath` | 0/1 | — |
| `config::export_env` | — | 0 | — |
| `config::export_json` | — | 0 | JSON |
| `config::self_test` | — | 0/1 | — |

---

## util_curl

HTTP client utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `curl::is_available` | — | 0/1 | — |
| `curl::get` | `url` | 0/1 | response body |
| `curl::post` | `url [data]` | 0/1 | response body |
| `curl::put` | `url [data]` | 0/1 | response body |
| `curl::delete` | `url` | 0/1 | response body |
| `curl::download` | `url dest` | 0/1 | — |
| `curl::upload` | `file url` | 0/1 | response body |
| `curl::check_url` | `url` | 0/1 | — |
| `curl::get_status_code` | `url` | 0/1 | HTTP status |
| `curl::get_headers` | `url` | 0/1 | headers |
| `curl::get_response_time` | `url` | 0/1 | time in seconds |
| `curl::get_with_retry` | `url [max_retries]` | 0/1 | response body |
| `curl::follow_redirects` | `url` | 0/1 | final URL |
| `curl::with_auth` | `user:pass url` | 0/1 | response body |
| `curl::with_headers` | `"Header: val" url` | 0/1 | response body |
| `curl::self_test` | — | 0/1 | — |

---

## util_dir

Directory operations.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `dir::exists` | `path` | 0/1 | — |
| `dir::create` | `path [mode]` | 0/1 | — |
| `dir::delete` | `path` | 0/1 | — |
| `dir::copy` | `src dest` | 0/1 | — |
| `dir::move` | `src dest` | 0/1 | — |
| `dir::is_empty` | `path` | 0/1 | — |
| `dir::is_readable` | `path` | 0/1 | — |
| `dir::is_writable` | `path` | 0/1 | — |
| `dir::ensure_exists` | `path [mode]` | 0/1 | — |
| `dir::ensure_writable` | `path` | 0/1 | — |
| `dir::empty` | `path` | 0/1 | — |
| `dir::get_size` | `path` | 0/1 | size in bytes |
| `dir::get_absolute_path` | `path` | 0/1 | absolute path |
| `dir::get_relative_path` | `path [base]` | 0/1 | relative path |
| `dir::in_path` | `dir` | 0/1 | — |
| `dir::list_files` | `path` | 0/1 | file list |
| `dir::list_dirs` | `path` | 0/1 | dir list |
| `dir::find_files` | `path pattern` | 0/1 | file list |
| `dir::count_files` | `path` | 0/1 | count |
| `dir::count_dirs` | `path` | 0/1 | count |
| `dir::backup` | `path [dest]` | 0/1 | backup path |
| `dir::rotate` | `path [count]` | 0/1 | — |
| `dir::cleanup_old` | `path days` | 0/1 | — |
| `dir::tempdir` | `[prefix]` | 0/1 | temp path |
| `dir::push` | `path` | 0/1 | — |
| `dir::pop` | — | 0/1 | — |
| `dir::self_test` | — | 0/1 | — |

---

## util_env

Environment variable management.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `env::get` | `name [default]` | 0/1 | value |
| `env::set` | `name value` | 0 | — |
| `env::unset` | `name` | 0 | — |
| `env::exists` | `name` | 0/1 | — |
| `env::require` | `name [msg]` | 0/exit | value |
| `env::check` | `names...` | 0/1 | — |
| `env::get_home` | — | 0 | home path |
| `env::get_user` | — | 0 | username |
| `env::get_temp_dir` | — | 0 | temp path |
| `env::get_xdg_config_home` | — | 0 | config path |
| `env::get_xdg_data_home` | — | 0 | data path |
| `env::get_xdg_cache_home` | — | 0 | cache path |
| `env::get_xdg_state_home` | — | 0 | state path |
| `env::is_ci` | — | 0/1 | — |
| `env::is_container` | — | 0/1 | — |
| `env::is_tmux` | — | 0/1 | — |
| `env::is_screen` | — | 0/1 | — |
| `env::remove_from_path` | `dir` | 0 | — |
| `env::save_to_file` | `filepath vars...` | 0/1 | — |
| `env::export_file` | `filepath` | 0/1 | — |
| `env::diff_files` | `file1 file2` | 0/1 | diff output |
| `env::validate_env_file` | `filepath` | 0/1 | — |
| `env::self_test` | — | 0/1 | — |

---

## util_file

File operations.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `file::exists` | `path` | 0/1 | — |
| `file::is_readable` | `path` | 0/1 | — |
| `file::is_writable` | `path` | 0/1 | — |
| `file::is_executable` | `path` | 0/1 | — |
| `file::is_non_empty` | `path` | 0/1 | — |
| `file::touch` | `path` | 0/1 | — |
| `file::delete` | `path` | 0/1 | — |
| `file::copy` | `src dest` | 0/1 | — |
| `file::move` | `src dest` | 0/1 | — |
| `file::append` | `path content` | 0/1 | — |
| `file::prepend` | `path content` | 0/1 | — |
| `file::contains` | `path pattern` | 0/1 | — |
| `file::replace_line` | `path pattern replacement` | 0/1 | — |
| `file::replace_env_vars` | `path` | 0/1 | — |
| `file::count_lines` | `path` | 0/1 | count |
| `file::get_size` | `path` | 0/1 | size in bytes |
| `file::get_checksum` | `path [algo]` | 0/1 | checksum |
| `file::get_basename` | `path` | 0 | basename |
| `file::get_dirname` | `path` | 0 | dirname |
| `file::get_extension` | `path` | 0 | extension |
| `file::compare` | `file1 file2` | 0/1 | — |
| `file::backup` | `path [suffix]` | 0/1 | backup path |
| `file::restore_old_backup` | `path` | 0/1 | — |
| `file::generate_filename` | `prefix [ext]` | 0 | filename |
| `file::copy_list_from_array` | `array_name dest` | 0/1 | — |
| `file::mktemp` | `[template]` | 0/1 | temp path |
| `file::self_test` | — | 0/1 | — |

---

## util_git

Git and GitHub utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `git::is_available` | — | 0/1 | — |
| `git::is_repo` | — | 0/1 | — |
| `git::clone` | `url [dest] [args...]` | 0/1 | — |
| `git::pull` | — | 0/1 | — |
| `git::push` | — | 0/1 | — |
| `git::commit` | `message [args...]` | 0/1 | — |
| `git::checkout` | `ref` | 0/1 | — |
| `git::create_branch` | `name` | 0/1 | — |
| `git::delete_branch` | `name [--force]` | 0/1 | — |
| `git::get_branch` | — | 0/1 | branch name |
| `git::get_commit` | — | 0/1 | commit hash |
| `git::get_remote_url` | — | 0/1 | URL |
| `git::get_root` | — | 0/1 | root path |
| `git::has_changes` | — | 0/1 | — |
| `git::is_clean` | — | 0/1 | — |
| `git::stash_save` | `[message]` | 0/1 | — |
| `git::stash_pop` | — | 0/1 | — |
| `git::tag` | `[name]` | 0/1 | tag list if no name |
| `git::submodule_update` | — | 0/1 | — |
| `git::set_config` | `key value [scope]` | 0/1 | — |
| `git::get_config` | `key` | 0/1 | value |
| `git::get_latest_release_info` | `owner/repo os arch [tag_var] [name_var] [asset_var]` | 0/1 | sets nameref vars |
| `git::get_release` | `owner/repo os arch dest` | 0/1 | — |
| `git::self_test` | — | 0/1 | — |

---

## util_go

Go language utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `go::is_available` | — | 0/1 | — |
| `go::get_version` | — | 0/1 | version |
| `go::install` | `[version]` | 0/1 | — |
| `go::install_tool` | `package` | 0/1 | — |
| `go::mod_init` | `module_name` | 0/1 | — |
| `go::mod_tidy` | — | 0/1 | — |
| `go::build` | `[target]` | 0/1 | — |
| `go::build_cross` | `os arch [target]` | 0/1 | — |
| `go::test` | — | 0/1 | test output |
| `go::fmt` | `[path]` | 0/1 | — |
| `go::vet` | `[path]` | 0/1 | — |
| `go::lint` | `[path]` | 0/1 | — |
| `go::set_module_proxy` | `url` | 0 | — |
| `go::work_init` | `[modules...]` | 0/1 | — |
| `go::get_gopath` | — | 0 | GOPATH |
| `go::get_goroot` | — | 0 | GOROOT |
| `go::self_test` | — | 0/1 | — |

---

## util_menu

Dialog-backed menu utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `menu::select_single` | `title prompt options...` | 0/1 | selected option |
| `menu::select_multi` | `title prompt options...` | 0/1 | selected options |
| `menu::select_or_input` | `title prompt options...` | 0/1 | value |
| `menu::confirm_action` | `prompt` | 0/1 | — |
| `menu::pause` | — | 0 | — |
| `menu::dynamic_from_file` | `title prompt timestamps filepath` | 0/1 | selected option |
| `menu::tree` | `title prompt timestamps nodes...` | 0 | return value |
| `menu::self_test` | — | 0/1 | — |

---

## util_net

Network utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `net::is_online` | `[target]` | 0/1 | — |
| `net::is_local_ip` | `ip` | 0/1 | — |
| `net::resolve_target` | `hostname` | 0/1 | IPv4 address |
| `net::resolve_target_ipv6` | `hostname` | 0/1 | IPv6 address |
| `net::get_gateway` | — | 0/1 | gateway IP |
| `net::get_dns_servers` | — | 0/1 | DNS IPs |
| `net::get_local_ips` | — | 0/1 | interface list |
| `net::get_external_ip` | — | 0/1 | external IP |
| `net::list_interfaces` | — | 0/1 | interface names |
| `net::get_interface_info` | `interface` | 0/1 | interface details |
| `net::get_ip_method` | `interface` | 0/1 | DHCP/Static/Unknown |
| `net::check_port` | `host port` | 0/1 | — |
| `net::repair_connectivity` | — | 0/1 | — |
| `net::full_diagnostic` | — | 0/1 | — |
| `net::self_test` | — | 0/1 | — |

---

## util_os

OS detection and information.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `os::detect` | — | 0 | linux/macos/wsl/windows/unknown |
| `os::is_linux` | — | 0/1 | — |
| `os::is_macos` | — | 0/1 | — |
| `os::is_wsl` | — | 0/1 | — |
| `os::is_root` | — | 0/1 | — |
| `os::require_root` | `[message]` | 0/1 | — |
| `os::get_distro` | — | 0 | distro name |
| `os::get_version` | — | 0 | version string |
| `os::get_arch` | — | 0 | amd64/arm64/386/etc |
| `os::is_arm` | — | 0/1 | — |
| `os::is_x86` | — | 0/1 | — |
| `os::get_shell` | — | 0 | shell name |
| `os::get_kernel_version` | — | 0 | kernel version |
| `os::get_hostname` | — | 0 | hostname |
| `os::get_uptime` | — | 0/1 | seconds |
| `os::get_memory_total` | — | 0/1 | bytes |
| `os::get_cpu_count` | — | 0/1 | count |
| `os::str` | — | 0 | "os version arch" |
| `os::self_test` | — | 0/1 | — |

---

## util_platform

Cross-platform abstractions.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `platform::detect_os` | — | 0 | sets PLATFORM_OS |
| `platform::detect_variant` | — | 0 | sets PLATFORM_VARIANT |
| `platform::setup_commands` | — | 0 | — |
| `platform::find_command` | `name` | 0/1 | path |
| `platform::check_gnu_tools` | — | 0/1 | — |
| `platform::stat` | `mode path` | 0/1 | stat value |
| `platform::date` | `format` | 0 | formatted date |
| `platform::checksum` | `path [algo]` | 0/1 | checksum |
| `platform::mktemp` | `[template]` | 0/1 | temp path |
| `platform::readlink_canonical` | `path` | 0/1 | canonical path |
| `platform::sed_inplace` | `pattern file` | 0/1 | — |
| `platform::timeout` | `seconds command...` | cmd exit | command output |
| `platform::dns_flush` | — | 0/1 | — |
| `platform::network_restart` | — | 0/1 | — |
| `platform::get_interface_ip` | `interface` | 0/1 | IP address |
| `platform::get_interface_mac` | `interface` | 0/1 | MAC address |
| `platform::info` | — | 0 | platform info |
| `platform::self_test` | — | 0/1 | — |

---

## util_py

Python utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `py::is_available` | `[version]` | 0/1 | — |
| `py::get_version` | `[python_cmd]` | 0/1 | version |
| `py::get_major_version` | `[version]` | 0/1 | major.minor |
| `py::get_path` | `[version]` | 0/1 | python path |
| `py::is_version_available` | `version` | 0/1 | — |
| `py::install_python` | `[version]` | 0/1 | — |
| `py::install_pip` | `[version]` | 0/1 | — |
| `py::pip_install` | `packages...` | 0/1 | — |
| `py::pip_install_for_version` | `version packages...` | 0/1 | — |
| `py::pip_upgrade` | `[version]` | 0/1 | — |
| `py::requirements_install` | `[file] [version]` | 0/1 | — |
| `py::is_package_installed` | `package [version]` | 0/1 | — |
| `py::get_package_version` | `package [version]` | 0/1 | version |
| `py::get_site_packages` | `[version]` | 0/1 | path |
| `py::freeze_requirements` | `[file] [version]` | 0/1 | — |
| `py::create_venv` | `path [version]` | 0/1 | — |
| `py::activate_venv` | `path` | 0/1 | — |
| `py::install_pipx` | — | 0/1 | — |
| `py::pipx_install` | `package` | 0/1 | — |
| `py::install_uv` | — | 0/1 | — |
| `py::uv_install` | `packages...` | 0/1 | — |
| `py::run_script` | `script [args...]` | script exit | script output |
| `py::pyenv_available` | — | 0/1 | — |
| `py::pyenv_install_version` | `version` | 0/1 | — |
| `py::pip_supports_break_system_packages` | — | 0/1 | — |
| `py::get_pip_args` | — | 0 | pip args |
| `py::install_build_dependencies` | — | 0/1 | — |
| `py::get_latest_patch_version` | `major.minor` | 0/1 | version |
| `py::download_source` | `version dest` | 0/1 | — |
| `py::compile_from_source` | `version [prefix]` | 0/1 | — |
| `py::self_test` | — | 0/1 | — |

---

## util_py_multi

Multi-version Python management.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `py_multi::set_versions` | `versions...` | 0 | — |
| `py_multi::get_versions` | — | 0 | version list |
| `py_multi::add_version` | `version` | 0/1 | — |
| `py_multi::remove_version` | `version` | 0/1 | — |
| `py_multi::find_latest` | — | 0/1 | version |
| `py_multi::set_default` | `[version]` | 0/1 | — |
| `py_multi::get_default` | — | 0 | version |
| `py_multi::install_all` | `[--compile]` | 0/1 | — |
| `py_multi::install_pip_all` | — | 0/1 | — |
| `py_multi::upgrade_pip_all` | — | 0/1 | — |
| `py_multi::pip_install_all` | `packages...` | 0/1 | — |
| `py_multi::requirements_install_all` | `[file]` | 0/1 | — |
| `py_multi::verify_package_all` | `package` | 0/1 | status per version |
| `py_multi::pipx_install_batch` | `array_name` | 0/1 | — |
| `py_multi::status` | — | 0 | status table |
| `py_multi::list_installed` | — | 0 | version list |
| `py_multi::cleanup_cache` | — | 0 | — |
| `py_multi::self_test` | — | 0/1 | — |

---

## util_ruby

Ruby and gem utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `ruby::is_available` | — | 0/1 | — |
| `ruby::get_version` | — | 0/1 | version |
| `ruby::get_path` | — | 0 | ruby path |
| `ruby::gem_available` | — | 0/1 | — |
| `ruby::gem_install` | `gems...` | 0/1 | — |
| `ruby::gem_install_spec` | `"gem -v version"` | 0/1 | — |
| `ruby::gem_install_batch` | `[array_name]` | 0-3 | — |
| `ruby::gem_install_with_version` | `gem version` | 0/1 | — |
| `ruby::gem_update` | — | 0/1 | — |
| `ruby::gem_uninstall` | `gem [version]` | 0/1 | — |
| `ruby::gem_cleanup` | — | 0/1 | — |
| `ruby::is_gem_installed` | `gem [version]` | 0/1 | — |
| `ruby::get_gem_version` | `gem` | 0/1 | version |
| `ruby::list_gems` | — | 0 | gem list |
| `ruby::gem_outdated` | — | 0 | outdated list |
| `ruby::bundler_install` | — | 0/1 | — |
| `ruby::get_bundler_version` | — | 0/1 | major version |
| `ruby::bundle_install` | — | 0/1 | — |
| `ruby::bundle_exec` | `command...` | cmd exit | command output |
| `ruby::run_script` | `script` | 0/1 | script output |
| `ruby::rbenv_available` | — | 0/1 | — |
| `ruby::rvm_available` | — | 0/1 | — |
| `ruby::install_rbenv` | — | 0/1 | — |
| `ruby::rbenv_install_version` | `version` | 0/1 | — |
| `ruby::env_info` | — | 0 | environment info |
| `ruby::self_test` | — | 0/1 | — |

---

## util_str

String manipulation utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `str::trim` | `string` | 0 | trimmed string |
| `str::trim_left` | `string` | 0 | trimmed string |
| `str::trim_right` | `string` | 0 | trimmed string |
| `str::to_lower` | `string` | 0 | lowercase string |
| `str::to_upper` | `string` | 0 | uppercase string |
| `str::capitalize` | `string` | 0 | capitalized string |
| `str::to_title_case` | `string` | 0 | title case string |
| `str::length` | `string` | 0 | length |
| `str::substring` | `string start [length]` | 0 | substring |
| `str::replace` | `string search replace` | 0 | result string |
| `str::replace_all` | `string search replace` | 0 | result string |
| `str::remove` | `string search` | 0 | result string |
| `str::remove_all` | `string search` | 0 | result string |
| `str::contains` | `string substring` | 0/1 | — |
| `str::starts_with` | `string prefix` | 0/1 | — |
| `str::ends_with` | `string suffix` | 0/1 | — |
| `str::is_empty` | `string` | 0/1 | — |
| `str::is_not_empty` | `string` | 0/1 | — |
| `str::is_blank` | `string` | 0/1 | — |
| `str::is_integer` | `string` | 0/1 | — |
| `str::is_positive_integer` | `string` | 0/1 | — |
| `str::is_float` | `string` | 0/1 | — |
| `str::is_alpha` | `string` | 0/1 | — |
| `str::is_alphanumeric` | `string` | 0/1 | — |
| `str::matches` | `string pattern` | 0/1 | — |
| `str::split` | `string delimiter var_name` | 0 | sets array |
| `str::join` | `delimiter elements...` | 0 | joined string |
| `str::repeat` | `string count` | 0 | repeated string |
| `str::reverse` | `string` | 0 | reversed string |
| `str::pad_left` | `string width [char]` | 0 | padded string |
| `str::pad_right` | `string width [char]` | 0 | padded string |
| `str::truncate` | `string length [suffix]` | 0 | truncated string |
| `str::count` | `string search` | 0 | count |
| `str::in_list` | `string list...` | 0/1 | — |
| `str::self_test` | — | 0/1 | — |

---

## util_tools

Tool installation and management.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `tools::install_git_tool` | `name url entry_point` | 0/1 | — |
| `tools::install_git_python` | `name url` | 0/1 | — |
| `tools::add_function` | `name body` | 0/1 | — |
| `tools::remove_function` | `name` | 0/1 | — |
| `tools::list_functions` | — | 0 | function list |
| `tools::list_installed` | — | 0 | tool list |
| `tools::get_install_status` | `tool` | 0/1 | status |
| `tools::test` | `tool` | 0/1 | — |
| `tools::test_batch` | `array_name` | 0/1 | status report |
| `tools::apply_fixes` | — | 0/1 | — |
| `tools::run_command` | `command...` | cmd exit | command output |
| `tools::self_test` | — | 0/1 | — |

---

## util_trap

Trap and cleanup management.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `trap::add_cleanup` | `function` | 0 | — |
| `trap::add_temp_file` | `path` | 0 | — |
| `trap::add_temp_dir` | `path` | 0 | — |
| `trap::with_cleanup` | `command...` | cmd exit | command output |
| `trap::clear_all` | — | 0 | — |
| `trap::list` | — | 0 | trap list |
| `trap::self_test` | — | 0/1 | — |

---

## util_tui

Terminal UI utilities.

| Function | Arguments | Returns | Output |
|----------|-----------|---------|--------|
| `tui::is_terminal` | — | 0/1 | — |
| `tui::supports_color` | — | 0/1 | — |
| `tui::get_terminal_width` | — | 0 | width |
| `tui::clear_line` | — | 0 | — |
| `tui::strip_color` | `string` | 0 | plain string |
| `tui::msg` | `type message` | 0 | — |
| `tui::pause` | `[message]` | 0 | — |
| `tui::prompt_input` | `prompt [default]` | 0/1 | input value |
| `tui::prompt_yes_no` | `prompt [default]` | 0/1 | — |
| `tui::prompt_select` | `prompt options...` | 0/1 | selected option |
| `tui::prompt_multiselect` | `prompt options...` | 0/1 | selected options |
| `tui::show_spinner` | `-- command...` | cmd exit | — |
| `tui::show_progress_bar` | `current total [width]` | 0 | — |
| `tui::show_dots` | `-- command...` | cmd exit | — |
| `tui::show_timer` | `-- command...` | cmd exit | — |
| `tui::self_test` | — | 0/1 | — |

---

## Loading the Library

```bash
#!/usr/bin/env bash
source /path/to/common_core/util.sh

# All modules are now available
os::str
```

## Self-Test All Modules

```bash
#!/usr/bin/env bash
source util.sh

# Run all self-tests
for module in apt brew cmd config curl dir env file git go menu net os platform py py_multi ruby str tools trap tui; do
    "${module}::self_test" || echo "FAIL: ${module}"
done
```
