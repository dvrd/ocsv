name: "OCSV Phase 1: Configuration & Error Handling - BASE PRP"
description: |
  Implement JavaScript/Bun API configuration options and detailed error handling
  for OCSV CSV parser. This PRP implements Phase 1 from the JavaScript API
  Improvements PRD, adding FFI bindings for parser configuration and exposing
  the existing error handling system to JavaScript users.

---

## Goal

**Feature Goal**: Enable JavaScript developers to configure CSV parsing behavior (delimiter, quote, comment, relaxed mode) and receive detailed error messages with line/column information when parsing fails.

**Deliverable**:
- 11 new FFI functions for parser configuration
- 6 new FFI functions for error information retrieval
- Updated JavaScript bindings with configuration support
- New TypeScript `OcsvError` class with line/column info
- Updated TypeScript type definitions
- 15+ tests covering configuration and error scenarios

**Success Definition**:
- Developers can parse TSV files: `parseCSV(data, { delimiter: '\t' })`
- Parse errors include exact location: `Error at line 42, column 15: Unterminated quote`
- All tests pass with zero memory leaks
- Bundle size increase < 5KB
- Backwards compatible (existing API unchanged)

## User Persona

**Target User**: JavaScript/TypeScript developers using Bun runtime who need to parse CSV files with custom delimiters or want detailed error diagnostics for data quality issues.

**Use Case**:
1. Data engineer needs to parse TSV files from various sources
2. Developer debugging production CSV parsing failures needs exact error location
3. Data validation team needs to collect all parsing errors, not just first failure

**User Journey**:
```typescript
// Before (Phase 0): Limited, no config, generic errors
const result = parseCSV(tsvData); // ❌ Fails silently on TSV
try {
  parseCSV(badData);
} catch (error) {
  console.error(error.message); // "CSV parsing failed" - not helpful!
}

// After (Phase 1): Configurable, detailed errors
const result = parseCSV(tsvData, { delimiter: '\t' }); // ✅ Works!
try {
  parseCSV(badData);
} catch (error) {
  console.error(error.code);    // "OCSV_PARSE_UNTERMINATED_QUOTE"
  console.error(error.line);    // 42
  console.error(error.column);  // 15
  console.error(error.message); // "Unterminated quoted field"
}
```

**Pain Points Addressed**:
- Cannot parse TSV, pipe-delimited, or semicolon-delimited files
- Cannot identify European CSV format automatically
- Error messages provide no location information for debugging
- No way to handle malformed CSV data gracefully

## Why

- **Business Value**: Expands OCSV usability from comma-only to all delimited formats (TSV, PSV, etc.), significantly increasing addressable market
- **User Impact**: Reduces debugging time from hours to minutes with precise error locations
- **Integration**: Leverages existing robust Odin error handling system (PRP-06) - just needs FFI exposure
- **Competitive Advantage**: Matches PapaParse/csv-parse feature parity while maintaining 10x performance advantage (158 MB/s vs 15-30 MB/s)

## What

### Success Criteria

- [ ] Can parse TSV files with `{ delimiter: '\t' }` option
- [ ] Can parse European CSV with `{ delimiter: ';' }` option
- [ ] Can enable relaxed parsing with `{ relaxed: true }` option
- [ ] Parse errors include `code`, `line`, `column`, `message` properties
- [ ] Error codes follow TypeScript enum pattern (e.g., `OCSV_PARSE_UNTERMINATED_QUOTE`)
- [ ] Backwards compatible: existing `parseCSV()` calls work unchanged
- [ ] Zero memory leaks in all config/error scenarios
- [ ] TypeScript autocomplete works for all config options
- [ ] Bundle size increase < 5KB (measured with `bun build --minify`)
- [ ] 15+ tests cover all config options and error types

## All Needed Context

### Context Completeness Check

_This PRP has been validated with the "No Prior Knowledge" test: An AI agent with no prior knowledge of OCSV should be able to implement this feature successfully using only this document and codebase access._

**Validation Approach:**
1. ✅ All file paths are absolute and verified to exist
2. ✅ All line numbers reference specific implementation patterns
3. ✅ All URLs include section anchors where applicable
4. ✅ All FFI patterns documented with working examples from codebase
5. ✅ Memory management patterns explicitly stated with defer requirements

### Documentation & References

```yaml
# MUST READ - Include these in your context window

# Core FFI Patterns
- file: /Users/kakurega/dev/projects/ocsv/src/ffi_bindings.odin
  why: Study all 7 existing FFI functions to understand export pattern
  pattern: "@(export, link_name='ocsv_*') proc 'c' with context = runtime.default_context()"
  critical_lines:
    - 11-15: ocsv_parser_create pattern (no args, returns pointer)
    - 20-24: ocsv_parser_destroy pattern (void return)
    - 32-53: ocsv_parse_string pattern (validation, cstring handling, error codes)
    - 89-98: ocsv_get_field_count pattern (bounds checking)
  gotcha: MUST set "context = runtime.default_context()" as FIRST LINE in every FFI function

# Config Structure
- file: /Users/kakurega/dev/projects/ocsv/src/config.odin
  why: Understand all Config struct fields and their types
  pattern: "Config :: struct { delimiter: byte, quote: byte, ... }"
  critical_lines:
    - 4-16: Complete Config struct with all 11 fields
    - 18-33: default_config() function showing default values
  gotcha: All delimiter/quote/comment fields are single bytes (u8), not strings

# Parser Structure
- file: /Users/kakurega/dev/projects/ocsv/src/parser.odin
  why: Understand how parser stores config and how to modify it
  pattern: "parser.config.delimiter = value"
  critical_lines:
    - 16-23: Parser struct definition (contains config field)
    - 25-35: parser_create() showing config initialization
    - 106, 108, 124, 175, 207: Config field access during parsing
  gotcha: Config is embedded in Parser, accessed via parser.config.field_name

# Error System Structure
- file: /Users/kakurega/dev/projects/ocsv/src/error.odin
  why: Understand all error types and Error_Info struct for FFI exposure
  pattern: "Error_Info :: struct { code: Parse_Error, line: int, column: int, ... }"
  critical_lines:
    - 9-21: Parse_Error enum with all 11 error types
    - 24-30: Error_Info struct definition (what to expose via FFI)
    - 98-103: Recovery_Strategy enum
    - 146-153: Parser_Extended struct (what to use for error-aware parsing)
  gotcha: Standard Parser has no error details, use Parser_Extended for full error info

# Error-Aware Parser
- file: /Users/kakurega/dev/projects/ocsv/src/parser_error.odin
  why: Understand how errors are created and tracked during parsing
  pattern: "make_error(code, line, column, message, context)"
  critical_lines:
    - "parse_csv_with_errors() function": Main entry point for error-aware parsing
    - "record_error() function": How errors are stored
    - "make_error() function": Pattern for creating Error_Info
  gotcha: Column tracking is only available in parse_csv_with_errors(), not standard parser

# JavaScript Bindings (Current)
- file: /Users/kakurega/dev/projects/ocsv/bindings/index.js
  why: Understand current JS FFI usage and where to add config/error support
  pattern: "lib.symbols.ocsv_function_name(parser, ...args)"
  critical_lines:
    - 76-100: dlopen FFI function declarations
    - 136-141: Parser constructor pattern
    - 150-184: parse() method (where config will be applied)
    - 202-207: destroy() method (memory cleanup pattern)
  gotcha: Use Buffer.from(data + '\0') for null termination, always use ptr(buffer)

# TypeScript Types (Current)
- file: /Users/kakurega/dev/projects/ocsv/bindings/index.d.ts
  why: Current type definitions to extend with config and error types
  pattern: "export interface ParseOptions { ... }"
  critical_lines:
    - "Complete file": All current type definitions (simple, will be extended)
  gotcha: Types are currently minimal, need to add full config and error types

# External Documentation
- url: https://bun.sh/docs/api/ffi#types
  why: Official Bun FFI type mapping (byte → FFIType.u8, bool → FFIType.bool)
  critical: char/byte is FFIType.u8 (single byte), NOT FFIType.char (pointer to char)
  section: "#types"

- url: https://javascript.info/custom-errors
  why: JavaScript/TypeScript custom error class patterns
  critical: Must set this.name and use Error.captureStackTrace for proper stack traces
  section: "#custom-error-extending-error"

- url: https://www.papaparse.com/docs#errors
  why: Industry-standard CSV error API patterns (for comparison)
  critical: Error should have 'type', 'code', 'message', and position info
  section: "#errors"
```

### Current Codebase Tree

