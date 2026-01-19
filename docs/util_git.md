# util_git.sh - Git Operations

Git repository management and GitHub integration utilities for common version control tasks.

## Overview

This module provides:
- Repository operations (clone, pull, push, commit)
- Branch management
- Status and information queries
- GitHub release downloads
- Git configuration management

## Dependencies

- `util_platform.sh` - Platform detection utilities
- `util_config.sh` - Configuration management
- `util_trap.sh` - Trap and cleanup utilities
- `util_cmd.sh` - Command execution utilities (for `cmd::exists`, `cmd::run`)
- `util_curl.sh` - HTTP utilities (for GitHub API calls)

## Functions

### Availability

#### git::is_available

Check if git is installed and accessible.

```bash
if git::is_available; then
    echo "Git is available"
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

#### git::is_repo

Check if current directory is a git repository.

```bash
if git::is_repo; then
    echo "Inside a git repository"
fi
```

**Returns:** `PASS` (0) if in repo, `FAIL` (1) otherwise

### Repository Operations

#### git::clone

Clone a repository.

```bash
git::clone "https://github.com/user/repo.git" "/path/to/dest"
git::clone "git@github.com:user/repo.git"  # Clones to current directory
git::clone "https://github.com/user/repo.git" "/path/to/dest" --depth 1  # With extra args
```

**Arguments:**
- `$1` - Repository URL (required)
- `$2` - Destination path (optional, defaults to repo name)
- `$@` - Additional git clone arguments (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::pull

Pull latest changes from remote with rebase.

```bash
git::pull
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- Uses `git pull --rebase` internally
- Auto-fetches first if `git.auto_fetch` config is enabled

#### git::push

Push commits to remote.

```bash
git::push
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::commit

Stage all changes and commit.

```bash
git::commit "Add new feature"
git::commit "Add new feature" --no-verify  # With extra args
```

**Arguments:**
- `$1` - Commit message (required)
- `$@` - Additional git commit arguments (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Stages all changes (`git add -A`) before committing

### Branch Management

#### git::get_branch

Get the current branch name.

```bash
branch=$(git::get_branch)
echo "Current branch: ${branch}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Branch name to stdout (or "unknown" if detection fails)

#### git::create_branch

Create and checkout a new branch.

```bash
git::create_branch "feature/new-feature"
```

**Arguments:**
- `$1` - New branch name (required)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Also checks out the new branch and displays the configured default branch name

#### git::delete_branch

Delete a local branch.

```bash
git::delete_branch "feature/old-feature"
git::delete_branch "feature/old-feature" --force  # Force delete unmerged branch
```

**Arguments:**
- `$1` - Branch name (required)
- `$2` - `--force` flag to force delete (optional, uses `-D` instead of `-d`)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::checkout

Checkout a branch or commit.

```bash
git::checkout "main"
git::checkout "feature/branch"
git::checkout "abc123"  # Specific commit
```

**Arguments:**
- `$1` - Branch, tag, or commit to checkout (required)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Status and Information

#### git::has_changes

Check if there are uncommitted changes (staged or unstaged).

```bash
if git::has_changes; then
    echo "There are uncommitted changes"
fi
```

**Returns:** `PASS` (0) if changes exist, `FAIL` (1) if clean

#### git::is_clean

Check if the working tree is clean (no uncommitted changes).

```bash
if git::is_clean; then
    echo "Working tree is clean"
fi
```

**Returns:** `PASS` (0) if clean, `FAIL` (1) if changes exist

#### git::get_commit

Get the current commit hash.

```bash
commit=$(git::get_commit)
echo "Current commit: ${commit}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Full commit hash to stdout (or "unknown" if detection fails)

#### git::get_remote_url

Get the URL of the origin remote.

```bash
url=$(git::get_remote_url)
echo "Origin URL: ${url}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Remote URL to stdout (or "unknown" if not configured)

#### git::get_root

Get the root directory of the repository.

```bash
root=$(git::get_root)
echo "Repo root: ${root}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Absolute path to repo root

### Stash Operations

#### git::stash_save

Stash current changes with optional message.

```bash
git::stash_save "WIP: working on feature"
git::stash_save  # Uses default message "WIP"
```

**Arguments:**
- `$1` - Stash message (optional, default: "WIP")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Returns `PASS` with info message if there are no changes to stash

#### git::stash_pop

Apply and remove the most recent stash.

```bash
git::stash_pop
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Tags

