# OCSV Implementation Action Plan
**Using PRP (Product Requirement Prompt) Methodology**
**Odin + Bun FFI Implementation**

**Document Date:** 2025-10-12
**Planning Approach:** PRP-based Agentic Engineering
**Reference:** https://github.com/Wirasm/PRPs-agentic-eng
**Technology Stack:** Odin programming language + Bun FFI
**Based on:** CISV v0.0.7 (C implementation)

---

## Executive Summary

This action plan transforms OCSV from concept to a production-ready, cross-platform CSV processing library using **Odin** and **Bun FFI** instead of C and Node.js N-API. Using PRP methodology, we structure implementation as vertical slices of working software with complete context and validation criteria.

**Current State (CISV Reference):**
- ✅ Excellent performance (71-104 MB/s in C)
- ⚠️ NOT production-ready (edge cases incomplete)
- ⚠️ Complex build system (node-gyp, binding.gyp)
- ⚠️ Limited platform support (Linux/Unix x86_64 only)
- ⚠️ Minimal test coverage (~20%)
- ⚠️ C/C++ complexity with N-API wrapper

**Target State (20 weeks):**
- ✅ Production-ready with RFC 4180 compliance
- ✅ Cross-platform (Windows, macOS, Linux, ARM64)
- ✅ >95% test coverage with fuzzing
- ✅ Comprehensive documentation
- ✅ Enterprise-grade error handling
- ✅ Advanced features (schema validation, parallel processing)
- ✅ **90-95% of C performance** (acceptable trade-off)
- ✅ **10x simpler build system** (no node-gyp)
- ✅ **20-30% faster development** (Odin advantages)

**Timeline:** 20 weeks across 5 phases (4 weeks faster than C version)
**Prioritization Strategy:** Setup → Critical Foundation → Platform → Features → Scale

---

## Why Odin + Bun?

### Key Advantages Over C + Node.js

**Development Speed:**
- ✅ 20-30% faster development
- ✅ Built-in testing (core:testing)
- ✅ Better error handling (multiple returns, enums)
- ✅ Memory safety (defer, slices, context allocators)

**Build Simplicity:**
- ✅ 10x simpler build (no Makefile, no node-gyp, no binding.gyp)
- ✅ One command: `odin build src -build-mode:shared`
- ✅ No Python dependency
- ✅ No C++ wrapper needed (Bun FFI direct)

**Performance:**
- ✅ 90-95% of C performance (LLVM backend)
- ✅ Bun faster than Node.js runtime
- ✅ Direct FFI calls (no N-API overhead)
- ✅ SIMD support (core:simd + foreign C hybrid)

**Developer Experience:**
- ✅ Type safety (slices, enums, structs)
- ✅ Explicit allocators
- ✅ Better debugging
- ✅ Modern language features

**See:** `docs/ARCHITECTURE_OVERVIEW.md` for technical details

---

## Priority Analysis Matrix

| PRP | Task | Complexity | Impact | Risk | Dependencies | Priority | Time |
|-----|------|-----------|--------|------|--------------|----------|------|
| PRP-00 | Project Setup & Validation | Low | Critical | Low | None | **P0** | 1 week |
| PRP-01 | RFC 4180 Edge Cases | **Low** ⬇️ | Critical | Low | PRP-00 | **P0** | 2 weeks |
| PRP-02 | Enhanced Testing | **Low** ⬇️ | Critical | Low | PRP-00 | **P0** | 2 weeks |
| PRP-03 | Documentation Foundation | Low | High | Low | None | **P0** | 1 week |
| PRP-04 | Windows Support | **Medium** ⬇️ | High | Medium | PRP-01, 02 | **P1** | 4 weeks |
| PRP-05 | ARM64/NEON SIMD | High | Medium | Medium | PRP-02 | **P1** | 2 weeks |
| PRP-06 | Error Handling | **Low** ⬇️ | High | Low | PRP-01 | **P2** | 1 week |
| PRP-07 | Performance Monitoring | Medium | Medium | Low | PRP-02 | **P2** | 2 weeks |
| PRP-08 | Schema Validation | Medium ⬇️ | Medium | Medium | PRP-01, 06 | **P3** | 3 weeks |
| PRP-09 | Advanced Transforms | Medium | Medium | Low | PRP-01 | **P3** | 2 weeks |
| PRP-10 | Parallel Processing | **Medium** ⬇️ | High | High | All above | **P4** | 2 weeks |
| PRP-11 | Plugin Architecture | High | Medium | Medium | PRP-08, 09 | **P4** | 2 weeks |

**Legend:**
- ⬇️ = **Reduced complexity** compared to C version

**Total Timeline: 20 weeks** (vs 24 weeks for C implementation)

---

## Phase -1: Project Setup (Week 0-1) ⭐ NEW

**Goal:** Validate Odin/Bun stack and setup project infrastructure

### PRP-00: Project Setup & Validation ⭐ CRITICAL

**Duration:** 1 week
**Priority:** P0
**Complexity:** Low
**Risk:** Low

#### Goal
Setup Odin project structure, validate Bun FFI integration, and benchmark performance targets before full implementation.

**Business Value:**
- De-risk technology choices early
- Validate performance targets (90% of C)
- Establish development workflow

**User Impact:**
- Confidence in technology stack
- Fast development iterations
- Clear performance baseline

#### Context

**Problem Statement:**
Before investing 20 weeks, we need to validate:
1. Odin can achieve 90%+ of C performance
2. Bun FFI works smoothly
3. Build system is simple
4. SIMD strategy is viable

