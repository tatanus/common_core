# Common Core

# Project Badges

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://github.com/tatanus/common_core/actions/workflows/main.yml/badge.svg)](https://github.com/tatanus/common_core/actions/workflows/main.yml)
[![Last Commit](https://img.shields.io/github/last-commit/tatanus/common_core)](https://github.com/tatanus/common_core/commits/main)

![Bash >=4.0](https://img.shields.io/badge/Bash-%3E%3D4.0-4EAA25?logo=gnu-bash&logoColor=white)

**common_core** is the single, shared Bash **core** for varius projects:

A comprehensive, modular bash utility library providing cross-platform support for Linux, macOS, and WSL. This library follows strict coding standards for security, maintainability, and portability.

## Features

- **Cross-platform compatibility** - Works on Linux, macOS, and WSL with automatic command abstraction
- **Secure by default** - No `eval` in user-facing APIs, proper quoting, input validation
- **Comprehensive logging** - Consistent logging with multiple levels
- **Self-testing** - Every module includes `::self_test` functions
- **Configuration system** - Centralized, validated configuration management

## Quick Start

### Installation

1. Clone the repository and run the installer:
```bash
git clone https://github.com/tatanus/common_core.git
cd common_core
./install.sh
```

This installs the library to `~/.config/bash/lib/common_core/` and configures your `.bashrc` to source it automatically.

2. Source the main loader in your script:

```bash
#!/usr/bin/env bash
source /path/to/util.sh
```

This automatically loads all modules in the correct dependency order.

---

## 📅 Authorship & Licensing

**Author**: Adam Compton
**Date Created**: 2024-12-15
This project is provided under the [MIT License](./LICENSE). Feel free to use and modify it for your needs.

