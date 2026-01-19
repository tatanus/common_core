# util_menu.sh - Dialog-Backed Menu Utilities

Dialog-backed menu utilities providing primitive menus and hierarchical tree menus with timestamp tracking.

## Overview

This module provides:
- Single-select and multi-select menus via `dialog`
- Hierarchical tree menus with breadcrumb navigation
- Timestamp tracking for menu items
- Dynamic menus loaded from files
- Confirmation dialogs and pause utilities

## Dependencies

- `util_config.sh` - Must be loaded before this module
- `dialog` - System command for terminal dialogs

## Global Variables

| Variable | Description |
|----------|-------------|
| `MENU_TIMESTAMP_FILE` | File storing per-menu item timestamps (default: `~/.local/state/menu_timestamps`) |
| `MENU_BREADCRUMB` | Array tracking navigation path |

## Configuration

Menu behavior can be configured via `config::set`:

```bash
config::set "menu.timestamps" "true"    # Show last-run timestamps
config::set "menu.breadcrumbs" "true"   # Show navigation breadcrumbs
```

## Functions

### Primitive Menu Utilities

#### menu::select_single

Display a single-select menu using dialog.

```bash
choice=$(menu::select_single "Title" "Select an option:" "Option 1" "Option 2" "Option 3")
echo "You chose: ${choice}"
```

**Arguments:**
- `$1` - Menu title
- `$2` - Prompt / message
- `$3..` - Options (each a label string)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error or cancel

**Outputs:** Selected option to stdout

---

#### menu::select_multi

Display a multi-select checklist using dialog.

```bash
selections=$(menu::select_multi "Features" "Select features to enable:" "Logging" "Debug" "Verbose")
echo "Selected: ${selections}"
```

**Arguments:**
- `$1` - Menu title
- `$2` - Prompt / message
- `$3..` - Options (each a label string)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error or cancel

**Outputs:** Space-separated selected options to stdout

---

#### menu::select_or_input

Display a single-select menu with an option for manual input.

```bash
value=$(menu::select_or_input "Server" "Select or enter server:" "localhost" "192.168.1.1")
echo "Server: ${value}"
```

**Arguments:**
- `$1` - Menu title
- `$2` - Prompt / message
- `$3..` - Options (each a label string)

**Behavior:**
- If user selects a listed option, that option is printed
- If user chooses "Manual entry", `tui::prompt_input` is used

**Returns:** `PASS` (0) on success, `FAIL` (1) on error or cancel

**Outputs:** Chosen or manually entered value to stdout

---

#### menu::confirm_action

Confirm a risky or important action (yes/no).

```bash
if menu::confirm_action "Delete all data?"; then
    rm -rf data/
fi
```

**Arguments:**
- `$1` - Confirmation prompt

**Returns:** `PASS` (0) if user confirmed, `FAIL` (1) if declined or canceled

---

#### menu::pause

Pause execution until the user presses ENTER.

```bash
echo "Operation complete."
menu::pause
```

**Returns:** `PASS` (0) always

---

### Dynamic Menus

#### menu::dynamic_from_file

Display a menu whose options are loaded dynamically from a file.

```bash
choice=$(menu::dynamic_from_file "Targets" "Choose a host:" false "/path/to/targets.txt")
```

**Arguments:**
- `$1` - Menu title
- `$2` - Prompt / message
- `$3` - Use timestamps (`true` or `false`)
- `$4` - Path to file containing options (one per line)

**File Format:**
- One option per line
- Lines starting with `#` are ignored (comments)
- Blank lines are ignored

**Returns:** `PASS` (0) on success, `FAIL` (1) if file missing, empty, or user cancels

**Outputs:** Selected option to stdout

---

### Hierarchical Menu Engine

#### menu::tree

The default menu renderer for all menus. Supports hierarchical navigation with submenus, function calls, commands, and return values.

```bash
declare -a MAIN_MENU=(
    "Install Tools|func|install_tools"
    "Configure|menu|CONFIG_MENU"
    "Run Tests|cmd|pytest tests/"
    "About|return|v1.0.0"
)

declare -a CONFIG_MENU=(
    "Network Settings|func|configure_network"
    "User Settings|func|configure_user"
)

result=$(menu::tree "Main Menu" "Select an action:" false "${MAIN_MENU[@]}")
```

**Arguments:**
- `$1` - Menu title
- `$2` - Menu prompt text
- `$3` - Whether to show timestamps (`true` or `false`)
- `$@` - Node array in format `"Label|TYPE|TARGET"`