**Technology Validation:**
- Odin compiler version: Latest stable
- Bun runtime version: Latest stable
- Target platforms: Linux (primary), macOS, Windows (future)

#### Implementation Blueprint

**1. Project Structure:**
```
ocsv/
├── src/
│   ├── cisv.odin              # Main package, re-exports
│   ├── parser.odin            # Parser state machine
│   ├── config.odin            # Configuration types
│   ├── transformer.odin       # Transformations
│   ├── writer.odin            # CSV writing
│   ├── simd.odin              # SIMD implementations
│   ├── validator.odin         # Schema validation
│   └── ffi_bindings.odin      # Bun FFI exports
│
├── bindings/
│   ├── cisv.js                # Bun FFI wrapper
│   └── types.d.ts             # TypeScript definitions
│
├── tests/
│   ├── test_parser.odin
│   ├── test_config.odin
│   └── test_integration.odin
│
├── benchmarks/
│   ├── benchmark.js
│   └── test_data/
│
├── lib/
│   └── libcisv.so             # Compiled library
│
├── docs/
│   └── (existing documentation)
│
├── Taskfile.yml               # Task runner (optional)
└── README.md
```

**2. Basic Parser Types (src/config.odin):**
```odin
package cisv

Config :: struct {
    delimiter: byte,
    quote: byte,
    escape: byte,
    skip_empty_lines: bool,
    comment: byte,
    trim: bool,
    relaxed: bool,
    max_row_size: int,
    from_line: int,
    to_line: int,
    skip_lines_with_error: bool,
}

default_config :: proc() -> Config {
    return Config{
        delimiter = ',',
        quote = '"',
        escape = '"',
        skip_empty_lines = false,
        comment = '#',
        trim = false,
        relaxed = false,
        max_row_size = 1024 * 1024, // 1MB
        from_line = 0,
        to_line = -1, // All lines
        skip_lines_with_error = false,
    }
}
```

**3. Minimal Parser (src/parser.odin):**
```odin
package cisv

import "core:os"
import "core:strings"

Parse_State :: enum {
    Field_Start,
    In_Field,
    In_Quoted_Field,
    Quote_In_Quote,
    Field_End,
}

Parser :: struct {
    config: Config,
    state: Parse_State,
    field_buffer: [dynamic]u8,
    current_row: [dynamic]string,
    all_rows: [dynamic][]string,
    line_number: int,
}

parser_create :: proc() -> ^Parser {
    parser := new(Parser)
    parser.config = default_config()
    parser.state = .Field_Start
    parser.field_buffer = make([dynamic]u8, 0, 1024)
    parser.current_row = make([dynamic]string)
    parser.all_rows = make([dynamic][]string)
    parser.line_number = 1
    return parser
}

parser_destroy :: proc(parser: ^Parser) {
    delete(parser.field_buffer)
    for row in parser.all_rows {
        delete(row)
    }
    delete(parser.all_rows)
    delete(parser.current_row)
    free(parser)
}

// Minimal parse implementation for validation
parse_simple_csv :: proc(parser: ^Parser, data: string) -> bool {
    lines := strings.split(data, "\n")
    defer delete(lines)

    for line in lines {
        if len(line) == 0 do continue

        fields := strings.split(line, string{parser.config.delimiter})
        append(&parser.all_rows, fields)
    }

    return true
}
```

**4. Bun FFI Bindings (src/ffi_bindings.odin):**
```odin
package cisv

import "core:runtime"
import "core:c"

// Export functions with C ABI for Bun FFI
@(export, link_name="cisv_parser_create")
cisv_parser_create :: proc "c" () -> ^Parser {
    context = runtime.default_context()
    return parser_create()
}

@(export, link_name="cisv_parser_destroy")
cisv_parser_destroy :: proc "c" (parser: ^Parser) {
    context = runtime.default_context()
    parser_destroy(parser)
}

@(export, link_name="cisv_parse_string")
cisv_parse_string :: proc "c" (parser: ^Parser, data: cstring, len: c.int) -> c.int {
    context = runtime.default_context()

    data_str := string(data[:len])
    ok := parse_simple_csv(parser, data_str)
    return ok ? 0 : -1
}

@(export, link_name="cisv_get_row_count")
cisv_get_row_count :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()
    return c.int(len(parser.all_rows))
}
```

**5. JavaScript FFI Wrapper (bindings/cisv.js):**
```javascript
import { dlopen, FFIType, CString, ptr } from "bun:ffi";
import { resolve } from "path";

const lib = dlopen(resolve("lib/libcisv.so"), {
  cisv_parser_create: {
    returns: FFIType.ptr,
  },
  cisv_parser_destroy: {
    args: [FFIType.ptr],
    returns: FFIType.void,
  },
  cisv_parse_string: {
    args: [FFIType.ptr, FFIType.cstring, FFIType.i32],
    returns: FFIType.i32,
  },
  cisv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
});

export class CisvParser {
  constructor() {
    this.parser = lib.symbols.cisv_parser_create();
  }

  parseString(data) {
    const cstr = new CString(data);
    const result = lib.symbols.cisv_parse_string(
      this.parser,
      cstr.ptr,
      data.length
    );
    if (result !== 0) {
      throw new Error("Parse failed");
    }
    return this.getRowCount();
  }

  getRowCount() {
    return lib.symbols.cisv_get_row_count(this.parser);
  }

  destroy() {
    lib.symbols.cisv_parser_destroy(this.parser);
  }
}
```

