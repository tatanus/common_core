# util_tui.sh - Terminal UI Utilities

Terminal user interface utilities providing spinners, progress bars, prompts, and dialog-backed interactions with safe fallbacks for non-interactive environments.

## Overview

This module provides:
- Animated spinners and progress indicators
- Interactive prompts (yes/no, text input, selection)
- Dialog-based UI when available
- Terminal capability detection

## Dependencies

- None (standalone module)

## Key Features

- **Array-based command execution** - Commands run in the current shell environment
- **Dialog fallback** - Uses dialog when available, falls back to simple prompts
- **Terminal detection** - Adapts to interactive vs non-interactive environments

## Functions

### Spinner and Progress

#### tui::show_spinner

Display an animated spinner while a command runs or while waiting for a process.

```bash
# Run command with spinner (array-based)
tui::show_spinner -- curl -fsSL https://example.com/file.tar.gz -o file.tar.gz

# Monitor existing background process
long_running_command &
tui::show_spinner $!
```

**Arguments:**
- `$1` - Either `--` (followed by command) or a PID to monitor
- `$@` - Command and arguments (when using `--`)

**Returns:** Exit code of the monitored process

**Notes:**
- Commands inherit the current shell environment (variables, functions)
- Use `--` separator when running commands
- Output shows elapsed time: `Processing... | (5s)`

#### tui::show_dots

Display simple animated dots while a command or process runs.

```bash
tui::show_dots -- make build
tui::show_dots $background_pid
```

**Arguments:** Same as `tui::show_spinner`

**Returns:** Exit code of the monitored process

#### tui::show_timer

Run a command and display elapsed time upon completion.

```bash
tui::show_timer make build
```

**Arguments:**
- `$@` - Command and arguments to execute

**Returns:** Exit code of the command

#### tui::show_progress_bar

Display a progress bar for percentage-based operations.

```bash
for i in {0..100..10}; do
    tui::show_progress_bar $i
    sleep 0.1
done
```

**Arguments:**
- `$1` - Percentage (0-100)

**Returns:** `PASS` always

### Prompts

#### tui::prompt_yes_no

Display a yes/no confirmation prompt.

```bash
if tui::prompt_yes_no "Proceed with installation?"; then
    install_package
fi
```

**Arguments:**
- `$1` - Prompt text (optional, default: "Continue?")

**Returns:** `PASS` (0) if yes, `FAIL` (1) if no

#### tui::prompt_input

Prompt for text input with optional default value.

```bash
name=$(tui::prompt_input "Enter your name" "Anonymous")
```

**Arguments:**
- `$1` - Prompt text
- `$2` - Default value (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on cancel

**Outputs:** User input or default value

#### tui::prompt_select

Display a single-selection menu.

```bash
choice=$(tui::prompt_select "Choose an option" "Option A" "Option B" "Option C")
```

**Arguments:**
- `$1` - Prompt text
- `$@` - Options to choose from

**Returns:** `PASS` (0) on selection, `FAIL` (1) on cancel

**Outputs:** Selected option

#### tui::prompt_multiselect

Display a multi-selection checklist.

```bash
selections=$(tui::prompt_multiselect "Select items" "Item 1" "Item 2" "Item 3")
```

**Arguments:**
- `$1` - Prompt text
- `$@` - Items to select from

**Returns:** `PASS` (0) on confirm, `FAIL` (1) on cancel

**Outputs:** Space-separated list of selected items

#### tui::prompt_password

Prompt for password input (hidden characters).

```bash
password=$(tui::prompt_password "Enter password")
```

**Arguments:**
- `$1` - Prompt text (optional)

**Returns:** `PASS` (0) on input, `FAIL` (1) on cancel

**Outputs:** Entered password

### Messages

#### tui::msg

Display a message box.

```bash
tui::msg "Operation completed successfully!"
```

**Arguments:**
- `$1` - Message to display

**Returns:** `PASS` always

### Terminal Utilities

#### tui::is_terminal

Check if running in an interactive terminal.

```bash
if tui::is_terminal; then
    # Use interactive features
else
    # Use non-interactive fallbacks
fi
```

**Returns:** `PASS` (0) if terminal, `FAIL` (1) otherwise

#### tui::supports_color

Check if terminal supports color output.

```bash
if tui::supports_color; then
    echo -e "\033[32mGreen text\033[0m"
fi
```

**Returns:** `PASS` (0) if color supported, `FAIL` (1) otherwise

#### tui::get_terminal_width

Get terminal width in columns.

```bash
width=$(tui::get_terminal_width)
```

**Returns:** `PASS` always

**Outputs:** Terminal width (default: 80)

#### tui::get_terminal_height

Get terminal height in lines.

```bash
height=$(tui::get_terminal_height)
```

**Returns:** `PASS` always

**Outputs:** Terminal height (default: 24)

## Examples

### Installation Script with Progress

```bash
#!/usr/bin/env bash
source util.sh

info "Starting installation..."

if ! tui::prompt_yes_no "This will install packages. Continue?"; then
    info "Installation cancelled"
    exit 0
fi

# Show spinner while downloading
tui::show_spinner -- curl -fsSL https://example.com/installer.sh -o /tmp/installer.sh

# Show spinner while running installer
tui::show_spinner -- bash /tmp/installer.sh

pass "Installation complete!"
```

### Interactive Configuration

```bash
#!/usr/bin/env bash
source util.sh

# Get user preferences
name=$(tui::prompt_input "Enter your name" "${USER}")
shell=$(tui::prompt_select "Choose shell" "bash" "zsh" "fish")

# Multi-select features
features=$(tui::prompt_multiselect "Select features" \
    "syntax-highlighting" \
    "auto-complete" \
    "themes" \
    "plugins")

echo "Configuring ${shell} for ${name} with: ${features}"
```

### Background Process Monitoring

```bash
#!/usr/bin/env bash
source util.sh

# Start long-running process in background
make build &
build_pid=$!

# Monitor with spinner
tui::show_spinner $build_pid

# Check exit status
if [[ $? -eq 0 ]]; then
    pass "Build succeeded"
else
    fail "Build failed"
fi
```

## Self-Test

```bash
source util.sh
tui::self_test
```

## Notes

- When `dialog` is installed, prompts use dialog-based UI
- Without dialog, falls back to simple terminal prompts
- Spinner functions run commands in subshells but inherit the parent environment
- The `--` separator is required for commands to distinguish from PID monitoring
