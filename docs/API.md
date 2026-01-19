# common_core API Reference

Complete API reference for all public functions in the common_core library.

## Data Format

The canonical API reference is available in YAML format: [`API.yaml`](./API.yaml)

This provides structured data with:
- **function**: Function name
- **description**: What the function does
- **arguments**: Required and optional parameters
- **returns**: Exit code (0 = success, 1 = failure)
- **output**: Data written to stdout (if any)

For detailed documentation with examples, see the individual `util_*.md` files.

## Conventions

- **Returns:** `PASS` (0) for success, `FAIL` (1) for failure unless otherwise noted
- **Outputs:** Data written to stdout; logging to stderr
- **Optional args:** Shown in `[brackets]`
- **~:** Indicates no value (null)

---

## Quick Reference

### util_apt — APT package management

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `apt::is_available` | Check if APT is available and usable | — | 0/1 | — |
| `apt::update` | Update the APT package lists | — | 0/1 | — |
| `apt::upgrade` | Upgrade all installed APT packages | — | 0/1 | — |
| `apt::install` | Install packages with validation and repair | `packages...` | 0/1 | — |
| `apt::is_installed` | Check if a package is installed | `package` | 0/1 | — |
| `apt::ensure_installed` | Install packages only if missing | `packages...` | 0/1 | — |
| `apt::install_from_array` | Install packages from named array | `array_name` | 0/1 | — |
| `apt::add_repository` | Add a repository to APT sources | `repo_url` | 0/1 | — |
| `apt::repair` | Fix broken APT dependencies | — | 0/1 | — |
| `apt::clean` | Clean APT cache | — | 0/1 | — |
| `apt::autoremove` | Remove unused packages | — | 0/1 | — |
| `apt::maintain` | Full maintenance (update, upgrade, clean) | — | 0/1 | — |
| `apt::get_version` | Get installed package version | `package` | 0/1 | version |
| `apt::self_test` | Run self-test | — | 0/1 | — |

---

### util_brew — Homebrew package management

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `brew::is_available` | Check if Homebrew is installed | — | 0/1 | — |
| `brew::install_self` | Install Homebrew | — | 0/1 | — |
| `brew::tap` | Add a Homebrew tap | `repo` | 0/1 | — |
| `brew::install` | Install packages | `packages...` | 0/1 | — |
| `brew::install_cask` | Install cask (macOS app) | `packages...` | 0/1 | — |
| `brew::is_installed` | Check if package is installed | `package` | 0/1 | — |
| `brew::ensure_installed` | Install packages only if missing | `packages...` | 0/1 | — |
| `brew::install_from_array` | Install packages from named array | `array_name` | 0/1 | — |
| `brew::uninstall` | Uninstall packages | `packages...` | 0/1 | — |
| `brew::update` | Update Homebrew metadata | — | 0/1 | — |
| `brew::upgrade` | Upgrade installed formulae | `[packages...]` | 0/1 | — |
| `brew::cleanup` | Remove old package versions | — | 0/1 | — |
| `brew::get_version` | Get installed package version | `package` | 0/1 | version |
| `brew::list` | List all installed formulae | — | 0 | package list |
| `brew::rosetta_available` | Check Rosetta 2 (ARM Macs) | — | 0/1 | — |
| `brew::self_test` | Run self-test | — | 0/1 | — |

---