**6. Performance Benchmark (benchmarks/benchmark.js):**
```javascript
import { CisvParser } from "../bindings/cisv.js";

const testData = `a,b,c
1,2,3
4,5,6
`.repeat(10000); // 30k rows

console.log("Benchmarking OCSV (Odin + Bun)...");

const parser = new CisvParser();

const start = performance.now();
const rowCount = parser.parseString(testData);
const end = performance.now();

const mb = (testData.length / 1024 / 1024).toFixed(2);
const time = (end - start).toFixed(2);
const throughput = (mb / (time / 1000)).toFixed(2);

console.log(`Parsed ${rowCount} rows`);
console.log(`Data size: ${mb} MB`);
console.log(`Time: ${time} ms`);
console.log(`Throughput: ${throughput} MB/s`);

// Target: >65 MB/s (90% of C's 71 MB/s baseline)
if (parseFloat(throughput) >= 65) {
  console.log("✅ Performance target met!");
} else {
  console.log("❌ Performance below target (need 65+ MB/s)");
}

parser.destroy();
```

#### Validation Loop

**Success Criteria:**
- [ ] Odin project compiles successfully
- [ ] Shared library builds (.so on Linux, .dylib on macOS)
- [ ] Bun FFI loads library and calls functions
- [ ] Simple CSV parsing works end-to-end
- [ ] Performance benchmark runs
- [ ] Throughput ≥65 MB/s (90% of C's 71 MB/s)
- [ ] Memory usage reasonable (<100MB for 1GB file)
- [ ] Build time <5 seconds

**Build & Run:**
```bash
# Build library
odin build src -out:lib/libcisv.so -build-mode:shared -o:speed

# Run benchmark
bun run benchmarks/benchmark.js

# Expected output:
# Benchmarking OCSV (Odin + Bun)...
# Parsed 30000 rows
# Data size: 0.69 MB
# Time: 9.5 ms
# Throughput: 72.6 MB/s
# ✅ Performance target met!
```

**SIMD Validation:**
```bash
# Test 1: Pure Odin SIMD
odin build src -build-mode:shared -o:speed -define:USE_CORE_SIMD=true

# Test 2: Foreign C SIMD (fallback)
odin build src -build-mode:shared -o:speed -define:USE_FOREIGN_SIMD=true

# Compare benchmarks
bun run benchmarks/benchmark.js
# Record: Which is faster? Pure Odin or foreign C?
```

**Decision Point:**
- If pure Odin ≥90% of C: Use pure Odin SIMD
- If foreign C needed: Keep hybrid approach
- Document decision in PRP-01

---

## Phase 0: Critical Foundation (Week 2-4)

**Goal:** Achieve production readiness

**Blockers Removed:**
- ❌ "not PROD ready" disclaimer
- ❌ Incomplete edge case handling
- ❌ Low test coverage

### PRP-01: RFC 4180 Edge Cases ⭐ CRITICAL

**Duration:** 2 weeks (vs 3 weeks in C)
**Priority:** P0
**Complexity:** Low ⬇️ (was Medium in C)
**Risk:** Low

#### Goal
Complete RFC 4180 compliance by handling all edge cases for quotes, delimiters, newlines, and comments.

**Why Easier in Odin:**
- Enums for states (vs int)
- Slices eliminate pointer arithmetic
- defer guarantees cleanup
- Better error handling
- Dynamic arrays (no manual realloc)

#### Context

**Problem Statement:**
Parser must handle complex edge cases:
```csv
# These must work:
"Field with ""nested"" quotes and
multiple lines"
"Mix of 'quotes' and ""escapes"""
# Comment inside "quoted,field"
```

**Files to Create/Modify:**
```
src/parser.odin (new - state machine)
src/config.odin (existing)
tests/test_edge_cases.odin (new)
```

**RFC 4180 Requirements:**
1. Fields with embedded delimiters must be quoted
2. Fields with embedded quotes must be quoted
3. Embedded quotes are escaped by doubling ("")
4. Fields with embedded newlines must be quoted
5. Comment lines start with comment char (if enabled)
6. Comment char inside quotes is NOT a comment

#### Implementation Blueprint

**1. Enhanced State Machine (src/parser.odin):**
```odin
package cisv

Parse_State :: enum {
    Field_Start,       // Beginning of field
    In_Field,          // Inside unquoted field
    In_Quoted_Field,   // Inside quoted field
    Quote_In_Quote,    // Found quote, might be "" or end
    Field_End,         // Field complete
}

parse_csv :: proc(parser: ^Parser, data: string) -> bool {
    state := Parse_State.Field_Start
    clear(&parser.field_buffer)
    clear(&parser.current_row)
    clear(&parser.all_rows)

    for ch, i in data {
        switch state {
        case .Field_Start:
            if ch == parser.config.quote {
                state = .In_Quoted_Field
            } else if ch == parser.config.delimiter {
                emit_empty_field(parser)
            } else if ch == '\n' {
                emit_row(parser)
            } else {
                append(&parser.field_buffer, byte(ch))
                state = .In_Field
            }

        case .In_Field:
            if ch == parser.config.delimiter {
                emit_field(parser)
                state = .Field_Start
            } else if ch == '\n' {
                emit_field(parser)
                emit_row(parser)
                state = .Field_Start
            } else {
                append(&parser.field_buffer, byte(ch))
            }

        case .In_Quoted_Field:
            if ch == parser.config.quote {
                state = .Quote_In_Quote
            } else {
                // Newlines, delimiters are literal inside quotes
                append(&parser.field_buffer, byte(ch))
            }

        case .Quote_In_Quote:
            if ch == parser.config.quote {
                // "" sequence = literal quote
                append(&parser.field_buffer, parser.config.quote)
                state = .In_Quoted_Field
            } else if ch == parser.config.delimiter {
                // End of quoted field
                emit_field(parser)
                state = .Field_Start
            } else if ch == '\n' {
                // End of quoted field and row
                emit_field(parser)
                emit_row(parser)
                state = .Field_Start
            } else {
                // RFC 4180 violation, handle based on relaxed mode
                if parser.config.relaxed {
                    append(&parser.field_buffer, parser.config.quote)
                    append(&parser.field_buffer, byte(ch))
                    state = .In_Quoted_Field
                } else {
                    // Error: invalid character after quote
                    return false
                }
            }
        }
    }

    // Handle end of input
    if state == .In_Field || state == .Quote_In_Quote {
        emit_field(parser)
    }
    if len(parser.current_row) > 0 {
        emit_row(parser)
    }

    return true
}

emit_field :: proc(parser: ^Parser) {
    field := string(parser.field_buffer[:])
    field_copy := strings.clone(field)
    append(&parser.current_row, field_copy)
    clear(&parser.field_buffer)
}

emit_empty_field :: proc(parser: ^Parser) {
    append(&parser.current_row, "")
}

emit_row :: proc(parser: ^Parser) {
    if len(parser.current_row) > 0 {
        row_copy := make([]string, len(parser.current_row))
        copy(row_copy, parser.current_row[:])
        append(&parser.all_rows, row_copy)
        clear(&parser.current_row)
    }
    parser.line_number += 1
}
```

**2. Comment Handling:**
```odin
is_comment_line :: proc(line: string, comment_char: byte) -> bool {
    if comment_char == 0 do return false

    // Skip leading whitespace
    trimmed := strings.trim_left_space(line)
    if len(trimmed) == 0 do return false

    return trimmed[0] == comment_char
}
```

**3. Edge Case Test Suite (tests/test_edge_cases.odin):**
```odin
package tests

import "core:testing"
import cisv "../src"

@(test)
test_nested_quotes :: proc(t: ^testing.T) {
    input := `"He said ""Hello"" to me"`
    expected := []string{"He said \"Hello\" to me"}

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), 1)
    testing.expect_value(t, parser.all_rows[0][0], expected[0])
}

@(test)
test_multiline_field :: proc(t: ^testing.T) {
    input := "\"Line 1\nLine 2\nLine 3\""
    expected := "Line 1\nLine 2\nLine 3"

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok)
    testing.expect_value(t, parser.all_rows[0][0], expected)
}

@(test)
test_empty_quoted_fields :: proc(t: ^testing.T) {
    input := `"",a,""`

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
    testing.expect_value(t, parser.all_rows[0][0], "")
    testing.expect_value(t, parser.all_rows[0][1], "a")
    testing.expect_value(t, parser.all_rows[0][2], "")
}

@(test)
test_comment_in_quotes :: proc(t: ^testing.T) {
    input := `"# Not a comment",a`

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok)
    testing.expect_value(t, parser.all_rows[0][0], "# Not a comment")
}

@(test)
test_delimiter_in_quotes :: proc(t: ^testing.T) {
    input := `"a,b,c",d`

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 2)
    testing.expect_value(t, parser.all_rows[0][0], "a,b,c")
    testing.expect_value(t, parser.all_rows[0][1], "d")
}

// ... 45 more edge case tests
```

#### Validation Loop

**Success Criteria:**
- [ ] All 50+ edge case tests pass
- [ ] RFC 4180 compliance verified
- [ ] Passes csv-spectrum test suite
- [ ] Performance degradation <5% vs simple parsing
- [ ] Memory leaks: zero (tracked allocator)

**Test Commands:**
```bash
# Run edge case tests
odin test tests -all-packages

# Run with tracking allocator to detect leaks
odin test tests -all-packages -define:USE_TRACKING_ALLOCATOR=true

# Run csv-spectrum tests
bun run tests/csv_spectrum_runner.js
```

---

### PRP-02: Enhanced Testing Suite ⭐ CRITICAL

**Duration:** 2 weeks (parallel with PRP-01)
**Priority:** P0
**Complexity:** Low ⬇️ (was Medium in C)
**Risk:** Low

#### Goal
Achieve >95% test coverage with unit tests, integration tests, and property-based testing.

**Why Easier in Odin:**
- Built-in test framework (core:testing)
- No external test framework needed
- Simpler setup than C
- Better debugging

#### Context

**Current State:**
- No tests yet (fresh implementation)

**Target State:**
- >95% line coverage
- 50+ unit tests
- Property-based tests
- Integration tests
- Performance regression tests

#### Implementation (Overview)

**Directory Structure:**
```
tests/
├── test_parser.odin           # Parser unit tests
├── test_config.odin           # Config tests
├── test_transformer.odin      # Transformer tests
├── test_writer.odin           # Writer tests
├── test_simd.odin             # SIMD tests
├── test_edge_cases.odin       # Edge cases (PRP-01)
├── test_integration.odin      # End-to-end tests
└── test_data/
    ├── simple.csv
    ├── complex.csv
    └── large.csv
```

**Example Test (tests/test_parser.odin):**
```odin
package tests

import "core:testing"
import "core:fmt"
import cisv "../src"

@(test)
test_parser_create_destroy :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    testing.expect(t, parser != nil)
    cisv.parser_destroy(parser)
}

@(test)
test_parse_simple :: proc(t: ^testing.T) {
    input := "a,b,c\n1,2,3\n"

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 2, "Should have 2 rows")
    testing.expect_value(t, len(parser.all_rows[0]), 3, "First row should have 3 fields")
}

@(test)
test_parse_empty :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, "")
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 0)
}

@(test)
test_parse_single_field :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, "hello")
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, parser.all_rows[0][0], "hello")
}

// ... 20+ more parser tests
```

**Integration Test (tests/test_integration.odin):**
```odin
package tests

import "core:testing"
import "core:os"
import cisv "../src"

@(test)
test_parse_file_integration :: proc(t: ^testing.T) {
    // Test full file parsing workflow
    test_file := "tests/test_data/simple.csv"

    data, ok := os.read_entire_file(test_file)
    testing.expect(t, ok, "Should read test file")
    defer delete(data)

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok = cisv.parse_csv(parser, string(data))
    testing.expect(t, ok, "Should parse successfully")
    testing.expect(t, len(parser.all_rows) > 0, "Should have rows")
}
```

#### Validation Loop

**Success Criteria:**
- [ ] >95% test coverage (core modules)
- [ ] 50+ tests passing
- [ ] All tests run in <10 seconds
- [ ] Zero memory leaks (tracking allocator)
- [ ] Integration tests pass

**Run Tests:**
```bash
# Run all tests
odin test tests -all-packages

# Run with coverage (manual check for now)
odin test tests -all-packages -debug

# Run specific test
odin test tests -collection:tests=test_parser
```

---

### PRP-03: Documentation Foundation

**Duration:** 1 week (parallel)
**Priority:** P0
**Complexity:** Low
**Risk:** Low

#### Goal
Create comprehensive documentation for users and contributors.

**Deliverables:**
1. ✅ Architecture documentation (ARCHITECTURE_OVERVIEW.md - exists)
2. ✅ Project analysis (PROJECT_ANALYSIS_SUMMARY.md - exists)
3. ✅ Action plan (ACTION_PLAN.md - this document)
4. ✅ Migration guide (ODIN_MIGRATION_GUIDE.md - exists)
5. API reference (from Odin doc comments)
6. Cookbook with 10+ examples
7. Contributing guide
8. README update for Odin/Bun

**Example API Documentation (src/parser.odin):**
```odin
package cisv

// Parser represents a CSV parser instance.
// Each parser maintains its own state and configuration.
//
// Example:
//     parser := parser_create()
//     defer parser_destroy(parser)
//     ok := parse_csv(parser, "a,b,c\n1,2,3\n")
//
Parser :: struct {
    config: Config,           // Configuration options
    state: Parse_State,       // Current parsing state
    field_buffer: [dynamic]u8, // Buffer for current field
    current_row: [dynamic]string, // Current row being built
    all_rows: [dynamic][]string,  // All parsed rows
    line_number: int,         // Current line number
}

// parser_create creates a new parser with default configuration.
// The caller must call parser_destroy when done.
parser_create :: proc() -> ^Parser { /* ... */ }

// parser_destroy frees all memory associated with the parser.
parser_destroy :: proc(parser: ^Parser) { /* ... */ }
```

**Quick Start Guide (docs/QUICK_START.md):**
```markdown
# OCSV Quick Start

## Installation

### Build from Source

```bash
# Clone repository
git clone https://github.com/username/ocsv
cd ocsv

# Build library
odin build src -out:lib/libcisv.so -build-mode:shared -o:speed

# Run tests
odin test tests -all-packages
```

## Usage

### JavaScript/TypeScript (Bun)

```javascript
import { CisvParser } from "ocsv/bindings/cisv.js";

const parser = new CisvParser();
const rows = parser.parseString("a,b,c\n1,2,3\n");
console.log(rows); // [[<"a", "b", "c"], ["1", "2", "3"]]
parser.destroy();
```

### Odin (Native)

```odin
package main

import "ocsv/src"

main :: proc() {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, "a,b,c\n1,2,3\n")
    if !ok {
        fmt.eprintln("Parse failed")
        return
    }

    for row in parser.all_rows {
        fmt.printfln("%v", row)
    }
}
```
```

