# API Reference

Complete API documentation for OCSV - Odin CSV Parser.

**Version:** 0.10.0
**Last Updated:** 2025-10-15

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

- **Pure parsing:** 61.84 MB/s (baseline)
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

**2. Use relaxed mode for malformed data:**
```odin
parser.config.relaxed = true  // Skip error checks
```

**3. Avoid unnecessary string operations:**
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

- [Configuration Guide](configuration.md) - Detailed configuration options
- [Error Handling Guide](error-handling.md) - Advanced error patterns
- [Cookbook](cookbook.md) - Common recipes and patterns
- [Streaming API](../03-advanced/streaming.md) - Memory-efficient large file parsing

---

**Last Updated:** 2025-10-15
