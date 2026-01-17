# util_curl.sh - HTTP Operations

HTTP/HTTPS operations and file transfers using curl with proxy support, retry logic, and integrated progress display.

## Overview

This module provides:
- HTTP method wrappers (GET, POST, PUT, DELETE)
- File download with progress
- Response header and status code inspection
- Retry and timeout handling
- Proxy support
- Authentication helpers

## Dependencies

- `util_platform.sh`
- `util_config.sh`
- `util_trap.sh`
- `util_tui.sh`

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `curl.timeout` | `30` | Request timeout in seconds |
| `curl.max_redirects` | `10` | Maximum redirects to follow |
| `curl.max_retries` | `3` | Maximum retry attempts |
| `curl.retry_delay` | `2` | Delay between retries in seconds |

## Global Variables

| Variable | Description |
|----------|-------------|
| `CURL_TIMEOUT` | Request timeout |
| `CURL_MAX_REDIRECTS` | Max redirects |
| `CURL_USER_AGENT` | User-Agent string |
| `PROXY` | Proxy prefix command (if configured) |

## Functions

### Availability

#### curl::is_available

Check if curl is installed.

```bash
if curl::is_available; then
    curl::get "https://example.com"
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

### Basic HTTP Methods

#### curl::get

Perform an HTTP GET request.

```bash
# Simple GET
body=$(curl::get "https://api.example.com/data")

# With query parameters
body=$(curl::get "https://api.example.com/search?q=term")
```

**Arguments:**
- `$1` - URL to fetch

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response body

#### curl::post

Perform an HTTP POST request.

```bash
# POST with data
response=$(curl::post "https://api.example.com/users" '{"name":"John"}')

# POST form data
response=$(curl::post "https://example.com/form" "name=John&email=john@example.com")
```

**Arguments:**
- `$1` - URL
- `$2` - Request body data

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response body

#### curl::put

Perform an HTTP PUT request.

```bash
response=$(curl::put "https://api.example.com/users/1" '{"name":"Jane"}')
```

**Arguments:**
- `$1` - URL
- `$2` - Request body data

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response body

#### curl::delete

Perform an HTTP DELETE request.

```bash
curl::delete "https://api.example.com/users/1"
```

**Arguments:**
- `$1` - URL

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### File Downloads

#### curl::download

Download a file with progress display.

```bash
curl::download "https://example.com/file.tar.gz" "/tmp/file.tar.gz"
```

**Arguments:**
- `$1` - URL to download
- `$2` - Destination path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Shows spinner during download

#### curl::download_if_missing

Download a file only if it doesn't exist locally.

```bash
curl::download_if_missing "https://example.com/file.tar.gz" "/tmp/file.tar.gz"
```

**Arguments:**
- `$1` - URL to download
- `$2` - Destination path

**Returns:** `PASS` (0) on success/exists, `FAIL` (1) on error

### Response Inspection

#### curl::get_status_code

Get the HTTP status code for a URL.

```bash
status=$(curl::get_status_code "https://example.com")
if [[ "${status}" == "200" ]]; then
    echo "OK"
fi
```

**Arguments:**
- `$1` - URL to check

**Returns:** `PASS` (0) always

**Outputs:** HTTP status code (e.g., 200, 404, 500)

#### curl::get_headers

Get response headers for a URL.

```bash
headers=$(curl::get_headers "https://example.com")
echo "${headers}"
```

**Arguments:**
- `$1` - URL

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response headers

#### curl::get_content_type

Get the Content-Type header.

```bash
content_type=$(curl::get_content_type "https://api.example.com/data")
if [[ "${content_type}" == *"application/json"* ]]; then
    echo "JSON response"
fi
```

**Arguments:**
- `$1` - URL

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Content-Type value

#### curl::get_response_time

Measure response time in seconds.

```bash
time=$(curl::get_response_time "https://example.com")
echo "Response time: ${time}s"
```

**Arguments:**
- `$1` - URL

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Time in seconds

### Retry and Advanced

#### curl::get_with_retry

GET request with automatic retry.

```bash
body=$(curl::get_with_retry "https://api.example.com/data" 5 3)
# 5 attempts, 3 second delay
```

**Arguments:**
- `$1` - URL
- `$2` - Number of attempts (default: 3)
- `$3` - Delay between attempts in seconds (default: 2)

**Returns:** `PASS` (0) on success, `FAIL` (1) if all attempts fail

**Outputs:** Response body

#### curl::with_auth

GET request with basic authentication.

```bash
body=$(curl::with_auth "https://api.example.com/secure" "username" "password")
```

**Arguments:**
- `$1` - URL
- `$2` - Username
- `$3` - Password

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response body

#### curl::with_headers

GET request with custom headers.

```bash
body=$(curl::with_headers "https://api.example.com/data" \
    "Authorization: Bearer token123" \
    "X-Custom-Header: value")
