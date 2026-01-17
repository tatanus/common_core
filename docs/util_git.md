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

- `util_cmd.sh`
- `util_tui.sh`

## Functions

### Availability

#### git::is_available

Check if git is installed.

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
```

**Arguments:**
- `$1` - Repository URL
- `$2` - Destination path (optional, defaults to repo name)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::pull

Pull latest changes from remote.

```bash
git::pull
git::pull "origin" "main"
```

**Arguments:**
- `$1` - Remote name (optional, default: origin)
- `$2` - Branch name (optional, default: current branch)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::push

Push commits to remote.

```bash
git::push
git::push "origin" "feature-branch"
```

**Arguments:**
- `$1` - Remote name (optional, default: origin)
- `$2` - Branch name (optional, default: current branch)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::commit

Stage all changes and commit.

```bash
git::commit "Add new feature"
```

**Arguments:**
- `$1` - Commit message

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

**Outputs:** Branch name

#### git::create_branch

Create a new branch.

```bash
git::create_branch "feature/new-feature"
git::create_branch "bugfix/issue-123" "main"  # From specific base
```

**Arguments:**
- `$1` - New branch name
- `$2` - Base branch (optional, default: current branch)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Also checks out the new branch

#### git::delete_branch

Delete a branch.

```bash
git::delete_branch "feature/old-feature"
git::delete_branch "feature/old-feature" true  # Force delete
```

**Arguments:**
- `$1` - Branch name
- `$2` - Force delete (true/false, default: false)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::checkout

Checkout a branch or commit.

```bash
git::checkout "main"
git::checkout "feature/branch"
git::checkout "abc123"  # Specific commit
```

**Arguments:**
- `$1` - Branch, tag, or commit to checkout

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Status and Information

#### git::has_changes

Check if there are uncommitted changes.

```bash
if git::has_changes; then
    echo "There are uncommitted changes"
fi
```

**Returns:** `PASS` (0) if changes exist, `FAIL` (1) if clean

#### git::is_clean

Check if the working tree is clean.

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

# Short hash
short=$(git::get_commit short)
echo "Short hash: ${short}"
```

**Arguments:**
- `$1` - "short" for abbreviated hash (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Commit hash

#### git::get_remote_url

Get the URL of a remote.

```bash
url=$(git::get_remote_url)
echo "Origin URL: ${url}"

url=$(git::get_remote_url "upstream")
```

**Arguments:**
- `$1` - Remote name (optional, default: origin)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Remote URL

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

Stash current changes.

```bash
git::stash_save "WIP: working on feature"
```

**Arguments:**
- `$1` - Stash message (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::stash_pop

Pop the most recent stash.

```bash
git::stash_pop
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Tags

#### git::tag

Create a tag.

```bash
git::tag "v1.0.0"
git::tag "v1.0.0" "Release version 1.0.0"  # Annotated tag
```

**Arguments:**
- `$1` - Tag name
- `$2` - Tag message (optional, creates annotated tag)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Submodules

#### git::submodule_update

Initialize and update submodules.

```bash
git::submodule_update
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Configuration

#### git::set_config

Set a git configuration value.

```bash
git::set_config "user.name" "John Doe"
git::set_config "user.email" "john@example.com"
git::set_config "core.editor" "vim" "--global"
```

**Arguments:**
- `$1` - Config key
- `$2` - Config value
- `$3` - Scope flag (optional, e.g., "--global")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### git::get_config

Get a git configuration value.

```bash
name=$(git::get_config "user.name")
echo "User: ${name}"
```

**Arguments:**
- `$1` - Config key

**Returns:** `PASS` (0) on success, `FAIL` (1) if not set

**Outputs:** Config value

### GitHub Integration

#### git::get_latest_release_info

Get information about the latest GitHub release.

```bash
info=$(git::get_latest_release_info "cli" "cli")
echo "${info}"  # Returns JSON
```

**Arguments:**
- `$1` - GitHub owner/org
- `$2` - Repository name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** JSON release information

#### git::get_release

Download a GitHub release asset.

```bash
git::get_release "cli" "cli" "gh_*_linux_amd64.tar.gz" "/tmp/gh.tar.gz"
```

**Arguments:**
- `$1` - GitHub owner/org
- `$2` - Repository name
- `$3` - Asset filename pattern (glob)
- `$4` - Destination path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

## Examples

### Repository Setup

```bash
#!/usr/bin/env bash
source util.sh

setup_repo() {
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

start_feature() {
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

finish_feature() {
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

create_release() {
    local version="$1"
    local message="$2"
    
    # Verify clean state
    if ! git::is_clean; then
        error "Working tree not clean"
        return "${FAIL}"
    fi
    
    # Create annotated tag
    git::tag "v${version}" "${message}"
    
    # Push with tags
    git push origin "v${version}"
    
    pass "Release v${version} created"
}
```

### Tool Installation from GitHub

```bash
#!/usr/bin/env bash
source util.sh

install_gh_cli() {
    local dest="/usr/local/bin/gh"
    local tmp_dir
    tmp_dir=$(dir::tempdir)
    
    # Download latest release
    git::get_release "cli" "cli" "gh_*_linux_amd64.tar.gz" "${tmp_dir}/gh.tar.gz"
    
    # Extract and install
    tar -xzf "${tmp_dir}/gh.tar.gz" -C "${tmp_dir}"
    cp "${tmp_dir}"/gh_*/bin/gh "${dest}"
    chmod +x "${dest}"
    
    pass "GitHub CLI installed"
}
```

### Pre-Commit Checks

```bash
#!/usr/bin/env bash
source util.sh

pre_commit() {
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

repo_info() {
    if ! git::is_repo; then
        error "Not in a git repository"
        return "${FAIL}"
    fi
    
    echo "Repository Information"
    echo "======================"
    echo "Root:     $(git::get_root)"
    echo "Branch:   $(git::get_branch)"
    echo "Commit:   $(git::get_commit short)"
    echo "Remote:   $(git::get_remote_url)"
    echo "Status:   $(git::is_clean && echo 'Clean' || echo 'Modified')"
}
```

## Self-Test

```bash
source util.sh
git::self_test
```

Tests:
- git availability
- Repository detection
- Branch operations
- Configuration access

## Notes

- All operations are logged via the logging system
- Push/pull operations may require authentication
- GitHub API has rate limits for unauthenticated requests
- Submodule operations are recursive by default
- Tags are not pushed by default; use `git push --tags`