---

## Phase 1: Platform Expansion (Week 5-10)

**Goal:** Cross-platform support

### PRP-04: Windows Support

**Duration:** 4 weeks (vs 5 weeks in C)
**Priority:** P1
**Complexity:** Medium ⬇️ (was High in C)
**Risk:** Medium

#### Goal
Full Windows support with native file handling and compatibility.

**Why Easier in Odin:**
- `core:os` abstracts platform differences
- No manual CreateFileMapping code
- Cross-platform paths handled automatically
- CRLF vs LF transparent

**Impact:** +40% potential user base

**Key Tasks:**
1. Windows file reading (core:os handles this)
2. Path handling (core:filepath)
3. Line endings (automatic)
4. Windows build testing
5. Windows CI/CD

**Example:**
```odin
// This works on ALL platforms!
data, ok := os.read_entire_file(path)
if !ok {
    return .File_Not_Found
}
defer delete(data)
```

No `#ifdef _WIN32` needed!

---

### PRP-05: ARM64/NEON SIMD Support

**Duration:** 2 weeks
**Priority:** P1
**Complexity:** High
**Risk:** Medium

#### Goal
ARM64 support with NEON SIMD optimizations for Apple Silicon and ARM servers.

**Impact:** Apple Silicon Macs, AWS Graviton, Raspberry Pi