### util_cmd — Command execution utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `cmd::run` | Execute command with logging | `command...` | cmd exit | output |
| `cmd::run_silent` | Execute command silently | `command...` | cmd exit | — |
| `cmd::run_with_env` | Run with custom env vars | `"VAR=val" cmd...` | cmd exit | output |
| `cmd::run_as_user` | Execute as specified user | `user command...` | cmd exit | output |
| `cmd::build` | Build command array safely | `parts...` | 0 | cmd string |
| `cmd::test` | Verify exit code matches | `expected cmd...` | cmd exit | — |
| `cmd::test_tool` | Test if tool is functioning | `tool_name` | 0/1 | — |
| `cmd::test_batch` | Run tests from assoc array | `array_name` | 0/1 | report |
| `cmd::require` | Require command or exit | `command [msg]` | 0/exit | — |
| `cmd::ensure` | Ensure tool exists, install if not | `command [pkg]` | 0/1 | — |
| `cmd::ensure_all` | Ensure multiple tools exist | `commands...` | 0/1 | — |
| `cmd::install_package` | Install package by OS | `package` | 0/1 | — |
| `cmd::retry` | Retry command with delays | `attempts cmd...` | cmd exit | output |
| `cmd::timeout` | Run with timeout | `seconds cmd...` | cmd exit | output |
| `cmd::parallel` | Run commands in parallel | `commands...` | 0/1 | outputs |
| `cmd::parallel_array` | Parallel from array | `array_name` | 0/1 | outputs |
| `cmd::elevate` | Run with sudo/root | `command...` | cmd exit | output |
| `cmd::sudo_available` | Check if sudo works | — | 0/1 | — |
| `cmd::ensure_sudo_cached` | Cache sudo credentials | — | 0/1 | — |
| `cmd::get_exit_code` | Get last exit code | — | 0 | exit code |
| `cmd::self_test` | Run self-test | — | 0/1 | — |

---

### util_config — Configuration management

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `config::init` | Initialize config system | — | 0 | — |
| `config::set` | Set config value | `key value` | 0/1 | — |
| `config::get` | Get config value | `key [default]` | 0/1 | value |
| `config::get_bool` | Get boolean config | `key [default]` | 0/1 | — |
| `config::get_int` | Get integer config | `key [default]` | 0/1 | integer |
| `config::register` | Register key with metadata | `key type default desc` | 0/1 | — |
| `config::validate` | Validate config value | — | 0/1 | — |
| `config::list` | List all config keys | — | 0 | key list |
| `config::count` | Count registered keys | — | 0 | count |
| `config::show` | Show config details | — | 0 | key=value |
| `config::reset` | Reset to default | — | 0 | — |
| `config::lock` | Lock key (immutable) | — | 0 | — |
| `config::unlock` | Unlock key | — | 0 | — |
| `config::load_from_env` | Load from env vars | `[prefix]` | 0/1 | — |
| `config::load_from_file` | Load from file | `filepath` | 0/1 | — |
| `config::load_from_files` | Load from locations | `files...` | 0/1 | — |
| `config::save_to_file` | Save to file | `filepath` | 0/1 | — |
| `config::export_env` | Export as env vars | — | 0 | — |
| `config::export_json` | Export as JSON | — | 0 | JSON |
| `config::self_test` | Run self-test | — | 0/1 | — |

---

### util_curl — HTTP client utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `curl::is_available` | Check if curl exists | — | 0/1 | — |
| `curl::get` | HTTP GET request | `url` | 0/1 | body |
| `curl::post` | HTTP POST request | `url [data]` | 0/1 | body |
| `curl::put` | HTTP PUT request | `url [data]` | 0/1 | body |
| `curl::delete` | HTTP DELETE request | `url` | 0/1 | body |
| `curl::download` | Download file | `url dest` | 0/1 | — |
| `curl::upload` | Upload file | `file url` | 0/1 | body |
| `curl::check_url` | Check if URL accessible | `url` | 0/1 | — |
| `curl::get_status_code` | Get HTTP status | `url` | 0/1 | status |
| `curl::get_headers` | Get response headers | `url` | 0/1 | headers |
| `curl::get_response_time` | Get response time | `url` | 0/1 | seconds |
| `curl::get_with_retry` | GET with retry | `url [max]` | 0/1 | body |
| `curl::follow_redirects` | Get final URL | `url` | 0/1 | final URL |
| `curl::with_auth` | Request with auth | `user:pass url` | 0/1 | body |
| `curl::with_headers` | Request with headers | `"H: v" url` | 0/1 | body |
| `curl::self_test` | Run self-test | — | 0/1 | — |

---

