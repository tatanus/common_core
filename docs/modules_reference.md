# Module Reference Guide

Quick reference for all utility modules in the bash utility library.

---

## util_trap.sh - Trap Handling

Safe trap handling and automatic cleanup utilities.

### Key Functions

| Function | Description |
|----------|-------------|
| `trap::add_cleanup "func"` | Add cleanup function to exit trap |
| `trap::add_temp_file "$path"` | Register temp file for auto-cleanup |
| `trap::add_temp_dir "$path"` | Register temp directory for auto-cleanup |
| `trap::with_cleanup cmd...` | Run command and auto-register output for cleanup |
| `trap::clear_all` | Clear all cleanup registrations |

### Example

```bash
# Auto-cleanup temp file
tmp=$(trap::with_cleanup mktemp)
echo "data" > "$tmp"
# File automatically deleted on exit
```

---

## util_str.sh - String Manipulation

String manipulation using Bash built-ins.

### Key Functions

| Function | Description |
|----------|-------------|
| `str::length "$str"` | Get string length |
| `str::is_empty "$str"` | Check if empty |
| `str::is_blank "$str"` | Check if empty/whitespace |
| `str::to_upper "$str"` | Convert to uppercase |
| `str::to_lower "$str"` | Convert to lowercase |
| `str::trim "$str"` | Trim whitespace |
| `str::substring "$str" start len` | Extract substring |
| `str::contains "$str" "$sub"` | Check for substring |
| `str::starts_with "$str" "$prefix"` | Check prefix |
| `str::ends_with "$str" "$suffix"` | Check suffix |
| `str::replace "$str" "$old" "$new"` | Replace first occurrence |
| `str::replace_all "$str" "$old" "$new"` | Replace all occurrences |
| `str::split "$str" "$delim"` | Split into array |
| `str::join "$delim" "${arr[@]}"` | Join array |
| `str::is_integer "$str"` | Check if integer |
| `str::is_float "$str"` | Check if float |
| `str::matches "$str" "$regex"` | Regex match |
| `str::repeat "$str" count` | Repeat string |
| `str::reverse "$str"` | Reverse string |

### Example

```bash
name=$(str::trim "  hello world  ")
upper=$(str::to_upper "$name")
if str::contains "$upper" "WORLD"; then
    echo "Found!"
fi
```

---

## util_env.sh - Environment Variables

Environment variable management and inspection.

### Key Functions

| Function | Description |
|----------|-------------|
| `env::get "VAR" "default"` | Get environment variable |
| `env::set "VAR" "value"` | Set environment variable |
| `env::unset "VAR"` | Unset variable |
| `env::exists "VAR"` | Check if exists |
| `env::require "VAR"` | Require variable (exit if missing) |
| `env::export_file "$path"` | Export from .env file |
| `env::save_to_file "$path"` | Save env to file |
| `env::is_ci` | Check if running in CI |
| `env::is_container` | Check if in container |
| `env::get_user` | Get current username |
| `env::get_home` | Get home directory |
| `env::get_temp_dir` | Get temp directory |
| `env::is_tmux` | Check if in tmux |

### XDG Directories

```bash
config=$(env::get_xdg_config_home)  # ~/.config
data=$(env::get_xdg_data_home)      # ~/.local/share
cache=$(env::get_xdg_cache_home)    # ~/.cache
```

---

## util_dir.sh - Directory Operations

Directory operations with safety checks.

### Key Functions

| Function | Description |
|----------|-------------|
| `dir::exists "$path"` | Check if exists |
| `dir::is_empty "$path"` | Check if empty |
| `dir::create "$path"` | Create directory |
| `dir::delete "$path"` | Delete directory |
| `dir::copy "$src" "$dst"` | Copy directory |
| `dir::move "$src" "$dst"` | Move directory |
| `dir::get_size "$path"` | Get size |
| `dir::list_files "$path"` | List files |
| `dir::list_dirs "$path"` | List subdirectories |
| `dir::find_files "$path" "pattern"` | Find files by pattern |
| `dir::backup "$path"` | Backup directory |
| `dir::tempdir` | Create temp directory |
| `dir::push "$path"` | Push directory (pushd) |
| `dir::pop` | Pop directory (popd) |
| `dir::ensure_exists "$path"` | Create if missing |
| `dir::count_files "$path"` | Count files |