#### git::tag

Create or list tags.

```bash
git::tag "v1.0.0"  # Create lightweight tag
git::tag           # List all tags
```

**Arguments:**
- `$1` - Tag name (optional; if omitted, lists all tags)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Creates lightweight tags only; use git directly for annotated tags

### Submodules

#### git::submodule_update

Initialize and update submodules recursively.

```bash
git::submodule_update
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Runs `git submodule update --init --recursive`

### Configuration

#### git::set_config

Set a git configuration value with input validation and security warnings.

```bash
git::set_config "user.name" "John Doe"
git::set_config "user.email" "john@example.com"
git::set_config "core.editor" "vim" "--global"
git::set_config "push.default" "current" "--local"
```

**Arguments:**
- `$1` - Config key (required, must match pattern `section.key` or `section.subsection.key`)
- `$2` - Config value (required)
- `$3` - Scope flag (optional: `--global`, `--local`, `--system`, `--worktree`, `--file`, `--file=<path>`)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Security Features:**
- Validates key format to prevent command injection
- Validates scope flag to ensure only allowed values
- Warns when setting security-sensitive keys:
  - `core.gitProxy`, `core.sshCommand`
  - `credential.*`
  - `http.proxy`, `https.proxy`
  - `filter.*`
  - `diff.external`, `merge.external`
  - `receive.denyCurrentBranch`
  - `safe.directory`

#### git::get_config

Get a git configuration value.

```bash
name=$(git::get_config "user.name")
echo "User: ${name}"
```

**Arguments:**
- `$1` - Config key (required)

**Returns:** `PASS` (0) if value exists and is non-empty, `FAIL` (1) if not set or empty

**Outputs:** Config value to stdout

### GitHub Integration

#### git::get_latest_release_info

Fetch latest GitHub release info and expose values via nameref variables.

```bash
local tag name asset
if git::get_latest_release_info "sharkdp/bat" "linux" "amd64" tag name asset; then
    echo "Tag:   ${tag}"
    echo "Name:  ${name}"
    echo "Asset: ${asset}"
fi

# Using default variable names
git::get_latest_release_info "cli/cli" "linux" "amd64"
echo "Tag: ${GIT_RELEASE_TAG}"
echo "Asset: ${GIT_RELEASE_ASSET}"
```

**Arguments:**
- `$1` - Repository in `owner/repo` format (required)
- `$2` - OS pattern to match in asset URL, e.g., "linux", "darwin" (required)
- `$3` - Architecture pattern to match in asset URL, e.g., "amd64", "x86_64", "arm64" (required)
- `$4` - Variable name to store tag (optional, default: `GIT_RELEASE_TAG`)
- `$5` - Variable name to store release name (optional, default: `GIT_RELEASE_NAME`)
- `$6` - Variable name to store asset URL (optional, default: `GIT_RELEASE_ASSET`)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Requirements:**
- `curl` must be available
- `jq` must be installed for JSON parsing

**Notes:**
- Uses GitHub API: `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- OS and architecture patterns are case-insensitive matches
- If multiple assets match, returns the first one

#### git::get_release

Download the latest GitHub release asset matching OS and architecture.

```bash
git::get_release "sharkdp/bat" "linux" "amd64" "/tmp/bat.tar.gz"
git::get_release "cli/cli" "darwin" "arm64" "/usr/local/bin/"
```

**Arguments:**
- `$1` - Repository in `owner/repo` format (required)
- `$2` - OS pattern to match in asset URL, e.g., "linux", "darwin" (required)
- `$3` - Architecture pattern to match in asset URL, e.g., "amd64", "x86_64" (required)
- `$4` - Destination path (required)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Behavior:**
- If `dest` is a directory, the asset's filename is preserved inside it
- If `dest` is a file path, the asset is saved exactly there
- Uses `trap::with_cleanup` for automatic temporary file cleanup

**Requirements:**
- `curl` must be available

### Self-Test

#### git::self_test

Run basic self-tests for util_git.sh.

```bash
git::self_test
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on critical failure

**Tests:**
- Git availability check
- Repository detection (if in a git repo)
- Branch and commit introspection (if in a git repo)

## Examples

### Repository Setup

```bash
#!/usr/bin/env bash
source util.sh