### util_dir — Directory operations

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `dir::exists` | Check directory exists | `path` | 0/1 | — |
| `dir::is_readable` | Check dir readable | `path` | 0/1 | — |
| `dir::is_writable` | Check dir writable | `path` | 0/1 | — |
| `dir::is_empty` | Check dir empty | `path` | 0/1 | — |
| `dir::create` | Create directory | `path [mode]` | 0/1 | — |
| `dir::delete` | Delete dir recursively | `path` | 0/1 | — |
| `dir::copy` | Copy dir recursively | `src dest` | 0/1 | — |
| `dir::move` | Move or rename dir | `src dest` | 0/1 | — |
| `dir::get_size` | Get directory size | `path` | 0/1 | bytes |
| `dir::list_files` | List files in dir | `path` | 0/1 | file list |
| `dir::list_dirs` | List subdirs | `path` | 0/1 | dir list |
| `dir::find_files` | Find files by pattern | `path pattern` | 0/1 | file list |
| `dir::backup` | Create timestamped backup | `path [dest]` | 0/1 | backup path |
| `dir::cleanup_old` | Remove old files | `path days` | 0/1 | — |
| `dir::get_absolute_path` | Get absolute path | `path` | 0/1 | abs path |
| `dir::get_relative_path` | Get relative path | `path [base]` | 0/1 | rel path |
| `dir::push` | Push to dir stack | `path` | 0/1 | — |
| `dir::pop` | Pop from dir stack | — | 0/1 | — |
| `dir::in_path` | Check if in PATH | `dir` | 0/1 | — |
| `dir::ensure_exists` | Create if missing | `path [mode]` | 0/1 | — |
| `dir::ensure_writable` | Ensure writable | `path` | 0/1 | — |
| `dir::tempdir` | Create temp dir | `[prefix]` | 0/1 | path |
| `dir::empty` | Empty dir contents | `path` | 0/1 | — |
| `dir::rotate` | Rotate backups | `path [count]` | 0/1 | — |
| `dir::count_files` | Count files | `path` | 0/1 | count |
| `dir::count_dirs` | Count subdirs | `path` | 0/1 | count |
| `dir::self_test` | Run self-test | — | 0/1 | — |

---

### util_env — Environment variable management

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `env::get_xdg_config_home` | Get XDG config dir | — | 0 | path |
| `env::get_xdg_data_home` | Get XDG data dir | — | 0 | path |
| `env::get_xdg_cache_home` | Get XDG cache dir | — | 0 | path |
| `env::get_xdg_state_home` | Get XDG state dir | — | 0 | path |
| `env::exists` | Check var defined | `name` | 0/1 | — |
| `env::check` | Check var non-empty | `names...` | 0/1 | — |
| `env::get` | Get var with default | `name [default]` | 0/1 | value |
| `env::set` | Set env variable | `name value` | 0 | — |
| `env::unset` | Remove env variable | `name` | 0 | — |
| `env::require` | Require var or exit | `name [msg]` | 0/exit | value |
| `env::remove_from_path` | Remove from PATH | `dir` | 0 | — |
| `env::validate_env_file` | Validate .env format | `filepath` | 0/1 | — |
| `env::diff_files` | Diff two .env files | `file1 file2` | 0/1 | diff |
| `env::export_file` | Load .env file | `filepath` | 0/1 | — |
| `env::save_to_file` | Save vars to file | `filepath vars...` | 0/1 | — |
| `env::is_ci` | Detect CI environment | — | 0/1 | — |
| `env::is_container` | Detect container | — | 0/1 | — |
| `env::get_user` | Get current username | — | 0 | username |
| `env::get_home` | Get home directory | — | 0 | path |
| `env::get_temp_dir` | Get temp directory | — | 0 | path |
| `env::is_tmux` | Detect tmux session | — | 0/1 | — |
| `env::is_screen` | Detect GNU screen | — | 0/1 | — |
| `env::self_test` | Run self-test | — | 0/1 | — |

---