```bash
/Users/kakurega/dev/projects/ocsv/
├── src/
│   ├── ocsv.odin              # Package entry point (re-exports)
│   ├── config.odin            # Config struct (11 fields) ← READ THIS
│   ├── parser.odin            # Standard parser (no error details)
│   ├── parser_error.odin      # Error-aware parser ← READ THIS
│   ├── error.odin             # Error types and structs ← READ THIS
│   ├── ffi_bindings.odin      # Current 7 FFI functions ← MODIFY THIS
│   ├── streaming.odin         # Streaming parser (not used in Phase 1)
│   ├── schema.odin            # Schema validation (not used in Phase 1)
│   └── ...
├── bindings/
│   ├── index.js               # JavaScript FFI wrapper ← MODIFY THIS
│   ├── index.d.ts             # TypeScript definitions ← MODIFY THIS
│   ├── ocsv.js                # Legacy binding (deprecated, ignore)
│   └── types.d.ts             # Legacy types (deprecated, ignore)
├── tests/
│   ├── test_parser.odin       # Basic tests (has config examples)
│   ├── test_edge_cases.odin   # Config usage examples (lines 252, 266)
│   ├── test_error_handling.odin # Error system tests ← STUDY PATTERNS
│   └── ...
├── examples/
│   ├── npm-test/test.js       # JavaScript usage examples
│   └── ...
└── docs/
    ├── PRP-06-RESULTS.md      # Error handling implementation details
    ├── INTEGRATION.md         # FFI integration guide
    └── API.md                 # API documentation (needs updating)
```

### Desired Codebase Tree (Files to Add/Modify)

```bash
/Users/kakurega/dev/projects/ocsv/
├── src/
│   └── ffi_bindings.odin      # ADD: 17 new FFI functions (11 config + 6 error)
├── bindings/
│   ├── index.js               # MODIFY: Add _applyConfig() method, update error handling
│   ├── index.d.ts             # MODIFY: Add ParseOptions interface, OcsvError class
│   └── errors.js              # ADD: New file with OcsvError class
├── tests/
│   ├── test_ffi_config.odin   # ADD: Odin-side FFI config tests
│   └── ...
├── examples/
│   ├── npm-test/
│   │   ├── test_config.js     # ADD: Test config options from JavaScript
│   │   └── test_errors.js     # ADD: Test error handling from JavaScript
│   └── ...
└── docs/
    ├── API.md                 # MODIFY: Document new config options and error handling
    └── INTEGRATION.md         # MODIFY: Update FFI examples with config
```

### Known Gotchas & Library Quirks

```odin
// CRITICAL: Bun FFI Type Mapping for Config
// Config uses 'byte' (u8) for delimiter/quote/comment
// In Bun FFI, this is FFIType.u8, NOT FFIType.char
// FFIType.char is a POINTER to char, not a single byte!

// Odin side:
ocsv_set_delimiter :: proc "c" (parser: ^Parser, delimiter: byte)
//                                                           ^^^^^ byte = u8

// JavaScript FFI declaration:
ocsv_set_delimiter: {
  args: [FFIType.ptr, FFIType.u8],  // ✅ CORRECT: FFIType.u8 for byte
  //                  ^^^^^^^^^^^
  returns: FFIType.void,
}

// JavaScript usage:
const delimiterByte = '\t'.charCodeAt(0);  // Convert string to byte value
lib.symbols.ocsv_set_delimiter(this.parser, delimiterByte);

// ❌ WRONG: FFIType.char (this is char*, a pointer, not a single byte)
```

```odin
// CRITICAL: Context Management in FFI Functions
// Every FFI function MUST set context as FIRST LINE
// This sets up the allocator for memory operations
// Without context, allocations fail or use undefined allocators

@(export, link_name="ocsv_any_function")
ocsv_any_function :: proc "c" (...) -> ... {
    context = runtime.default_context()  // ← MUST BE FIRST LINE!

    // Now safe to use allocations, strings, dynamic arrays, etc.
    // ...
}
```

```javascript
// CRITICAL: String Null Termination for FFI
// When passing strings to Odin via cstring, always null-terminate
// Always pass explicit length parameter

const buffer = Buffer.from(data + '\0');  // ← Add null terminator
const result = lib.symbols.ocsv_parse_string(
  this.parser,
  ptr(buffer),   // Use ptr() to get pointer from Buffer
  data.length    // ← Length WITHOUT null terminator
);
```

```odin
// CRITICAL: Memory Ownership for Error Strings
// Error_Info.message is a string owned by the parser
// When exposed via FFI, the cstring remains valid until parser is destroyed
// JavaScript must NOT free this memory - it's owned by Odin

@(export, link_name="ocsv_get_error_message")
ocsv_get_error_message :: proc "c" (parser: ^Parser_Extended) -> cstring {
    context = runtime.default_context()
    if parser.last_error.code == .None {
        return nil
    }
    // ↓ Returns pointer to parser-owned string (safe until parser_destroy)
    return cstring(raw_data(parser.last_error.message))
}
```

