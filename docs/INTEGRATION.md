# Bun FFI Integration Guide

Complete guide for integrating OCSV with Bun using FFI (Foreign Function Interface).

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo

---

## Table of Contents

1. [Overview](#overview)
2. [Setup](#setup)
3. [Basic Usage](#basic-usage)
4. [Wrapper Class](#wrapper-class)
5. [TypeScript Integration](#typescript-integration)
6. [Error Handling](#error-handling)
7. [Performance Tips](#performance-tips)
8. [Common Issues](#common-issues)
9. [Advanced Examples](#advanced-examples)

---

## Overview

### What is Bun FFI?

Bun FFI allows JavaScript/TypeScript to call native libraries (written in Odin, C, Rust, etc.) directly without requiring Node-API wrappers.

**Benefits:**
- ✅ No C++ wrapper needed
- ✅ Direct function calls (fast)
- ✅ Simple API (`dlopen`)
- ✅ TypeScript support
- ✅ No build complexity

### OCSV FFI Architecture

```
┌─────────────────┐
│  Bun/TypeScript │
│     App         │
└────────┬────────┘
         │ FFI calls
         ▼
┌─────────────────┐
│  libcsv.dylib   │
│  (Odin binary)  │
└─────────────────┘
```

---

## Setup

### Prerequisites

```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Verify installation
bun --version
```

### Build OCSV Library

```bash
# Clone repository
git clone https://github.com/yourusername/ocsv.git
cd ocsv

# Build shared library
odin build src -build-mode:shared -out:libcsv.dylib -o:speed

# Verify library exists
ls -lh libcsv.dylib
```

---

## Basic Usage

### Step 1: Load Library

```typescript
import { dlopen, FFIType, suffix } from "bun:ffi";

const lib = dlopen(`./libcsv.${suffix}`, {
  cisv_parser_create: {
    returns: FFIType.ptr,
  },
  cisv_parser_destroy: {
    args: [FFIType.ptr],
    returns: FFIType.void,
  },
  cisv_parse_string: {
    args: [FFIType.ptr, FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
  cisv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
  cisv_get_field_count: {
    args: [FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
  cisv_get_field: {
    args: [FFIType.ptr, FFIType.i32, FFIType.i32],
    returns: FFIType.cstring,
  },
});
```

### Step 2: Parse CSV

```typescript
// Create parser
const parser = lib.symbols.cisv_parser_create();

// Prepare CSV data (MUST use Buffer)
const csvData = new TextEncoder().encode("name,age\nAlice,30\nBob,25\n");

// Parse
const result = lib.symbols.cisv_parse_string(parser, csvData, csvData.length);

if (result === 0) {
  console.log("Parse succeeded!");
} else {
  console.log("Parse failed!");
}

// Cleanup
lib.symbols.cisv_parser_destroy(parser);
```

### Step 3: Access Results

```typescript
const rowCount = lib.symbols.cisv_get_row_count(parser);
console.log(`Parsed ${rowCount} rows`);

for (let i = 0; i < rowCount; i++) {
  const fieldCount = lib.symbols.cisv_get_field_count(parser, i);
  const row: string[] = [];

  for (let j = 0; j < fieldCount; j++) {
    const field = lib.symbols.cisv_get_field(parser, i, j);
    row.push(field);
  }

  console.log(`Row ${i}:`, row);
}
```

---

## Wrapper Class

Create a reusable wrapper class for convenience:

### CsvParser.ts

```typescript
import { dlopen, FFIType, suffix, CString } from "bun:ffi";

export class CsvParser {
  private lib: any;
  private parser: number;

  constructor(libPath: string = `./libcsv.${suffix}`) {
    this.lib = dlopen(libPath, {
      cisv_parser_create: {
        returns: FFIType.ptr,
      },
      cisv_parser_destroy: {
        args: [FFIType.ptr],
        returns: FFIType.void,
      },
      cisv_parse_string: {
        args: [FFIType.ptr, FFIType.ptr, FFIType.i32],
        returns: FFIType.i32,
      },
      cisv_get_row_count: {
        args: [FFIType.ptr],
        returns: FFIType.i32,
      },
      cisv_get_field_count: {
        args: [FFIType.ptr, FFIType.i32],
        returns: FFIType.i32,
      },
      cisv_get_field: {
        args: [FFIType.ptr, FFIType.i32, FFIType.i32],
        returns: FFIType.cstring,
      },
    });

    this.parser = this.lib.symbols.cisv_parser_create();
  }

  /**
   * Parse CSV string and return 2D array
   */
  parse(csvData: string): string[][] {
    const encoded = new TextEncoder().encode(csvData);
    const result = this.lib.symbols.cisv_parse_string(
      this.parser,
      encoded,
      encoded.length
    );

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    return this.getRows();
  }

  /**
   * Get all parsed rows
   */
  private getRows(): string[][] {
    const rows: string[][] = [];
    const rowCount = this.lib.symbols.cisv_get_row_count(this.parser);

    for (let i = 0; i < rowCount; i++) {
      const fieldCount = this.lib.symbols.cisv_get_field_count(this.parser, i);
      const row: string[] = [];

      for (let j = 0; j < fieldCount; j++) {
        const field = this.lib.symbols.cisv_get_field(this.parser, i, j);
        row.push(field);
      }

      rows.push(row);
    }

    return rows;
  }

  /**
   * Get number of parsed rows
   */
  getRowCount(): number {
    return this.lib.symbols.cisv_get_row_count(this.parser);
  }

  /**
   * Clean up and free memory
   */
  destroy() {
    this.lib.symbols.cisv_parser_destroy(this.parser);
  }
}
```

### Usage

```typescript
import { CsvParser } from "./CsvParser";

const parser = new CsvParser();

try {
  const rows = parser.parse("name,age,city\nAlice,30,NYC\nBob,25,SF\n");
  console.log(rows);
  // [
  //   ["name", "age", "city"],
  //   ["Alice", "30", "NYC"],
  //   ["Bob", "25", "SF"]
  // ]
} finally {
  parser.destroy();
}
```

---

## TypeScript Integration

### Type Definitions

```typescript
// types.ts
export interface CsvRow {
  [key: string]: string;
}

export interface CsvOptions {
  hasHeader?: boolean;
  delimiter?: string;
}

export class TypedCsvParser {
  private parser: CsvParser;

  constructor(libPath?: string) {
    this.parser = new CsvParser(libPath);
  }

  /**
   * Parse CSV and return array of objects with typed keys
   */
  parseToObjects(csvData: string, options: CsvOptions = {}): CsvRow[] {
    const rows = this.parser.parse(csvData);

    if (rows.length === 0) {
      return [];
    }

    const hasHeader = options.hasHeader !== false;
    const headers = hasHeader ? rows[0] : rows[0].map((_, i) => `col${i}`);
    const dataRows = hasHeader ? rows.slice(1) : rows;

    return dataRows.map((row) => {
      const obj: CsvRow = {};
      headers.forEach((header, i) => {
        obj[header] = row[i] || "";
      });
      return obj;
    });
  }

  destroy() {
    this.parser.destroy();
  }
}
```

### Usage

```typescript
const parser = new TypedCsvParser();

const csvData = `name,age,city
Alice,30,NYC
Bob,25,SF`;

const records = parser.parseToObjects(csvData);
console.log(records);
// [
//   { name: "Alice", age: "30", city: "NYC" },
//   { name: "Bob", age: "25", city: "SF" }
// ]

parser.destroy();
```

---

## Error Handling

### Check Parse Result

```typescript
const result = lib.symbols.cisv_parse_string(parser, data, data.length);

if (result !== 0) {
  console.error("Parse failed");
  // result === -1: Error occurred
}
```

### Wrapper with Error Handling

```typescript
class SafeCsvParser extends CsvParser {
  parse(csvData: string): string[][] | null {
    try {
      const encoded = new TextEncoder().encode(csvData);
      const result = this.lib.symbols.cisv_parse_string(
        this.parser,
        encoded,
        encoded.length
      );

      if (result !== 0) {
        console.error("CSV parse error");
        return null;
      }

      return this.getRows();
    } catch (error) {
      console.error("Exception during parsing:", error);
      return null;
    }
  }
}
```

### Try-Finally Pattern

```typescript
const parser = new CsvParser();

try {
  const rows = parser.parse(csvData);
  processRows(rows);
} catch (error) {
  console.error("Error:", error);
} finally {
  parser.destroy(); // Always cleanup
}
```

---

## Performance Tips

### 1. Reuse Parser Instance

**Bad:**
```typescript
for (const file of csvFiles) {
  const parser = new CsvParser();  // Create each time
  const data = await Bun.file(file).text();
  const rows = parser.parse(data);
  parser.destroy();
}
```

**Good:**
```typescript
const parser = new CsvParser();

try {
  for (const file of csvFiles) {
    const data = await Bun.file(file).text();
    const rows = parser.parse(data);  // Reuse parser
    processRows(rows);
  }
} finally {
  parser.destroy();
}
```

### 2. Use TextEncoder Once

```typescript
const encoder = new TextEncoder();

for (const csvString of csvStrings) {
  const encoded = encoder.encode(csvString);
  // Use encoded buffer...
}
```

### 3. Batch File Reading

```typescript
// Read multiple files in parallel
const files = ["data1.csv", "data2.csv", "data3.csv"];
const parser = new CsvParser();

try {
  const results = await Promise.all(
    files.map(async (file) => {
      const data = await Bun.file(file).text();
      return parser.parse(data);
    })
  );

  results.forEach((rows, i) => {
    console.log(`${files[i]}: ${rows.length} rows`);
  });
} finally {
  parser.destroy();
}
```

---

## Common Issues

### Issue 1: "Library not found"

**Error:** `Could not open library: libcsv.dylib`

**Solution:**
```typescript
// Use absolute path
import { resolve } from "path";

const libPath = resolve("./libcsv.dylib");
const parser = new CsvParser(libPath);
```

### Issue 2: "Parse always fails"

**Cause:** Passing string instead of Buffer

**Wrong:**
```typescript
const data = "name,age\nAlice,30\n";
lib.symbols.cisv_parse_string(parser, data, data.length);  // WRONG
```

**Correct:**
```typescript
const data = new TextEncoder().encode("name,age\nAlice,30\n");
lib.symbols.cisv_parse_string(parser, data, data.length);  // CORRECT
```

### Issue 3: "Segmentation fault"

**Causes:**
- Parser not initialized
- Calling after destroy
- Invalid pointer

**Solution:**
```typescript
class SafeParser {
  private destroyed = false;

  parse(data: string): string[][] {
    if (this.destroyed) {
      throw new Error("Parser already destroyed");
    }
    // ... parse
  }

  destroy() {
    if (!this.destroyed) {
      this.lib.symbols.cisv_parser_destroy(this.parser);
      this.destroyed = true;
    }
  }
}
```

---

## Advanced Examples

### Parse CSV from File

```typescript
const parser = new CsvParser();

try {
  const file = Bun.file("data.csv");
  const csvData = await file.text();
  const rows = parser.parse(csvData);

  console.log(`Parsed ${rows.length} rows from data.csv`);
} finally {
  parser.destroy();
}
```

### Stream Large Files (Chunked)

```typescript
async function parseChunked(filePath: string, chunkSize: number = 1024 * 1024) {
  const file = Bun.file(filePath);
  const parser = new CsvParser();

  try {
    // For very large files, you'd read in chunks
    // Current API requires full data, streaming API coming in Phase 2
    const data = await file.text();
    return parser.parse(data);
  } finally {
    parser.destroy();
  }
}
```

### Convert CSV to JSON

```typescript
import { writeFileSync } from "fs";

const parser = new TypedCsvParser();

try {
  const csvData = await Bun.file("input.csv").text();
  const records = parser.parseToObjects(csvData);

  // Write to JSON
  writeFileSync("output.json", JSON.stringify(records, null, 2));

  console.log(`Converted ${records.length} records to JSON`);
} finally {
  parser.destroy();
}
```

### Custom Delimiter (Future)

```typescript
// Note: Custom delimiter configuration will be added in future FFI API
// For now, use default comma delimiter
// Workaround: Pre-process CSV to replace delimiters

function preprocessTsv(tsvData: string): string {
  return tsvData.replace(/\t/g, ",");
}

const parser = new CsvParser();
const csvData = preprocessTsv(tsvData);
const rows = parser.parse(csvData);
```

### Benchmark Parsing

```typescript
const parser = new CsvParser();

try {
  const csvData = generateLargeCsv(100_000); // 100k rows

  const start = performance.now();
  const rows = parser.parse(csvData);
  const end = performance.now();

  const sizeMB = csvData.length / 1024 / 1024;
  const timeSec = (end - start) / 1000;
  const throughput = sizeMB / timeSec;

  console.log(`Parsed ${rows.length} rows`);
  console.log(`Size: ${sizeMB.toFixed(2)} MB`);
  console.log(`Time: ${(end - start).toFixed(2)} ms`);
  console.log(`Throughput: ${throughput.toFixed(2)} MB/s`);
} finally {
  parser.destroy();
}
```

---

## API Reference

See [API.md](API.md) for complete Odin API documentation.

### FFI Function Summary

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `cisv_parser_create` | `() -> ptr` | Parser pointer | Create new parser |
| `cisv_parser_destroy` | `(ptr) -> void` | - | Destroy parser |
| `cisv_parse_string` | `(ptr, ptr, i32) -> i32` | 0=success, -1=error | Parse CSV data |
| `cisv_get_row_count` | `(ptr) -> i32` | Row count | Get number of rows |
| `cisv_get_field_count` | `(ptr, i32) -> i32` | Field count | Get fields in row |
| `cisv_get_field` | `(ptr, i32, i32) -> cstring` | Field value | Get field value |

---

## Additional Resources

- **[API Reference](API.md)** - Complete API documentation
- **[Cookbook](COOKBOOK.md)** - Usage examples
- **[Bun FFI Docs](https://bun.sh/docs/api/ffi)** - Official Bun FFI guide

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo
