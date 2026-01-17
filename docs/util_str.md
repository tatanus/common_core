# util_str.sh - String Manipulation

String manipulation and text processing utilities using Bash built-ins where possible to minimize external command usage.

## Overview

This module provides:
- String length and empty checks
- Case conversion
- Trimming and padding
- Substring extraction
- Search and replace
- Splitting and joining
- Type validation (integer, float, alpha)
- Pattern matching

## Dependencies

None (standalone module)

## Functions

### Length and Empty Checks

#### str::length

Get the length of a string.

```bash
len=$(str::length "hello world")
echo "${len}"  # 11
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Length of string

#### str::is_empty

Check if a string is empty or unset.

```bash
if str::is_empty "${var}"; then
    echo "Variable is empty"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if empty, `FAIL` (1) if not empty

#### str::is_not_empty

Check if a string is not empty.

```bash
if str::is_not_empty "${var}"; then
    echo "Variable has content: ${var}"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if not empty, `FAIL` (1) if empty

#### str::is_blank

Check if a string is empty or contains only whitespace.

```bash
if str::is_blank "   "; then
    echo "String is blank"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if blank, `FAIL` (1) if has non-whitespace content

### Case Conversion

#### str::to_upper

Convert string to uppercase.

```bash
upper=$(str::to_upper "hello")
echo "${upper}"  # HELLO
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Uppercase string

#### str::to_lower

Convert string to lowercase.

```bash
lower=$(str::to_lower "HELLO")
echo "${lower}"  # hello
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Lowercase string

#### str::capitalize

Capitalize the first letter of a string.

```bash
cap=$(str::capitalize "hello world")
echo "${cap}"  # Hello world
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** String with first letter capitalized

#### str::to_title_case

Convert string to title case (capitalize each word).

```bash
title=$(str::to_title_case "hello world")
echo "${title}"  # Hello World
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Title-cased string

### Trimming and Padding

#### str::trim

Trim leading and trailing whitespace.

```bash
trimmed=$(str::trim "  hello world  ")
echo "'${trimmed}'"  # 'hello world'
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Trimmed string

#### str::trim_left

Trim leading whitespace only.

```bash
trimmed=$(str::trim_left "  hello")
echo "'${trimmed}'"  # 'hello'
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Left-trimmed string

#### str::trim_right

Trim trailing whitespace only.

```bash
trimmed=$(str::trim_right "hello  ")
echo "'${trimmed}'"  # 'hello'
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Right-trimmed string

#### str::pad_left

Pad a string on the left to a specified width.

```bash
padded=$(str::pad_left "42" 5 "0")
echo "${padded}"  # 00042
```

**Arguments:**
- `$1` - Input string
- `$2` - Target width
- `$3` - Padding character (default: space)

**Returns:** `PASS` (0) always

**Outputs:** Left-padded string

#### str::pad_right

Pad a string on the right to a specified width.

```bash
padded=$(str::pad_right "hello" 10 ".")
echo "${padded}"  # hello.....
```

**Arguments:**
- `$1` - Input string
- `$2` - Target width
- `$3` - Padding character (default: space)

**Returns:** `PASS` (0) always

**Outputs:** Right-padded string

### Substring Operations

#### str::substring

Extract a substring from a string.

```bash
sub=$(str::substring "hello world" 0 5)
echo "${sub}"  # hello

sub=$(str::substring "hello world" 6)
echo "${sub}"  # world
```

**Arguments:**
- `$1` - Input string
- `$2` - Start position (0-indexed)
- `$3` - Length (optional, defaults to end of string)

**Returns:** `PASS` (0) always

**Outputs:** Extracted substring

#### str::truncate

Truncate a string to a maximum length with optional suffix.

```bash
short=$(str::truncate "hello world" 8)
echo "${short}"  # hello...

short=$(str::truncate "hello world" 8 "…")
echo "${short}"  # hello w…
```

**Arguments:**
- `$1` - Input string
- `$2` - Maximum length
- `$3` - Suffix (default: "...")

**Returns:** `PASS` (0) always

**Outputs:** Truncated string

### Search Operations

#### str::contains

Check if a string contains a substring.

```bash
if str::contains "hello world" "world"; then
    echo "Found!"
fi
```

**Arguments:**
- `$1` - Input string
- `$2` - Substring to find

**Returns:** `PASS` (0) if found, `FAIL` (1) if not found

#### str::starts_with

Check if a string starts with a prefix.

```bash
if str::starts_with "hello world" "hello"; then
    echo "Starts with hello"
fi
```

**Arguments:**
- `$1` - Input string
- `$2` - Prefix to check

**Returns:** `PASS` (0) if matches, `FAIL` (1) if not

#### str::ends_with

Check if a string ends with a suffix.

```bash
if str::ends_with "file.txt" ".txt"; then
    echo "It's a text file"
fi
```

**Arguments:**
- `$1` - Input string
- `$2` - Suffix to check

**Returns:** `PASS` (0) if matches, `FAIL` (1) if not

#### str::count

Count occurrences of a substring.

```bash
count=$(str::count "banana" "a")
echo "${count}"  # 3
```

**Arguments:**
- `$1` - Input string
- `$2` - Substring to count

**Returns:** `PASS` (0) always

**Outputs:** Number of occurrences

#### str::in_list

Check if a string is in a list of values.

```bash
if str::in_list "apple" "apple" "banana" "cherry"; then
    echo "Found in list"
fi
```

**Arguments:**
- `$1` - String to find
- `$@` - List of values to search

**Returns:** `PASS` (0) if found, `FAIL` (1) if not

### Replace Operations

#### str::replace

Replace the first occurrence of a pattern.

```bash
result=$(str::replace "hello world" "world" "bash")
echo "${result}"  # hello bash
```

**Arguments:**
- `$1` - Input string
- `$2` - Pattern to find
- `$3` - Replacement string

**Returns:** `PASS` (0) always

**Outputs:** Modified string

#### str::replace_all

Replace all occurrences of a pattern.

```bash
result=$(str::replace_all "banana" "a" "o")
echo "${result}"  # bonono
```

**Arguments:**
- `$1` - Input string
- `$2` - Pattern to find
- `$3` - Replacement string

**Returns:** `PASS` (0) always

**Outputs:** Modified string

#### str::remove

Remove the first occurrence of a pattern.

```bash
result=$(str::remove "hello world" "world")
echo "${result}"  # hello 
```

**Arguments:**
- `$1` - Input string
- `$2` - Pattern to remove

**Returns:** `PASS` (0) always

**Outputs:** Modified string

#### str::remove_all

Remove all occurrences of a pattern.

```bash
result=$(str::remove_all "banana" "a")
echo "${result}"  # bnn
```

**Arguments:**
- `$1` - Input string
- `$2` - Pattern to remove

**Returns:** `PASS` (0) always

**Outputs:** Modified string

### Split and Join

#### str::split

Split a string by delimiter into an array.

```bash
str::split "a,b,c" "," result_array
echo "${result_array[0]}"  # a
echo "${result_array[1]}"  # b
echo "${result_array[2]}"  # c
```

**Arguments:**
- `$1` - Input string
- `$2` - Delimiter
- `$3` - Name of array variable to populate

**Returns:** `PASS` (0) always

#### str::join

Join array elements with a delimiter.

```bash
arr=("apple" "banana" "cherry")
result=$(str::join ", " "${arr[@]}")
echo "${result}"  # apple, banana, cherry
```

**Arguments:**
- `$1` - Delimiter
- `$@` - Elements to join

**Returns:** `PASS` (0) always

**Outputs:** Joined string

### Type Validation

#### str::is_integer

Check if a string is a valid integer (including negative).

```bash
if str::is_integer "-42"; then
    echo "Valid integer"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if integer, `FAIL` (1) otherwise

#### str::is_positive_integer

Check if a string is a positive integer.

```bash
if str::is_positive_integer "42"; then
    echo "Valid positive integer"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if positive integer, `FAIL` (1) otherwise

#### str::is_float

Check if a string is a valid floating-point number.

```bash
if str::is_float "3.14"; then
    echo "Valid float"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if float, `FAIL` (1) otherwise

#### str::is_alpha

Check if a string contains only alphabetic characters.