**Node Types:**

| Type | Description | TARGET |
|------|-------------|--------|
| `menu` | Opens a submenu | Name of array variable containing submenu nodes |
| `func` | Calls a function | Function name (e.g., `install_packages`) |
| `cmd` | Executes a shell command | Shell command string |
| `return` | Returns a value and exits | Value to return |

**Returns:** `PASS` (0) always

**Outputs:** For `return` type nodes, prints the target value to stdout

**Features:**
- Automatic "Back" option added to all menus
- Breadcrumb navigation (when enabled)
- Timestamp tracking (when enabled)
- ESC key returns to previous menu

---

## Examples

### Simple Single-Select Menu

```bash
#!/usr/bin/env bash
source util.sh

action=$(menu::select_single "Actions" "What would you like to do?" \
    "Install" "Update" "Remove" "Exit")

case "${action}" in
    Install) install_packages ;;
    Update)  update_packages ;;
    Remove)  remove_packages ;;
    Exit)    exit 0 ;;
esac
```

### Hierarchical Menu with Submenus

```bash
#!/usr/bin/env bash
source util.sh

# Define submenu
declare -a NETWORK_MENU=(
    "Show IP|func|show_ip"
    "Test Connectivity|func|test_connection"
    "DNS Lookup|func|dns_lookup"
)

# Define main menu
declare -a MAIN_MENU=(
    "Network Tools|menu|NETWORK_MENU"
    "System Info|func|show_system_info"
    "Exit|return|exit"
)

function show_ip() {
    net::get_local_ips
}

function test_connection() {
    net::is_online && pass "Online" || fail "Offline"
}

function show_system_info() {
    os::str
}

# Run the menu
result=$(menu::tree "System Tools" "Select a category:" false "${MAIN_MENU[@]}")

if [[ "${result}" == "exit" ]]; then
    exit 0
fi
```

### Menu with Timestamps

```bash
#!/usr/bin/env bash
source util.sh

declare -a TASKS=(
    "Backup Database|func|backup_db"
    "Clear Cache|func|clear_cache"
    "Generate Report|func|gen_report"
)

# Enable timestamps to show when each task was last run
menu::tree "Maintenance Tasks" "Select a task:" true "${TASKS[@]}"
```

### Dynamic Menu from File

```bash
#!/usr/bin/env bash
source util.sh

# targets.txt contains:
# server1.example.com
# server2.example.com
# # This is a comment
# server3.example.com

target=$(menu::dynamic_from_file "Targets" "Select deployment target:" false "targets.txt")
echo "Deploying to: ${target}"
```

### Confirmation Before Dangerous Action

```bash
#!/usr/bin/env bash
source util.sh

if menu::confirm_action "This will delete all logs. Continue?"; then
    rm -rf /var/log/app/*
    pass "Logs deleted"
else
    info "Operation cancelled"
fi
```

### Mixed Menu with Commands and Functions

```bash
#!/usr/bin/env bash
source util.sh

declare -a DEV_MENU=(
    "Run Tests|cmd|pytest -v tests/"
    "Build Project|cmd|make build"
    "Deploy|func|deploy_to_staging"
    "View Logs|cmd|tail -f /var/log/app.log"
    "Version|return|1.2.3"
)

version=$(menu::tree "Developer Tools" "Select action:" false "${DEV_MENU[@]}")
[[ -n "${version}" ]] && echo "Version: ${version}"
```

## Internal Functions

These functions are used internally but are documented for completeness:

| Function | Purpose |
|----------|---------|
| `menu::_push_breadcrumb` | Add item to breadcrumb trail |
| `menu::_pop_breadcrumb` | Remove last item from breadcrumb |
| `menu::_get_breadcrumb` | Get current breadcrumb as string |
| `menu::_dialog` | Thin wrapper around `dialog` command |
| `menu::_timestamp_get` | Retrieve timestamp for menu item |
| `menu::_timestamp_set` | Set/update timestamp for menu item |

## Self-Test

```bash
source util.sh
menu::self_test
```

## Security Notes

- The `cmd` node type uses `eval` to execute commands
- Menu nodes should only be defined in source code, never from user input
- For user-provided commands, use `func` type with proper validation
- The timestamp file is stored in user's state directory

## Notes

- Requires `dialog` to be installed on the system
- Supports arrow keys, mouse, and ENTER for navigation
- ESC key or "Back" option returns to previous menu level
- Timestamps are stored persistently across sessions