### util_file — File operations

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `file::exists` | Check file exists | `path` | 0/1 | — |
| `file::is_readable` | Check file readable | `path` | 0/1 | — |
| `file::is_writable` | Check file writable | `path` | 0/1 | — |
| `file::is_executable` | Check file executable | `path` | 0/1 | — |
| `file::get_size` | Get file size | `path` | 0/1 | bytes |
| `file::is_non_empty` | Check file non-empty | `path` | 0/1 | — |
| `file::get_extension` | Get file extension | `path` | 0 | ext |
| `file::get_basename` | Get filename | `path` | 0 | basename |
| `file::get_dirname` | Get directory | `path` | 0 | dirname |
| `file::generate_filename` | Generate timestamped name | `prefix [ext]` | 0 | filename |
| `file::backup` | Create .bak backup | `path [suffix]` | 0/1 | backup path |
| `file::copy` | Copy file | `src dest` | 0/1 | — |
| `file::copy_list_from_array` | Copy files from array | `array dest` | 0/1 | — |
| `file::move` | Move file | `src dest` | 0/1 | — |
| `file::delete` | Delete file | `path` | 0/1 | — |
| `file::touch` | Create/update mtime | `path` | 0/1 | — |
| `file::append` | Append to file | `path content` | 0/1 | — |
| `file::mktemp` | Create temp file | `[template]` | 0/1 | path |
| `file::prepend` | Prepend to file | `path content` | 0/1 | — |
| `file::replace_line` | Replace pattern | `path pattern repl` | 0/1 | — |
| `file::replace_env_vars` | Replace placeholders | `path` | 0/1 | — |
| `file::contains` | Check contains pattern | `path pattern` | 0/1 | — |
| `file::count_lines` | Count lines | `path` | 0/1 | count |
| `file::get_checksum` | Compute checksum | `path [algo]` | 0/1 | checksum |
| `file::compare` | Compare two files | `file1 file2` | 0/1 | — |
| `file::restore_old_backup` | Restore .old-N backup | `path` | 0/1 | — |
| `file::self_test` | Run self-test | — | 0/1 | — |

---

### util_git — Git and GitHub utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `git::is_available` | Check git installed | — | 0/1 | — |
| `git::is_repo` | Check in git repo | — | 0/1 | — |
| `git::set_config` | Set git config value | `key value [scope]` | 0/1 | — |
| `git::stash_save` | Stash changes | `[message]` | 0/1 | — |
| `git::stash_pop` | Pop stash | — | 0/1 | — |
| `git::submodule_update` | Update submodules | — | 0/1 | — |
| `git::create_branch` | Create and checkout branch | `name` | 0/1 | — |
| `git::delete_branch` | Delete local branch | `name [--force]` | 0/1 | — |
| `git::get_branch` | Get current branch | — | 0/1 | branch |
| `git::get_commit` | Get commit hash | — | 0/1 | hash |
| `git::get_remote_url` | Get origin URL | — | 0/1 | URL |
| `git::has_changes` | Check uncommitted changes | — | 0/1 | — |
| `git::is_clean` | Check working dir clean | — | 0/1 | — |
| `git::clone` | Clone repository | `url [dest] [args]` | 0/1 | — |
| `git::pull` | Pull from remote | — | 0/1 | — |
| `git::push` | Push to remote | — | 0/1 | — |
| `git::commit` | Commit changes | `message [args]` | 0/1 | — |
| `git::tag` | Create or list tags | `[name]` | 0/1 | tag list |
| `git::checkout` | Checkout ref | `ref` | 0/1 | — |
| `git::get_root` | Get repo root | — | 0/1 | path |
| `git::get_config` | Get git config | `key` | 0/1 | value |
| `git::get_latest_release_info` | Get GitHub release info | `owner/repo os arch [vars]` | 0/1 | namerefs |
| `git::get_release` | Download GitHub release | `owner/repo os arch dest` | 0/1 | — |
| `git::self_test` | Run self-test | — | 0/1 | — |

---

### util_go — Go language utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `go::is_available` | Check Go installed | — | 0/1 | — |
| `go::get_version` | Get Go version | — | 0/1 | version |
| `go::install` | Install Go | `[version]` | 0/1 | — |
| `go::set_module_proxy` | Configure module proxy | `url` | 0 | — |
| `go::build_cross` | Cross-compile | `os arch [target]` | 0/1 | — |
| `go::work_init` | Initialize workspace | `[modules...]` | 0/1 | — |
| `go::get_gopath` | Get GOPATH | — | 0 | GOPATH |
| `go::get_goroot` | Get GOROOT | — | 0 | GOROOT |
| `go::mod_init` | Initialize module | `module_name` | 0/1 | — |
| `go::mod_tidy` | Tidy dependencies | — | 0/1 | — |
| `go::build` | Build project | `[target]` | 0/1 | — |
| `go::test` | Run tests | — | 0/1 | test output |
| `go::install_tool` | Install Go tool | `package` | 0/1 | — |
| `go::fmt` | Format code | `[path]` | 0/1 | — |
| `go::vet` | Static analysis | `[path]` | 0/1 | — |
| `go::lint` | Run linter | `[path]` | 0/1 | — |
| `go::self_test` | Run self-test | — | 0/1 | — |