```bash
if str::is_alpha "Hello"; then
    echo "Only letters"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if all alpha, `FAIL` (1) otherwise

#### str::is_alphanumeric

Check if a string contains only alphanumeric characters.

```bash
if str::is_alphanumeric "Hello123"; then
    echo "Only letters and numbers"
fi
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) if alphanumeric, `FAIL` (1) otherwise

### Pattern Matching

#### str::matches

Check if a string matches a regular expression.

```bash
if str::matches "user@example.com" "^[^@]+@[^@]+\.[^@]+$"; then
    echo "Valid email format"
fi
```

**Arguments:**
- `$1` - Input string
- `$2` - Regular expression pattern

**Returns:** `PASS` (0) if matches, `FAIL` (1) otherwise

### Utility Functions

#### str::repeat

Repeat a string a specified number of times.

```bash
result=$(str::repeat "ab" 3)
echo "${result}"  # ababab
```

**Arguments:**
- `$1` - Input string
- `$2` - Number of repetitions

**Returns:** `PASS` (0) always

**Outputs:** Repeated string

#### str::reverse

Reverse a string.

```bash
result=$(str::reverse "hello")
echo "${result}"  # olleh
```

**Arguments:**
- `$1` - Input string

**Returns:** `PASS` (0) always

**Outputs:** Reversed string

## Examples

### Input Validation

```bash
#!/usr/bin/env bash
source util.sh

validate_username() {
    local username="$1"
    
    if str::is_empty "${username}"; then
        error "Username cannot be empty"
        return "${FAIL}"
    fi
    
    if ! str::is_alphanumeric "${username}"; then
        error "Username must be alphanumeric"
        return "${FAIL}"
    fi
    
    local len
    len=$(str::length "${username}")
    if (( len < 3 || len > 20 )); then
        error "Username must be 3-20 characters"
        return "${FAIL}"
    fi
    
    return "${PASS}"
}
```

### Text Processing

```bash
#!/usr/bin/env bash
source util.sh

# Clean and normalize input
input="  Hello,  World!  "

# Trim whitespace
clean=$(str::trim "${input}")

# Convert to lowercase
lower=$(str::to_lower "${clean}")

# Remove punctuation (simple)
normalized=$(str::remove_all "${lower}" ",")
normalized=$(str::remove_all "${normalized}" "!")

echo "${normalized}"  # hello  world
```

### CSV Parsing

```bash
#!/usr/bin/env bash
source util.sh

parse_csv_line() {
    local line="$1"
    local -a fields
    
    str::split "${line}" "," fields
    
    echo "Field 1: ${fields[0]}"
    echo "Field 2: ${fields[1]}"
    echo "Field 3: ${fields[2]}"
}

parse_csv_line "John,Doe,30"
```

### Path Manipulation

```bash
#!/usr/bin/env bash
source util.sh

get_file_info() {
    local path="$1"
    
    # Check extension
    if str::ends_with "${path}" ".sh"; then
        echo "Shell script"
    elif str::ends_with "${path}" ".py"; then
        echo "Python script"
    fi
    
    # Extract filename from path
    if str::contains "${path}" "/"; then
        # Get everything after last /
        local filename="${path##*/}"
        echo "Filename: ${filename}"
    fi
}
```

### Building Formatted Output

```bash
#!/usr/bin/env bash
source util.sh

print_table_row() {
    local col1="$1"
    local col2="$2"
    local col3="$3"
    
    # Pad columns to fixed widths
    col1=$(str::pad_right "${col1}" 20)
    col2=$(str::pad_right "${col2}" 15)
    col3=$(str::pad_left "${col3}" 10)
    
    echo "${col1}${col2}${col3}"
}

print_table_row "Name" "Status" "Count"
print_table_row "----" "------" "-----"
print_table_row "Server 1" "Running" "42"
print_table_row "Server 2" "Stopped" "0"
```

## Self-Test

```bash
source util.sh
str::self_test
```

## Performance Notes

- All functions use Bash built-ins where possible
- No external commands (sed, awk, tr) for basic operations
- Pattern matching uses Bash's built-in `[[ =~ ]]`
- String operations are O(n) where n is string length

## Notes

- Empty strings are handled gracefully
- Unicode support depends on locale settings
- Pattern matching uses extended regular expressions
- Functions don't modify input strings (pure functions)
