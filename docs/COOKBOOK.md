# OCSV Cookbook - Common Usage Patterns

**Document Version:** 2.0
**Last Updated:** 2025-10-13
**Author:** Dan Castrillo

---

## Table of Contents

1. [Basic Parsing](#basic-parsing)
2. [Custom Delimiters](#custom-delimiters)
3. [Handling Comments](#handling-comments)
4. [Large File Processing](#large-file-processing)
5. [Error Handling](#error-handling)
6. [Parser Reuse](#parser-reuse)
7. [UTF-8 and International Characters](#utf-8-and-international-characters)
8. [Working with Quoted Fields](#working-with-quoted-fields)
9. [Custom Configuration](#custom-configuration)
10. [Performance Optimization](#performance-optimization)
11. [Parallel Processing (PRP-10)](#parallel-processing-prp-10)
12. [Bun FFI Integration](#bun-ffi-integration)
13. [Common Patterns](#common-patterns)

---

## Basic Parsing

### Parse a Simple CSV String

```odin
package main

import "core:fmt"
import cisv "src"

main :: proc() {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
    ok := ocsv.parse_csv(parser, csv_data)

    if !ok {
        fmt.eprintln("Failed to parse CSV")
        return
    }

    fmt.printfln("Parsed %d rows", len(parser.all_rows))

    for row, i in parser.all_rows {
        fmt.printf("Row %d: ", i)
        for field in row {
            fmt.printf("[%s] ", field)
        }
        fmt.println()
    }
}
```

**Output:**
```
Parsed 3 rows
Row 0: [name] [age] [city]
Row 1: [Alice] [30] [NYC]
Row 2: [Bob] [25] [SF]
```

### Parse CSV from File

```odin
package main

import "core:fmt"
import "core:os"
import cisv "src"

main :: proc() {
    // Read file
    data, ok := os.read_entire_file("data.csv")
    if !ok {
        fmt.eprintln("Failed to read file")
        return
    }
    defer delete(data)

    // Parse
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    ok = ocsv.parse_csv(parser, string(data))
    if !ok {
        fmt.eprintln("Failed to parse CSV")
        return
    }

    fmt.printfln("Parsed %d rows from file", len(parser.all_rows))
}
```

---

## Custom Delimiters

### TSV (Tab-Separated Values)

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Set tab as delimiter
parser.config.delimiter = '\t'

tsv_data := "name\tage\tcity\nAlice\t30\tNYC\nBob\t25\tSF\n"
ok := ocsv.parse_csv(parser, tsv_data)
```

### European CSV (Semicolon)

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// European format uses semicolon
parser.config.delimiter = ';'

csv_data := "name;age;city\nAlice;30;NYC\nBob;25;SF\n"
ok := ocsv.parse_csv(parser, csv_data)
```

### Pipe-Separated Values

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Pipe delimiter
parser.config.delimiter = '|'

psv_data := "name|age|city\nAlice|30|NYC\nBob|25|SF\n"
ok := ocsv.parse_csv(parser, psv_data)
```

---

## Handling Comments

### Skip Comment Lines

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Lines starting with # will be skipped
parser.config.comment = '#'

csv_data := `# This is a comment
# Data for Q1 2024
name,age,city
# Another comment
Alice,30,NYC
Bob,25,SF
`

ok := ocsv.parse_csv(parser, csv_data)
// Result: Only 3 rows (header + 2 data rows)
```

### Comments Inside Quoted Fields

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

parser.config.comment = '#'

// # inside quotes is NOT a comment
csv_data := `name,description
Product A,"#1 Best Seller"
Product B,"Use #hashtags"
`

ok := ocsv.parse_csv(parser, csv_data)
// Result: "Product A" has field "#1 Best Seller" (literal #)
```

---

## Large File Processing

### Process Large CSV File

```odin
package main

import "core:fmt"
import "core:os"
import "core:time"
import cisv "src"

process_large_file :: proc(filename: string) {
    fmt.printfln("Reading file: %s", filename)

    start := time.now()
    data, ok := os.read_entire_file(filename)
    if !ok {
        fmt.eprintln("Failed to read file")
        return
    }
    defer delete(data)

    read_time := time.diff(start, time.now())
    fmt.printfln("Read time: %v", read_time)

    // Parse
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    parse_start := time.now()
    ok = ocsv.parse_csv(parser, string(data))
    parse_time := time.diff(parse_start, time.now())

    if !ok {
        fmt.eprintln("Failed to parse CSV")
        return
    }

    // Statistics
    total_time := time.diff(start, time.now())
    size_mb := f64(len(data)) / 1024.0 / 1024.0
    throughput := size_mb / time.duration_seconds(parse_time)

    fmt.printfln("Rows parsed: %d", len(parser.all_rows))
    fmt.printfln("File size: %.2f MB", size_mb)
    fmt.printfln("Parse time: %v", parse_time)
    fmt.printfln("Throughput: %.2f MB/s", throughput)
    fmt.printfln("Total time: %v", total_time)
}

main :: proc() {
    process_large_file("large_data.csv")
}
```

### Memory-Efficient Processing

```odin
// Process CSV and free rows as you go
process_csv_streaming :: proc(parser: ^ocsv.Parser) {
    for row, i in parser.all_rows {
        // Process row
        process_row(row)

        // Free row data immediately after processing
        for field in row {
            delete(field)
        }
        delete(row)
    }

    // Clear the array
    clear(&parser.all_rows)
}

process_row :: proc(row: []string) {
    // Your processing logic here
    // Example: save to database, transform data, etc.
}
```

---

## Error Handling

### Check Parse Success

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

csv_data := "name,age,city\nAlice,30,NYC\n"
ok := ocsv.parse_csv(parser, csv_data)

if !ok {
    fmt.eprintln("Parse failed")
    return
}

if len(parser.all_rows) == 0 {
    fmt.eprintln("No data parsed")
    return
}

fmt.printfln("Successfully parsed %d rows", len(parser.all_rows))
```

### Relaxed Mode for Malformed CSV

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Enable relaxed mode to handle RFC 4180 violations
parser.config.relaxed = true

// This would normally fail (unterminated quote)
malformed_csv := `name,description
Alice,"Unterminated quote
Bob,"Another field"
`

ok := ocsv.parse_csv(parser, malformed_csv)
// With relaxed mode, this may succeed
```

---

## Parser Reuse

### Reuse Parser for Multiple Files

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

files := []string{"data1.csv", "data2.csv", "data3.csv"}

for filename in files {
    // Read file
    data, ok := os.read_entire_file(filename)
    if !ok {
        fmt.eprintfln("Skipping %s", filename)
        continue
    }
    defer delete(data)

    // Parse
    ok = ocsv.parse_csv(parser, string(data))
    if !ok {
        fmt.eprintfln("Failed to parse %s", filename)
        continue
    }

    // Process data
    fmt.printfln("%s: %d rows", filename, len(parser.all_rows))

    // IMPORTANT: Clear parser data before next file
    ocsv.clear_parser_data(parser)
}
```

**Key Point:** Always call `clear_parser_data()` between parses to free memory and reset state.

---

## UTF-8 and International Characters

### Parse CSV with Unicode

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// UTF-8 content with CJK characters
csv_data := `name,language,greeting
田中,Japanese,こんにちは
李明,Chinese,你好
김철수,Korean,안녕하세요
José,Spanish,¡Hola!
François,French,Bonjour
`

ok := ocsv.parse_csv(parser, csv_data)

if ok {
    for row in parser.all_rows {
        fmt.printfln("%s speaks %s: %s", row[0], row[1], row[2])
    }
}
```

### Emojis and Special Characters

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

csv_data := `product,rating,emoji
Widget A,5,⭐⭐⭐⭐⭐
Gadget B,4,⭐⭐⭐⭐
Tool C,3,⭐⭐⭐
Device D,5,🔥🔥🔥
`

ok := ocsv.parse_csv(parser, csv_data)
// Emojis are correctly parsed and preserved
```

---

## Working with Quoted Fields

### Fields with Embedded Delimiters

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

csv_data := `name,address
Alice,"123 Main St, Apt 4B, New York, NY"
Bob,"456 Oak Ave, San Francisco, CA"
`

ok := ocsv.parse_csv(parser, csv_data)

// Row 1: ["Alice", "123 Main St, Apt 4B, New York, NY"]
// The commas inside quotes are preserved as part of the field
```

### Nested Quotes

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Use "" to represent literal quotes inside quoted fields
csv_data := `name,quote
Alice,"She said ""Hello"" to me"
Bob,"His nickname is ""The Builder"""
`

ok := ocsv.parse_csv(parser, csv_data)

// Row 1: ["Alice", "She said \"Hello\" to me"]
// Row 2: ["Bob", "His nickname is \"The Builder\""]
```

### Multiline Fields

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

csv_data := `product,description
Widget A,"This is a great product.
It has multiple features.
Buy now!"
Gadget B,"Another excellent item."
`

ok := ocsv.parse_csv(parser, csv_data)

// Row 1 field 2 contains newlines:
// "This is a great product.\nIt has multiple features.\nBuy now!"
```

---

## Custom Configuration

### Full Configuration Example

```odin
package main

import "core:fmt"
import cisv "src"

main :: proc() {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    // Configure all options
    parser.config.delimiter = ';'           // Semicolon delimiter
    parser.config.quote = '\''              // Single quote instead of "
    parser.config.comment = '#'             // Skip # comment lines
    parser.config.skip_empty_lines = true   // Skip blank lines
    parser.config.relaxed = false           // Strict RFC 4180 mode
    parser.config.trim = false              // Don't trim whitespace

    csv_data := `# Comment line
'Product A';'Description with ; semicolon';100
'Product B';'Another description';200
`

    ok := ocsv.parse_csv(parser, csv_data)

    if ok {
        for row in parser.all_rows {
            fmt.printfln("%v", row)
        }
    }
}
```

### Create Custom Config Helper

```odin
// Helper function for common configurations
create_tsv_parser :: proc() -> ^ocsv.Parser {
    parser := ocsv.parser_create()
    parser.config.delimiter = '\t'
    parser.config.comment = 0  // Disable comments
    return parser
}

create_european_parser :: proc() -> ^ocsv.Parser {
    parser := ocsv.parser_create()
    parser.config.delimiter = ';'
    return parser
}

// Usage
main :: proc() {
    parser := create_tsv_parser()
    defer ocsv.parser_destroy(parser)

    // Parse TSV data
    // ...
}
```

---

## Performance Optimization

### Preallocate for Known Data Size

```odin
// If you know approximate row/field counts
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Reserve capacity to avoid reallocations
reserve(&parser.all_rows, 10000)  // Expect ~10k rows

ok := ocsv.parse_csv(parser, large_csv_data)
```

### Benchmark Your Parsing

```odin
package main

import "core:fmt"
import "core:time"
import "core:os"
import cisv "src"

benchmark_parse :: proc(filename: string) {
    data, ok := os.read_entire_file(filename)
    if !ok {
        fmt.eprintln("Failed to read file")
        return
    }
    defer delete(data)

    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    // Warm-up
    ocsv.parse_csv(parser, string(data))
    ocsv.clear_parser_data(parser)

    // Actual benchmark
    iterations :: 10
    total_duration: time.Duration

    for i in 0..<iterations {
        start := time.now()
        ocsv.parse_csv(parser, string(data))
        duration := time.diff(start, time.now())
        total_duration += duration
        ocsv.clear_parser_data(parser)
    }

    avg_duration := total_duration / iterations
    size_mb := f64(len(data)) / 1024.0 / 1024.0
    throughput := size_mb / time.duration_seconds(avg_duration)

    fmt.printfln("Average parse time: %v", avg_duration)
    fmt.printfln("Throughput: %.2f MB/s", throughput)
}

main :: proc() {
    benchmark_parse("test_data.csv")
}
```

---

## Parallel Processing (PRP-10)

### Parse Large File in Parallel

**Recommended for files ≥10 MB**

```odin
package main

import "core:fmt"
import "core:os"
import "core:time"
import ocsv "src"

main :: proc() {
    // Read large CSV file
    data, ok := os.read_entire_file("large_data.csv")
    if !ok {
        fmt.eprintln("Failed to read file")
        return
    }
    defer delete(data)

    fmt.printfln("File size: %.2f MB", f64(len(data)) / (1024.0 * 1024.0))

    // Parse in parallel (auto configuration)
    start := time.now()
    parser, parse_ok := ocsv.parse_parallel(string(data))
    elapsed := time.since(start)
    defer ocsv.parser_destroy(parser)

    if !parse_ok {
        fmt.eprintln("Parse failed")
        return
    }

    throughput := f64(len(data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed)

    fmt.printfln("Rows: %d", len(parser.all_rows))
    fmt.printfln("Time: %v", elapsed)
    fmt.printfln("Throughput: %.2f MB/s", throughput)
}
```

### Custom Thread Configuration

```odin
// Use specific number of threads
config := ocsv.Parallel_Config{
    num_threads = 8,  // Force 8 threads
}

parser, ok := ocsv.parse_parallel(csv_data, config)
defer ocsv.parser_destroy(parser)
```

### Custom File Size Threshold

```odin
// Use parallel for files ≥5 MB (instead of default 10 MB)
config := ocsv.Parallel_Config{
    min_file_size = 5 * 1024 * 1024,  // 5 MB
}

parser, ok := ocsv.parse_parallel(csv_data, config)
defer ocsv.parser_destroy(parser)
```

### Determine Optimal Thread Count

```odin
package main

import "core:fmt"
import "core:os"
import ocsv "src"

main :: proc() {
    data, ok := os.read_entire_file("data.csv")
    if !ok {
        fmt.eprintln("Failed to read file")
        return
    }
    defer delete(data)

    // Get optimal thread count for this file size
    optimal_threads := ocsv.get_optimal_thread_count(len(data))

    fmt.printfln("File size: %.2f MB", f64(len(data)) / (1024.0 * 1024.0))
    fmt.printfln("Optimal threads: %d", optimal_threads)

    if optimal_threads == 1 {
        // File too small, use sequential
        fmt.println("Using sequential parsing")
        parser := ocsv.parser_create()
        defer ocsv.parser_destroy(parser)
        ocsv.parse_csv(parser, string(data))
    } else {
        // Use parallel
        fmt.printfln("Using parallel parsing with %d threads", optimal_threads)
        config := ocsv.Parallel_Config{num_threads = optimal_threads}
        parser, ok := ocsv.parse_parallel(string(data), config)
        defer ocsv.parser_destroy(parser)
    }
}
```

### Compare Sequential vs Parallel

```odin
package main

import "core:fmt"
import "core:os"
import "core:time"
import ocsv "src"

compare_performance :: proc(filename: string) {
    data, ok := os.read_entire_file(filename)
    if !ok {
        fmt.eprintln("Failed to read file")
        return
    }
    defer delete(data)

    file_size_mb := f64(len(data)) / (1024.0 * 1024.0)
    fmt.printfln("File: %s (%.2f MB)", filename, file_size_mb)
    fmt.println()

    // Sequential parsing
    {
        parser := ocsv.parser_create()
        defer ocsv.parser_destroy(parser)

        start := time.now()
        ok := ocsv.parse_csv(parser, string(data))
        elapsed := time.since(start)

        if ok {
            throughput := file_size_mb / time.duration_seconds(elapsed)
            fmt.println("Sequential:")
            fmt.printfln("  Time: %v", elapsed)
            fmt.printfln("  Rows: %d", len(parser.all_rows))
            fmt.printfln("  Throughput: %.2f MB/s", throughput)
            fmt.println()
        }
    }

    // Parallel parsing (4 threads)
    {
        config := ocsv.Parallel_Config{num_threads = 4, min_file_size = 0}
        start := time.now()
        parser, ok := ocsv.parse_parallel(string(data), config)
        elapsed := time.since(start)
        defer ocsv.parser_destroy(parser)

        if ok {
            throughput := file_size_mb / time.duration_seconds(elapsed)
            fmt.println("Parallel (4 threads):")
            fmt.printfln("  Time: %v", elapsed)
            fmt.printfln("  Rows: %d", len(parser.all_rows))
            fmt.printfln("  Throughput: %.2f MB/s", throughput)
        }
    }
}

main :: proc() {
    compare_performance("large_data.csv")
}
```

### Parallel Processing with Transform Pipeline

```odin
package main

import "core:fmt"
import ocsv "src"

main :: proc() {
    // Parse large file in parallel
    data := get_large_csv_data()
    parser, ok := ocsv.parse_parallel(data)
    defer ocsv.parser_destroy(parser)

    if !ok {
        fmt.eprintln("Parse failed")
        return
    }

    // Apply transforms to parsed data
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    // Transform column 0: trim → uppercase
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, 0)
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_UPPERCASE, 0)

    // Transform column 1: trim → parse to float
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, 1)
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_PARSE_FLOAT, 1)

    // Apply pipeline to all rows
    ocsv.pipeline_apply_to_all(pipeline, registry, parser.all_rows[:])

    fmt.printfln("Processed %d rows", len(parser.all_rows))
}

get_large_csv_data :: proc() -> string {
    // Your large CSV data here
    return "..."
}
```

### Best Practices for Parallel Processing

**When to Use Parallel:**
```odin
// ✅ Good: Files ≥10 MB
data_size := len(csv_data)
if data_size >= 10 * 1024 * 1024 {
    parser, ok := ocsv.parse_parallel(csv_data)
    // Will use parallel processing
}

// ✅ Good: Let OCSV decide automatically
parser, ok := ocsv.parse_parallel(csv_data)
// Automatic threshold detection
```

**When NOT to Use Parallel:**
```odin
// ❌ Bad: Small files (< 10 MB)
// Threading overhead dominates, slower than sequential
small_data := "name,age\nAlice,30\n"
parser, ok := ocsv.parse_parallel(small_data)
// Will automatically fall back to sequential

// ✅ Good: Use sequential directly for small files
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)
ocsv.parse_csv(parser, small_data)
```

**Memory Considerations:**
```odin
// Parallel parsing uses ~2-4x memory during merge
// For 50 MB file: expect ~100-200 MB peak usage

// If memory is constrained, use streaming instead:
streaming_parser := ocsv.streaming_parser_create()
defer ocsv.streaming_parser_destroy(streaming_parser)

// Process in chunks (memory-efficient)
for chunk in read_chunks("large_file.csv") {
    ocsv.streaming_parse_chunk(streaming_parser, chunk)
    rows := ocsv.streaming_get_complete_rows(streaming_parser)
    // Process rows
    ocsv.streaming_clear_rows(streaming_parser)
}
```

### Performance Expectations

Based on PRP-10 benchmarks (Apple Silicon M-series):

```
File Size | Sequential | Parallel (4t) | Speedup
----------|------------|---------------|--------
15 KB     | 137 µs     | 140 µs        | 0.98x (auto fallback)
3.5 MB    | 26.4 ms    | 26.6 ms       | 0.99x (auto fallback)
14 MB     | 329 ms     | 175 ms        | 1.87x ✨
29 MB     | 632 ms     | 492 ms        | 1.29x ✨
```

**Key Observations:**
- Files < 10 MB: Automatic sequential fallback (zero overhead)
- Files 10-20 MB: **1.5-2x speedup** with 4 threads
- Files > 20 MB: **1.3-1.8x speedup** with 4 threads
- Throughput increases from ~40 MB/s to ~60-80 MB/s

---

## Bun FFI Integration

### Basic Bun FFI Usage

```typescript
import { dlopen, FFIType, suffix } from "bun:ffi";

// Load library
const lib = dlopen(`./libcsv.${suffix}`, {
  ocsv_parser_create: {
    returns: FFIType.ptr,
  },
  ocsv_parser_destroy: {
    args: [FFIType.ptr],
    returns: FFIType.void,
  },
  ocsv_parse_string: {
    args: [FFIType.ptr, FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
  ocsv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
  ocsv_get_field_count: {
    args: [FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
  ocsv_get_field: {
    args: [FFIType.ptr, FFIType.i32, FFIType.i32],
    returns: FFIType.cstring,
  },
});

// Parse CSV
const parser = lib.symbols.ocsv_parser_create();
const csvData = new TextEncoder().encode("name,age\nAlice,30\nBob,25\n");

const result = lib.symbols.ocsv_parse_string(
  parser,
  csvData,
  csvData.length
);

if (result === 0) {
  const rowCount = lib.symbols.ocsv_get_row_count(parser);
  console.log(`Parsed ${rowCount} rows`);

  for (let i = 0; i < rowCount; i++) {
    const fieldCount = lib.symbols.ocsv_get_field_count(parser, i);
    const row = [];
    for (let j = 0; j < fieldCount; j++) {
      const field = lib.symbols.ocsv_get_field(parser, i, j);
      row.push(field);
    }
    console.log(row);
  }
}

lib.symbols.ocsv_parser_destroy(parser);
```

### Wrapper Class for Bun

```typescript
class CsvParser {
  private parser: number;
  private lib: any;

  constructor(libPath: string) {
    this.lib = dlopen(libPath, {
      ocsv_parser_create: { returns: FFIType.ptr },
      ocsv_parser_destroy: { args: [FFIType.ptr], returns: FFIType.void },
      ocsv_parse_string: {
        args: [FFIType.ptr, FFIType.ptr, FFIType.i32],
        returns: FFIType.i32
      },
      ocsv_get_row_count: { args: [FFIType.ptr], returns: FFIType.i32 },
      ocsv_get_field_count: {
        args: [FFIType.ptr, FFIType.i32],
        returns: FFIType.i32
      },
      ocsv_get_field: {
        args: [FFIType.ptr, FFIType.i32, FFIType.i32],
        returns: FFIType.cstring
      },
    });
    this.parser = this.lib.symbols.ocsv_parser_create();
  }

  parse(csvData: string): string[][] {
    const encoded = new TextEncoder().encode(csvData);
    const result = this.lib.symbols.ocsv_parse_string(
      this.parser,
      encoded,
      encoded.length
    );

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    const rows: string[][] = [];
    const rowCount = this.lib.symbols.ocsv_get_row_count(this.parser);

    for (let i = 0; i < rowCount; i++) {
      const fieldCount = this.lib.symbols.ocsv_get_field_count(this.parser, i);
      const row: string[] = [];
      for (let j = 0; j < fieldCount; j++) {
        const field = this.lib.symbols.ocsv_get_field(this.parser, i, j);
        row.push(field);
      }
      rows.push(row);
    }

    return rows;
  }

  destroy() {
    this.lib.symbols.ocsv_parser_destroy(this.parser);
  }
}

// Usage
const parser = new CsvParser("./libcsv.dylib");
const rows = parser.parse("name,age\nAlice,30\nBob,25\n");
console.log(rows);
parser.destroy();
```

---

## Common Patterns

### Extract Header Row

```odin
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
ok := ocsv.parse_csv(parser, csv_data)

if ok && len(parser.all_rows) > 0 {
    header := parser.all_rows[0]
    data_rows := parser.all_rows[1:]

    fmt.printfln("Columns: %v", header)
    fmt.printfln("Data rows: %d", len(data_rows))
}
```

### Convert to Map/Dictionary Structure

```odin
import "core:slice"

// Convert CSV to array of maps (column name -> value)
csv_to_maps :: proc(parser: ^ocsv.Parser) -> []map[string]string {
    if len(parser.all_rows) == 0 {
        return nil
    }

    header := parser.all_rows[0]
    data_rows := parser.all_rows[1:]

    result := make([]map[string]string, len(data_rows))

    for row, i in data_rows {
        row_map := make(map[string]string)
        for field, j in row {
            if j < len(header) {
                row_map[header[j]] = field
            }
        }
        result[i] = row_map
    }

    return result
}

// Usage
main :: proc() {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
    ocsv.parse_csv(parser, csv_data)

    maps := csv_to_maps(parser)
    defer delete(maps)

    for row_map in maps {
        fmt.printfln("Name: %s, Age: %s, City: %s",
            row_map["name"], row_map["age"], row_map["city"])
        delete(row_map)
    }
}
```

### Filter Rows

```odin
// Filter rows based on a condition
filter_rows :: proc(parser: ^ocsv.Parser, predicate: proc([]string) -> bool) -> [][]string {
    filtered := make([dynamic][]string)

    for row in parser.all_rows {
        if predicate(row) {
            row_copy := make([]string, len(row))
            copy(row_copy, row)
            append(&filtered, row_copy)
        }
    }

    return filtered[:]
}

// Usage
main :: proc() {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\nCarol,35,LA\n"
    ocsv.parse_csv(parser, csv_data)

    // Filter: age > 26
    filtered := filter_rows(parser, proc(row: []string) -> bool {
        if len(row) < 2 do return false
        age, ok := strconv.parse_int(row[1])
        return ok && age > 26
    })
    defer delete(filtered)

    fmt.printfln("Filtered rows: %d", len(filtered))
}
```

### Count Unique Values

```odin
import "core:strings"

// Count occurrences of values in a specific column
count_unique :: proc(parser: ^ocsv.Parser, column_index: int) -> map[string]int {
    counts := make(map[string]int)

    for row in parser.all_rows {
        if column_index < len(row) {
            value := row[column_index]
            counts[value] = counts[value] + 1
        }
    }

    return counts
}

// Usage
main :: proc() {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    csv_data := "name,city\nAlice,NYC\nBob,SF\nCarol,NYC\nDave,SF\n"
    ocsv.parse_csv(parser, csv_data)

    // Count unique cities (column 1)
    counts := count_unique(parser, 1)
    defer delete(counts)

    for city, count in counts {
        fmt.printfln("%s: %d", city, count)
    }
}
```

---

## Additional Resources

- **[API Reference](API.md)** - Complete API documentation
- **[RFC 4180 Guide](RFC4180.md)** - Edge case handling details
- **[Performance Tuning](PERFORMANCE.md)** - Optimization strategies
- **[Integration Examples](INTEGRATION.md)** - More FFI examples

---

**Document Version:** 2.0
**Last Updated:** 2025-10-13
**Author:** Dan Castrillo