function setup_repo() {
    local url="$1"
    local dir="$2"

    # Clone if doesn't exist
    if [[ ! -d "${dir}/.git" ]]; then
        git::clone "${url}" "${dir}"
    fi

    cd "${dir}" || return "${FAIL}"

    # Configure
    git::set_config "core.autocrlf" "input"

    # Update submodules
    git::submodule_update

    pass "Repository ready"
}
```

### Feature Branch Workflow

```bash
#!/usr/bin/env bash
source util.sh

function start_feature() {
    local feature_name="$1"

    # Ensure clean state
    if git::has_changes; then
        git::stash_save "WIP before ${feature_name}"
    fi

    # Update main
    git::checkout "main"
    git::pull

    # Create feature branch
    git::create_branch "feature/${feature_name}"

    pass "Ready to work on ${feature_name}"
}

function finish_feature() {
    local message="$1"

    # Commit changes
    if git::has_changes; then
        git::commit "${message}"
    fi

    # Push branch
    git::push

    pass "Feature branch pushed"
}
```

### Release Tagging

```bash
#!/usr/bin/env bash
source util.sh

function create_release() {
    local version="$1"

    # Verify clean state
    if ! git::is_clean; then
        error "Working tree not clean"
        return "${FAIL}"
    fi

    # Create lightweight tag
    git::tag "v${version}"

    # Push tag to remote
    git push origin "v${version}"

    pass "Release v${version} created"
}
```

### Tool Installation from GitHub

```bash
#!/usr/bin/env bash
source util.sh

function install_bat() {
    local dest="/usr/local/bin"
    local tmp_dir
    tmp_dir=$(dir::tempdir)

    # Get release info first
    local tag name asset_url
    if ! git::get_latest_release_info "sharkdp/bat" "linux" "x86_64" tag name asset_url; then
        fail "Could not get release info"
        return "${FAIL}"
    fi

    info "Installing bat ${tag}"

    # Download latest release
    git::get_release "sharkdp/bat" "linux" "x86_64" "${tmp_dir}/bat.tar.gz"

    # Extract and install
    tar -xzf "${tmp_dir}/bat.tar.gz" -C "${tmp_dir}"
    cp "${tmp_dir}"/bat-*/bat "${dest}/"
    chmod +x "${dest}/bat"

    pass "bat ${tag} installed"
}
```

### Pre-Commit Checks

```bash
#!/usr/bin/env bash
source util.sh

function pre_commit() {
    # Get staged files
    local files
    files=$(git diff --cached --name-only --diff-filter=ACM)

    # Run checks
    for file in ${files}; do
        case "${file}" in
            *.sh)
                bash -n "${file}" || return "${FAIL}"
                ;;
            *.py)
                python -m py_compile "${file}" || return "${FAIL}"
                ;;
        esac
    done

    pass "Pre-commit checks passed"
}
```

### Repository Information

```bash
#!/usr/bin/env bash
source util.sh

function repo_info() {
    if ! git::is_repo; then
        error "Not in a git repository"
        return "${FAIL}"
    fi

    echo "Repository Information"
    echo "======================"
    echo "Root:     $(git::get_root)"
    echo "Branch:   $(git::get_branch)"
    echo "Commit:   $(git::get_commit)"
    echo "Remote:   $(git::get_remote_url)"
    echo "Status:   $(git::is_clean && echo 'Clean' || echo 'Modified')"
}
```

### Secure Configuration

```bash
#!/usr/bin/env bash
source util.sh

function configure_git_identity() {
    local name="$1"
    local email="$2"

    # Set local repository identity
    git::set_config "user.name" "${name}" "--local"
    git::set_config "user.email" "${email}" "--local"

    # Set global defaults
    git::set_config "init.defaultBranch" "main" "--global"
    git::set_config "pull.rebase" "true" "--global"

    pass "Git identity configured"
}
```

## Self-Test

```bash
source util.sh
git::self_test
```

Tests:
- Git availability
- Repository detection
- Branch and commit introspection (when in a repo)

## Notes

- All operations are logged via the logging system (info, warn, error, debug, pass, fail)
- Push/pull operations may require authentication
- GitHub API has rate limits for unauthenticated requests (60 requests/hour)
- Submodule operations are recursive by default
- Tags are not pushed by default; use `git push origin <tag>` or `git push --tags`
- The `git::set_config` function includes security validation and warns on sensitive keys
- Functions that produce data output to stdout; all logging goes to stderr