---

## util_os.sh - OS Detection

Operating system detection and information.

### Key Functions

| Function | Description |
|----------|-------------|
| `os::detect` | Get OS name |
| `os::is_linux` | Check if Linux |
| `os::is_macos` | Check if macOS |
| `os::is_wsl` | Check if WSL |
| `os::get_distro` | Get Linux distro |
| `os::get_version` | Get OS version |
| `os::get_arch` | Get architecture |
| `os::get_kernel` | Get kernel version |
| `os::get_hostname` | Get hostname |
| `os::get_memory` | Get total memory |
| `os::get_cpu_count` | Get CPU count |

### Example

```bash
if os::is_linux; then
    distro=$(os::get_distro)
    echo "Running on ${distro}"
fi
```

---

## util_curl.sh - HTTP Operations

HTTP/HTTPS operations using curl.

### Key Functions

| Function | Description |
|----------|-------------|
| `curl::is_available` | Check if curl installed |
| `curl::get "$url"` | HTTP GET (returns body) |
| `curl::post "$url" "$data"` | HTTP POST |
| `curl::put "$url" "$data"` | HTTP PUT |
| `curl::delete "$url"` | HTTP DELETE |
| `curl::download "$url" "$path"` | Download file |
| `curl::get_status_code "$url"` | Get HTTP status |
| `curl::get_headers "$url"` | Get response headers |
| `curl::get_with_retry "$url" attempts delay` | GET with retry |
| `curl::with_auth "$url" "$user" "$pass"` | GET with basic auth |
| `curl::with_headers "$url" "Header: value"...` | GET with headers |
| `curl::get_response_time "$url"` | Measure response time |

### Example

```bash
if body=$(curl::get "https://api.example.com/data"); then
    echo "Response: ${body}"
fi

curl::download "https://example.com/file.tar.gz" "/tmp/file.tar.gz"
```

---

## util_git.sh - Git Operations

Git and GitHub operations.

### Key Functions

| Function | Description |
|----------|-------------|
| `git::is_available` | Check if git installed |
| `git::is_repo` | Check if in git repo |
| `git::clone "$url" "$path"` | Clone repository |
| `git::pull` | Pull changes |
| `git::push` | Push changes |
| `git::commit "message"` | Commit changes |
| `git::get_branch` | Get current branch |
| `git::create_branch "name"` | Create branch |
| `git::delete_branch "name"` | Delete branch |
| `git::checkout "ref"` | Checkout branch/commit |
| `git::has_changes` | Check for uncommitted changes |
| `git::is_clean` | Check if working tree clean |
| `git::stash_save "msg"` | Stash changes |
| `git::stash_pop` | Pop stash |
| `git::get_commit` | Get current commit hash |
| `git::get_remote_url` | Get remote URL |
| `git::get_root` | Get repo root directory |
| `git::set_config "key" "value"` | Set git config |
| `git::tag "name"` | Create tag |
| `git::get_release "$owner" "$repo"` | Download GitHub release |

---

## util_net.sh - Network Utilities

Network management and diagnostics.

### Key Functions

| Function | Description |
|----------|-------------|
| `net::is_online` | Check internet connectivity |
| `net::get_local_ip` | Get local IP address |
| `net::get_external_ip` | Get external IP address |
| `net::get_default_interface` | Get default network interface |
| `net::get_gateway` | Get default gateway |
| `net::get_dns_servers` | Get DNS servers |
| `net::check_port "$host" "$port"` | Check if port is open |
| `net::resolve_target "$host"` | Resolve hostname to IP |
| `net::ping "$host"` | Ping host |
| `net::get_ip_method "$iface"` | Get DHCP/Static status |
| `net::repair_connectivity` | Attempt network repair |