---

### util_menu — Dialog-backed menus

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `menu::select_single` | Single-select menu | `title prompt opts...` | 0/1 | selection |
| `menu::select_multi` | Multi-select checklist | `title prompt opts...` | 0/1 | selections |
| `menu::select_or_input` | Select or enter value | `title prompt opts...` | 0/1 | value |
| `menu::confirm_action` | Yes/no confirmation | `prompt` | 0/1 | — |
| `menu::pause` | Pause until continue | — | 0 | — |
| `menu::dynamic_from_file` | Menu from file | `title prompt ts file` | 0/1 | selection |
| `menu::tree` | Tree-based navigation | `title prompt ts nodes...` | 0 | return val |
| `menu::self_test` | Run self-test | — | 0/1 | — |

---

### util_net — Network utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `net::is_online` | Check connectivity | `[target]` | 0/1 | — |
| `net::resolve_target_ipv6` | Resolve to IPv6 | `hostname` | 0/1 | IPv6 |
| `net::get_dns_servers` | List DNS servers | — | 0/1 | DNS IPs |
| `net::resolve_target` | Resolve to IPv4 | `hostname` | 0/1 | IPv4 |
| `net::is_local_ip` | Check local/private IP | `ip` | 0/1 | — |
| `net::get_gateway` | Get default gateway | — | 0/1 | gateway IP |
| `net::list_interfaces` | List network interfaces | — | 0/1 | iface names |
| `net::get_interface_info` | Get interface details | `interface` | 0/1 | details |
| `net::check_port` | Check port open | `host port` | 0/1 | — |
| `net::get_ip_method` | Get DHCP/Static | `interface` | 0/1 | method |
| `net::get_local_ips` | Get local IPs | — | 0/1 | iface list |
| `net::get_external_ip` | Get external IP | — | 0/1 | ext IP |
| `net::repair_connectivity` | Self-heal network | — | 0/1 | — |
| `net::full_diagnostic` | Full network check | — | 0/1 | — |
| `net::self_test` | Run self-test | — | 0/1 | — |

---

### util_os — Operating system detection

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `os::detect` | Detect OS | — | 0 | os name |
| `os::is_linux` | Check Linux | — | 0/1 | — |
| `os::is_macos` | Check macOS | — | 0/1 | — |
| `os::is_wsl` | Check WSL | — | 0/1 | — |
| `os::get_distro` | Get Linux distro | — | 0 | distro |
| `os::get_version` | Get OS version | — | 0 | version |
| `os::get_arch` | Get architecture | — | 0 | arch |
| `os::is_arm` | Check ARM arch | — | 0/1 | — |
| `os::is_x86` | Check x86 arch | — | 0/1 | — |
| `os::get_shell` | Get current shell | — | 0 | shell |
| `os::is_root` | Check root user | — | 0/1 | — |
| `os::require_root` | Require root or exit | `[message]` | 0/exit | — |
| `os::get_kernel_version` | Get kernel version | — | 0 | version |
| `os::get_hostname` | Get hostname | — | 0 | hostname |
| `os::get_uptime` | Get uptime | — | 0/1 | seconds |
| `os::get_memory_total` | Get total memory | — | 0/1 | bytes |
| `os::get_cpu_count` | Get CPU count | — | 0/1 | count |
| `os::str` | Get OS string | — | 0 | "OS ver arch" |
| `os::self_test` | Run self-test | — | 0/1 | — |

---

