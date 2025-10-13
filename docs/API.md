# OCSV API Reference

Complete API documentation for OCSV - Odin CSV Parser.

**Version:** 0.10.0 (Phase 4: Parallel Processing)
**Last Updated:** 2025-10-13

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
- [Parallel Processing](#parallel-processing)
  - [parse_parallel](#parse_parallel)
  - [Parallel_Config](#parallel_config)
  - [get_optimal_thread_count](#get_optimal_thread_count)
- [Transform System](#transform-system)
  - [Transform Functions](#transform-functions)
  - [Transform Registry](#transform-registry)
  - [Transform Pipeline](#transform-pipeline)
- [Streaming API](#streaming-api)
  - [Streaming Functions](#streaming-functions)
- [FFI Functions (Bun)](#ffi-functions-bun)
  - [ocsv_parser_create](#ocsv_parser_create)
  - [ocsv_parser_destroy](#ocsv_parser_destroy)
  - [ocsv_parse_string](#ocsv_parse_string)
  - [ocsv_get_row_count](#ocsv_get_row_count)
  - [ocsv_get_field_count](#ocsv_get_field_count)
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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

ocsv.parse_csv(parser, csv_data)

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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Configure for TSV with comments
parser.config.delimiter = '\t'
parser.config.comment = '#'
parser.config.relaxed = true

ocsv.parse_csv(parser, tsv_data)
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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)  // Recommended: use defer

// Alternative (manual):
ocsv.parser_destroy(parser)
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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
ok := ocsv.parse_csv(parser, csv_data)

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
ok := ocsv.parse_csv(parser, malformed_csv)
// Returns true even if CSV violates RFC 4180
```

**Parser Reuse:**
```odin
// Parse multiple CSVs with same parser (previous results are cleared)
ocsv.parse_csv(parser, csv1)  // Results in parser.all_rows
ocsv.parse_csv(parser, csv2)  // Previous results are freed, new results in parser.all_rows
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
config := ocsv.default_config()
config.delimiter = '\t'  // Override delimiter
config.comment = 0       // Disable comments

parser := ocsv.parser_create()
parser.config = config   // Apply custom config
defer ocsv.parser_destroy(parser)
```

**Note:** `parser_create` automatically initializes `parser.config` with defaults, so you typically just modify the parser's config directly:

```odin
parser := ocsv.parser_create()
parser.config.delimiter = '\t'
```

---

## Parallel Processing

**Version:** 0.10.0
**Status:** Production-ready (4+ threads)

OCSV provides multi-threaded CSV parsing for large files (≥10 MB) with automatic fallback to sequential parsing for smaller files.

### parse_parallel

Parses CSV data in parallel using multiple worker threads.

**Signature:**
```odin
parse_parallel :: proc(
    data: string,
    config: Parallel_Config = {},
    allocator := context.allocator,
) -> (^Parser, bool)
```

**Parameters:**
- `data` - CSV string to parse
- `config` - Parallel configuration (optional, see [Parallel_Config](#parallel_config))
- `allocator` - Memory allocator (default: context.allocator)

**Returns:**
- `^Parser` - Pointer to parser with parsed results
- `bool` - Success status

**Behavior:**
- Automatically falls back to sequential for files < 10 MB (configurable)
- Splits data at safe row boundaries (never in middle of quoted fields)
- Each thread parses its chunk independently
- Results are merged in original order
- Returns merged parser with all rows

**Example (Auto Configuration):**
```odin
import ocsv "../src"

// Read large CSV file
data, ok := os.read_entire_file("large_data.csv")
defer delete(data)

// Parse in parallel (auto-detects threads and threshold)
parser, parse_ok := ocsv.parse_parallel(string(data))
defer ocsv.parser_destroy(parser)

if parse_ok {
    fmt.printfln("Parsed %d rows", len(parser.all_rows))
}
```

**Example (Custom Configuration):**
```odin
config := ocsv.Parallel_Config{
    num_threads   = 8,              // Use 8 threads
    min_file_size = 5 * 1024 * 1024, // 5 MB threshold
}

parser, ok := ocsv.parse_parallel(csv_data, config)
defer ocsv.parser_destroy(parser)
```

**Performance:**
```
File Size | Sequential | Parallel (4t) | Speedup
----------|------------|---------------|--------
15 KB     | 137 µs     | 140 µs        | 0.98x (sequential fallback)
3.5 MB    | 26.4 ms    | 26.6 ms       | 0.99x (sequential fallback)
14 MB     | 329 ms     | 175 ms        | 1.87x ✨
29 MB     | 632 ms     | 492 ms        | 1.29x ✨
```

**Thread Safety:**
- Creates independent parsers for each chunk
- Thread-safe result collection
- No shared mutable state between workers

**Known Limitations:**
- 2-thread configuration may have intermittent race condition (use 4+ threads)
- Requires minimum 1 MB per thread
- Memory overhead: ~2-4x during merge phase

---

### Parallel_Config

Configuration for parallel parsing.

**Structure:**
```odin
Parallel_Config :: struct {
    num_threads:   int,  // Number of worker threads (0 = auto-detect)
    min_file_size: int,  // Minimum file size for parallel (0 = 10 MB default)
}
```

**Fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `num_threads` | `int` | `0` | Number of threads (0 = auto-detect CPU cores) |
| `min_file_size` | `int` | `10485760` | Minimum bytes for parallel (10 MB default, 0 = use default) |

**Auto-Detection Behavior:**
- `num_threads = 0`: Uses `os.processor_core_count()`
- Limits threads based on data size (minimum 1 MB per thread)
- Falls back to sequential if only 1 thread needed

**Examples:**

**Auto Configuration (Recommended):**
```odin
config := ocsv.Parallel_Config{}  // All defaults
// or
parser, ok := ocsv.parse_parallel(data)  // Implicit default config
```

**Fixed Thread Count:**
```odin
config := ocsv.Parallel_Config{
    num_threads = 4,  // Always use 4 threads
}
```

**Custom Threshold:**
```odin
config := ocsv.Parallel_Config{
    min_file_size = 5 * 1024 * 1024,  // Use parallel for files ≥5 MB
}
```

**Aggressive Parallel (Testing):**
```odin
config := ocsv.Parallel_Config{
    num_threads   = 8,
    min_file_size = 0,  // Use 10 MB default threshold
}
```

**Force Sequential:**
```odin
config := ocsv.Parallel_Config{
    num_threads   = 1,  // Forces sequential
}
```

---

### get_optimal_thread_count

Returns the optimal number of threads for a given data size.

**Signature:**
```odin
get_optimal_thread_count :: proc(data_size: int) -> int
```

**Parameters:**
- `data_size` - Size of CSV data in bytes

**Returns:**
- Optimal thread count (1 = sequential, 2+ = parallel)

**Logic:**
1. Files < 10 MB: Returns `1` (sequential)
2. Calculates: `max_threads = data_size / (1 MB)`
3. Uses min of: `max_threads` and `CPU cores`

**Example:**
```odin
data_size := len(csv_data)
optimal := ocsv.get_optimal_thread_count(data_size)

fmt.printfln("Data size: %d MB", data_size / (1024*1024))
fmt.printfln("Optimal threads: %d", optimal)

if optimal == 1 {
    // Use sequential
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)
    ocsv.parse_csv(parser, csv_data)
} else {
    // Use parallel
    config := ocsv.Parallel_Config{num_threads = optimal}
    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)
}
```

**Typical Results:**
```
Data Size | Optimal Threads | Reason
----------|----------------|--------
1 MB      | 1              | Too small (< 10 MB)
5 MB      | 1              | Too small (< 10 MB)
10 MB     | 4              | 10 MB / 1 MB = 10, limited by CPU cores
50 MB     | 8              | 50 MB / 1 MB = 50, limited by CPU cores
100 MB    | 8              | 100 MB / 1 MB = 100, limited by CPU cores
```

---

## Transform System

**Version:** 0.9.0
**Status:** Production-ready

Transform system for data cleaning, normalization, and type conversion.

### Transform Functions

Built-in transforms available in the registry:

**String Transforms:**
```odin
TRANSFORM_TRIM              // Remove leading/trailing whitespace
TRANSFORM_TRIM_LEFT         // Remove leading whitespace
TRANSFORM_TRIM_RIGHT        // Remove trailing whitespace
TRANSFORM_UPPERCASE         // Convert to uppercase
TRANSFORM_LOWERCASE         // Convert to lowercase
TRANSFORM_CAPITALIZE        // Capitalize first letter
TRANSFORM_NORMALIZE_SPACE   // Normalize whitespace to single spaces
TRANSFORM_REMOVE_QUOTES     // Remove surrounding quotes
```

**Numeric Transforms:**
```odin
TRANSFORM_PARSE_FLOAT       // Parse to float representation
TRANSFORM_PARSE_INT         // Parse to integer representation
```

**Boolean Transforms:**
```odin
TRANSFORM_PARSE_BOOL        // Parse to "true"/"false"
```

**Date Transforms:**
```odin
TRANSFORM_DATE_ISO8601      // Convert various formats to ISO 8601
```

**Example:**
```odin
registry := ocsv.registry_create()
defer ocsv.registry_destroy(registry)

// Apply single transform
result := ocsv.apply_transform(registry, ocsv.TRANSFORM_UPPERCASE, "hello", context.allocator)
defer delete(result)
fmt.println(result)  // "HELLO"
```

### Transform Registry

Central registry for managing transforms.

**Functions:**
```odin
// Create/destroy registry
registry_create :: proc() -> ^Transform_Registry
registry_destroy :: proc(registry: ^Transform_Registry)

// Register custom transform
register_transform :: proc(
    registry: ^Transform_Registry,
    name: string,
    func: Transform_Func,
)

// Apply transforms
apply_transform :: proc(
    registry: ^Transform_Registry,
    name: string,
    input: string,
    allocator := context.allocator,
) -> string

apply_transform_to_row :: proc(
    registry: ^Transform_Registry,
    name: string,
    row: []string,
    column_index: int,
    allocator := context.allocator,
) -> bool

apply_transform_to_column :: proc(
    registry: ^Transform_Registry,
    name: string,
    rows: [][]string,
    column_index: int,
    allocator := context.allocator,
)
```

**Example:**
```odin
// Create registry
registry := ocsv.registry_create()
defer ocsv.registry_destroy(registry)

// Register custom transform
my_transform :: proc(input: string, allocator := context.allocator) -> string {
    return strings.to_upper(input, allocator)
}

ocsv.register_transform(registry, "my_uppercase", my_transform)

// Apply to entire column
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

ocsv.parse_csv(parser, csv_data)
ocsv.apply_transform_to_column(registry, "my_uppercase", parser.all_rows[:], 0)
```

### Transform Pipeline

Chain multiple transforms together.

**Functions:**
```odin
// Create/destroy pipeline
pipeline_create :: proc() -> ^Transform_Pipeline
pipeline_destroy :: proc(pipeline: ^Transform_Pipeline)

// Add transformation steps
pipeline_add_step :: proc(
    pipeline: ^Transform_Pipeline,
    transform_name: string,
    column_index: int,
)

// Apply pipeline
pipeline_apply_to_row :: proc(
    pipeline: ^Transform_Pipeline,
    registry: ^Transform_Registry,
    row: []string,
    allocator := context.allocator,
)

pipeline_apply_to_all :: proc(
    pipeline: ^Transform_Pipeline,
    registry: ^Transform_Registry,
    rows: [][]string,
    allocator := context.allocator,
)
```

**Example:**
```odin
registry := ocsv.registry_create()
defer ocsv.registry_destroy(registry)

pipeline := ocsv.pipeline_create()
defer ocsv.pipeline_destroy(pipeline)

// Build pipeline: trim → uppercase → normalize spaces
ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, 0)        // Column 0
ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_UPPERCASE, 0)   // Column 0
ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_NORMALIZE_SPACE, 0) // Column 0

// Parse and apply
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

ocsv.parse_csv(parser, csv_data)
ocsv.pipeline_apply_to_all(pipeline, registry, parser.all_rows[:])
```

---

## Streaming API

**Version:** 0.8.0
**Status:** Production-ready

Memory-efficient streaming parser for large files.

### Streaming Functions

```odin
// Create streaming parser
streaming_parser_create :: proc() -> ^Streaming_Parser
streaming_parser_destroy :: proc(parser: ^Streaming_Parser)

// Process in chunks
streaming_parse_chunk :: proc(
    parser: ^Streaming_Parser,
    chunk: string,
) -> bool

// Get complete rows
streaming_get_complete_rows :: proc(
    parser: ^Streaming_Parser,
) -> [][]string

// Clear processed rows
streaming_clear_rows :: proc(parser: ^Streaming_Parser)
```

**Example:**
```odin
import "core:os"

streaming_parser := ocsv.streaming_parser_create()
defer ocsv.streaming_parser_destroy(streaming_parser)

file, err := os.open("large_file.csv")
defer os.close(file)

buffer: [4096]byte
for {
    bytes_read, read_err := os.read(file, buffer[:])
    if bytes_read == 0 do break

    chunk := string(buffer[:bytes_read])
    ocsv.streaming_parse_chunk(streaming_parser, chunk)

    // Process complete rows
    complete_rows := ocsv.streaming_get_complete_rows(streaming_parser)
    for row in complete_rows {
        // Process row
    }
    ocsv.streaming_clear_rows(streaming_parser)
}
```

---

## FFI Functions (Bun)

Functions exported with C ABI for use with Bun FFI.

### ocsv_parser_create

Creates a new parser (FFI version).

**Signature:**
```c
void* ocsv_parser_create()
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

### ocsv_parser_destroy

Destroys a parser (FFI version).

**Signature:**
```c
void ocsv_parser_destroy(void* parser)
```

**Parameters:**
- `parser` - Pointer to parser

**Example (TypeScript):**
```typescript
lib.symbols.parser_destroy(parser);
```

---

### ocsv_parse_string

Parses CSV data (FFI version).

**Signature:**
```c
int ocsv_parse_string(void* parser, const char* data, int len)
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

### ocsv_get_row_count

Gets the number of parsed rows (FFI version).

**Signature:**
```c
int ocsv_get_row_count(void* parser)
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

### ocsv_get_field_count

Gets the number of fields in a specific row (FFI version).

**Signature:**
```c
int ocsv_get_field_count(void* parser, int row_index)
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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)  // Guaranteed cleanup
```

**Don't leak parsers:**
```odin
// BAD: Parser leaked
parse_data :: proc(csv: string) {
    parser := ocsv.parser_create()
    ocsv.parse_csv(parser, csv)
    // Missing parser_destroy - MEMORY LEAK
}

// GOOD: Cleanup guaranteed
parse_data :: proc(csv: string) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)
    ocsv.parse_csv(parser, csv)
}
```

**Reusing parsers:**
```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

for csv_file in csv_files {
    data := os.read_entire_file(csv_file)
    defer delete(data)

    ocsv.parse_csv(parser, string(data))  // Old results automatically freed
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
ok := ocsv.parse_csv(parser, csv_data)
if !ok {
    fmt.eprintln("Invalid CSV format")
    return
}
```

**Relaxed Mode:**
```odin
parser.config.relaxed = true
ok := ocsv.parse_csv(parser, csv_data)
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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)
ocsv.parse_csv(parser, data)
```

**Multi-threaded:**
```odin
parse_worker :: proc(csv_data: string) {
    parser := ocsv.parser_create()  // Each thread creates its own
    defer ocsv.parser_destroy(parser)
    ocsv.parse_csv(parser, csv_data)
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
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

for csv_file in files {
    data := read_file(csv_file)
    ocsv.parse_csv(parser, string(data))  // Reuse parser
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

**Document Version:** 2.0
**Last Updated:** 2025-10-13
**Author:** Dan Castrillo
**Version:** 0.10.0 (Phase 4: Parallel Processing)
