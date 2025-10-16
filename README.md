# OCSV - Odin CSV Parser

A high-performance, RFC 4180 compliant CSV parser written in Odin with Bun FFI support.

[![npm version](https://img.shields.io/npm/v/ocsv)](https://www.npmjs.com/package/ocsv)
[![Tests](https://img.shields.io/badge/tests-201%20passing-brightgreen)]()
[![Memory Leaks](https://img.shields.io/badge/memory%20leaks-0-brightgreen)]()
[![RFC 4180](https://img.shields.io/badge/RFC%204180-compliant-blue)]()

**Platform Support:**
[![macOS](https://img.shields.io/badge/macOS-ARM64-blue)]()

## Features

- ⚡ **High Performance** - Fast CSV parsing with SIMD optimizations
- 🦺 **Memory Safe** - Zero memory leaks, comprehensive testing
- ✅ **RFC 4180 Compliant** - Full CSV specification support
- 🌍 **UTF-8 Support** - Correct handling of international characters
- 🔧 **Flexible Configuration** - Custom delimiters, quotes, comments
- 📦 **Bun Native** - Direct FFI integration with Bun runtime
- 🛡️ **Error Handling** - Detailed error messages with line/column info
- 🎯 **Schema Validation** - Type checking, constraints, type conversion
- 🌊 **Streaming API** - Memory-efficient chunk-based processing
- 🔄 **Transform System** - Built-in transforms and pipelines
- 🔌 **Plugin System** - Extensible architecture for custom functionality

## Why Odin + Bun?

**Key Advantages:**
- ✅ Simple build system (no node-gyp, no Python)
- ✅ Better memory safety (explicit memory management + defer)
- ✅ Better error handling (enums + multiple returns)
- ✅ No C++ wrapper needed (Bun FFI is direct)

## Quick Start

### npm Installation (Recommended)

Install OCSV as an npm package for easy integration with your Bun projects:

```bash
# Using Bun
bun add ocsv

# Using npm
npm install ocsv
```

Then use it in your project:

```typescript
import { parseCSV } from 'ocsv';

// Parse CSV string
const result = parseCSV('name,age\nJohn,30\nJane,25', { hasHeader: true });
console.log(result.headers); // ['name', 'age']
console.log(result.rows);    // [['John', '30'], ['Jane', '25']]

// Parse CSV file
import { parseCSVFile } from 'ocsv';
const data = await parseCSVFile('./data.csv', { hasHeader: true });
console.log(`Parsed ${data.rowCount} rows`);
```

### Manual Installation (Development)

For building from source or contributing:

```bash
git clone https://github.com/dvrd/ocsv.git
cd ocsv
```

### Build

**Current Support:** macOS ARM64 (cross-platform support in progress)

```bash
# Using Task (recommended)
task build          # Build release library
task build-dev      # Build debug library
task test           # Run all tests
task info           # Show platform info

# Manual build
odin build src -build-mode:shared -out:libocsv.dylib -o:speed
```

### Basic Usage (Odin)

```odin
package main

import "core:fmt"
import ocsv "src"

main :: proc() {
    // Create parser
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    // Parse CSV data
    csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
    ok := ocsv.parse_csv(parser, csv_data)

    if ok {
        // Access parsed data
        fmt.printfln("Parsed %d rows", len(parser.all_rows))
        for row in parser.all_rows {
            for field in row {
                fmt.printf("%s ", field)
            }
            fmt.printf("\n")
        }
    }
}
```

### Bun API Examples

#### Basic Parsing

```typescript
import { parseCSV } from 'ocsv';

// Parse CSV with headers
const result = parseCSV('name,age,city\nAlice,30,NYC\nBob,25,SF', {
  hasHeader: true
});

console.log(result.headers); // ['name', 'age', 'city']
console.log(result.rows);    // [['Alice', '30', 'NYC'], ['Bob', '25', 'SF']]
console.log(result.rowCount); // 2
```

#### Parse from File

```typescript
import { parseCSVFile } from 'ocsv';

// Parse CSV file with headers
const data = await parseCSVFile('./sales.csv', {
  hasHeader: true,
  delimiter: ',',
});

console.log(`Parsed ${data.rowCount} rows`);
console.log(`Columns: ${data.headers.join(', ')}`);

// Process rows
for (const row of data.rows) {
  console.log(row);
}
```

#### Custom Configuration

```typescript
import { parseCSV } from 'ocsv';

// Parse TSV (tab-separated)
const tsvData = parseCSV('col1\tcol2\trow1\tdata', {
  delimiter: '\t',
  hasHeader: true,
});

// Parse with semicolon delimiter (European CSV)
const europeanData = parseCSV('name;age;city\nJohn;30;Paris', {
  delimiter: ';',
  hasHeader: true,
});

// Relaxed mode (allows some RFC violations)
const relaxedData = parseCSV('messy,csv,"data', {
  relaxed: true,
});
```

#### Manual Parser Management

For more control, use the `Parser` class directly:

```typescript
import { Parser } from 'ocsv';

const parser = new Parser();
try {
  const result = parser.parse('a,b,c\n1,2,3');
  console.log(result.rows);
} finally {
  parser.destroy(); // Important: free memory
}
```

## Configuration

```odin
// Create parser with custom configuration
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// TSV (Tab-Separated Values)
parser.config.delimiter = '\t'

// European CSV (semicolon)
parser.config.delimiter = ';'

// Comments (skip lines starting with #)
parser.config.comment = '#'

// Relaxed mode (handle malformed CSV)
parser.config.relaxed = true

// Custom quote character
parser.config.quote = '\''
```

## RFC 4180 Compliance

OCSV fully implements RFC 4180 with support for:

- ✅ Quoted fields with embedded delimiters (`"field, with, commas"`)
- ✅ Nested quotes (`"field with ""quotes"""` → `field with "quotes"`)
- ✅ Multiline fields (newlines inside quotes)
- ✅ CRLF and LF line endings (Windows/Unix)
- ✅ Empty fields (consecutive delimiters: `a,,c`)
- ✅ Trailing delimiters (`a,b,` → 3 fields, last is empty)
- ✅ Leading delimiters (`,a,b` → 3 fields, first is empty)
- ✅ Comments (extension: lines starting with `#`)
- ✅ Unicode/UTF-8 (CJK characters, emojis, etc.)

**Example:**
```csv
# Sales data for Q1 2024
product,price,description,quantity
"Widget A",19.99,"A great widget, now with more features!",100
"Gadget B",29.99,"Essential gadget
Multi-line description",50
```

## Testing

**~201 tests, 100% pass rate, 0 memory leaks**

```bash
# Run all tests (standard)
odin test tests

# Run with memory tracking
odin test tests -debug
```

### Test Suites

The project includes comprehensive test coverage across multiple suites:
- Basic functionality and core parsing operations
- RFC 4180 edge cases and compliance
- Integration tests for end-to-end workflows
- Schema validation and type checking
- Transform system and pipelines
- Plugin system functionality
- Streaming API with chunk boundaries
- Large file handling
- Performance regression monitoring
- Error handling and recovery strategies
- Property-based fuzzing tests
- Parallel processing capabilities
- SIMD optimization verification

## Project Structure

```
ocsv/
├── src/
│   ├── ocsv.odin         # Main module
│   ├── parser.odin       # RFC 4180 state machine parser
│   ├── parser_simd.odin  # SIMD-optimized parser
│   ├── parser_error.odin # Error-aware parser
│   ├── streaming.odin    # Streaming API
│   ├── parallel.odin     # Parallel processing
│   ├── transform.odin    # Transform system
│   ├── plugin.odin       # Plugin architecture
│   ├── simd.odin         # SIMD search functions
│   ├── error.odin        # Error handling system
│   ├── schema.odin       # Schema validation & type system
│   ├── config.odin       # Configuration types
│   └── ffi_bindings.odin # Bun FFI exports
├── tests/               # Comprehensive test suite
├── plugins/             # Example plugins
├── bindings/            # Bun/TypeScript bindings
├── benchmarks/          # Performance benchmarks
├── examples/            # Usage examples
└── README.md           # This file
```

## Requirements

- **Odin:** Latest version (tested with Odin dev-2025-01)
- **Bun:** v1.0+ (for FFI integration, optional)
- **Platform:** macOS ARM64 (cross-platform support in development)
- **Task:** v3+ (optional, for automated builds)

## Contributing

Contributions are welcome!

**Development Workflow:**
1. Fork the repository
2. Create a feature branch
3. Make changes with tests (`odin test tests`)
4. Ensure zero memory leaks
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- **Odin Language:** [https://odin-lang.org/](https://odin-lang.org/)
- **Bun Runtime:** [https://bun.sh/](https://bun.sh/)
- **RFC 4180:** [https://www.rfc-editor.org/rfc/rfc4180](https://www.rfc-editor.org/rfc/rfc4180)

## Related Projects

- **d3-dsv** - Pure JavaScript CSV/DSV parser
- **papaparse** - Popular JavaScript CSV parser
- **xsv** - Rust CLI tool for CSV processing
- **csv-parser** - Node.js streaming CSV parser

## Contact

- **Issues:** [GitHub Issues](https://github.com/dvrd/ocsv/issues)
- **Discussions:** [GitHub Discussions](https://github.com/dvrd/ocsv/discussions)

---

**Built with ❤️ using Odin + Bun**

**Version:** 1.0.0

**Last Updated:** 2025-10-16