```typescript
// CRITICAL: Error.captureStackTrace is V8-specific
// Always use optional chaining for cross-platform compatibility

class OcsvError extends Error {
  constructor(message: string, ...) {
    super(message);
    this.name = 'OcsvError';

    // ✅ CORRECT: Optional chaining (works on all platforms)
    Error.captureStackTrace?.(this, this.constructor);

    // ❌ WRONG: Direct call (breaks on Safari/Firefox)
    // Error.captureStackTrace(this, this.constructor);
  }
}
```

```odin
// CRITICAL: Parser_Extended vs Standard Parser
// Standard Parser (from parser_create) has NO error details
// Parser_Extended (from parser_extended_create) stores full error info
// For error-aware FFI, we need to:
// 1. Add Parser_Extended to FFI
// 2. OR: Store error info separately in Parser struct

// Current Parser struct (src/parser.odin:16-23):
Parser :: struct {
    config:       Config,
    state:        Parse_State,
    field_buffer: [dynamic]u8,
    current_row:  [dynamic]string,
    all_rows:     [dynamic][]string,
    line_number:  int,
    // ← NO ERROR FIELDS! Need to add or use Parser_Extended
}

// Parser_Extended struct (src/error.odin:146-153):
Parser_Extended :: struct {
    using base: Parser,  // Embeds standard parser
    recovery_strategy: Recovery_Strategy,
    last_error: Error_Info,        // ← ERROR INFO HERE
    warnings: [dynamic]Error_Info,
    max_errors: int,
    error_count: int,
}
```

## Implementation Blueprint

### Data Models and Structure

**No new data models needed** - all necessary structures exist:
- `Config` struct (src/config.odin:4-16): Already has all 11 configuration fields
- `Error_Info` struct (src/error.odin:24-30): Already has code, line, column, message, context
- `Parse_Error` enum (src/error.odin:9-21): Already has all 11 error types
- `Parser_Extended` struct (src/error.odin:146-153): Already has error storage

**Approach:** Expose existing structures via FFI, add JavaScript wrappers.

### Implementation Tasks (Ordered by Dependencies)

