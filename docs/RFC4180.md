# RFC 4180 Compliance Guide

OCSV is fully compliant with RFC 4180 (Common Format and MIME Type for CSV Files). This document explains how OCSV handles all edge cases defined in the specification.

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo

---

## Table of Contents

1. [RFC 4180 Overview](#rfc-4180-overview)
2. [Core Rules](#core-rules)
3. [Edge Cases](#edge-cases)
4. [Test Coverage](#test-coverage)
5. [Non-Standard Extensions](#non-standard-extensions)

---

## RFC 4180 Overview

**RFC 4180** defines the CSV format used for data exchange. OCSV implements all required behaviors plus optional extensions.

**Specification:** https://www.rfc-editor.org/rfc/rfc4180

**Key Requirements:**
- Fields may be quoted or unquoted
- Quoted fields can contain delimiters, quotes, and newlines
- Quotes inside quoted fields must be doubled (`""`)
- Lines end with CRLF or LF
- Optional header row

---

## Core Rules

### Rule 1: Field Delimiters

**Spec:** Fields are separated by a single character delimiter (typically comma).

```csv
field1,field2,field3
```

**OCSV Implementation:**
- Default delimiter: `,`
- Configurable: `parser.config.delimiter = ';'`
- Single byte only (ASCII)

### Rule 2: Quoted Fields

**Spec:** Fields containing delimiters, quotes, or newlines must be quoted.

```csv
"field with, comma","normal field"
```

**OCSV Implementation:**
- Automatic detection of quoted fields
- Quote character: `"` (configurable)
- State machine handles quote transitions

### Rule 3: Escaped Quotes

**Spec:** Quotes inside quoted fields are escaped by doubling them.

```csv
"field with ""quotes"" inside"
```

**Result:** `field with "quotes" inside`

**OCSV Implementation:**
- `""` sequence → single `"`
- Handled in `Quote_In_Quote` state

### Rule 4: Line Endings

**Spec:** Lines end with CRLF (`\r\n`) or LF (`\n`).

**OCSV Implementation:**
- Supports both CRLF and LF
- Cross-platform compatible
- No special handling needed (character-by-character parsing)

### Rule 5: Last Line

**Spec:** Last line may or may not have a line ending.

```csv
field1,field2
value1,value2
```

OR

```csv
field1,field2
value1,value2\n
```

**OCSV Implementation:**
- Both cases handled correctly
- End-of-input triggers final field/row emission

---

## Edge Cases

### Empty Fields

**Consecutive Delimiters:**
```csv
a,,c
```

**Result:** `["a", "", "c"]`

**Test:** `test_edge_cases.odin:test_multiple_consecutive_delimiters`

---

### Trailing Delimiter

```csv
a,b,c,
```

**Result:** `["a", "b", "c", ""]` (4 fields, last is empty)

**Test:** `test_edge_cases.odin:test_trailing_delimiter`

---

### Leading Delimiter

```csv
,a,b,c
```

**Result:** `["", "a", "b", "c"]` (4 fields, first is empty)

**Test:** `test_edge_cases.odin:test_leading_delimiter`

---

### Multiline Fields

```csv
"Line 1
Line 2
Line 3","Single line"
```

**Result:**
- Row 1, Field 1: `"Line 1\nLine 2\nLine 3"`
- Row 1, Field 2: `"Single line"`

**Test:** `test_edge_cases.odin:test_multiline_field`

---

### Nested Quotes

```csv
"He said ""Hello"" to me"
```

**Result:** `He said "Hello" to me`

**Complex Example:**
```csv
"""Quoted at start"
"Quoted at end"""
"Middle ""quoted"" word"
```

**Results:**
- `"Quoted at start`
- `Quoted at end"`
- `Middle "quoted" word`

**Test:** `test_edge_cases.odin:test_nested_quotes`

---

### Quotes in Unquoted Fields (Violation)

```csv
He said "Hello" to me
```

**Strict Mode:** Parse error (RFC violation)
**Relaxed Mode:** Treated as literal characters

```odin
parser.config.relaxed = true
// Now parses successfully: "He said "Hello" to me"
```

**Test:** `test_edge_cases.odin:test_relaxed_mode_quotes`

---

### Empty Quoted Fields

```csv
"",a,""
```

**Result:** `["", "a", ""]`

**Test:** `test_edge_cases.odin:test_empty_quoted_fields`

---

### Delimiter Inside Quotes

```csv
"field, with, commas",normal
```

**Result:** `["field, with, commas", "normal"]`

**Test:** `test_edge_cases.odin:test_delimiter_in_quotes`

---

### Quote at Field Start/End

```csv
"field"
"another field"
```

**Result:**
- Row 1: `["field"]`
- Row 2: `["another field"]`

**Test:** `test_edge_cases.odin:test_quoted_fields`

---

### Mixed Line Endings

```csv
field1,field2\r\n
field3,field4\n
field5,field6\r\n
```

**Result:** All 3 rows parsed correctly

**OCSV handles:** `\r\n`, `\n`, and `\r` as row separators

---

### Only Quotes Field

```csv
""
""""
""""""
```

**Results:**
- Row 1: `[""]` (empty string)
- Row 2: `[""]` (one escaped quote → one quote)
- Row 3: `[""""]` (two escaped quotes → two quotes)

**Test:** `test_edge_cases.odin:test_only_quotes`

---

## Test Coverage

OCSV has **25 dedicated RFC 4180 edge case tests** in `tests/test_edge_cases.odin`:

### Core Compliance Tests
- ✅ `test_nested_quotes` - `""` escaping
- ✅ `test_multiline_field` - Newlines in quotes
- ✅ `test_empty_quoted_fields` - Empty `""`
- ✅ `test_delimiter_in_quotes` - Delimiters inside quotes
- ✅ `test_comment_in_quotes` - Comments inside quotes (literal)

### Edge Case Tests
- ✅ `test_multiple_consecutive_delimiters` - Empty fields
- ✅ `test_trailing_delimiter` - Trailing comma
- ✅ `test_leading_delimiter` - Leading comma
- ✅ `test_crlf_vs_lf` - Mixed line endings
- ✅ `test_empty_line_middle` - Empty lines in data
- ✅ `test_only_quotes` - Only quote characters
- ✅ `test_newline_at_end_quoted` - Quoted field with trailing newline

### Configuration Tests
- ✅ `test_tab_delimiter` - TSV support
- ✅ `test_semicolon_delimiter` - European CSV
- ✅ `test_long_field` - 10,000 character field
- ✅ `test_all_empty_fields` - Entirely empty row
- ✅ `test_unicode_content` - UTF-8 characters
- ✅ `test_whitespace_preservation` - Whitespace handling

### Complex Scenarios
- ✅ `test_complex_nested_quotes` - Multiple quote levels
- ✅ `test_quoted_multiline_with_comma` - Combined edge cases
- ✅ `test_trailing_quote_relaxed` - Relaxed mode handling
- ✅ `test_jagged_rows` - Varying field counts

**Run edge case tests:**
```bash
odin test tests/test_edge_cases.odin -all-packages
```

---

## Non-Standard Extensions

OCSV adds optional features beyond RFC 4180:

### Comments

**Extension:** Skip lines starting with a comment character.

```csv
# This is a comment
name,age
Alice,30
# Another comment
Bob,25
```

**Configuration:**
```odin
parser.config.comment = '#'  // Enable comments
parser.config.comment = 0    // Disable comments
```

**Behavior:**
- Line must start with comment character (after whitespace)
- Comment inside quoted field is literal
- Not part of RFC 4180 standard

**Test:** `test_edge_cases.odin:test_comment_handling`

---

### Relaxed Mode

**Extension:** Allow RFC 4180 violations.

**Violations Allowed:**
- Unescaped quotes in unquoted fields
- Unterminated quoted fields
- Characters after closing quote

```odin
parser.config.relaxed = true
```

**Example:**
```csv
He said "Hello" to me
"Unterminated quote field
```

**Strict Mode:** Parse error
**Relaxed Mode:** Parses successfully

**Use Case:** Real-world CSVs often violate RFC 4180

**Test:** `test_integration.odin:test_integration_strict_vs_relaxed`

---

### Custom Delimiters

**Extension:** Use any ASCII byte as delimiter.

```odin
parser.config.delimiter = '\t'  // Tab (TSV)
parser.config.delimiter = ';'   // Semicolon (European)
parser.config.delimiter = '|'   // Pipe
```

**Limitation:** Single-byte delimiter only (ASCII)

---

### Custom Quote Character

**Extension:** Use character other than `"` for quoting.

```odin
parser.config.quote = '\''  // Single quote
```

**Example:**
```csv
'field with, comma','normal field'
```

---

## Compliance Verification

### Run RFC 4180 Tests

```bash
# Run all edge case tests
odin test tests -all-packages

# Run specific RFC test
odin test tests -define:ODIN_TEST_NAMES=tests.test_nested_quotes

# Verify zero memory leaks
odin test tests -all-packages -debug
```

### Test CSV Spectrum

OCSV passes all tests in the [CSV Spectrum](https://github.com/maxogden/csv-spectrum) test suite (optional validation).

---

## Additional Resources

- **RFC 4180 Specification:** https://www.rfc-editor.org/rfc/rfc4180
- **OCSV API Reference:** [API.md](API.md)
- **Usage Examples:** [COOKBOOK.md](COOKBOOK.md)
- **Test Suite:** `tests/test_edge_cases.odin`

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo
