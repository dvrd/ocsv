# Streaming API

**Version:** 0.8.0
**Status:** Production-ready
**Last Updated:** 2025-10-15

---

## Overview

The Streaming API provides memory-efficient parsing for large CSV files by processing data in chunks. Unlike the standard parser which loads entire files into memory, the streaming parser processes rows incrementally as data becomes available.

**Key Benefits:**
- **Low Memory Footprint** - Only complete rows are kept in memory
- **Incremental Processing** - Start processing before entire file is loaded
- **Handles Large Files** - Parse GB-sized files with minimal RAM
- **Chunk Boundary Safety** - Correctly handles rows split across chunks

---

## Core Functions

### streaming_parser_create

Creates a new streaming parser.

**Signature:**
```odin
streaming_parser_create :: proc() -> ^Streaming_Parser
```

**Returns:**
- `^Streaming_Parser` - Pointer to newly created streaming parser

**Memory:**
- Allocates memory for parser and internal buffers
- Must be freed with `streaming_parser_destroy`

**Example:**
```odin
streaming_parser := ocsv.streaming_parser_create()
defer ocsv.streaming_parser_destroy(streaming_parser)
```

---

### streaming_parser_destroy

Destroys a streaming parser and frees all associated memory.

**Signature:**
```odin
streaming_parser_destroy :: proc(parser: ^Streaming_Parser)
```

**Parameters:**
- `parser` - Pointer to streaming parser to destroy

**Memory:**
- Frees all complete rows
- Frees internal buffers
- Frees the parser struct itself

**Example:**
```odin
defer ocsv.streaming_parser_destroy(streaming_parser)
```

---

### streaming_parse_chunk

Parses a chunk of CSV data and accumulates complete rows.

**Signature:**
```odin
streaming_parse_chunk :: proc(
    parser: ^Streaming_Parser,
    chunk: string,
) -> bool
```

**Parameters:**
- `parser` - Pointer to streaming parser
- `chunk` - CSV data chunk to process

**Returns:**
- `true` - Chunk processed successfully
- `false` - Parse error occurred

**Behavior:**
- Processes the chunk incrementally
- Accumulates complete rows in internal buffer
- Preserves incomplete rows (split across chunk boundaries)
- Can be called multiple times with sequential chunks

**Example:**
```odin
streaming_parser := ocsv.streaming_parser_create()
defer ocsv.streaming_parser_destroy(streaming_parser)

// Process chunks
chunk1 := "name,age\nAl"
chunk2 := "ice,30\nBob,25\n"

ok1 := ocsv.streaming_parse_chunk(streaming_parser, chunk1)
ok2 := ocsv.streaming_parse_chunk(streaming_parser, chunk2)

// Get complete rows (both chunks merged)
rows := ocsv.streaming_get_complete_rows(streaming_parser)
// rows = [["name", "age"], ["Alice", "30"], ["Bob", "25"]]
```

**Chunk Boundary Handling:**
```csv
Chunk 1: "name,ag"    ← Incomplete row (no \n)
Chunk 2: "e\nJohn,30" ← Completes first row, adds second
```

The parser correctly buffers incomplete rows across chunks.

---

### streaming_get_complete_rows

Returns all complete rows parsed so far.

**Signature:**
```odin
streaming_get_complete_rows :: proc(
    parser: ^Streaming_Parser,
) -> [][]string
```

**Parameters:**
- `parser` - Pointer to streaming parser

**Returns:**
- `[][]string` - Slice of complete rows (each row is a slice of fields)

**Behavior:**
- Returns only rows that are fully parsed (ended with newline)
- Incomplete rows (at chunk boundaries) are not returned until completed
- Safe to call multiple times (returns same rows until cleared)

**Example:**
```odin
rows := ocsv.streaming_get_complete_rows(streaming_parser)
for row in rows {
    for field in row {
        fmt.printf("%s ", field)
    }
    fmt.printf("\n")
}
```

---

### streaming_clear_rows

Clears all complete rows from the parser, freeing memory.

**Signature:**
```odin
streaming_clear_rows :: proc(parser: ^Streaming_Parser)
```

**Parameters:**
- `parser` - Pointer to streaming parser

**Behavior:**
- Frees memory for all complete rows
- Preserves incomplete rows (at chunk boundaries)
- Resets row buffer to empty

**Example:**
```odin
// Get and process rows
rows := ocsv.streaming_get_complete_rows(streaming_parser)
process_rows(rows)

// Clear processed rows to free memory
ocsv.streaming_clear_rows(streaming_parser)

// Continue parsing more chunks...
```

**Important:** Call this regularly when processing large files to avoid memory buildup.

---

## Usage Patterns

### Basic File Streaming

```odin
import "core:os"
import ocsv "../src"

parse_large_file :: proc(filename: string) {
    streaming_parser := ocsv.streaming_parser_create()
    defer ocsv.streaming_parser_destroy(streaming_parser)

    file, err := os.open(filename)
    if err != os.ERROR_NONE {
        fmt.eprintfln("Error opening file: %v", err)
        return
    }
    defer os.close(file)

    buffer: [4096]byte
    for {
        bytes_read, read_err := os.read(file, buffer[:])
        if bytes_read == 0 do break

        chunk := string(buffer[:bytes_read])
        ok := ocsv.streaming_parse_chunk(streaming_parser, chunk)

        if !ok {
            fmt.eprintln("Parse error in chunk")
            break
        }

        // Process complete rows incrementally
        complete_rows := ocsv.streaming_get_complete_rows(streaming_parser)
        for row in complete_rows {
            // Process row immediately
            fmt.println(row)
        }

        // Free memory after processing
        ocsv.streaming_clear_rows(streaming_parser)
    }
}
```

### Larger Buffer Size

For better performance, use larger buffers:

```odin
buffer: [64 * 1024]byte  // 64 KB chunks
```

**Trade-offs:**
- Larger buffers = fewer system calls, better I/O performance
- Smaller buffers = more granular memory control, faster initial response

**Recommended:** 16-64 KB for most use cases

---

### Network Streaming

```odin
parse_http_stream :: proc(url: string) {
    streaming_parser := ocsv.streaming_parser_create()
    defer ocsv.streaming_parser_destroy(streaming_parser)

    // Pseudo-code for HTTP streaming
    response := http.get_stream(url)
    defer http.close(response)

    for chunk in response {
        ocsv.streaming_parse_chunk(streaming_parser, chunk)

        rows := ocsv.streaming_get_complete_rows(streaming_parser)
        process_rows(rows)
        ocsv.streaming_clear_rows(streaming_parser)
    }
}
```

---

### Row-by-Row Processing

```odin
process_csv_streaming :: proc(filename: string) {
    streaming_parser := ocsv.streaming_parser_create()
    defer ocsv.streaming_parser_destroy(streaming_parser)

    file, _ := os.open(filename)
    defer os.close(file)

    buffer: [4096]byte
    row_count := 0

    for {
        bytes_read, _ := os.read(file, buffer[:])
        if bytes_read == 0 do break

        chunk := string(buffer[:bytes_read])
        ocsv.streaming_parse_chunk(streaming_parser, chunk)

        // Process each row immediately
        rows := ocsv.streaming_get_complete_rows(streaming_parser)
        for row in rows {
            row_count += 1
            fmt.printfln("Row %d: %v", row_count, row)
        }

        // Free memory after each batch
        ocsv.streaming_clear_rows(streaming_parser)
    }

    fmt.printfln("Total rows: %d", row_count)
}
```

---

## Performance Characteristics

### Memory Usage

| Standard Parser | Streaming Parser |
|-----------------|------------------|
| Loads entire file | Processes incrementally |
| Memory = ~5x file size | Memory = buffer + few rows |
| Fast random access | Sequential access only |

**Example:**
- **1 GB CSV file**
  - Standard: ~5 GB RAM required
  - Streaming: ~10-20 MB RAM (buffer + active rows)

### Throughput

Streaming parser is slightly slower than standard parser due to chunk overhead:

| Parser Type | Throughput | Use Case |
|-------------|------------|----------|
| Standard | ~60 MB/s | Files that fit in memory |
| Streaming | ~45 MB/s | Files larger than available RAM |

**Trade-off:** Accept 25% slower parsing for 100x less memory usage.

---

## Edge Cases

### Chunk Boundaries

The streaming parser correctly handles:

**Row Split Across Chunks:**
```
Chunk 1: "name,age\nJo"
Chunk 2: "hn,30\n"
Result: ["name", "age"], ["John", "30"]
```

**Quoted Field Split:**
```
Chunk 1: "name,description\nWidget,\"A gre"
Chunk 2: "at product\"\n"
Result: ["name", "description"], ["Widget", "A great product"]
```

**Multiline Field Split:**
```
Chunk 1: "id,note\n1,\"Line 1"
Chunk 2: "\nLine 2\"\n"
Result: ["id", "note"], ["1", "Line 1\nLine 2"]
```

