# OCSV Architecture Overview

**Document Date:** 2025-10-12
**Project Version:** v0.3.0
**Purpose:** Comprehensive technical architecture documentation

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Design Philosophy](#design-philosophy)
3. [Core Components](#core-components)
4. [Memory Management](#memory-management)
5. [State Machine Design](#state-machine-design)
6. [FFI Layer](#ffi-layer)
7. [Performance Characteristics](#performance-characteristics)
8. [Extension Points](#extension-points)
9. [Future Architecture](#future-architecture)

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │  Bun/JS App      │  │  Odin CLI Tool   │  │  Odin App  │ │
│  └────────┬─────────┘  └────────┬─────────┘  └─────┬──────┘ │
└───────────┼────────────────────┼─────────────────────┼───────┘
            │                    │                     │
┌───────────┼────────────────────┘                     │
│           ▼                                          │
│  ┌─────────────────┐                                 │
│  │  Bun FFI Layer  │                                 │
│  │  (dlopen)       │                                 │
│  └────────┬────────┘                                 │
│           │                                          │
│  FFI Bridge Layer                                    │
└───────────┼──────────────────────────────────────────┼───────┘
            │                                          │
┌───────────┼──────────────────────────────────────────┼───────┐
│           ▼                                          ▼       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 OCSV Core Library                     │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │  parser.odin       │  ffi_bindings.odin              │ │
│  │  - Parsing logic   │  - FFI exports                   │ │
│  │  - State machine   │  - Type conversions              │ │
│  │  - UTF-8 handling  │  - Memory safety                 │ │
│  │                    │                                   │ │
│  │  config.odin       │  cisv.odin                       │ │
│  │  - Configuration   │  - Public API                    │ │
│  │  - Defaults        │  - Re-exports                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Core Layer (Odin)                                          │
└──────────────────────────────────────────────────────────────┘
            │
┌───────────┼──────────────────────────────────────────────────┐
│           ▼                                                   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Odin Runtime & Standard Library                     │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │  • Memory Allocators (context.allocator)             │    │
│  │  • Dynamic Arrays ([dynamic]T)                       │    │
│  │  • String Utilities (core:strings)                   │    │
│  │  • UTF-8 Handling (core:unicode/utf8)                │    │
│  │  • OS Abstractions (core:os)                         │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  Platform Layer                                               │
└───────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Simplicity First**: Clean, readable code over clever tricks
2. **Memory Safety**: Explicit allocations with `defer` cleanup
3. **RFC 4180 Compliance**: Full standard compliance with edge case handling
4. **Zero-Copy When Possible**: Minimize memory allocations
5. **UTF-8 Native**: First-class Unicode support
6. **Performance**: Fast parsing without compromising correctness

---

## Design Philosophy

### Why Odin?

**Odin** is a modern systems programming language that provides:
- **Simplicity**: Clear, readable syntax
- **Safety**: Bounds checking, explicit memory management
- **Speed**: Compiles to native code with LLVM
- **Built-in Testing**: `odin test` command for testing
- **Fast Compilation**: Seconds, not minutes
- **No Hidden Allocations**: Every allocation is explicit

### Why Bun FFI?

**Bun FFI** provides:
- **Direct function calls**: No wrapper layer needed
- **Simple API**: `dlopen()` and function signatures
- **Fast**: Native performance with minimal overhead
- **Type-safe**: FFI types match Odin exports
- **No build complexity**: No node-gyp, no Python dependencies

### Why This Combination?

The Odin + Bun combination offers:
- ✅ **10x simpler build**: One command vs complex build systems
- ✅ **Memory safety**: `defer` guarantees cleanup
- ✅ **Fast iteration**: 2-second builds
- ✅ **Native performance**: 66.67 MB/s throughput
- ✅ **Modern ecosystem**: Bun + TypeScript support

---

## Core Components

### 1. Parser (`parser.odin`)

The parser implements a 5-state machine for RFC 4180 compliance.

**Key Structures:**

```odin
Parser :: struct {
    config:       Config,                 // Parser configuration
    state:        Parse_State,            // Current state
    field_buffer: [dynamic]u8,            // Buffer for current field
    current_row:  [dynamic]string,        // Current row being built
    all_rows:     [dynamic][]string,      // All parsed rows
    line_number:  int,                    // Current line (1-indexed)
}

Parse_State :: enum {
    Field_Start,        // Beginning of a field
    In_Field,           // Inside unquoted field
    In_Quoted_Field,    // Inside quoted field
    Quote_In_Quote,     // Found quote (might be "" or end)
    Field_End,          // Field complete
}
```

**Key Functions:**

```odin
parser_create :: proc() -> ^Parser
parser_destroy :: proc(parser: ^Parser)
parse_csv :: proc(parser: ^Parser, data: string) -> bool
clear_parser_data :: proc(parser: ^Parser)
```

### 2. Configuration (`config.odin`)

Configuration options for parser behavior.

```odin
Config :: struct {
    delimiter:               byte,    // Field delimiter (default: ',')
    quote:                   byte,    // Quote character (default: '"')
    escape:                  byte,    // Escape character (default: '"')
    skip_empty_lines:        bool,    // Skip empty lines
    comment:                 byte,    // Comment character (default: '#')
    trim:                    bool,    // Trim whitespace
    relaxed:                 bool,    // Relaxed parsing mode
    max_row_size:            int,     // Maximum row size
    from_line:               int,     // Start line
    to_line:                 int,     // End line
    skip_lines_with_error:   bool,    // Skip error lines
}

default_config :: proc() -> Config
```

### 3. FFI Bindings (`ffi_bindings.odin`)

Exports for Bun FFI integration.

```odin
// Export with C ABI
@(export, link_name="cisv_parser_create")
cisv_parser_create :: proc "c" () -> ^Parser {
    context = runtime.default_context()
    // ...
}

@(export, link_name="cisv_parse_string")
cisv_parse_string :: proc "c" (parser: ^Parser, data: [^]byte, len: i32) -> i32 {
    context = runtime.default_context()
    // ...
}

@(export, link_name="cisv_parser_destroy")
cisv_parser_destroy :: proc "c" (parser: ^Parser) {
    context = runtime.default_context()
    // ...
}
```

**Critical FFI Pattern:**
```odin
context = runtime.default_context()
```
This line is **required** in all FFI functions to ensure proper memory management.

### 4. Main Module (`cisv.odin`)

Package entry point that re-exports all public APIs.

```odin
package cisv

// Version information
VERSION_MAJOR :: 0
VERSION_MINOR :: 3
VERSION_PATCH :: 0

// Re-export public APIs
// (imports from parser, config, ffi_bindings)
```

---

## Memory Management

### Odin's Memory Model

**Explicit Allocations:**
```odin
buffer := make([dynamic]u8)        // Allocate dynamic array
defer delete(buffer)                // Guaranteed cleanup

str := strings.clone(input)         // Clone string
defer delete(str)                   // Cleanup
```

**Context Allocators:**
```odin
// Use temporary allocator for short-lived allocations
context.temp_allocator = // ... set temp allocator
data := make([dynamic]u8)  // Uses temp allocator
// Auto-freed when temp allocator is reset
```

### Parser Memory Management

**1. Parser Creation:**
```odin
parser := parser_create()
// Allocates:
// - Parser struct
// - field_buffer (dynamic array)
// - current_row (dynamic array)
// - all_rows (dynamic array)
```

**2. Parsing:**
```odin
parse_csv(parser, csv_data)
// Allocates:
// - Field strings (cloned for safety)
// - Row arrays
// All stored in parser.all_rows
```

**3. Parser Destruction:**
```odin
parser_destroy(parser)
// Frees (in order):
// 1. All field strings in all rows
// 2. All row arrays
// 3. field_buffer
// 4. current_row
// 5. all_rows
// 6. Parser struct itself
```

**4. Parser Reuse:**
```odin
clear_parser_data(parser)
// Frees:
// 1. All field strings
// 2. All row arrays
// Clears but doesn't free the dynamic arrays themselves
```

### Memory Safety Guarantees

✅ **No memory leaks**: Comprehensive cleanup in `parser_destroy`
✅ **No use-after-free**: String cloning for FFI boundary
✅ **No double-free**: Clear ownership rules
✅ **Bounds checking**: Enabled in debug builds

---

## State Machine Design

### State Transitions

```
Start
  │
  ├─ quote (")    → In_Quoted_Field
  ├─ delimiter    → emit empty field, stay Field_Start
  ├─ newline      → emit empty row
  ├─ comment (#)  → Field_End (skip line)
  └─ other        → In_Field

In_Field
  │
  ├─ delimiter    → emit field, Field_Start
  ├─ newline      → emit field + row, Field_Start
  └─ other        → append to buffer, stay In_Field

In_Quoted_Field
  │
  ├─ quote (")    → Quote_In_Quote
  └─ other        → append to buffer (including newlines!)

Quote_In_Quote
  │
  ├─ quote (")    → append literal ", In_Quoted_Field
  ├─ delimiter    → emit field, Field_Start
  ├─ newline      → emit field + row, Field_Start
  └─ other        → ERROR (or relaxed mode)
```

### Edge Case Handling

**Nested Quotes:**
```csv
"field with ""quotes""" → field with "quotes"
```

**Multiline Fields:**
```csv
"line 1
line 2
line 3"
```

**Delimiters in Quotes:**
```csv
"field, with, commas" → single field
```

**Empty Fields:**
```csv
a,,c → ["a", "", "c"]
```

**Trailing Delimiters:**
```csv
a,b, → ["a", "b", ""]
```

---

## FFI Layer

### JavaScript Side (Bun)

```javascript
import { dlopen, FFIType, suffix } from "bun:ffi";

const lib = dlopen(`./libcsv.${suffix}`, {
  cisv_parser_create: {
    returns: FFIType.ptr,
  },
  cisv_parse_string: {
    args: [FFIType.ptr, FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
  cisv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
  cisv_parser_destroy: {
    args: [FFIType.ptr],
    returns: FFIType.void,
  },
});

// Usage
const parser = lib.symbols.cisv_parser_create();
const data = new TextEncoder().encode("a,b,c\n1,2,3");
const result = lib.symbols.cisv_parse_string(parser, data, data.length);
const rowCount = lib.symbols.cisv_get_row_count(parser);
lib.symbols.cisv_parser_destroy(parser);
```

### Odin Side

```odin
@(export, link_name="cisv_parser_create")
cisv_parser_create :: proc "c" () -> ^Parser {
    context = runtime.default_context()  // CRITICAL!

    parser := new(Parser)
    parser.config = default_config()
    parser.field_buffer = make([dynamic]u8)
    parser.current_row = make([dynamic]string)
    parser.all_rows = make([dynamic][]string)
    parser.state = .Field_Start
    parser.line_number = 1

    return parser
}
```

### Type Conversions

**Odin → JavaScript:**
- `^Parser` → `FFIType.ptr`
- `i32` → `FFIType.i32`
- `cstring` → `FFIType.cstring`
- `bool` → `FFIType.bool`

**JavaScript → Odin:**
- `Buffer` → `[^]byte`
- `number` → `i32`
- `string` → `cstring` (via `new TextEncoder()`)

---

## Performance Characteristics

### Throughput

**Measured Performance:**
- **Pure parsing**: 66.67 MB/s (30k rows, 180KB data)
- **Row throughput**: 217,876 rows/second (100k row test)
- **Large files**: 3-4 MB/s (10-50MB with data generation)

### Time Complexity

**Parsing:**
- Best case: O(n) - single pass through data
- Average case: O(n) - character-by-character processing
- Worst case: O(n) - even with complex quotes/multiline

**Memory:**
- Space: O(rows × avg_fields × avg_field_size)
- Overhead: ~5x input size (string cloning + structure overhead)

### Performance Factors

**Fast:**
- ✅ Single-pass parsing
- ✅ Minimal branching in hot path
- ✅ Direct byte operations
- ✅ Native code (LLVM-optimized)

**Slower:**
- ⚠️ String cloning for FFI safety (~10% overhead)
- ⚠️ UTF-8 encoding/decoding (~5% overhead)
- ⚠️ Dynamic array resizing (amortized O(1))

### Memory Usage

| Input Size | Estimated Memory | Ratio |
|------------|------------------|-------|
| 1 MB | ~5 MB | 5:1 |
| 10 MB | ~50 MB | 5:1 |
| 50 MB | ~250 MB | 5:1 |

Memory overhead comes from:
- String cloning (safety requirement)
- Row/field structure overhead
- Dynamic array capacity (power-of-2 growth)

---

## Extension Points

### 1. Custom Delimiters

```odin
parser := parser_create()
parser.config.delimiter = '\t'  // TSV
parser.config.delimiter = ';'   // European CSV
parser.config.delimiter = '|'   // Pipe-separated
```

### 2. Custom Quote Characters

```odin
parser.config.quote = '\''  // Single quotes instead of double
```

### 3. Comment Lines

```odin
parser.config.comment = '#'  // Skip lines starting with #
parser.config.comment = 0    // Disable comments
```

### 4. Relaxed Mode

```odin
parser.config.relaxed = true  // Allow RFC 4180 violations
```

### 5. Future: Transformations

```odin
// Planned for Phase 2-3
parser.add_transform(0, Transform.Uppercase)
parser.add_transform(1, Transform.To_Int)
parser.add_custom_transform(2, custom_transform_proc)
```

### 6. Future: Streaming API

```odin
// Planned for Phase 2-3
parser.stream_mode = true
parser.on_row_callback = my_row_handler
parse_csv_stream(parser, io.Reader)
```

---

## Future Architecture

### Phase 1: Platform Expansion (Planned)

**Windows Support:**
- Cross-platform file I/O
- Windows-specific optimizations
- MSVC compatibility

**ARM64 Support:**
- NEON SIMD optimizations (expected 20-30% boost)
- Apple Silicon optimizations
- Raspberry Pi support

### Phase 2: Advanced Features (Planned)

**Streaming API:**
```odin
Parser_Stream :: struct {
    parser: ^Parser,
    on_row: proc(row: []string),
    buffer_size: int,
}
```

**Schema Validation:**
```odin
Schema :: struct {
    fields: []Field_Schema,
}

Field_Schema :: struct {
    name: string,
    type: Field_Type,
    required: bool,
    constraints: []Constraint,
}
```

### Phase 3: Performance (Planned)

**SIMD Optimizations:**
- Delimiter detection with NEON (ARM) / AVX2 (x86)
- Quote scanning
- Newline detection
- Expected: 20-30% performance improvement

**Multi-threading:**
- Chunk-based parallel parsing
- Lock-free data structures
- Work-stealing scheduler
- Expected: 2-4x speedup on multi-core systems

### Phase 4: Ecosystem (Planned)

**Plugin Architecture:**
```odin
Plugin :: struct {
    name: string,
    version: string,
    init: proc(parser: ^Parser),
    transform: proc(field: string) -> string,
}
```

**Writer API:**
```odin
Writer :: struct {
    config: Writer_Config,
    output: io.Writer,
}

write_csv :: proc(writer: ^Writer, rows: [][]string) -> bool
```

---

## Build System

### Compilation

**Release Build:**
```bash
odin build src -build-mode:shared -out:lib/libcsv.dylib -o:speed
```

**Debug Build:**
```bash
odin build src -build-mode:shared -out:lib/libcsv.dylib -debug
```

**Compilation Time:** ~2 seconds

### Testing

**Run All Tests:**
```bash
odin test tests -all-packages
```

**Run Specific Test:**
```bash
odin test tests -define:ODIN_TEST_NAMES=tests.test_basic_csv
```

**With Memory Tracking:**
```bash
odin test tests -all-packages -debug
```

### Optimization Flags

**Current:**
- `-o:speed`: Maximum optimization
- `-build-mode:shared`: Shared library
- `-march:native`: (planned) CPU-specific optimizations

**Future:**
- `-no-bounds-check`: Remove bounds checking in release
- `-microarch:specific`: Target specific CPU microarchitecture
- `-lto`: Link-time optimization

---

## Conclusion

OCSV's architecture is built around three core principles:

1. **Simplicity**: Clean Odin code, simple state machine, direct FFI
2. **Safety**: Explicit memory management, bounds checking, UTF-8 native
3. **Performance**: Native code, minimal overhead, single-pass parsing

The combination of Odin's modern language features and Bun's simple FFI creates a CSV parser that is:
- ✅ Fast (66.67 MB/s)
- ✅ Correct (RFC 4180 compliant)
- ✅ Safe (zero memory leaks)
- ✅ Simple (2-second builds, one command)
- ✅ Maintainable (clean, readable code)

**Future Roadmap:**
- Phase 1: Cross-platform support (Windows, ARM64)
- Phase 2: Advanced features (streaming, schema validation)
- Phase 3: Performance optimizations (SIMD, multi-threading)
- Phase 4: Ecosystem (plugins, writers, tools)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo
