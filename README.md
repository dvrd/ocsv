# OCSV - Odin CSV Parser

A high-performance, RFC 4180 compliant CSV parser written in Odin with Bun FFI support.

[![Release](https://github.com/dvrd/ocsv/actions/workflows/release.yml/badge.svg)](https://github.com/dvrd/ocsv/releases)
[![npm version](https://badge.fury.io/js/ocsv.svg)](https://www.npmjs.com/package/ocsv)
[![CI](https://github.com/dvrd/ocsv/actions/workflows/ci.yml/badge.svg)](https://github.com/dvrd/ocsv/actions)
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

## Performance Modes

OCSV offers two access modes to optimize for different use cases:

### Mode Comparison

| Feature | Eager Mode (default) | Lazy Mode |
|---------|---------------------|-----------|
| **Performance** | ~8 MB/s throughput | **≥180 MB/s** (22x faster) |
| **Memory Usage** | High (all data in JS) | **Low** (<200 MB for 10M rows) |
| **Parse Time (10M rows)** | ~150s | **<7s** (21x faster) |
| **Access Pattern** | Random access, arrays | Random access, on-demand |
| **Memory Management** | Automatic (GC) | **Manual** (`destroy()` required) |
| **Best For** | Small files, full iteration | Large files, selective access |
| **TypeScript Support** | Full | Full (discriminated unions) |

### Eager Mode (Default)

**Best for:** Small to medium files (<100k rows), full dataset iteration, simple workflows

All rows are materialized into JavaScript arrays immediately. Easy to use, no cleanup required.

```typescript
import { parseCSV } from 'ocsv';

// Default: eager mode
const result = parseCSV(data, { hasHeader: true });

console.log(result.headers);   // ['name', 'age', 'city']
console.log(result.rows);      // [['Alice', '30', 'NYC'], ...]
console.log(result.rowCount);  // 2

// Arrays: standard JavaScript operations
result.rows.forEach(row => console.log(row));
result.rows.map(row => row[0]);
result.rows.filter(row => row[1] > '25');
```

**Pros:**
- ✅ Simple API - standard JavaScript arrays
- ✅ No manual cleanup required
- ✅ Familiar array methods (map, filter, slice)
- ✅ Safe for GC-managed memory

**Cons:**
- ❌ Slower for large files (7.5x overhead)
- ❌ High memory usage (all rows in JS heap)
- ❌ Parse time proportional to data crossing FFI boundary

### Lazy Mode (High Performance)

**Best for:** Large files (>1M rows), selective access, memory-constrained environments

Rows stay in native Odin memory and are accessed on-demand. Achieves near-FFI performance with minimal memory footprint.

```typescript
import { parseCSV } from 'ocsv';

// Lazy mode: high performance
const result = parseCSV(data, {
  mode: 'lazy',
  hasHeader: true
});

try {
  console.log(result.headers);   // ['name', 'age', 'city']
  console.log(result.rowCount);  // 10000000

  // On-demand row access
  const row = result.getRow(5000000);
  console.log(row.get(0));       // 'Alice'
  console.log(row.get(1));       // '30'

  // Iterate fields
  for (const field of row) {
    console.log(field);
  }

  // Materialize row to array (when needed)
  const arr = row.toArray();     // ['Alice', '30', 'NYC']

  // Efficient slicing (generator)
  for (const row of result.slice(1000, 2000)) {
    console.log(row.get(0));
  }

  // Full iteration (if needed)
  for (const row of result) {
    console.log(row.get(0));
  }

} finally {
  // CRITICAL: Must cleanup native memory
  result.destroy();
}
```

**Pros:**
- ✅ **22x faster** parse time than eager mode
- ✅ **Low memory** footprint (<200 MB for 10M rows)
- ✅ LRU cache (1000 hot rows) for repeated access
- ✅ Generator-based slicing (memory efficient)
- ✅ Random access to any row (O(1) after cache)

**Cons:**
- ❌ **Manual cleanup required** (`destroy()` must be called)
- ❌ Not standard arrays (use `.get(i)` or `.toArray()`)
- ❌ Use-after-destroy throws errors

### When to Use Each Mode

```
                    Start
                      |
           Is file size > 100MB or > 1M rows?
                 /         \
               Yes          No
                |            |
         Do you need to    Use Eager Mode
         access all rows?   (simple, safe)
              /    \
            No     Yes
             |      |
        Lazy Mode  Memory constrained?
     (fast, low     /              \
      memory)     Yes               No
                   |                 |
              Lazy Mode         Try Eager first
           (streaming)        (measure, switch if slow)
```

**Use Lazy Mode when:**
- File size > 100 MB or > 1M rows
- You need selective row access (not full iteration)
- Memory is constrained (< 1 GB available)
- You're building streaming/ETL pipelines
- You need maximum parsing performance

**Use Eager Mode when:**
- File size < 100 MB or < 1M rows
- You need full dataset iteration
- You prefer simpler API (standard arrays)
- Memory cleanup must be automatic (GC)
- You're prototyping or writing quick scripts

### Performance Benchmarks

**Test Setup:** 10M rows, 4 columns, 1.2 GB CSV file

```
Mode          Parse Time    Throughput    Memory Usage
────────────────────────────────────────────────────────
FFI Direct    6.2s          193 MB/s      50 MB (baseline)
Lazy Mode     6.8s          176 MB/s      <200 MB
Eager Mode    151.7s        7.9 MB/s      ~8 GB
```

**Key Metrics:**
- Lazy mode is **22x faster** than eager mode
- Lazy mode uses **40x less memory** than eager mode
- Lazy mode is **only 9% slower** than raw FFI (acceptable overhead)

### FFI Performance Optimization (Phase 3)

For advanced users who need maximum FFI throughput, OCSV offers an optimized packed buffer mode:

**Test Setup:** 100K rows, 13.80 MB CSV file

```
Mode              Throughput    ns/row    vs Native      Improvement
──────────────────────────────────────────────────────────────────────
Native Odin       109.28 MB/s   915       100%           (baseline)
Phase 3 Optimized 61.25 MB/s    2,253     56.1%          +17.1% vs P2
Phase 2 Packed    52.32 MB/s    2,238     47.9%          +30.0% vs P1
Phase 1 Bulk JSON 40.68 MB/s    2,878     37.2%          (baseline)
Field-by-Field    29.58 MB/s    3,957     27.1%          N/A
```

**Phase 3 Optimizations:**
- ⚡ **61.25 MB/s** average throughput (56% of native, 109 MB/s baseline)
- 📈 **+17% improvement** over Phase 2 (best JS optimization without Odin SIMD)
- 🚀 **Batched TextDecoder** (reduced decoder overhead by ~30%)
- 💾 **Pre-allocated arrays** (reduced GC pressure)
- 📊 **SIMD-friendly memory access** patterns
- 🔄 **Row size adaptive strategy** (<4KB batched, >4KB individual)
- 📦 **Binary packed format** with length-prefixed strings
- ✨ **Single FFI call** (vs N×M calls)

**FFI Overhead:** Phase 3 shows ~44% overhead compared to pure Odin (56% efficiency). Further optimization requires Odin-side SIMD implementation or alternative serialization strategies.

**Usage:**
```typescript
import { parseCSVPacked } from 'ocsv/bindings/simple';

// Zero-copy packed buffer (highest FFI performance)
const rows = parseCSVPacked(csvData);
// Returns string[][] with minimal FFI overhead
```

**When to use Packed Buffer:**
- Need maximum FFI throughput (>40 MB/s)
- Willing to trade API simplicity for performance
- Working with medium-large files through Bun FFI
- Want to minimize cross-language boundary overhead

### Memory Management

#### Eager Mode
```typescript
// Automatic cleanup via garbage collector
const result = parseCSV(data);
// ... use result.rows ...
// Memory freed automatically when result goes out of scope
```

#### Lazy Mode
```typescript
// Manual cleanup required
const result = parseCSV(data, { mode: 'lazy' });
try {
  // ... use result ...
} finally {
  // CRITICAL: Always call destroy()
  result.destroy();
}
```

**Common Pitfalls:**

❌ **Forgetting to destroy:**
```typescript
const result = parseCSV(data, { mode: 'lazy' });
console.log(result.getRow(0));
// Memory leak! Parser not cleaned up
```

❌ **Use after destroy:**
```typescript
const result = parseCSV(data, { mode: 'lazy' });
result.destroy();
result.getRow(0);  // Error: LazyResult has been destroyed
```

✅ **Correct pattern:**
```typescript
const result = parseCSV(data, { mode: 'lazy' });
try {
  const row = result.getRow(0);
  console.log(row.toArray());
} finally {
  result.destroy();
}
```

### TypeScript Support

OCSV provides discriminated union types for type-safe mode selection:

```typescript
import { parseCSV } from 'ocsv';

// Type: ParseResult (array-based)
const eager = parseCSV(data);
console.log(eager.rows[0]);  // Type: string[]

// Type: LazyResult (on-demand)
const lazy = parseCSV(data, { mode: 'lazy' });
console.log(lazy.getRow(0)); // Type: LazyRow

// Compiler error: mode mismatch
const wrong = parseCSV(data, { mode: 'lazy' });
console.log(wrong.rows);  // Error: Property 'rows' does not exist
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

## Release Process

This project uses automated releases via [semantic-release](https://github.com/semantic-release/semantic-release). Releases are triggered automatically when changes are pushed to the `main` branch.

### Commit Message Format

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Examples:**
```bash
git commit -m "feat: add streaming parser API"
git commit -m "fix: handle empty fields correctly"
git commit -m "docs: update installation instructions"
git commit -m "feat!: remove deprecated parseFile method

BREAKING CHANGE: parseFile has been removed, use parseCSVFile instead"
```

**Commit Types:**
- `feat:` New feature (triggers minor version bump)
- `fix:` Bug fix (triggers patch version bump)
- `perf:` Performance improvement (triggers patch version bump)
- `docs:` Documentation changes (no release)
- `chore:` Maintenance tasks (no release)
- `refactor:` Code refactoring (no release)
- `test:` Test changes (no release)
- `ci:` CI/CD changes (no release)

### Version Bumps

- **Patch (1.1.0 → 1.1.1):** `fix:`, `perf:`
- **Minor (1.1.0 → 1.2.0):** `feat:`
- **Major (1.1.0 → 2.0.0):** Any commit with `BREAKING CHANGE:` in footer or `!` after type

### Release Workflow

1. Developer pushes commits to `main` branch
2. CI runs tests and builds
3. semantic-release analyzes commits
4. If releasable changes found:
   - Determines new version number
   - Updates CHANGELOG.md
   - Updates package.json
   - Creates git tag
   - Publishes to npm with provenance
   - Creates GitHub release with prebuilt binaries

**Manual Release (Emergency Only):**
```bash
npm run release:dry  # Test what would be released
git push origin main  # Trigger automated release
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on commit messages and pull request process.

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