### Empty Chunks

```odin
ok := ocsv.streaming_parse_chunk(streaming_parser, "")
// ok = true, no rows added
```

### Final Chunk Without Newline

```odin
ocsv.streaming_parse_chunk(streaming_parser, "a,b,c\n")
ocsv.streaming_parse_chunk(streaming_parser, "d,e,f")  // No trailing \n

rows := ocsv.streaming_get_complete_rows(streaming_parser)
// rows = [["a","b","c"]]  ← Last row not returned (incomplete)

// To flush final row, add newline or finalize parser
ocsv.streaming_parse_chunk(streaming_parser, "\n")
rows = ocsv.streaming_get_complete_rows(streaming_parser)
// rows = [["d","e","f"]]  ← Now complete
```

---

## Configuration

The streaming parser respects the same configuration as the standard parser:

```odin
streaming_parser := ocsv.streaming_parser_create()
defer ocsv.streaming_parser_destroy(streaming_parser)

// Configure delimiter, quotes, etc.
streaming_parser.config.delimiter = '\t'
streaming_parser.config.relaxed = true
streaming_parser.config.comment = '#'

// Now process chunks with custom config
ocsv.streaming_parse_chunk(streaming_parser, chunk)
```

See [Configuration Guide](../02-user-guide/configuration.md) for all options.

---

## Error Handling

### Parse Errors

```odin
ok := ocsv.streaming_parse_chunk(streaming_parser, chunk)
if !ok {
    fmt.eprintln("Parse error in chunk")
    // Error details available in parser.error (if error tracking enabled)
}
```

**Common Errors:**
- Unterminated quoted field (in strict mode)
- Invalid character after closing quote

**Relaxed Mode:**
```odin
streaming_parser.config.relaxed = true
// Now tolerates malformed CSV
```

---

## Best Practices

### 1. Clear Rows Regularly

```odin
// BAD: Memory builds up
for chunk in chunks {
    ocsv.streaming_parse_chunk(parser, chunk)
    // Never clear rows → memory leak
}

// GOOD: Clear after processing
for chunk in chunks {
    ocsv.streaming_parse_chunk(parser, chunk)
    rows := ocsv.streaming_get_complete_rows(parser)
    process_rows(rows)
    ocsv.streaming_clear_rows(parser)  // ← Free memory
}
```

### 2. Use Appropriate Buffer Size

```odin
// Too small (1 KB) - too many system calls
buffer: [1024]byte

// Good (16 KB) - balanced
buffer: [16 * 1024]byte

// Better (64 KB) - fewer system calls
buffer: [64 * 1024]byte

// Too large (1 MB) - diminishing returns
buffer: [1024 * 1024]byte
```

### 3. Handle Final Row

```odin
// Process all chunks
for chunk in chunks {
    ocsv.streaming_parse_chunk(parser, chunk)
    process_and_clear(parser)
}

// Don't forget: flush final row if no trailing newline
ocsv.streaming_parse_chunk(parser, "\n")
final_rows := ocsv.streaming_get_complete_rows(parser)
process_rows(final_rows)
```

### 4. Defer Cleanup

```odin
streaming_parser := ocsv.streaming_parser_create()
defer ocsv.streaming_parser_destroy(streaming_parser)  // ← Always use defer
```

---

## Comparison with Standard Parser

| Feature | Standard Parser | Streaming Parser |
|---------|----------------|------------------|
| **API** | `parse_csv(parser, data)` | `streaming_parse_chunk(parser, chunk)` |
| **Memory** | ~5x file size | ~Buffer size |
| **Speed** | ~60 MB/s | ~45 MB/s |
| **Random Access** | ✅ All rows available | ❌ Sequential only |
| **Large Files** | ❌ Limited by RAM | ✅ Process any size |
| **Simplicity** | ✅ One function call | ⚠️ Loop with chunks |

**Use Standard Parser When:**
- File fits comfortably in memory
- Need random access to all rows
- Want maximum throughput

**Use Streaming Parser When:**
- File larger than available RAM
- Processing incrementally (e.g., network stream)
- Want low, predictable memory usage

---

## See Also

- [API Reference](../02-user-guide/api-reference.md) - Standard parser API
- [Configuration Guide](../02-user-guide/configuration.md) - Parser configuration
- [Cookbook](../02-user-guide/cookbook.md) - Common usage patterns
- [Performance Tuning](../04-internals/performance-tuning.md) - Optimization strategies

---

**Last Updated:** 2025-10-15
