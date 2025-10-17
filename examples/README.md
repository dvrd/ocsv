# OCSV Examples

Two benchmark implementations demonstrating OCSV's high-performance CSV parsing:
1. **Pure Odin** - Zero abstraction, native speed
2. **TypeScript/Bun** - Minimal FFI bindings for JavaScript

## Files

- **`benchmark.odin`** - Pure Odin benchmark (fastest, zero abstraction)
- **`benchmark.ts`** - TypeScript/Bun benchmark (minimal FFI bindings)
- **`generate_large_data.ts`** - Generate test CSV files of any size
- **`large_data.csv`** - Generated test data (not in git)

## Quick Start

### 1. Generate test data

```bash
# Generate 10 million rows (~662 MB)
bun run examples/generate_large_data.ts 10000000
```

### 2. Run benchmark

Choose your preferred implementation:

```bash
# Pure Odin (fastest - 116+ MB/s)
cd examples && odin run benchmark.odin -file -out:benchmark_odin -o:speed

# TypeScript/Bun (FFI - 95+ MB/s)
bun run examples/benchmark.ts
```

## Performance Comparison

Tested with 10M rows (662 MB):

| Implementation | Throughput | Time/row | Parse time |
|----------------|-----------|----------|------------|
| **Pure Odin** | 116.62 MB/s | 567 ns | 5.68s |
| TypeScript/Bun (FFI) | 24.95 MB/s | 2653 ns | 26.53s |

**Why is Odin faster?**
- Zero FFI overhead
- No type conversions
- No JavaScript GC pauses
- Direct memory access
- Native code execution

## Benchmark Output

### Pure Odin (benchmark.odin)

```
📄 File Information
   Size: 661.88 MB (0.65 GB)
   Bytes: 694,027,843

⚡ Parsing CSV (Fast Dimension Check)
   Rows: 10,000,001
   Parse time: 5.43 s
   Throughput: 121.94 MB/s
   Rows/sec: 1,842,349

⚡ Full Parse (All Data Access)
   Rows parsed: 10,000,001
   Parse time: 5.68 s
   Throughput: 116.62 MB/s
   Rows/sec: 1,761,917

🎯 Performance Rating
   Throughput: 116.62 MB/s
   vs Baseline: 188.6%
   Status: ✅ EXCELLENT (above baseline)

📊 Summary:
   • Parsed 10,000,001 rows in 5.68s
   • 116.62 MB/s throughput
   • 567 ns per row
   • Zero memory leaks, zero abstractions
   • Pure Odin - No FFI overhead!
```

### TypeScript/Bun (benchmark.ts)

```
📄 File Information
   Size: 661.88 MB (0.65 GB)
   Bytes: 694,027,843

⚡ Parsing CSV (Fast Dimension Check)
   Rows: 10,000,001
   Parse time: 6.91 s
   Throughput: 95.83 MB/s
   Rows/sec: 1,447,832

⚡ Full Parse (All Data Extraction)
   Rows parsed: 10,000,001
   Parse time: 26.53 s
   Throughput: 24.95 MB/s
   Rows/sec: 376,888

📊 Summary:
   • Parsed 10,000,001 rows in 26.53s
   • 24.95 MB/s throughput
   • 2653 ns per row
   • Zero memory leaks, zero abstractions
```

## API Examples

### Pure Odin (Zero Abstraction)

```odin
import ocsv "../src"

parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)

// Parse CSV
ok := ocsv.parse_csv(parser, csv_string)

// Access data directly
for row in parser.all_rows {
    for field in row {
        fmt.println(field)
    }
}
```

### TypeScript/Bun (Minimal FFI)

```typescript
import { parseCSV, getCSVDimensions, ffi } from "../bindings/simple";

// Simple parse - returns 2D array
const rows = parseCSV(csvData);

// Fast dimension check
const { rows, avgFields } = getCSVDimensions(csvData);

// Direct FFI access for advanced use
const parser = ffi.ocsv_parser_create();
ffi.ocsv_parse_string(parser, buffer, length);
const rowCount = ffi.ocsv_get_row_count(parser);
ffi.ocsv_parser_destroy(parser);
```

## Custom Files

Benchmark any CSV file:

```bash
# Pure Odin
cd examples && odin run benchmark.odin -file -out:benchmark_odin -o:speed -- path/to/file.csv

# TypeScript/Bun
bun run examples/benchmark.ts path/to/file.csv
```

## Generate Different Sizes

```bash
# Small (10K rows, ~1 MB)
bun run examples/generate_large_data.ts 10000

# Medium (100K rows, ~12 MB)
bun run examples/generate_large_data.ts 100000

# Large (1M rows, ~116 MB)
bun run examples/generate_large_data.ts 1000000

# Extra large (10M rows, ~662 MB)
bun run examples/generate_large_data.ts 10000000

# Custom output file
bun run examples/generate_large_data.ts 10000000 custom.csv
```

## Features Demonstrated

✅ **Zero abstraction** - Direct access to native code (Odin) or minimal FFI (TypeScript)
✅ **High performance** - 116+ MB/s (Odin), 95+ MB/s (TypeScript dim check)
✅ **Large datasets** - Handles millions of rows
✅ **RFC 4180 compliance** - All edge cases handled
✅ **UTF-8 support** - Full Unicode support
✅ **Memory safety** - Zero leaks, proper cleanup

## When to Use Which?

### Use Pure Odin when:
- ✅ Maximum performance is critical
- ✅ Building CLI tools
- ✅ Server-side batch processing
- ✅ You're already using Odin
- ✅ You need 100+ MB/s throughput

### Use TypeScript/Bun when:
- ✅ Integrating with JavaScript/TypeScript projects
- ✅ Web applications
- ✅ Node.js/Bun services
- ✅ Quick prototyping
- ✅ 20-95 MB/s is sufficient

## Learn More

- [`benchmark.odin`](benchmark.odin) - Pure Odin benchmark implementation
- [`benchmark.ts`](benchmark.ts) - TypeScript/Bun benchmark implementation
- [`../bindings/simple.ts`](../bindings/simple.ts) - Minimal FFI bindings
- [`../bindings/README-SIMPLE.md`](../bindings/README-SIMPLE.md) - FFI API documentation
- [`../src/`](../src/) - Odin source code
- [`../README.md`](../README.md) - Project overview