```

**Arguments:**
- `$1` - URL
- `$@` - Headers in "Name: Value" format

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response body

#### curl::with_bearer

GET request with Bearer token authentication.

```bash
body=$(curl::with_bearer "https://api.example.com/data" "your_token_here")
```

**Arguments:**
- `$1` - URL
- `$2` - Bearer token

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Response body

### Utility Functions

#### curl::url_encode

URL-encode a string.

```bash
encoded=$(curl::url_encode "hello world")
echo "${encoded}"  # hello%20world
```

**Arguments:**
- `$1` - String to encode

**Returns:** `PASS` (0) always

**Outputs:** URL-encoded string

#### curl::is_url_reachable

Check if a URL is reachable (returns 2xx).

```bash
if curl::is_url_reachable "https://example.com"; then
    echo "Site is up"
fi
```

**Arguments:**
- `$1` - URL to check

**Returns:** `PASS` (0) if reachable, `FAIL` (1) otherwise

## Examples

### API Client

```bash
#!/usr/bin/env bash
source util.sh

API_BASE="https://api.example.com"
API_TOKEN="your_token_here"

api_get() {
    local endpoint="$1"
    curl::with_bearer "${API_BASE}${endpoint}" "${API_TOKEN}"
}

api_post() {
    local endpoint="$1"
    local data="$2"
    
    curl::with_headers "${API_BASE}${endpoint}" \
        "Authorization: Bearer ${API_TOKEN}" \
        "Content-Type: application/json" \
        --data "${data}"
}

# Usage
users=$(api_get "/users")
result=$(api_post "/users" '{"name":"John"}')
```

### Download with Verification

```bash
#!/usr/bin/env bash
source util.sh

download_with_checksum() {
    local url="$1"
    local dest="$2"
    local expected_sha256="$3"
    
    # Download file
    if ! curl::download "${url}" "${dest}"; then
        fail "Download failed"
        return "${FAIL}"
    fi
    
    # Verify checksum
    local actual_sha256
    actual_sha256=$(file::get_checksum "${dest}" "sha256")
    
    if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
        fail "Checksum mismatch!"
        rm -f "${dest}"
        return "${FAIL}"
    fi
    
    pass "Download verified"
    return "${PASS}"
}
```

### Health Check Script

```bash
#!/usr/bin/env bash
source util.sh

check_endpoints() {
    local -a endpoints=(
        "https://api.example.com/health"
        "https://app.example.com"
        "https://cdn.example.com/test.txt"
    )
    
    local failed=0
    
    for url in "${endpoints[@]}"; do
        local status response_time
        status=$(curl::get_status_code "${url}")
        response_time=$(curl::get_response_time "${url}")
        
        if [[ "${status}" == "200" ]]; then
            pass "${url}: ${status} (${response_time}s)"
        else
            fail "${url}: ${status}"
            ((failed++))
        fi
    done
    
    return ${failed}
}
```

### Retry with Exponential Backoff

```bash
#!/usr/bin/env bash
source util.sh

fetch_with_backoff() {
    local url="$1"
    local max_attempts=5
    local delay=1
    
    for ((i=1; i<=max_attempts; i++)); do
        if body=$(curl::get "${url}" 2>/dev/null); then
            echo "${body}"
            return "${PASS}"
        fi
        
        warn "Attempt ${i} failed, retrying in ${delay}s..."
        sleep "${delay}"
        delay=$((delay * 2))  # Exponential backoff
    done
    
    fail "All ${max_attempts} attempts failed"
    return "${FAIL}"
}
```

### POST with JSON

```bash
#!/usr/bin/env bash
source util.sh

create_user() {
    local name="$1"
    local email="$2"
    
    local payload
    payload=$(printf '{"name":"%s","email":"%s"}' "${name}" "${email}")
    
    local response
    if response=$(curl::post "https://api.example.com/users" "${payload}"); then
        echo "User created: ${response}"
        return "${PASS}"
    else
        error "Failed to create user"
        return "${FAIL}"
    fi
}
```

### Download Multiple Files

```bash
#!/usr/bin/env bash
source util.sh

download_assets() {
    local -a urls=(
        "https://example.com/file1.tar.gz"
        "https://example.com/file2.tar.gz"
        "https://example.com/file3.tar.gz"
    )
    
    local dest_dir="/tmp/assets"
    mkdir -p "${dest_dir}"
    
    for url in "${urls[@]}"; do
        local filename="${url##*/}"
        info "Downloading ${filename}..."
        
        curl::download "${url}" "${dest_dir}/${filename}"
    done
    
    pass "Downloaded ${#urls[@]} files"
}
```

## Self-Test

```bash
source util.sh
curl::self_test
```

Tests:
- curl availability
- URL encoding
- Status code retrieval
- Basic GET request

## Notes

- All functions respect the `PROXY` environment variable
- Timeouts are configurable via `config::set "curl.timeout" "60"`
- User-Agent can be customized via `CURL_USER_AGENT`
- SSL verification is enabled by default
- Binary downloads should use `curl::download`, not `curl::get`