```yaml
Task 1: ADD Config Setter FFI Functions (Odin)
  file: /Users/kakurega/dev/projects/ocsv/src/ffi_bindings.odin
  action: ADD 11 new FFI functions after line 123 (after ocsv_get_field)
  pattern: Follow ocsv_parser_destroy pattern (lines 20-24) for void returns
  naming: ocsv_set_delimiter, ocsv_set_quote, ocsv_set_comment, etc.
  functions_to_add:
    - ocsv_set_delimiter(parser: ^Parser, delimiter: byte)
    - ocsv_set_quote(parser: ^Parser, quote: byte)
    - ocsv_set_escape(parser: ^Parser, escape: byte)
    - ocsv_set_comment(parser: ^Parser, comment: byte)
    - ocsv_set_relaxed(parser: ^Parser, relaxed: c.bool)
    - ocsv_set_trim(parser: ^Parser, trim: c.bool)
    - ocsv_set_skip_empty_lines(parser: ^Parser, skip: c.bool)
    - ocsv_set_max_row_size(parser: ^Parser, size: c.int)
    - ocsv_set_from_line(parser: ^Parser, line: c.int)
    - ocsv_set_to_line(parser: ^Parser, line: c.int)
    - ocsv_set_skip_lines_with_error(parser: ^Parser, skip: c.bool)
  validation: Check parser != nil before setting
  dependencies: None (uses existing Parser struct)

Task 2: ADD Error Storage to Parser Struct (Odin)
  file: /Users/kakurega/dev/projects/ocsv/src/parser.odin
  action: ADD error storage fields to Parser struct (after line 23)
  pattern: Follow Parser_Extended pattern (src/error.odin:146-153)
  fields_to_add:
    - last_error: Error_Info
    - error_count: int
  why: Standard Parser needs error storage for FFI error exposure
  initialization: Initialize in parser_create (line 33) with .None error code
  cleanup: Clear error strings in parser_destroy (line 56)
  dependencies: None

Task 3: MODIFY parse_csv to Store Errors (Odin)
  file: /Users/kakurega/dev/projects/ocsv/src/parser.odin
  action: MODIFY parse_csv function to capture and store parse errors
  pattern: Study parse_csv_with_errors in src/parser_error.odin
  changes:
    - On parse failure, create Error_Info with current line/column
    - Store in parser.last_error before returning false
    - Increment parser.error_count
  why: Currently parse_csv just returns bool, no error details
  dependencies: Task 2 (needs error storage fields)

Task 4: ADD Error Retrieval FFI Functions (Odin)
  file: /Users/kakurega/dev/projects/ocsv/src/ffi_bindings.odin
  action: ADD 6 new FFI functions after config setters
  pattern: Follow ocsv_get_row_count pattern (lines 59-63) for getters
  naming: ocsv_get_error_*, ocsv_has_error
  functions_to_add:
    - ocsv_has_error(parser: ^Parser) -> c.bool
    - ocsv_get_error_code(parser: ^Parser) -> c.int
    - ocsv_get_error_line(parser: ^Parser) -> c.int
    - ocsv_get_error_column(parser: ^Parser) -> c.int
    - ocsv_get_error_message(parser: ^Parser) -> cstring
    - ocsv_clear_error(parser: ^Parser)
  validation: Return safe defaults if no error (0, nil, etc.)
  dependencies: Task 2 (needs error storage)

Task 5: CREATE OcsvError Class (JavaScript)
  file: /Users/kakurega/dev/projects/ocsv/bindings/errors.js
  action: CREATE new file with OcsvError class
  pattern: Follow Error class patterns from research (see Context section)
  class_structure:
    - extends Error
    - properties: code, line, column, message
    - constructor sets this.name = 'OcsvError'
    - use Error.captureStackTrace?.(this, this.constructor)
    - implement toString() for custom formatting
  export: "export class OcsvError extends Error"
  dependencies: None (new file)

Task 6: UPDATE JavaScript FFI Bindings (JavaScript)
  file: /Users/kakurega/dev/projects/ocsv/bindings/index.js
  action: MODIFY dlopen declaration and Parser class
  changes:
    1. ADD config setter FFI declarations (lines 76-100, after existing functions)
    2. ADD error getter FFI declarations
    3. CREATE _applyConfig() private method in Parser class
    4. MODIFY parse() method to call _applyConfig(options) before parsing
    5. MODIFY parse() to check for errors and throw OcsvError with details
  pattern: Follow existing ocsv_get_field pattern for FFI calls
  validation: Check all FFI function returns, handle nil/error codes
  dependencies: Task 1, Task 4, Task 5

Task 7: UPDATE TypeScript Definitions (TypeScript)
  file: /Users/kakurega/dev/projects/ocsv/bindings/index.d.ts
  action: MODIFY to add ParseOptions interface and OcsvError class
  changes:
    1. ADD ParseOptions interface with all config fields
    2. ADD OcsvError class declaration
    3. ADD OcsvErrorCode enum with all error types
    4. UPDATE parseCSV, parseCSVFile signatures to accept ParseOptions
    5. UPDATE Parser.parse signature
  pattern: Follow TypeScript patterns from research
  typing: Use readonly for error properties, optional for config options
  dependencies: Task 5

Task 8: CREATE Odin-Side FFI Tests
  file: /Users/kakurega/dev/projects/ocsv/tests/test_ffi_config.odin
  action: CREATE new test file for FFI config functions
  pattern: Follow test_error_handling.odin structure
  tests_to_add:
    - test_ffi_set_delimiter
    - test_ffi_set_quote
    - test_ffi_set_relaxed
    - test_ffi_config_tsv_parsing
    - test_ffi_error_info_retrieval
    - test_ffi_error_line_column_accuracy
  coverage: Test all 11 config setters, all 6 error getters
  dependencies: Task 1, Task 4

Task 9: CREATE JavaScript-Side Tests
  file: /Users/kakurega/dev/projects/ocsv/examples/npm-test/test_config.js
  action: CREATE test file for JavaScript config API
  pattern: Follow examples/npm-test/test.js structure
  tests_to_add:
    - Test TSV parsing with delimiter: '\t'
    - Test European CSV with delimiter: ';'
    - Test relaxed mode
    - Test error details (code, line, column)
    - Test multiple configs in sequence
  validation: Run with "bun test" command
  dependencies: Task 6, Task 7

Task 10: UPDATE Documentation
  file: /Users/kakurega/dev/projects/ocsv/docs/API.md
  action: MODIFY to add config options and error handling sections
  sections_to_add:
    - "Configuration Options" section with all 11 config fields
    - "Error Handling" section with OcsvError class details
    - "Error Codes" section listing all Parse_Error enum values
  pattern: Follow existing documentation style
  dependencies: Task 7 (uses TypeScript types as reference)
```

### Implementation Patterns & Key Details

