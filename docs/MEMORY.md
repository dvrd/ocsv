# Memory Ownership & Management Guide

**Version:** 1.0
**Last Updated:** 2025-01-14
**Status:** ✅ Complete

---

## Table of Contents

1. [Introduction](#introduction)
2. [Core Principles](#core-principles)
3. [Ownership Patterns](#ownership-patterns)
4. [Module-by-Module Guide](#module-by-module-guide)
5. [Common Pitfalls](#common-pitfalls)
6. [Best Practices](#best-practices)
7. [Memory Leak Prevention](#memory-leak-prevention)
8. [Debugging Memory Issues](#debugging-memory-issues)

---

## Introduction

OCSV maintains **zero memory leaks** across all 182+ tests. This guide documents memory ownership patterns throughout the codebase to help contributors maintain this standard.

**Key Goals:**
- ✅ Explicit ownership for all heap-allocated data
- ✅ Clear documentation of who frees what
- ✅ Predictable memory lifetimes
- ✅ Zero-copy designs where possible

---

## Core Principles

### 1. Explicit Ownership

Every heap allocation has a clear owner responsible for freeing it.

```odin
// GOOD: Ownership is explicit
parser := parser_create()        // Caller owns parser
defer parser_destroy(parser)     // Caller frees parser

// GOOD: Documented return value ownership
result := apply_transform(registry, "uppercase", "hello")  // Caller owns result
defer delete(result)
```

### 2. Ownership Transfer

When ownership transfers, the original owner **must not** free the data.

```odin
// Ownership transfer example
my_string := "hello"
append(&parser.current_row, my_string)  // Parser now owns my_string
// Do NOT delete(my_string) here!
```

### 3. Temporary Data

Use `context.temp_allocator` for short-lived allocations.

```odin
// GOOD: Temporary allocation
lower := strings.to_lower(field, context.temp_allocator)
// No delete() needed - freed at scope exit
```

### 4. Callback Lifetimes

Data passed to callbacks is **temporary** unless documented otherwise.

```odin
// Callback receives TEMPORARY data
row_callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
    // row is ONLY valid during this callback
    // If you need to keep it, clone the strings
    my_copy := make([]string, len(row))
    for field, i in row {
        my_copy[i] = strings.clone(field)
    }
    return true
}
```

---

## Ownership Patterns

### Pattern 1: Creator Owns

**Signature:** `proc() -> ^Type`

The **caller** owns the returned pointer and must destroy it.

```odin
// CALLER owns
parser := parser_create()
defer parser_destroy(parser)

registry := registry_create()
defer registry_destroy(registry)

pipeline := pipeline_create()
defer pipeline_destroy(pipeline)

plugin_reg := plugin_registry_create()
defer plugin_registry_destroy(plugin_reg)
```

### Pattern 2: Allocator Returns

**Signature:** `proc(..., allocator := context.allocator) -> string`

The **caller** owns the returned value and must free it.

```odin
// CALLER owns result
result := apply_transform(registry, "uppercase", "hello")
defer delete(result)

trimmed := transform_trim("  hello  ")
defer delete(trimmed)
```

### Pattern 3: In-Place Mutation

**Signature:** `proc(data: ^Type, ...)`

Function **mutates** existing data and manages memory internally.

```odin
// Function frees old value and replaces it
apply_transform_to_row(registry, "uppercase", row, 0)
// Old row[0] was freed, new value is in place
// Do NOT free the old value yourself
```

### Pattern 4: Container Ownership

**Signature:** `struct { data: [dynamic]T }`

Container **owns** all elements. Destroying container frees all elements.

```odin
Parser :: struct {
    field_buffer: [dynamic]u8,      // Parser owns buffer
    current_row:  [dynamic]string,  // Parser owns strings
    all_rows:     [dynamic][]string, // Parser owns all rows and their strings
}

// parser_destroy() frees:
// 1. All strings in all rows
// 2. All row arrays
// 3. All buffers
// 4. The parser itself
```

### Pattern 5: Temporary/Callback Data

**Signature:** `callback :: proc(data: []T, ...) -> bool`

Callback receives **temporary** data valid only during callback.

```odin
// Streaming parser example
parse_csv_stream(config, "data.csv")

// Inside row callback:
row_callback :: proc(row: []string, ...) -> bool {
    // row is TEMPORARY - will be freed after callback returns

    // If you need to keep data, clone it:
    my_copy := make([]string, len(row))
    for field, i in row {
        my_copy[i] = strings.clone(field)
    }

    // Store my_copy somewhere
    return true
}
```

### Pattern 6: Error Messages

**Signature:** `result: Validation_Result`

Error messages may be **allocated or literals** - check before freeing.

```odin
// Validation errors contain messages
result := validate_row(schema, row, 1)

// Messages from fmt.aprintf() are allocated
// Messages from custom validators might be literals
// Use free_messages parameter carefully:

validation_result_destroy(&result, free_messages=true)  // Only if you're sure all messages are allocated
validation_result_destroy(&result, free_messages=false) // Safe default
```

---

## Module-by-Module Guide

### Parser (parser.odin)

#### parser_create()
```odin
parser_create :: proc() -> ^Parser
```
- **Returns:** Heap-allocated parser
- **Ownership:** CALLER owns, must call `parser_destroy()`
- **Lifetime:** Until explicitly destroyed

**Example:**
```odin
parser := parser_create()
defer parser_destroy(parser)
```

#### parser_destroy()
```odin
parser_destroy :: proc(parser: ^Parser)
```
- **Frees:**
  - `parser.field_buffer`
  - All strings in `parser.all_rows` (deep free)
  - All row arrays in `parser.all_rows`
  - `parser.all_rows` itself
  - All strings in `parser.current_row`
  - `parser.current_row` itself
  - The `parser` struct
- **Call Once:** Must only be called once per parser

#### parse_csv()
```odin
parse_csv :: proc(parser: ^Parser, data: string) -> bool
```
- **Input:** `data` is **not owned** by parser (no copy made)
- **Output:** Results stored in `parser.all_rows`
- **Ownership:** PARSER owns all results until destroyed
- **Reuse:** Safe to call multiple times on same parser

**Example:**
```odin
parser := parser_create()
defer parser_destroy(parser)

ok := parse_csv(parser, "a,b,c\n1,2,3\n")
// parser.all_rows now contains results
// PARSER owns all rows until parser_destroy()
```

#### clear_parser_data()
```odin
clear_parser_data :: proc(parser: ^Parser)
```
- **Frees:** All data in `parser.all_rows` and `parser.current_row`
- **Use Case:** Reusing parser for multiple files
- **Does NOT:** Free the parser itself

**Example:**
```odin
parser := parser_create()
defer parser_destroy(parser)

parse_csv(parser, "file1.csv")
// Process parser.all_rows...

clear_parser_data(parser)  // Free old data
parse_csv(parser, "file2.csv")  // Parse new data
```

---

### Transform (transform.odin)

#### registry_create()
```odin
registry_create :: proc(allocator := context.allocator) -> ^Transform_Registry
```
- **Returns:** Heap-allocated registry
- **Ownership:** CALLER owns, must call `registry_destroy()`

#### registry_destroy()
```odin
registry_destroy :: proc(registry: ^Transform_Registry)
```
- **Frees:**
  - `registry.transforms` map
  - The `registry` struct
- **Does NOT:** Free transform functions (they're just function pointers)

#### Transform Functions (Built-in)
```odin
transform_uppercase :: proc(field: string, allocator := context.allocator) -> string
transform_trim :: proc(field: string, allocator := context.allocator) -> string
// ... etc
```
- **Returns:** NEW allocated string
- **Ownership:** CALLER owns result, must `delete()` it
- **Input:** NOT modified (read-only)

**Example:**
```odin
result := transform_uppercase("hello")
defer delete(result)
// result == "HELLO"
```

#### apply_transform()
```odin
apply_transform :: proc(
    registry: ^Transform_Registry,
    name: string,
    field: string,
    allocator := context.allocator,
) -> string
```
- **Returns:** NEW allocated string
- **Ownership:** CALLER owns result, must `delete()` it
- **Fallback:** If transform not found, returns `strings.clone(field)`

**Example:**
```odin
result := apply_transform(registry, "uppercase", "hello")
defer delete(result)
```

#### apply_transform_to_row()
```odin
apply_transform_to_row :: proc(
    registry: ^Transform_Registry,
    transform_name: string,
    row: []string,
    field_index: int,
    allocator := context.allocator,
) -> bool
```
- **Mutates:** `row[field_index]` **in place**
- **Frees:** Old value of `row[field_index]`
- **Ownership:** Row still owns the new value

**Example:**
```odin
row := []string{"hello", "world"}
// ... row is owned by something (e.g., parser.all_rows)

apply_transform_to_row(registry, "uppercase", row, 0)
// row[0] changed: "hello" -> "HELLO"
// Old "hello" was freed
// Row still owns "HELLO"
```

#### Transform_Pipeline

```odin
pipeline_create :: proc(allocator := context.allocator) -> ^Transform_Pipeline
pipeline_destroy :: proc(pipeline: ^Transform_Pipeline)
```
- **Ownership:** CALLER owns pipeline, must destroy
- **Memory:** Pipeline only stores steps (metadata), not data

**Example:**
```odin
pipeline := pipeline_create()
defer pipeline_destroy(pipeline)

pipeline_add_step(pipeline, "trim", 0)
pipeline_add_step(pipeline, "uppercase", 0)

// Apply to row (mutates in place)
pipeline_apply_to_row(pipeline, registry, row)
```

---

### Schema (schema.odin)

#### validate_row()
```odin
validate_row :: proc(schema: ^Schema, row: []string, row_num: int) -> Validation_Result
```
- **Returns:** `Validation_Result` with allocated errors/warnings
- **Ownership:** CALLER owns result, must call `validation_result_destroy()`
- **Error Messages:** Allocated with `fmt.aprintf()` - must be freed

**Example:**
```odin
result := validate_row(schema, row, 1)
defer validation_result_destroy(&result, free_messages=true)

if !result.valid {
    for err in result.errors {
        fmt.println(err.message)
    }
}
```

#### validation_result_destroy()
```odin
validation_result_destroy :: proc(result: ^Validation_Result, free_messages: bool = true)
```
- **Frees:**
  - `result.errors` array
  - `result.warnings` array
  - If `free_messages=true`: All error message strings
- **Warning:** Only set `free_messages=true` if ALL messages are allocated
- **Safe Default:** `free_messages=false` (avoids double-free of literals)

**Example:**
```odin
// All messages from fmt.aprintf() - safe to free
result := validate_row(schema, row, 1)
validation_result_destroy(&result, free_messages=true)

// Custom validator might return literals - don't free
result2 := validate_row(schema2, row, 1)
validation_result_destroy(&result2, free_messages=false)
```

#### validate_and_convert()
```odin
validate_and_convert :: proc(schema: ^Schema, rows: [][]string) -> (typed_rows: []Typed_Row, result: Validation_Result)
```
- **Returns:**
  - `typed_rows`: CALLER owns, must free
  - `result`: CALLER owns, must call `validation_result_destroy()`
- **Typed Values:** Union types - no separate deallocation needed

**Example:**
```odin
typed_rows, result := validate_and_convert(schema, parser.all_rows)
defer delete(typed_rows)
defer validation_result_destroy(&result, free_messages=true)

for typed_row in typed_rows {
    // typed_row contains union values (no dealloc needed)
    for val in typed_row {
        switch v in val {
        case string:
            fmt.println("String:", v)
        case i64:
            fmt.println("Int:", v)
        // ...
        }
    }
}
```

---

### Streaming (streaming.odin)

#### streaming_parser_create()
```odin
streaming_parser_create :: proc(config: Streaming_Config) -> ^Streaming_Parser
```
- **Returns:** Heap-allocated streaming parser
- **Ownership:** CALLER owns, must call `streaming_parser_destroy()`

#### streaming_parser_destroy()
```odin
streaming_parser_destroy :: proc(parser: ^Streaming_Parser)
```
- **Frees:**
  - `parser.field_buffer`
  - `parser.leftover`
  - All strings in `parser.current_row`
  - `parser.current_row` itself
  - The `parser` struct

#### parse_csv_stream()
```odin
parse_csv_stream :: proc(
    config: Streaming_Config,
    file_path: string,
) -> (rows_processed: int, ok: bool)
```
- **Callbacks:** `config.row_callback` or `config.schema_callback`
- **Row Lifetime:** TEMPORARY - valid ONLY during callback
- **Zero-Copy Design:** Streaming parser does NOT accumulate rows in memory

**Critical:** Row data passed to callbacks is **freed immediately** after callback returns.

**Example (CORRECT):**
```odin
my_data := make([dynamic][]string)

row_callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
    data := cast(^[dynamic][]string)user_data

    // Clone the row if you need to keep it
    row_copy := make([]string, len(row))
    for field, i in row {
        row_copy[i] = strings.clone(field)
    }

    append(data, row_copy)
    return true
}

config := default_streaming_config(row_callback)
config.user_data = &my_data

parse_csv_stream(config, "data.csv")

// Clean up cloned rows
defer {
    for row in my_data {
        for field in row {
            delete(field)
        }
        delete(row)
    }
    delete(my_data)
}
```

**Example (INCORRECT - Memory Corruption):**
```odin
my_data := make([dynamic][]string)

row_callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
    data := cast(^[dynamic][]string)user_data

    // BUG: Storing pointer to temporary data!
    append(data, row)  // ❌ row will be freed after callback returns
    return true
}

// my_data now contains dangling pointers! 💥
```

#### Row_Callback Signature
```odin
Row_Callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool
```
- **row:** TEMPORARY slice - valid only during callback
- **Strings in row:** TEMPORARY - freed after callback returns
- **user_data:** Passed through from `config.user_data`
- **Return:** `false` to stop parsing, `true` to continue

---

### Plugin (plugin.odin)

#### plugin_registry_create()
```odin
plugin_registry_create :: proc(allocator := context.allocator) -> ^Plugin_Registry
```
- **Returns:** Heap-allocated plugin registry
- **Ownership:** CALLER owns, must call `plugin_registry_destroy()`

#### plugin_registry_destroy()
```odin
plugin_registry_destroy :: proc(registry: ^Plugin_Registry)
```
- **Calls:** `cleanup()` on all plugins that have cleanup functions
- **Frees:**
  - All plugin maps
  - The `registry` struct
- **Plugin Lifecycle:** Calls cleanup functions in this order:
  1. Transform plugins
  2. Validator plugins
  3. Parser plugins
  4. Output plugins

#### Transform Plugin Functions

Transform plugins follow the same memory rules as standard transforms:

```odin
Transform_Func :: #type proc(field: string, allocator := context.allocator) -> string
```
- **Returns:** NEW allocated string
- **Ownership:** CALLER owns result, must `delete()` it

#### Plugin Bridge Functions

```odin
plugin_sync_transform_to_registry :: proc(
    plugin_reg: ^Plugin_Registry,
    plugin_name: string,
    transform_reg: ^Transform_Registry,
) -> bool
```
- **No Ownership Transfer:** Just registers function pointer
- **No Memory Impact:** Only stores reference to transform function

```odin
plugin_create_unified_registry :: proc(allocator := context.allocator) -> (^Plugin_Registry, ^Transform_Registry)
```
- **Returns:** TWO registries
- **Ownership:** CALLER owns both, must destroy both

**Example:**
```odin
plugin_reg, transform_reg := plugin_create_unified_registry()
defer plugin_registry_destroy(plugin_reg)
defer registry_destroy(transform_reg)
```

---

## Common Pitfalls

### Pitfall 1: String Builder Premature Destruction

**Bug Example:**
```odin
generate_content :: proc() -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)  // ❌ BUG!

    strings.write_string(&builder, "hello")
    return strings.to_string(builder)  // Returns dangling pointer!
}
```

**Fix:**
```odin
generate_content :: proc(allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)
    // Note: Caller must delete returned string

    strings.write_string(&builder, "hello")
    return strings.to_string(builder)  // Ownership transfers to caller
}

// Usage:
content := generate_content()
defer delete(content)
```

**Why:** `strings.to_string(builder)` returns the internal buffer. If you destroy the builder before returning, you return freed memory.

---

### Pitfall 2: Callback Data Lifetime

**Bug Example:**
```odin
stored_rows := make([dynamic][]string)

callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
    rows := cast(^[dynamic][]string)user_data
    append(rows, row)  // ❌ BUG: row is temporary!
    return true
}

parse_csv_stream(config, "data.csv")
// stored_rows contains dangling pointers! 💥
```

**Fix:**
```odin
stored_rows := make([dynamic][]string)

callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
    rows := cast(^[dynamic][]string)user_data

    // Clone the row
    row_copy := make([]string, len(row))
    for field, i in row {
        row_copy[i] = strings.clone(field)
    }

    append(rows, row_copy)  // ✅ Safe: we own row_copy
    return true
}
```

---

### Pitfall 3: Double Free

**Bug Example:**
```odin
row := []string{"hello", "world"}

// Apply transform (frees old value)
apply_transform_to_row(registry, "uppercase", row, 0)

// BUG: Trying to free again
delete(row[0])  // ❌ Double free! Already freed by apply_transform_to_row
```

**Fix:**
```odin
row := []string{"hello", "world"}

// Apply transform (handles freeing internally)
apply_transform_to_row(registry, "uppercase", row, 0)

// Don't manually free - function already did it
// row[0] is now "HELLO" (new allocation owned by row)
```

---

### Pitfall 4: Forgetting to Free Transform Results

**Bug Example:**
```odin
// Memory leak - result is never freed
result := apply_transform(registry, "uppercase", "hello")
// ❌ BUG: Forgot to delete(result)
```

**Fix:**
```odin
result := apply_transform(registry, "uppercase", "hello")
defer delete(result)  // ✅ Properly freed
```

---

### Pitfall 5: Reusing Parser Without Clearing

**Bug Example:**
```odin
parser := parser_create()
defer parser_destroy(parser)

parse_csv(parser, "file1.csv")
// Process data...

// BUG: Parsing again without clearing causes memory leak
parse_csv(parser, "file2.csv")  // ❌ file1.csv data still in memory!
```

**Fix:**
```odin
parser := parser_create()
defer parser_destroy(parser)

parse_csv(parser, "file1.csv")
// Process data...

clear_parser_data(parser)  // ✅ Free old data
parse_csv(parser, "file2.csv")
```

---

### Pitfall 6: Validation Error Message Lifetime

**Bug Example:**
```odin
// Custom validator returns string literal
my_validator :: proc(value: string, ctx: rawptr) -> (bool, string) {
    if len(value) == 0 {
        return false, "Value cannot be empty"  // String literal
    }
    return true, ""
}

result := validate_row(schema, row, 1)
validation_result_destroy(&result, free_messages=true)  // ❌ BUG: Tries to free literal!
```

**Fix Option 1 (Don't free literals):**
```odin
validation_result_destroy(&result, free_messages=false)  // ✅ Safe
```

**Fix Option 2 (Allocate messages):**
```odin
my_validator :: proc(value: string, ctx: rawptr) -> (bool, string) {
    if len(value) == 0 {
        return false, strings.clone("Value cannot be empty")  // Allocated
    }
    return true, ""
}

result := validate_row(schema, row, 1)
validation_result_destroy(&result, free_messages=true)  // ✅ Safe now
```

---

## Best Practices

### 1. Always Use defer for Cleanup

```odin
// GOOD: Cleanup guaranteed
parser := parser_create()
defer parser_destroy(parser)

// GOOD: Even with early returns
if !parse_csv(parser, data) {
    return false  // parser_destroy() still called
}
```

### 2. Document Ownership in Comments

```odin
// generate_csv_content returns a newly allocated string.
// Caller is responsible for deleting the returned string.
generate_csv_content :: proc(config: Benchmark_Config) -> string {
    builder := strings.builder_make()
    // ... build content ...
    return strings.to_string(builder)  // Ownership transfers to caller
}
```

### 3. Use Temp Allocator for Short-Lived Data

```odin
// GOOD: Temporary allocation
lower := strings.to_lower(field, context.temp_allocator)
// No manual cleanup needed

// GOOD: Use temp allocator in inner loops
for field in row {
    trimmed := strings.trim_space(field, context.temp_allocator)
    // Process trimmed...
}
```

### 4. Clone Before Storing Callback Data

```odin
callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
    // GOOD: Clone if you need to keep the data
    row_copy := make([]string, len(row))
    for field, i in row {
        row_copy[i] = strings.clone(field)
    }

    store_somewhere(row_copy)
    return true
}
```

### 5. Clear Before Reusing Containers

```odin
// GOOD: Clear before reuse
parser := parser_create()
defer parser_destroy(parser)

for file in files {
    clear_parser_data(parser)  // Free previous data
    parse_csv(parser, file)
    // Process...
}
```

### 6. Prefer Zero-Copy Designs

```odin
// GOOD: Streaming doesn't accumulate in memory
parse_csv_stream(config, "huge_file.csv")

// BAD: Regular parser loads entire file
parser := parser_create()
defer parser_destroy(parser)
parse_csv(parser, huge_string)  // All rows in memory
```

---

## Memory Leak Prevention

### Checklist for New Code

- [ ] Every `make()` has a corresponding `delete()`
- [ ] Every `new()` has a corresponding `free()`
- [ ] Every `*_create()` has a corresponding `*_destroy()`
- [ ] All returned strings are documented (who owns them?)
- [ ] Callbacks document data lifetime (temporary or transferred?)
- [ ] String builders are not destroyed prematurely
- [ ] Temp allocator used for short-lived data
- [ ] Reused containers are cleared before reuse

### Testing for Leaks

```bash
# Run tests with tracking allocator
odin test tests -all-packages -define:USE_TRACKING_ALLOCATOR=true -debug

# Expected output: 0 leaks
# Testing...
# Total memory leaks: 0
```

### Common Leak Patterns to Avoid

1. **Forgetting to destroy created objects**
   ```odin
   parser := parser_create()
   // ❌ Forgot defer parser_destroy(parser)
   ```

2. **Not freeing transform results**
   ```odin
   result := apply_transform(registry, "uppercase", "hello")
   // ❌ Forgot defer delete(result)
   ```

3. **Leaking validation errors**
   ```odin
   result := validate_row(schema, row, 1)
   // ❌ Forgot validation_result_destroy(&result)
   ```

4. **Not clearing parser before reuse**
   ```odin
   parse_csv(parser, "file1.csv")
   parse_csv(parser, "file2.csv")  // ❌ file1 data leaked
   ```

---

## Debugging Memory Issues

### Step 1: Enable Tracking Allocator

```odin
when ODIN_DEBUG {
    import "core:mem"

    main :: proc() {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
        defer mem.tracking_allocator_destroy(&track)

        // Your code here...

        if len(track.allocation_map) > 0 {
            fmt.println("Memory leaks detected:")
            for _, entry in track.allocation_map {
                fmt.printf("  %v bytes at %p\n", entry.size, entry.memory)
            }
        }
    }
}
```

### Step 2: Use Valgrind (Linux)

```bash
# Compile with debug symbols
odin build src -debug -out:ocsv

# Run with valgrind
valgrind --leak-check=full --show-leak-kinds=all ./ocsv
```

### Step 3: Use Instruments (macOS)

```bash
# Compile with debug symbols
odin build src -debug -out:ocsv

# Open in Instruments
instruments -t Leaks ./ocsv
```

### Step 4: Add Logging

```odin
// Add logging to track allocations
parser_create :: proc() -> ^Parser {
    fmt.println("[ALLOC] parser_create")
    parser := new(Parser)
    // ...
    return parser
}

parser_destroy :: proc(parser: ^Parser) {
    fmt.println("[FREE] parser_destroy")
    // ...
}
```

---

## Quick Reference

| Operation | Owner | Must Free? | How? |
|-----------|-------|------------|------|
| `parser_create()` | Caller | ✅ | `parser_destroy()` |
| `parse_csv()` results | Parser | ✅ | `parser_destroy()` or `clear_parser_data()` |
| `registry_create()` | Caller | ✅ | `registry_destroy()` |
| `apply_transform()` result | Caller | ✅ | `delete()` |
| `apply_transform_to_row()` | Row (mutates in place) | ❌ | Handled internally |
| `validate_row()` result | Caller | ✅ | `validation_result_destroy()` |
| Streaming callback `row` | Temporary | ❌ | Freed after callback |
| `plugin_registry_create()` | Caller | ✅ | `plugin_registry_destroy()` |
| `pipeline_create()` | Caller | ✅ | `pipeline_destroy()` |
| String builder result | Caller | ✅ | `delete()` |
| Temp allocator data | Auto | ❌ | Freed at scope exit |

---

## Summary

**Golden Rules:**

1. **Every allocation has an owner** - Document who frees what
2. **Use `defer` for cleanup** - Ensures cleanup even on early returns
3. **Callback data is temporary** - Clone if you need to keep it
4. **Test with tracking allocator** - Maintain zero-leak standard
5. **When in doubt, check this guide** - Memory patterns are documented

**Achievement:** OCSV maintains **zero memory leaks** across 182+ tests by following these patterns consistently.

---

**Questions or Issues?**

- Check module-specific sections above
- Review common pitfalls
- Run tests with tracking allocator
- Report issues at: https://github.com/anthropics/ocsv/issues
