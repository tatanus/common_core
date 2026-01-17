# util_menu.sh - Interactive Menu System

Interactive menu system for building command-line interfaces.

## Overview

This module provides:
- Dynamic menu creation
- Item selection handling
- Nested menu support
- Action callbacks

## Dependencies

- `util_tui.sh`

## Functions

### Menu Creation

#### menu::create

Create a new menu.

```bash
menu::create "Main Menu"
```

**Arguments:**
- `$1` - Menu title

**Returns:** `PASS` (0) always

#### menu::add_item

Add an item to the current menu.

```bash
menu::add_item "Install packages" "install_packages"
menu::add_item "Configure system" "configure_system"
menu::add_item "Exit" "exit 0"
```

**Arguments:**
- `$1` - Item label
- `$2` - Action (function name or command)

**Returns:** `PASS` (0) always

#### menu::add_separator

Add a visual separator.

```bash
menu::add_separator
```

**Returns:** `PASS` (0) always

#### menu::clear

Clear all menu items.

```bash
menu::clear
```

**Returns:** `PASS` (0) always

### Menu Display

#### menu::show

Display the menu and handle selection.

```bash
menu::show
```

**Returns:** Result of selected action

**Notes:** Loops until exit action is selected

## Examples

### Simple Menu

```bash
#!/usr/bin/env bash
source util.sh

install_packages() {
    info "Installing packages..."
    # installation code
}

configure_system() {
    info "Configuring system..."
    # configuration code
}

main_menu() {
    menu::create "Main Menu"
    menu::add_item "Install packages" "install_packages"
    menu::add_item "Configure system" "configure_system"
    menu::add_separator
    menu::add_item "Exit" "return 0"
    menu::show
}

main_menu
```

### Nested Menus

```bash
#!/usr/bin/env bash
source util.sh

network_menu() {
    menu::create "Network Settings"
    menu::add_item "Show IP" "net::get_local_ip"
    menu::add_item "Check connectivity" "net::is_online"
    menu::add_item "Back" "return 0"
    menu::show
}

main_menu() {
    menu::create "System Tools"
    menu::add_item "Network" "network_menu"
    menu::add_item "Disk usage" "df -h"
    menu::add_item "Exit" "exit 0"
    menu::show
}

main_menu
```

## Self-Test

```bash
source util.sh
menu::self_test
```