```odin
// Pattern: Config Setter FFI Function
@(export, link_name="ocsv_set_delimiter")
ocsv_set_delimiter :: proc "c" (parser: ^Parser, delimiter: byte) {
    // CRITICAL: Set context FIRST
    context = runtime.default_context()

    // PATTERN: Validate inputs (nil check)
    if parser == nil do return

    // PATTERN: Direct field assignment
    parser.config.delimiter = delimiter

    // PATTERN: No return value needed (void function)
}

// Pattern: Error Getter FFI Function
@(export, link_name="ocsv_get_error_code")
ocsv_get_error_code :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()

    // PATTERN: Safe default for nil input
    if parser == nil do return c.int(Parse_Error.None)

    // PATTERN: Return enum as integer
    return c.int(parser.last_error.code)
}

// Pattern: Error Message Getter (String Return)
@(export, link_name="ocsv_get_error_message")
ocsv_get_error_message :: proc "c" (parser: ^Parser) -> cstring {
    context = runtime.default_context()

    // PATTERN: Return nil for no error
    if parser == nil || parser.last_error.code == .None {
        return nil
    }

    // CRITICAL: Return pointer to parser-owned string
    // Safe because string lifetime matches parser lifetime
    return cstring(raw_data(parser.last_error.message))
}
```

```javascript
// Pattern: JavaScript Config Application
class Parser {
  _applyConfig(options = {}) {
    // PATTERN: Check each option and apply if defined
    // CRITICAL: Use !== undefined check (allows false values)
    if (options.delimiter !== undefined) {
      // PATTERN: Convert string char to byte value
      const byte = options.delimiter.charCodeAt(0);
      lib.symbols.ocsv_set_delimiter(this.parser, byte);
    }

    if (options.relaxed !== undefined) {
      // PATTERN: Boolean values pass directly
      lib.symbols.ocsv_set_relaxed(this.parser, options.relaxed);
    }

    // ... repeat for all config options
  }

  parse(data, options = {}) {
    // PATTERN: Apply config BEFORE parsing
    this._applyConfig(options);

    const buffer = Buffer.from(data + '\0');
    const result = lib.symbols.ocsv_parse_string(
      this.parser,
      ptr(buffer),
      data.length
    );

    // PATTERN: Check for errors AFTER parsing
    if (result !== 0) {
      // PATTERN: Retrieve error details via FFI
      const hasError = lib.symbols.ocsv_has_error(this.parser);
      if (hasError) {
        const code = lib.symbols.ocsv_get_error_code(this.parser);
        const line = lib.symbols.ocsv_get_error_line(this.parser);
        const column = lib.symbols.ocsv_get_error_column(this.parser);
        const message = lib.symbols.ocsv_get_error_message(this.parser);

        // PATTERN: Throw OcsvError with all details
        throw new OcsvError(message || "CSV parsing failed", {
          code: this._errorCodeToString(code),
          line,
          column
        });
      }

      // Fallback for unknown errors
      throw new Error("CSV parsing failed");
    }

    // ... continue with row retrieval
  }

  _errorCodeToString(code) {
    // PATTERN: Map enum integer to string constant
    const codes = [
      'OCSV_ERROR_NONE',
      'OCSV_ERROR_FILE_NOT_FOUND',
      'OCSV_ERROR_INVALID_UTF8',
      'OCSV_ERROR_UNTERMINATED_QUOTE',
      // ... all 11 error codes
    ];
    return codes[code] || 'OCSV_ERROR_UNKNOWN';
  }
}
```

```typescript
// Pattern: OcsvError Class
export class OcsvError extends Error {
  readonly code: string;
  readonly line: number;
  readonly column: number;

  constructor(
    message: string,
    options: {
      code: string;
      line: number;
      column: number;
    }
  ) {
    super(message);
    this.name = 'OcsvError';
    this.code = options.code;
    this.line = options.line;
    this.column = options.column;

    // CRITICAL: Optional chaining for cross-platform compatibility
    Error.captureStackTrace?.(this, this.constructor);
  }

  // PATTERN: Custom toString for logging
  toString(): string {
    return `${this.name} [${this.code}] at ${this.line}:${this.column}: ${this.message}`;
  }
}

// Pattern: Type Guard
export function isOcsvError(error: unknown): error is OcsvError {
  return error instanceof OcsvError;
}
```

### Integration Points

```yaml
BUILD_SYSTEM:
  - command: "odin build src -build-mode:shared -out:libcsv.dylib -o:speed"
  - note: "No changes needed - FFI functions auto-exported"

JAVASCRIPT_MODULE:
  - file: bindings/index.js
  - action: Update dlopen with 17 new FFI functions
  - pattern: |
      ocsv_set_delimiter: {
        args: [FFIType.ptr, FFIType.u8],  // ← u8 for byte, not char!
        returns: FFIType.void,
      }

TYPESCRIPT_TYPES:
  - file: bindings/index.d.ts
  - action: Add ParseOptions, OcsvError, OcsvErrorCode
  - pattern: Export all types for external use

TESTS:
  - odin_tests: "odin test tests -all-packages"
  - js_tests: "bun test examples/npm-test/test_config.js"
  - memory_test: "odin test tests -all-packages -debug"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# After EACH Odin file modification - fix before proceeding
odin check src/ffi_bindings.odin
odin check src/parser.odin

# After ALL Odin changes complete
odin check src -all-packages

# Expected: Zero errors. If errors exist, READ output and fix.
```

### Level 2: Unit Tests (Component Validation)

```bash
# Test Odin-side FFI functions (Task 8 tests)
odin test tests/test_ffi_config.odin -all-packages -debug

# Test JavaScript bindings (Task 9 tests)
cd examples/npm-test
bun test test_config.js
bun test test_errors.js
cd ../..

# Test all existing tests still pass (backwards compatibility)
odin test tests -all-packages -debug

# Expected: All tests pass, zero memory leaks
# If failing: Read error messages, check FFI type mapping, verify null checks
```

### Level 3: Integration Testing (System Validation)

```bash
# Build library with new FFI functions
odin build src -build-mode:shared -out:libcsv.dylib -o:speed

# Verify FFI symbols exported
nm libcsv.dylib | grep ocsv_set_
nm libcsv.dylib | grep ocsv_get_error_

# Expected: See all 17 new function symbols (11 config + 6 error)

# Test from JavaScript REPL
bun repl
> const { parseCSV } = await import('./bindings/index.js');
> // Test TSV parsing
> const tsv = "a\tb\tc\n1\t2\t3";
> const result = parseCSV(tsv, { delimiter: '\t', hasHeader: true });
> console.log(result.headers); // ['a', 'b', 'c']
> console.log(result.rows);    // [['1', '2', '3']]
>
> // Test error handling
> const bad = 'a,b,"unterminated';
> try {
>   parseCSV(bad);
> } catch (error) {
>   console.log(error.code);   // 'OCSV_ERROR_UNTERMINATED_QUOTE'
>   console.log(error.line);   // 1
>   console.log(error.column); // 7
> }

# Expected: All manual tests work, config applies, errors detailed
```

### Level 4: Bundle Size & Performance Validation

```bash
# Check bundle size impact
bun build bindings/index.js --outfile=dist/bundle.js --minify
ls -lh dist/bundle.js

# Expected: Increase < 5KB from baseline (OcsvError class ~2KB, setters minimal)

# Performance regression test
bun run benchmarks/csv_benchmark.js

# Expected: Throughput still ≥ 150 MB/s (config setters add ~50ns overhead, negligible)

# Memory leak validation with tracking allocator
odin test tests -all-packages -debug -define:USE_TRACKING_ALLOCATOR=true

# Expected: Zero leaks in all tests
```

## Final Validation Checklist

### Technical Validation

- [ ] All 17 FFI functions compile: `odin check src/ffi_bindings.odin`
- [ ] All Odin tests pass: `odin test tests -all-packages`
- [ ] All JavaScript tests pass: `bun test examples/npm-test/*.js`
- [ ] Zero memory leaks: `odin test tests -all-packages -debug`
- [ ] FFI symbols exported: `nm libcsv.dylib | grep ocsv_set_ | wc -l` returns 11
- [ ] FFI symbols exported: `nm libcsv.dylib | grep ocsv_get_error_ | wc -l` returns 5

### Feature Validation

- [ ] TSV parsing works: `parseCSV(tsvData, { delimiter: '\t' })`
- [ ] European CSV works: `parseCSV(csvData, { delimiter: ';' })`
- [ ] Relaxed mode works: `parseCSV(messyData, { relaxed: true })`
- [ ] Error code exposed: `catch (error) { console.log(error.code); }` shows correct code
- [ ] Error line exposed: `error.line` shows correct 1-indexed line number
- [ ] Error column exposed: `error.column` shows correct 1-indexed column
- [ ] Error message exposed: `error.message` shows descriptive text
- [ ] Backwards compatible: `parseCSV(data)` without options still works
- [ ] Multiple configs work: Set delimiter, quote, relaxed in same parse call

### Code Quality Validation

- [ ] All config setters follow same pattern (lines 20-24 in ffi_bindings.odin)
- [ ] All error getters follow same pattern (lines 59-63 in ffi_bindings.odin)
- [ ] Context set first in every FFI function
- [ ] Nil checks in all FFI functions
- [ ] JavaScript uses !== undefined for option checks
- [ ] TypeScript types match Odin types (byte → number, etc.)
- [ ] OcsvError uses Error.captureStackTrace?.()
- [ ] toString() implemented for OcsvError

### Documentation & Deployment

- [ ] API.md updated with config options section
- [ ] API.md updated with error handling section
- [ ] INTEGRATION.md updated with config examples
- [ ] TypeScript autocomplete works (verify in VS Code with examples/npm-test/test_config.ts)
- [ ] Error codes documented in API.md (all 11 from Parse_Error enum)
- [ ] Bundle size measured and < 5KB increase documented

