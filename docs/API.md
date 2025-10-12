# OCSV API Reference

Complete API documentation for OCSV - Odin CSV Parser.

**Version:** 0.3.0 (Phase 0 Complete)
**Last Updated:** 2025-10-12

---

## Table of Contents

- [Overview](#overview)
- [Core Types](#core-types)
  - [Parser](#parser)
  - [Config](#config)
  - [Parse_State](#parse_state)
- [Core Functions](#core-functions)
  - [parser_create](#parser_create)
  - [parser_destroy](#parser_destroy)
  - [parse_csv](#parse_csv)
  - [default_config](#default_config)
- [FFI Functions (Bun)](#ffi-functions-bun)
  - [cisv_parser_create](#cisv_parser_create)
  - [cisv_parser_destroy](#cisv_parser_destroy)
  - [cisv_parse_string](#cisv_parse_string)
  - [cisv_get_row_count](#cisv_get_row_count)
  - [cisv_get_field_count](#cisv_get_field_count)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)
- [Thread Safety](#thread-safety)
- [Performance Considerations](#performance-considerations)

---

## Overview

OCSV provides a simple, high-performance API for parsing CSV data. The API is divided into two layers:

1. **Odin API** - Native Odin functions for use within Odin programs
2. **FFI API** - C ABI exports for use with Bun FFI (JavaScript/TypeScript)

Both APIs follow the same general pattern:
1. Create a parser
2. Configure it (optional)
3. Parse CSV data
4. Access parsed results
5. Destroy the parser

---

## Core Types

### Parser

The main parser structure that maintains state during parsing.

```odin
Parser :: struct {
    config:       Config,                 // Parser configuration
    state:        Parse_State,            // Current parse state
    field_buffer: [dynamic]u8,            // Buffer for accumulating current field
    current_row:  [dynamic]string,        // Current row being built
    all_rows:     [dynamic][]string,      // All parsed rows
    line_number:  int,                    // Current line number (1-indexed)
}
```

**Fields:**
- `config`: Configuration options (see [Config](#config))
- `state`: Internal state machine state (see [Parse_State](#parse_state))
- `field_buffer`: Internal buffer for building fields
- `current_row`: Internal buffer for building current row
- `all_rows`: **Public** - All parsed rows (array of string arrays)
- `line_number`: Current line being parsed (1-indexed)

**Access Pattern:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

cisv.parse_csv(parser, csv_data)

// Access all rows
for row in parser.all_rows {
    for field in row {
        // Process field
    }
}
```

**Memory Ownership:**
- `Parser` owns all strings in `all_rows`
- Strings are cloned during parsing
- All memory is freed in `parser_destroy`

---

### Config

Configuration options for the parser.

```odin
Config :: struct {
    delimiter:               byte,    // Field delimiter (default: ',')
    quote:                   byte,    // Quote character (default: '"')
    escape:                  byte,    // Escape character (default: '"')
    skip_empty_lines:        bool,    // Skip empty lines
    comment:                 byte,    // Comment character (default: '#')
    trim:                    bool,    // Trim whitespace from fields
    relaxed:                 bool,    // Relaxed parsing (allow RFC violations)
    max_row_size:            int,     // Maximum row size in bytes
    from_line:               int,     // Start parsing from line N (0 = start)
    to_line:                 int,     // Stop parsing at line N (-1 = end)
    skip_lines_with_error:   bool,    // Skip lines that fail to parse
}
```

**Field Descriptions:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `delimiter` | `byte` | `','` | Character that separates fields |
| `quote` | `byte` | `'"'` | Character used to quote fields |
| `escape` | `byte` | `'"'` | Character used to escape quotes (RFC 4180 uses `"` for `""`) |
| `skip_empty_lines` | `bool` | `false` | Skip rows that are completely empty |
| `comment` | `byte` | `'#'` | Lines starting with this are skipped (0 = disabled) |
| `trim` | `bool` | `false` | Trim leading/trailing whitespace from fields |
| `relaxed` | `bool` | `false` | Allow RFC 4180 violations (e.g., unterminated quotes) |
| `max_row_size` | `int` | `1048576` | Maximum bytes per row (1MB default) |
| `from_line` | `int` | `0` | Start parsing from this line (0 = start) |
| `to_line` | `int` | `-1` | Stop parsing at this line (-1 = end) |
| `skip_lines_with_error` | `bool` | `false` | Continue parsing after encountering errors |

**Example:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

// Configure for TSV with comments
parser.config.delimiter = '\t'
parser.config.comment = '#'
parser.config.relaxed = true

cisv.parse_csv(parser, tsv_data)
```

**Common Configurations:**

**TSV (Tab-Separated Values):**
```odin
parser.config.delimiter = '\t'
```

**European CSV (semicolon):**
```odin
parser.config.delimiter = ';'
```

**Pipe-Separated Values:**
```odin
parser.config.delimiter = '|'
```

**With Comments:**
```odin
parser.config.comment = '#'  // Lines starting with # are skipped
```

**Relaxed Mode (handle malformed CSV):**
```odin
parser.config.relaxed = true
```

---

### Parse_State

Internal state machine states. You typically don't need to use this directly.

```odin
Parse_State :: enum {
    Field_Start,        // Beginning of a field
    In_Field,           // Inside an unquoted field
    In_Quoted_Field,    // Inside a quoted field
    Quote_In_Quote,     // Found a quote, might be "" or end of quoted field
    Field_End,          // Field complete
}
```

**State Transitions:**

```
Field_Start → In_Field (regular character)
Field_Start → In_Quoted_Field (quote character)
In_Field → Field_Start (delimiter or newline)
In_Quoted_Field → Quote_In_Quote (quote character)
Quote_In_Quote → In_Quoted_Field ("" sequence)
Quote_In_Quote → Field_Start (end of quoted field)
```

---

## Core Functions

### parser_create

Creates a new parser with default configuration.

**Signature:**
```odin
parser_create :: proc() -> ^Parser
```

**Returns:**
- `^Parser` - Pointer to newly created parser

**Memory:**
- Allocates memory for parser and internal buffers
- Must be freed with `parser_destroy`

**Example:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

// Use parser...
```

**Thread Safety:** Not thread-safe. Create separate parser per thread.

---

### parser_destroy

Destroys a parser and frees all associated memory.

**Signature:**
```odin
parser_destroy :: proc(parser: ^Parser)
```

**Parameters:**
- `parser` - Pointer to parser to destroy

**Memory:**
- Frees all strings in `all_rows`
- Frees all internal buffers
- Frees the parser struct itself

**Example:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)  // Recommended: use defer

// Alternative (manual):
cisv.parser_destroy(parser)
```

**Important:** Always destroy parsers when done to prevent memory leaks.

---

### parse_csv

Parses CSV data according to RFC 4180.

**Signature:**
```odin
parse_csv :: proc(parser: ^Parser, data: string) -> bool
```

**Parameters:**
- `parser` - Pointer to parser (must not be `nil`)
- `data` - CSV string to parse

**Returns:**
- `true` - Parse succeeded
- `false` - Parse failed (invalid CSV in strict mode)

**Behavior:**
- Clears previous parse results (frees old data)
- Parses `data` using state machine
- Stores results in `parser.all_rows`
- Returns `true` on success, `false` on parse error

**Example:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
ok := cisv.parse_csv(parser, csv_data)

if ok {
    fmt.printfln("Parsed %d rows", len(parser.all_rows))
    for row in parser.all_rows {
        for field in row {
            fmt.printf("%s ", field)
        }
        fmt.printf("\n")
    }
} else {
    fmt.eprintln("Parse failed")
}
```

**Error Conditions:**
- Unterminated quoted field (strict mode)
- Character after closing quote without delimiter (strict mode)

**Relaxed Mode:**
```odin
parser.config.relaxed = true
ok := cisv.parse_csv(parser, malformed_csv)
// Returns true even if CSV violates RFC 4180
```

**Parser Reuse:**
```odin
// Parse multiple CSVs with same parser (previous results are cleared)
cisv.parse_csv(parser, csv1)  // Results in parser.all_rows
cisv.parse_csv(parser, csv2)  // Previous results are freed, new results in parser.all_rows
```

---

### default_config

Returns a `Config` with sensible defaults.

**Signature:**
```odin
default_config :: proc() -> Config
```

**Returns:**
- `Config` with default values

**Defaults:**
```odin
Config{
    delimiter            = ',',
    quote                = '"',
    escape               = '"',
    skip_empty_lines     = false,
    comment              = '#',
    trim                 = false,
    relaxed              = false,
    max_row_size         = 1024 * 1024,  // 1MB per row
    from_line            = 0,
    to_line              = -1,           // Parse all lines
    skip_lines_with_error = false,
}
```

**Example:**
```odin
config := cisv.default_config()
config.delimiter = '\t'  // Override delimiter
config.comment = 0       // Disable comments

parser := cisv.parser_create()
parser.config = config   // Apply custom config
defer cisv.parser_destroy(parser)
```

**Note:** `parser_create` automatically initializes `parser.config` with defaults, so you typically just modify the parser's config directly:

```odin
parser := cisv.parser_create()
parser.config.delimiter = '\t'
```

---

## FFI Functions (Bun)

Functions exported with C ABI for use with Bun FFI.

### cisv_parser_create

Creates a new parser (FFI version).

**Signature:**
```c
void* cisv_parser_create()
```

**Returns:**
- Pointer to `Parser` (as opaque pointer)

**Example (TypeScript):**
```typescript
import { dlopen, FFIType, suffix } from "bun:ffi";

const lib = dlopen(`./libcsv.${suffix}`, {
  parser_create: { returns: FFIType.ptr },
  // ... other functions
});

const parser = lib.symbols.parser_create();
```

---

### cisv_parser_destroy

Destroys a parser (FFI version).

**Signature:**
```c
void cisv_parser_destroy(void* parser)
```

**Parameters:**
- `parser` - Pointer to parser

**Example (TypeScript):**
```typescript
lib.symbols.parser_destroy(parser);
```

---

### cisv_parse_string

Parses CSV data (FFI version).

**Signature:**
```c
int cisv_parse_string(void* parser, const char* data, int len)
```

**Parameters:**
- `parser` - Pointer to parser
- `data` - Pointer to CSV data
- `len` - Length of data in bytes

**Returns:**
- `0` - Success
- `-1` - Error (null parser, null data, negative length, or parse failure)

**Example (TypeScript):**
```typescript
const csvData = Buffer.from("name,age\nAlice,30\n");
const result = lib.symbols.parse_string(parser, csvData, csvData.length);

if (result === 0) {
  console.log("Parse succeeded");
} else {
  console.log("Parse failed");
}
```

**Important:** Pass data as `Buffer` not string to get correct byte pointer.

---

### cisv_get_row_count

Gets the number of parsed rows (FFI version).

**Signature:**
```c
int cisv_get_row_count(void* parser)
```

**Parameters:**
- `parser` - Pointer to parser

**Returns:**
- Number of rows (≥0)

**Example (TypeScript):**
```typescript
const rowCount = lib.symbols.get_row_count(parser);
console.log(`Parsed ${rowCount} rows`);
```

---

### cisv_get_field_count

Gets the number of fields in a specific row (FFI version).

**Signature:**
```c
int cisv_get_field_count(void* parser, int row_index)
```

**Parameters:**
- `parser` - Pointer to parser
- `row_index` - Row index (0-based)

**Returns:**
- Number of fields in row (≥0)
- `-1` if row_index is invalid

**Example (TypeScript):**
```typescript
const rowCount = lib.symbols.get_row_count(parser);
for (let i = 0; i < rowCount; i++) {
  const fieldCount = lib.symbols.get_field_count(parser, i);
  console.log(`Row ${i} has ${fieldCount} fields`);
}
```

---

## Memory Management

### Ownership Rules

1. **Parser Ownership:**
   - `parser_create()` allocates, caller owns
   - `parser_destroy()` deallocates

2. **String Ownership:**
   - All strings in `parser.all_rows` are owned by parser
   - Strings are cloned during parsing
   - Strings are freed in `parser_destroy()`

3. **Parser Reuse:**
   - Calling `parse_csv()` multiple times frees old data
   - Always safe to reuse parser

### Best Practices

**Always use `defer`:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)  // Guaranteed cleanup
```

**Don't leak parsers:**
```odin
// BAD: Parser leaked
parse_data :: proc(csv: string) {
    parser := cisv.parser_create()
    cisv.parse_csv(parser, csv)
    // Missing parser_destroy - MEMORY LEAK
}

// GOOD: Cleanup guaranteed
parse_data :: proc(csv: string) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    cisv.parse_csv(parser, csv)
}
```

**Reusing parsers:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

for csv_file in csv_files {
    data := os.read_entire_file(csv_file)
    defer delete(data)

    cisv.parse_csv(parser, string(data))  // Old results automatically freed
    process_rows(parser.all_rows)
}
```

---

## Error Handling

### Parse Errors

`parse_csv()` returns `false` on error. Errors occur in **strict mode** when:

1. **Unterminated quoted field:**
   ```csv
   "field without closing quote
   ```

2. **Character after closing quote:**
   ```csv
   "quoted"extra,field
   ```

**Handling Errors:**

**Strict Mode (default):**
```odin
ok := cisv.parse_csv(parser, csv_data)
if !ok {
    fmt.eprintln("Invalid CSV format")
    return
}
```

**Relaxed Mode:**
```odin
parser.config.relaxed = true
ok := cisv.parse_csv(parser, csv_data)
// ok will be true even for malformed CSV
```

### FFI Errors

FFI functions return `-1` on error:

```typescript
const result = lib.symbols.parse_string(parser, data, len);
if (result === -1) {
  console.error("Parse failed");
}
```

---

## Thread Safety

**Not thread-safe.** Each thread must use its own parser.

**Single-threaded:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)
cisv.parse_csv(parser, data)
```

**Multi-threaded:**
```odin
parse_worker :: proc(csv_data: string) {
    parser := cisv.parser_create()  // Each thread creates its own
    defer cisv.parser_destroy(parser)
    cisv.parse_csv(parser, csv_data)
}

thread1 := thread.create(parse_worker, data1)
thread2 := thread.create(parse_worker, data2)
```

---

## Performance Considerations

### Throughput

- **Pure parsing:** 66.67 MB/s (PRP-01 benchmark)
- **Row processing:** 217,876 rows/sec (100k row test)
- **Memory overhead:** ~5x input size

### Optimization Tips

**1. Reuse parsers:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

for csv_file in files {
    data := read_file(csv_file)
    cisv.parse_csv(parser, string(data))  // Reuse parser
    process(parser.all_rows)
}
```

**2. Pre-allocate for large files:**
```odin
// Parser handles allocation internally, no action needed
```

**3. Use relaxed mode for malformed data:**
```odin
parser.config.relaxed = true  // Skip error checks
```

**4. Avoid unnecessary string operations:**
```odin
// Process directly
for row in parser.all_rows {
    for field in row {
        // Use field directly, don't clone
    }
}
```

### Memory Usage

| Input Size | Estimated Memory | Ratio |
|------------|------------------|-------|
| 1 MB | ~5 MB | 5:1 |
| 10 MB | ~50 MB | 5:1 |
| 50 MB | ~250 MB | 5:1 |

Memory overhead comes from:
- String cloning for FFI safety
- Row/field structure overhead
- Dynamic array capacity

---

## See Also

- [Usage Cookbook](COOKBOOK.md) - Common patterns and examples
- [RFC 4180 Compliance](RFC4180.md) - Edge case handling
- [Performance Tuning](PERFORMANCE.md) - Optimization strategies
- [Integration Examples](INTEGRATION.md) - Bun FFI examples

---

**Last Updated:** 2025-10-12
**Version:** 0.3.0 (Phase 0 Complete)