### util_platform — Platform abstraction

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `platform::detect_os` | Detect OS (cached) | — | 0 | os type |
| `platform::detect_variant` | Detect cmd variant | `command` | 0 | variant |
| `platform::find_command` | Find best command | `command` | 0/1 | path |
| `platform::setup_commands` | Init cmd mappings | — | 0 | — |
| `platform::stat` | Get file stats | `path format` | 0/1 | value |
| `platform::date` | Format date | `format [ts]` | 0 | date |
| `platform::sed_inplace` | In-place sed | `pattern file` | 0/1 | — |
| `platform::readlink_canonical` | Get canonical path | `path` | 0/1 | path |
| `platform::mktemp` | Create temp | `[options]` | 0/1 | path |
| `platform::timeout` | Run with timeout | `seconds cmd...` | cmd exit | output |
| `platform::dns_flush` | Flush DNS cache | — | 0/1 | — |
| `platform::network_restart` | Restart network | — | 0/1 | — |
| `platform::checksum` | Calculate checksum | `algo file` | 0/1 | checksum |
| `platform::get_interface_ip` | Get interface IP | `interface` | 0/1 | IP |
| `platform::get_interface_mac` | Get interface MAC | `interface` | 0/1 | MAC |
| `platform::info` | Show platform info | — | 0 | info |
| `platform::check_gnu_tools` | Check GNU tools | — | 0/1 | — |
| `platform::self_test` | Run self-test | — | 0/1 | — |

---

### util_py — Python utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `py::is_available` | Check Python installed | — | 0/1 | — |
| `py::is_version_available` | Check version installed | `version` | 0/1 | — |
| `py::get_major_version` | Get major version | — | 0 | 2 or 3 |
| `py::pyenv_available` | Check pyenv installed | — | 0/1 | — |
| `py::pyenv_install_version` | Install via pyenv | `version` | 0/1 | — |
| `py::get_path` | Get python path | — | 0/1 | path |
| `py::get_version` | Get Python version | — | 0 | version |
| `py::pip_supports_break_system_packages` | Check pip flag support | — | 0/1 | — |
| `py::get_pip_args` | Build pip args | — | 0 | — |
| `py::install_build_dependencies` | Install build deps | — | 0/1 | — |
| `py::get_latest_patch_version` | Get latest patch | `minor` | 0/1 | patch |
| `py::download_source` | Download source | `version` | 0/1 | path |
| `py::compile_from_source` | Compile Python | `version [prefix]` | 0/1 | — |
| `py::install_python` | Install Python | `version` | 0/1 | — |
| `py::install_pip` | Install pip | — | 0/1 | — |
| `py::install_uv` | Install uv | — | 0/1 | — |
| `py::install_pipx` | Install pipx | — | 0/1 | — |
| `py::uv_install` | Install via uv | `packages...` | 0/1 | — |
| `py::pipx_install` | Install via pipx | `package` | 0/1 | — |
| `py::create_venv` | Create virtualenv | `path` | 0/1 | — |
| `py::activate_venv` | Activate venv | `path` | 0/1 | — |
| `py::freeze_requirements` | Export requirements | `[output]` | 0/1 | — |
| `py::pip_install` | Install via pip | `packages...` | 0/1 | — |
| `py::pip_install_for_version` | Install for version | `ver packages...` | 0/1 | — |
| `py::pip_upgrade` | Upgrade pip | — | 0/1 | — |
| `py::requirements_install` | Install from file | `[file]` | 0/1 | — |
| `py::is_package_installed` | Check pkg installed | `package` | 0/1 | — |
| `py::get_package_version` | Get pkg version | `package` | 0/1 | version |
| `py::get_site_packages` | Get site-packages | — | 0/1 | path |
| `py::run_script` | Run Python script | `script [args]` | exit | output |
| `py::self_test` | Run self-test | — | 0/1 | — |

---

### util_py_multi — Multi-version Python

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `py_multi::set_versions` | Set versions to manage | `versions...` | 0 | — |
| `py_multi::get_versions` | Get configured versions | — | 0 | list |
| `py_multi::add_version` | Add version | `version` | 0/1 | — |
| `py_multi::remove_version` | Remove version | `version` | 0/1 | — |
| `py_multi::find_latest` | Find highest version | — | 0/1 | version |
| `py_multi::set_default` | Set default version | `[version]` | 0/1 | — |
| `py_multi::get_default` | Get default version | — | 0 | version |
| `py_multi::install_all` | Install all versions | `[--compile]` | 0/1 | — |
| `py_multi::install_pip_all` | Install pip for all | — | 0/1 | — |
| `py_multi::upgrade_pip_all` | Upgrade pip for all | — | 0/1 | — |
| `py_multi::pip_install_all` | Install pkgs for all | `packages...` | 0/1 | — |
| `py_multi::requirements_install_all` | Install reqs for all | `[file]` | 0/1 | — |
| `py_multi::verify_package_all` | Verify pkg all versions | `package` | 0/1 | status |
| `py_multi::pipx_install_batch` | Install pipx batch | `array_name` | 0/1 | — |
| `py_multi::status` | Show all versions status | — | 0 | table |
| `py_multi::list_installed` | List installed versions | — | 0 | list |
| `py_multi::cleanup_cache` | Clear pip caches | — | 0 | — |
| `py_multi::self_test` | Run self-test | — | 0/1 | — |