**Strategy:**
1. Use `core:simd` for portable SIMD
2. Fall back to foreign C for critical paths if needed
3. Conditional compilation with `when ODIN_ARCH`

**Example:**
```odin
package cisv

import "core:simd"

when ODIN_ARCH == .arm64 {
    find_delimiter_neon :: proc(data: []byte, delim: byte) -> int {
        // Use core:simd or foreign C NEON
        // ...
    }
} else when ODIN_ARCH == .amd64 {
    find_delimiter_avx :: proc(data: []byte, delim: byte) -> int {
        // Use core:simd or foreign C AVX
        // ...
    }
}
```

---

## Phase 2: Robustness (Week 11-13)

**Goal:** Production-grade error handling and observability

### PRP-06: Error Handling & Recovery

**Duration:** 1 week (vs 2 weeks in C)
**Priority:** P2
**Complexity:** Low ⬇️ (was Medium in C)
**Risk:** Low

#### Goal
Comprehensive error handling with clear messages, recovery strategies, and partial parsing.

**Why Easier in Odin:**
- Multiple return values
- Enums for error types
- No magic error codes
- `or_return` for propagation

**Example:**
```odin
Parse_Error :: enum {
    None,
    File_Not_Found,
    Invalid_UTF8,
    Max_Row_Size_Exceeded,
    Unterminated_Quote,
    Invalid_Escape,
}

Error_Info :: struct {
    code: Parse_Error,
    line: int,
    column: int,
    message: string,
}

parse_file :: proc(path: string) -> (rows: [][]string, err: Error_Info) {
    data, ok := os.read_entire_file(path)
    if !ok {
        return nil, Error_Info{
            code = .File_Not_Found,
            message = fmt.aprintf("File not found: %s", path),
        }
    }
    defer delete(data)

    rows = parse_data(data) or_return
    return rows, Error_Info{code = .None}
}
```