---

## util_apt.sh - APT Package Manager

Debian/Ubuntu package management.

### Key Functions

| Function | Description |
|----------|-------------|
| `apt::is_available` | Check if apt available |
| `apt::update` | Update package lists |
| `apt::install "pkg"...` | Install packages |
| `apt::remove "pkg"...` | Remove packages |
| `apt::upgrade` | Upgrade all packages |
| `apt::is_installed "pkg"` | Check if installed |
| `apt::get_version "pkg"` | Get package version |
| `apt::search "pattern"` | Search packages |
| `apt::autoremove` | Remove unused packages |
| `apt::add_repo "$ppa"` | Add PPA repository |

---

## util_brew.sh - Homebrew Package Manager

Homebrew package management for macOS/Linux.

### Key Functions

| Function | Description |
|----------|-------------|
| `brew::is_available` | Check if brew available |
| `brew::install_self` | Install Homebrew |
| `brew::update` | Update Homebrew |
| `brew::install "pkg"...` | Install packages |
| `brew::uninstall "pkg"...` | Uninstall packages |
| `brew::upgrade` | Upgrade all packages |
| `brew::is_installed "pkg"` | Check if installed |
| `brew::tap "repo"` | Add tap |
| `brew::cask_install "pkg"` | Install cask |
| `brew::search "pattern"` | Search packages |

---

## util_py.sh - Python Environment

Python environment and package management.

### Key Functions

| Function | Description |
|----------|-------------|
| `py::is_available` | Check if Python available |
| `py::get_version` | Get Python version |
| `py::get_path` | Get Python path |
| `py::create_venv "$path"` | Create virtual environment |
| `py::activate_venv "$path"` | Activate venv |
| `py::pip_install "pkg"...` | Install packages |
| `py::requirements_install "$file"` | Install from requirements.txt |
| `py::is_package_installed "pkg"` | Check if package installed |
| `py::install_pip` | Install/upgrade pip |
| `py::install_uv` | Install uv (fast pip) |
| `py::install_pipx` | Install pipx |
| `py::uv_install "pkg"` | Install with uv |
| `py::pipx_install "pkg"` | Install with pipx |
| `py::run_script "$script"` | Run Python script |

---

## util_ruby.sh - Ruby Environment

Ruby environment and gem management.

### Key Functions

| Function | Description |
|----------|-------------|
| `ruby::is_available` | Check if Ruby available |
| `ruby::get_version` | Get Ruby version |
| `ruby::gem_install "gem"...` | Install gems |
| `ruby::gem_update` | Update all gems |
| `ruby::is_gem_installed "gem"` | Check if gem installed |
| `ruby::bundler_install` | Run bundle install |
| `ruby::bundler_exec cmd...` | Run via bundler |

---

## util_go.sh - Go Environment

Go environment management.

### Key Functions

| Function | Description |
|----------|-------------|
| `go::is_available` | Check if Go available |
| `go::get_version` | Get Go version |
| `go::install "pkg"` | Install Go package |
| `go::build` | Build current project |
| `go::test` | Run tests |
| `go::mod_init "name"` | Initialize module |
| `go::mod_tidy` | Tidy dependencies |

---

## util_menu.sh - Interactive Menus

Interactive menu system.

### Key Functions

| Function | Description |
|----------|-------------|
| `menu::create "title"` | Create new menu |
| `menu::add_item "label" "action"` | Add menu item |
| `menu::show` | Display and run menu |
| `menu::clear` | Clear menu items |

---

## util_tools.sh - Tool Management

Tool installation and management.

### Key Functions

| Function | Description |
|----------|-------------|
| `tools::install_git_tool "$repo" "$name"` | Install from git |
| `tools::install_git_python "$repo" "$name"` | Install Python tool from git |
| `tools::add_function "name" "body"` | Add shell function |
| `tools::remove_function "name"` | Remove shell function |
| `tools::list_installed` | List installed tools |
| `tools::test "name" "command"` | Test tool |
| `tools::run_command "name" args...` | Run tool command |