---

### util_ruby — Ruby utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `ruby::is_available` | Check Ruby installed | — | 0/1 | — |
| `ruby::gem_available` | Check gem available | — | 0/1 | — |
| `ruby::get_version` | Get Ruby version | — | 0 | version |
| `ruby::get_path` | Get Ruby path | — | 0/1 | path |
| `ruby::rbenv_available` | Check rbenv installed | — | 0/1 | — |
| `ruby::rvm_available` | Check RVM installed | — | 0/1 | — |
| `ruby::gem_install` | Install gems | `gems...` | 0/1 | — |
| `ruby::gem_install_spec` | Install with version | `spec` | 0/1 | — |
| `ruby::gem_install_batch` | Install from array | `array_name` | 0/1 | — |
| `ruby::gem_install_with_version` | Install specific version | `gem version` | 0/1 | — |
| `ruby::gem_update` | Update all gems | — | 0/1 | — |
| `ruby::install_rbenv` | Install rbenv | — | 0/1 | — |
| `ruby::rbenv_install_version` | Install via rbenv | `version` | 0/1 | — |
| `ruby::get_bundler_version` | Get Bundler version | — | 0 | version |
| `ruby::gem_cleanup` | Remove old versions | — | 0/1 | — |
| `ruby::is_gem_installed` | Check gem installed | `gem` | 0/1 | — |
| `ruby::get_gem_version` | Get gem version | `gem` | 0/1 | version |
| `ruby::gem_uninstall` | Uninstall gem | `gem` | 0/1 | — |
| `ruby::bundler_install` | Install Bundler | — | 0/1 | — |
| `ruby::bundle_install` | Run bundle install | — | 0/1 | — |
| `ruby::bundle_exec` | Run in bundle context | `command...` | exit | output |
| `ruby::run_script` | Run Ruby script | `script [args]` | exit | output |
| `ruby::list_gems` | List installed gems | — | 0 | gem list |
| `ruby::gem_outdated` | List outdated gems | — | 0 | list |
| `ruby::env_info` | Show Ruby env info | — | 0 | info |
| `ruby::self_test` | Run self-test | — | 0/1 | — |

---

### util_str — String manipulation

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `str::length` | Get string length | `string` | 0 | length |
| `str::is_empty` | Check string empty | `string` | 0/1 | — |
| `str::is_not_empty` | Check string not empty | `string` | 0/1 | — |
| `str::is_blank` | Check blank/whitespace | `string` | 0/1 | — |
| `str::to_upper` | Convert to uppercase | `string` | 0 | UPPER |
| `str::to_lower` | Convert to lowercase | `string` | 0 | lower |
| `str::capitalize` | Capitalize first char | `string` | 0 | String |
| `str::to_title_case` | Title Case Each Word | `string` | 0 | Title |
| `str::trim` | Trim whitespace | `string` | 0 | trimmed |
| `str::trim_left` | Trim left whitespace | `string` | 0 | trimmed |
| `str::trim_right` | Trim right whitespace | `string` | 0 | trimmed |
| `str::pad_left` | Pad on left | `string len [ch]` | 0 | padded |
| `str::pad_right` | Pad on right | `string len [ch]` | 0 | padded |
| `str::substring` | Extract substring | `string start [len]` | 0 | substr |
| `str::contains` | Check contains substr | `string substr` | 0/1 | — |
| `str::starts_with` | Check starts with | `string prefix` | 0/1 | — |
| `str::ends_with` | Check ends with | `string suffix` | 0/1 | — |
| `str::replace` | Replace first match | `string pat repl` | 0 | modified |
| `str::replace_all` | Replace all matches | `string pat repl` | 0 | modified |
| `str::remove` | Remove first match | `string pattern` | 0 | modified |
| `str::remove_all` | Remove all matches | `string pattern` | 0 | modified |
| `str::split` | Split to array | `string delim arr` | 0 | — |
| `str::join` | Join array | `delim array_name` | 0 | joined |
| `str::is_integer` | Check integer | `string` | 0/1 | — |
| `str::is_positive_integer` | Check positive int | `string` | 0/1 | — |
| `str::is_float` | Check float | `string` | 0/1 | — |
| `str::is_alpha` | Check alphabetic | `string` | 0/1 | — |
| `str::is_alphanumeric` | Check alphanumeric | `string` | 0/1 | — |
| `str::matches` | Check regex match | `string pattern` | 0/1 | — |
| `str::repeat` | Repeat string n times | `string count` | 0 | repeated |
| `str::reverse` | Reverse string | `string` | 0 | reversed |
| `str::count` | Count occurrences | `string substr` | 0 | count |
| `str::truncate` | Truncate with suffix | `string len [sfx]` | 0 | truncated |
| `str::in_list` | Check value in list | `value array` | 0/1 | — |
| `str::self_test` | Run self-test | — | 0/1 | — |