---

### PRP-07: Performance Monitoring & Profiling

**Duration:** 2 weeks
**Priority:** P2
**Complexity:** Medium
**Risk:** Low

#### Goal
Built-in performance monitoring, profiling tools, and regression testing.

**Features:**
- Parse time tracking
- Memory usage profiling
- SIMD usage statistics
- Automated performance regression tests

**Example:**
```odin
Parse_Stats :: struct {
    duration_ns: i64,
    bytes_parsed: int,
    rows_parsed: int,
    throughput_mb_s: f64,
    memory_used: int,
    simd_used: bool,
}

parse_with_stats :: proc(parser: ^Parser, data: string) -> (ok: bool, stats: Parse_Stats) {
    start := time.now()

    ok = parse_csv(parser, data)

    end := time.now()
    duration := time.diff(start, end)

    stats.duration_ns = i64(time.duration_nanoseconds(duration))
    stats.bytes_parsed = len(data)
    stats.rows_parsed = len(parser.all_rows)
    stats.throughput_mb_s = f64(len(data)) / 1024 / 1024 / (f64(stats.duration_ns) / 1e9)

    return
}
```

---

## Phase 3: Advanced Features (Week 14-18)

**Goal:** Enterprise feature set

### PRP-08: Schema Validation & Type Inference

**Duration:** 3 weeks (vs 4 weeks in C)
**Priority:** P3
**Complexity:** Medium ⬇️ (was High in C)
**Risk:** Medium

#### Goal
Schema validation DSL, automatic type inference, and data quality reporting.

**Why Easier in Odin:**
- Tagged unions for field types
- Procedures as first-class values
- Better string handling

**Example:**
```odin
Field_Type :: union {
    Int_Type: struct { min, max: i64 },
    Float_Type: struct { min, max: f64 },
    String_Type: struct { pattern: string, max_len: int },
    Date_Type: struct { format: string },
}

Field_Schema :: struct {
    name: string,
    type: Field_Type,
    required: bool,
    nullable: bool,
}

Schema :: struct {
    fields: []Field_Schema,
}

validate_row :: proc(row: []string, schema: Schema) -> []Validation_Error {
    errors := make([dynamic]Validation_Error)

    for field, i in schema.fields {
        if i >= len(row) {
            if field.required {
                append(&errors, Validation_Error{
                    field = field.name,
                    message = "Missing required field",
                })
            }
            continue
        }

        value := row[i]

        // Validate based on type
        switch t in field.type {
        case Int_Type:
            num, ok := strconv.parse_i64(value)
            if !ok || num < t.min || num > t.max {
                append(&errors, Validation_Error{
                    field = field.name,
                    message = "Invalid integer",
                })
            }
        // ... other types
        }
    }

    return errors[:]
}
```

---

### PRP-09: Advanced Transformations

**Duration:** 2 weeks
**Priority:** P3
**Complexity:** Medium
**Risk:** Low

#### Goal
Extended built-in transformations and transform plugin API.

**New Transforms:**
- Date/time parsing (ISO 8601, custom formats)
- Numeric formatting
- String normalization
- Currency parsing
- Regex replacement

**Example:**
```odin
Transform_Func :: #type proc(field: string, allocator := context.allocator) -> string

Transform_Registry :: struct {
    transforms: map[string]Transform_Func,
}

register_transform :: proc(registry: ^Transform_Registry, name: string, fn: Transform_Func) {
    registry.transforms[name] = fn
}

apply_transform_by_name :: proc(registry: ^Transform_Registry, name: string, field: string) -> string {
    if fn, ok := registry.transforms[name]; ok {
        return fn(field)
    }
    return field
}
```

---

## Phase 4: Scale & Ecosystem (Week 19-20)

**Goal:** Handle massive datasets and build ecosystem

### PRP-10: Parallel Processing

**Duration:** 2 weeks (vs 3 weeks in C)
**Priority:** P4
**Complexity:** Medium ⬇️ (was High in C)
**Risk:** High

#### Goal
Multi-threaded parsing for 2-4x speedup on large files.

**Why Easier in Odin:**
- `core:thread` simpler than pthreads
- Better synchronization primitives
- Safer concurrency

**Strategy:**
```odin
import "core:thread"
import "core:sync"

parse_parallel :: proc(data: string, num_threads: int) -> [][]string {
    chunk_size := len(data) / num_threads

    // Find row boundaries
    chunks := find_safe_chunks(data, num_threads)

    // Parse in parallel
    results := make([]^Parser, num_threads)
    threads := make([]^thread.Thread, num_threads)

    for i in 0..<num_threads {
        results[i] = parser_create()
        threads[i] = thread.create(parse_worker)
        thread.start(threads[i], Parse_Job{
            parser = results[i],
            data = chunks[i],
        })
    }

    // Wait for completion
    for t in threads {
        thread.join(t)
    }

    // Merge results
    all_rows := merge_results(results)

    return all_rows
}
```

---

### PRP-11: Plugin Architecture

**Duration:** 2 weeks
**Priority:** P4
**Complexity:** High
**Risk:** Medium

#### Goal
Plugin system for community-contributed transforms, validators, and outputs.

**Plugin API:**
```odin
Plugin_Type :: enum {
    Transform,
    Validator,
    Output,
}

Plugin :: struct {
    name: string,
    version: string,
    type: Plugin_Type,
    init: proc() -> rawptr,
    destroy: proc(ctx: rawptr),
    // Type-specific callbacks
    data: union {
        Transform_Plugin: struct {
            transform: Transform_Func,
        },
        Validator_Plugin: struct {
            validate: Validator_Func,
        },
    },
}
```

---

## Implementation Order & Dependencies

### Dependency Graph

```
PRP-00 (Project Setup)
  └─> PRP-01 (Edge Cases)
      └─> PRP-06 (Error Handling)
          └─> PRP-08 (Schema Validation)

PRP-00
  └─> PRP-02 (Testing)
      ├─> PRP-04 (Windows)
      ├─> PRP-05 (ARM64)
      └─> PRP-07 (Performance)

PRP-00
  └─> PRP-03 (Documentation) - parallel

PRP-01 + PRP-02 + PRP-06
  └─> PRP-09 (Transforms)

All Phase 0-2
  └─> PRP-10 (Parallel)

PRP-08 + PRP-09
  └─> PRP-11 (Plugins)
```

### Timeline Gantt Chart

```
Week  0 |████| PRP-00 (Project Setup)
Week  1 |████████████████| PRP-01 (Edge Cases)
Week  2 |████████████████| PRP-01 complete
         ├────────────────────────────┤
Week  1 |████████████████| PRP-02 (Testing)
Week  2 |████████████████| PRP-02 complete
         ├────────┤
Week  1 |████████| PRP-03 (Docs)

Week  3 |████████████████████████████| PRP-04 (Windows)
Week  4 |████████████████████████████| PRP-04 continues
Week  5 |████████████████| PRP-04 complete
Week  6 |████████████████| PRP-05 (ARM64)
Week  7 |████████████████| PRP-05 complete

Week  8 |████████| PRP-06 (Error Handling)
Week  9 |████████████████| PRP-07 (Performance)
Week 10 |████████████████| PRP-07 complete

Week 11 |████████████████████████| PRP-08 (Schema)
Week 12 |████████████████████████| PRP-08 continues
Week 13 |████████████████| PRP-08 complete
Week 14 |████████████████| PRP-09 (Transforms)
Week 15 |████████████████| PRP-09 complete

Week 16 |████████████████| PRP-10 (Parallel)
Week 17 |████████████████| PRP-10 complete
Week 18 |████████████████| PRP-11 (Plugins)
Week 19 |████████████████| PRP-11 continues
Week 20 |████████| PRP-11 initial release
```

**Total: 20 weeks** (4 weeks faster than C implementation)

---

## Risk Assessment & Mitigation

### High Risks

#### 1. SIMD Performance (Medium Impact, Medium Probability)
**Risk:** Odin SIMD may not match C intrinsics

**Mitigation:**
- Benchmark early (PRP-00)
- Hybrid approach (foreign C calls)
- Target: 90% minimum
- Validate in Week 0

**Contingency:** Keep SIMD in C via foreign

#### 2. Team Learning Curve (Low Impact, Low Probability)
**Risk:** Learning Odin takes time

**Mitigation:**
- Odin syntax similar to Go/C
- Excellent documentation
- Small codebase (~2000 lines)
- Gradual onboarding

### Medium Risks

#### 3. Bun Ecosystem Maturity (Low Impact, Low Probability)
**Risk:** Bun newer than Node.js

**Mitigation:**
- Bun is production-ready
- FFI is stable
- Can add Node.js N-API later if needed

#### 4. Cross-Platform Issues (Medium Impact, Low Probability)
**Risk:** Platform-specific bugs

**Mitigation:**
- core:os handles differences
- Test early on all platforms
- CI/CD for Linux/macOS/Windows

---

## Success Metrics

### Phase -1 Metrics (Week 0-1)

**Technical:**
- ✅ Odin project builds successfully
- ✅ Bun FFI integration works
- ✅ Performance: ≥65 MB/s (90% of C)
- ✅ Memory: <100MB for 1GB file

**Business:**
- ✅ Technology validated
- ✅ Development workflow established
- ✅ Team confident in stack

### Phase 0 Metrics (Week 2-4)

**Technical:**
- ✅ RFC 4180 compliance: 100%
- ✅ Test coverage: >95%
- ✅ Performance: <5% regression
- ✅ Zero memory leaks

**Business:**
- ✅ Can start using in production
- ✅ v1.0.0-rc1 ready

### Phase 1 Metrics (Week 5-10)

**Technical:**
- ✅ Windows support: All tests pass
- ✅ ARM64: Performance within 10% of x86
- ✅ CI: 3 platforms

**Business:**
- ✅ User base: +40% (Windows)
- ✅ Downloads: 10k/month

### Phase 2 Metrics (Week 11-13)

**Technical:**
- ✅ Clear error messages
- ✅ Performance profiling built-in

**Business:**
- ✅ Production deployments: 5+
- ✅ Community PRs: 3+

### Phase 3 Metrics (Week 14-18)

**Technical:**
- ✅ Schema validation: 10+ validators
- ✅ Transforms: 10+ new

**Business:**
- ✅ Enterprise users: 2+
- ✅ Downloads: 30k/month

### Phase 4 Metrics (Week 19-20)

**Technical:**
- ✅ Parallel: 2-4x speedup
- ✅ Plugins: 3+ community plugins

**Business:**
- ✅ v2.0.0 release
- ✅ Downloads: 50k/month
- ✅ Contributors: 10+

---

## Next Actions

### Immediate (This Week)

1. **Install Dependencies**
   - [ ] Install Odin compiler (latest stable)
   - [ ] Install Bun runtime
   - [ ] Setup editor (VS Code + Odin extension)

2. **Create Project Structure**
   - [ ] Create ocsv/ directory structure
   - [ ] Initialize git repository
   - [ ] Create Taskfile.yml

3. **Begin PRP-00**
   - [ ] Create basic types (Config, Parser)
   - [ ] Implement minimal parser
   - [ ] Create Bun FFI bindings
   - [ ] Run first benchmark

### Short-term (Next 2 Weeks)

1. **Complete PRP-00**
   - [ ] Validate performance (≥65 MB/s)
   - [ ] Decide on SIMD strategy
   - [ ] Document decisions

2. **Begin PRP-01 & PRP-02**
   - [ ] Implement state machine
   - [ ] Write 50+ tests
   - [ ] Setup CI

3. **Community Setup**
   - [ ] Create GitHub repo
   - [ ] Write README
   - [ ] Add LICENSE

### Medium-term (Next Month)

1. **Complete Phase 0**
   - [ ] RFC 4180 complete
   - [ ] >95% test coverage
   - [ ] Documentation complete

2. **Release v0.1.0**
   - [ ] Tag release
   - [ ] Publish to GitHub
   - [ ] Announce to community

---

## Appendix: Build Commands

### Development

```bash
# Build library (debug)
odin build src -out:lib/libcisv.so -build-mode:shared -debug

# Build library (release)
odin build src -out:lib/libcisv.so -build-mode:shared -o:speed

# Run tests
odin test tests -all-packages

# Run tests with tracking allocator (leak detection)
odin test tests -all-packages -define:USE_TRACKING_ALLOCATOR=true

# Run benchmarks
bun run benchmarks/benchmark.js

# Run specific test file
odin test tests -collection:tests=test_parser
```

### With Task Runner (Optional)

```yaml
# Taskfile.yml
version: '3'

tasks:
  build:
    desc: Build release library
    cmds:
      - odin build src -out:lib/libcisv.so -build-mode:shared -o:speed

  build-dev:
    desc: Build debug library
    cmds:
      - odin build src -out:lib/libcisv.so -build-mode:shared -debug

  test:
    desc: Run all tests
    cmds:
      - odin test tests -all-packages

  test-leaks:
    desc: Run tests with leak detection
    cmds:
      - odin test tests -all-packages -define:USE_TRACKING_ALLOCATOR=true

  bench:
    desc: Run benchmarks
    cmds:
      - bun run benchmarks/benchmark.js

  clean:
    desc: Clean build artifacts
    cmds:
      - rm -rf lib/*.so lib/*.dylib lib/*.dll
```

Usage:
```bash
task build      # Build release
task test       # Run tests
task bench      # Run benchmarks
```

---

## Conclusion

This action plan leverages Odin's modern features and Bun's FFI simplicity to create a production-ready CSV parser in **20 weeks** — 4 weeks faster than the C implementation.

**Key Advantages:**
- ✅ Faster development (20-30%)
- ✅ Simpler build (10x reduction)
- ✅ Safer code (memory safety)
- ✅ Better DX (developer experience)
- ✅ 90-95% C performance (acceptable)

**Technology Stack Validated:**
- Odin: Modern systems language with LLVM backend
- Bun: Fast JavaScript runtime with simple FFI
- core:testing: Built-in test framework
- core:simd: SIMD support (+ foreign C fallback)

**Next Step:** Begin PRP-00 (Project Setup & Validation)

---

**Document Version:** 2.0 (Odin/Bun)
**Last Updated:** 2025-10-12
**Total PRPs:** 12 (PRP-00 through PRP-11)
**Estimated Timeline:** 20 weeks
**Technology:** Odin + Bun FFI
**Performance Target:** 90-95% of C
**Next Review:** After PRP-00 completion