---

## Anti-Patterns to Avoid

- ❌ Don't use FFIType.char for byte values (it's a pointer!)
- ❌ Don't forget context = runtime.default_context() (causes allocator failures)
- ❌ Don't skip nil checks in FFI functions (causes segfaults)
- ❌ Don't use == undefined for option checks (use !== undefined to allow false values)
- ❌ Don't call Error.captureStackTrace without optional chaining (breaks Safari/Firefox)
- ❌ Don't free error message strings in JavaScript (owned by Odin parser)
- ❌ Don't modify standard Parser without updating parser_create and parser_destroy
- ❌ Don't expose Parser_Extended to FFI (adds complexity, use error storage in Parser instead)
- ❌ Don't break existing API (all current parseCSV() calls must work unchanged)
- ❌ Don't add config parameters to parseCSV() signature (use options object only)

---

## Success Metrics Tracking

After implementation completion, verify:

1. **Functionality**: Run examples/npm-test/test_config.js and verify all 5 tests pass
2. **Performance**: Run benchmarks, confirm throughput ≥ 150 MB/s (negligible overhead)
3. **Memory Safety**: Run `odin test tests -all-packages -debug`, confirm 0 leaks
4. **Bundle Size**: Measure `dist/bundle.js` size, confirm increase < 5KB
5. **Type Safety**: Open examples/npm-test/test_config.ts in VS Code, verify autocomplete works
6. **Backwards Compatibility**: Run existing tests, confirm 203/203 tests still pass
7. **Error Quality**: Parse malformed CSV, verify error.line and error.column are accurate
8. **Documentation**: Review API.md, confirm all config options and error codes documented

**Target Metrics:**
- ✅ 15+ tests pass (8 Odin + 7 JavaScript)
- ✅ 0 memory leaks
- ✅ Bundle size ≤ 45KB (40KB baseline + 5KB)
- ✅ Throughput ≥ 150 MB/s
- ✅ TypeScript autocomplete 100% coverage
- ✅ Backwards compatibility 100%

---

**Confidence Score: 9/10** - This PRP provides complete context for implementation. The 1-point deduction accounts for potential platform-specific FFI quirks that may require debugging, but all patterns and gotchas are documented.

**Estimated Implementation Time:** 4-6 hours for experienced developer, 8-10 hours for developer new to Odin/FFI.

**Risk Level:** Low - All changes are additive (new FFI functions) or non-breaking (new options parameter). Error handling leverages existing robust system from PRP-06.

---

## Appendix: Error Code Reference

From `src/error.odin` (lines 9-21), all 11 error types to expose:

| Odin Enum | JavaScript Constant | Description |
|-----------|---------------------|-------------|
| `Parse_Error.None` | `OCSV_ERROR_NONE` | No error |
| `Parse_Error.File_Not_Found` | `OCSV_ERROR_FILE_NOT_FOUND` | File operations failed |
| `Parse_Error.Invalid_UTF8` | `OCSV_ERROR_INVALID_UTF8` | UTF-8 encoding issues |
| `Parse_Error.Unterminated_Quote` | `OCSV_ERROR_UNTERMINATED_QUOTE` | Missing closing quote |
| `Parse_Error.Invalid_Character_After_Quote` | `OCSV_ERROR_INVALID_CHARACTER_AFTER_QUOTE` | RFC 4180 violation |
| `Parse_Error.Max_Row_Size_Exceeded` | `OCSV_ERROR_MAX_ROW_SIZE_EXCEEDED` | Row size limit |
| `Parse_Error.Max_Field_Size_Exceeded` | `OCSV_ERROR_MAX_FIELD_SIZE_EXCEEDED` | Field size limit |
| `Parse_Error.Inconsistent_Column_Count` | `OCSV_ERROR_INCONSISTENT_COLUMN_COUNT` | Column count mismatch |
| `Parse_Error.Invalid_Escape_Sequence` | `OCSV_ERROR_INVALID_ESCAPE_SEQUENCE` | Escape handling |
| `Parse_Error.Empty_Input` | `OCSV_ERROR_EMPTY_INPUT` | Empty data validation |
| `Parse_Error.Memory_Allocation_Failed` | `OCSV_ERROR_MEMORY_ALLOCATION_FAILED` | Memory errors |

---

**Document Version:** 1.0
**Created:** 2025-10-15
**Based On:** JavaScript API Improvements PRD - Phase 1
**Next Phase:** Phase 2 - Streaming API (AsyncIterator support)