---

### util_tools — Tool installation

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `tools::add_function` | Add alias function | `name body` | 0/1 | — |
| `tools::remove_function` | Remove alias function | `name` | 0/1 | — |
| `tools::list_functions` | List tool functions | — | 0 | list |
| `tools::install_git_python` | Clone + venv + alias | `repo_url [name]` | 0/1 | — |
| `tools::install_git_tool` | Clone + alias | `repo_url [name]` | 0/1 | — |
| `tools::test` | Test tool working | `tool_name` | 0/1 | — |
| `tools::test_batch` | Batch test tools | `array_name` | 0/1 | results |
| `tools::apply_fixes` | Apply tool fixes | `array_name` | 0/1 | — |
| `tools::get_install_status` | Get install status | `tool_name` | 0/1 | status |
| `tools::list_installed` | List installed tools | — | 0 | list |
| `tools::run_command` | Run tool command | `tool args...` | exit | output |
| `tools::self_test` | Run self-test | — | 0/1 | — |

---

### util_trap — Cleanup and trap management

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `trap::add_cleanup` | Add cleanup function | `function_name` | 0 | — |
| `trap::add_temp_file` | Register temp file | `filepath` | 0 | — |
| `trap::add_temp_dir` | Register temp dir | `dirpath` | 0 | — |
| `trap::with_cleanup` | Run with cleanup | `command...` | exit | output |
| `trap::clear_all` | Clear all cleanups | — | 0 | — |
| `trap::list` | List cleanups | — | 0 | list |
| `trap::self_test` | Run self-test | — | 0/1 | — |

---

### util_tui — Terminal UI utilities

| Function | Description | Arguments | Returns | Output |
|----------|-------------|-----------|---------|--------|
| `tui::prompt_yes_no` | Yes/no prompt | `question [def]` | 0/1 | — |
| `tui::prompt_input` | Text input prompt | `prompt [default]` | 0/1 | input |
| `tui::prompt_select` | Single-select menu | `prompt opts...` | 0/1 | selection |
| `tui::prompt_multiselect` | Multi-select menu | `prompt opts...` | 0/1 | selections |
| `tui::msg` | Display message box | `message` | 0 | — |
| `tui::show_spinner` | Show spinner | `message cmd...` | exit | — |
| `tui::show_dots` | Show animated dots | `message cmd...` | exit | — |
| `tui::show_progress_bar` | Show progress bar | `percent message` | 0 | — |
| `tui::show_timer` | Show elapsed time | `command...` | exit | — |
| `tui::is_terminal` | Check interactive | — | 0/1 | — |
| `tui::supports_color` | Check color support | — | 0/1 | — |
| `tui::get_terminal_width` | Get terminal width | — | 0 | columns |
| `tui::clear_line` | Clear current line | — | 0 | — |
| `tui::pause` | Pause for ENTER | — | 0 | — |
| `tui::strip_color` | Remove ANSI codes | `[text]` | 0 | stripped |
| `tui::self_test` | Run self-test | — | 0/1 | — |
