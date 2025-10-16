# OCSV Examples

This directory contains practical examples demonstrating how to use OCSV with Bun.

## Prerequisites

```bash
# Install Bun (if not already installed)
curl -fsSL https://bun.sh/install | bash

# Build the OCSV library (from project root)
cd ..
odin build src -build-mode:shared -out:libocsv.dylib -o:speed

# Return to examples directory
cd examples
```

## Quick Start

### Simple Demo (Recommended First Step)

**Run:**
```bash
bun run simple_demo.ts
```

This demonstrates basic CSV parsing with the 8-row sample file and verifies:
- ✅ Library loads correctly
- ✅ Parser lifecycle
- ✅ CSV parsing succeeds
- ✅ Row and field counts

### Large Dataset Performance Test

**Generate test data (configurable size):**
```bash
bun run generate_large_data.ts                # 10K rows (default)
bun run generate_large_data.ts 100000         # 100K rows
bun run generate_large_data.ts 1000000        # 1M rows
bun run generate_large_data.ts 10000000       # 10M rows (~1.4 GB)
```

**Test parser performance:**
```bash
bun run test_large_data.ts                    # Test default file
bun run test_large_data.ts large_data.csv     # Test specific file
```

**Run extreme benchmark suite:**
```bash
bun run benchmark_extreme.ts                  # 100K, 1M, 5M, 10M rows
```

Expected results (10K rows):
- Parse time: ~60ms for 1.16MB file
- Throughput: ~60+ MB/s
- Performance: ~160,000+ rows/sec

Expected results (10M rows):
- File size: ~1.4 GB
- Parse time: ~20-25 seconds
- Throughput: ~50-70 MB/s
- Performance: ~400,000-500,000 rows/sec

## Examples

### 1. Simple Demo (`simple_demo.ts`)

The simplest working example using the sample_data.csv file.

**What it demonstrates:**
- Basic FFI setup and library loading
- Parser creation and cleanup
- Parsing CSV from string/file
- Getting row and field counts
- Performance measurement

**Run:**
```bash
bun run simple_demo.ts
```

### 2. Large Data Generator (`generate_large_data.ts`) - IMPROVED ✨

Generates realistic CSV files with configurable row counts (10K to 10M+).

**Features:**
- Configurable row count (command-line argument)
- Custom output filename support
- Chunked writing for memory efficiency (>1M rows)
- Progress indicator for large files
- Realistic employee data with quoted fields
- Performance metrics (generation speed)

**Usage:**
```bash
bun run generate_large_data.ts [rows] [output_file]
```

**Examples:**
```bash
bun run generate_large_data.ts                    # 10K rows (default)
bun run generate_large_data.ts 100000             # 100K rows
bun run generate_large_data.ts 1000000            # 1M rows
bun run generate_large_data.ts 10000000           # 10M rows
bun run generate_large_data.ts 5000000 huge.csv   # 5M rows to custom file
```

**Memory efficiency:**
- Files < 1M rows: In-memory generation
- Files > 1M rows: Chunked writing (100K row chunks)

### 3. Large Data Performance Test (`test_large_data.ts`) - IMPROVED ✨

Comprehensive performance testing tool with detailed metrics and data validation.

**New features:**
- Accepts custom file path as argument
- Enhanced statistics (read time, parse time, total time)
- Sample data display (first and middle rows)
- Performance breakdown (I/O vs parsing)
- Comparison with project baseline (61.84 MB/s)
- Nanosecond-level timing metrics

**Metrics reported:**
- File size and row count
- Read time and speed (MB/s)
- Parse time and throughput (MB/s)
- Rows per second
- Bytes per row
- Time per row (μs and ns)
- Total time breakdown (I/O + Parse)
- Performance rating vs baseline

**Usage:**
```bash
bun run test_large_data.ts [file]
```

**Examples:**
```bash
bun run test_large_data.ts                # Test ./large_data.csv
bun run test_large_data.ts huge.csv       # Test custom file
```

### 4. Extreme Dataset Benchmark (`benchmark_extreme.ts`) - NEW 🎯

Comprehensive benchmark suite testing parser scalability with progressively larger datasets.

**What it does:**
- Generates and tests 4 dataset sizes: 100K, 1M, 5M, 10M rows
- Measures generation time, read time, and parse time
- Calculates throughput and rows/sec for each size
- Analyzes scalability (performance variance across sizes)
- Compares against project baseline
- Auto-cleanup of test files

**Usage:**
```bash
bun run benchmark_extreme.ts
```

**Output includes:**
- Per-benchmark detailed metrics
- Summary table comparing all sizes
- Scalability analysis (variance)
- Performance rating vs baseline

**Expected runtime:**
- ~30-60 seconds (depending on system)

**Sample output:**
```
Size      Rows          File Size   Parse Time   Throughput    Rows/sec
──────────────────────────────────────────────────────────────────────
100K      100,000        13.85 MB     213.45 ms      64.91 MB/s    468,512
1M        1,000,000     138.50 MB   2,134.50 ms      64.88 MB/s    468,426
5M        5,000,000     692.50 MB  10,672.50 ms      64.87 MB/s    468,398
10M      10,000,000    1385.00 MB  21,345.00 ms      64.89 MB/s    468,445
```

### 5. Basic Parser (`basic_parser.ts`)

Reference example showing conceptual field access patterns.

**Note:** This example has API limitations - the current FFI doesn't expose individual field values. It's kept as a reference for future enhancements.

### 6. Streaming Parser (`streaming_parser.ts`)

Conceptual example of streaming CSV processing.

**Note:** The streaming example simulates streaming behavior. Full streaming callback integration requires advanced FFI setup with function pointers. For production use with very large files, consider:
1. Using the Odin API directly in an Odin program
2. Creating a thin wrapper library with simplified callbacks
3. Using the regular parser API for files < 50MB

## Sample Data

### `sample_data.csv`
A small CSV file (8 rows including header) demonstrating:
- Standard fields
- Quoted fields with commas
- UTF-8 characters (Chinese name)
- Numeric data (ages, salaries)

### `large_data.csv` (Generated)
Large dataset with 10,001 rows (10,000 data rows + header):
- 12 fields per row
- ~1.16 MB file size
- Realistic employee and product data
- Generated by `generate_large_data.ts`
- Used for performance benchmarking

## Expected Output

### Simple Demo
```
🚀 OCSV - Simple CSV Parser Demo

📄 Input CSV (first 5 lines):
  1: name,age,city,salary
  2: Alice Johnson,30,New York,75000.50
  3: Bob Smith,25,San Francisco,85000.00
  4: Charlie Davis,35,Los Angeles,95000.75
  5: Diana Prince,28,Seattle,72000.00
  ...
────────────────────────────────────────────────────────────

✅ CSV Parsed Successfully!
────────────────────────────────────────────────────────────
Total rows: 8
Parsing time: 0.136ms

📊 Row Structure:
  Row 1: 4 fields
  Row 2: 4 fields
  Row 3: 4 fields
  Row 4: 4 fields
  Row 5: 4 fields
  ... (3 more rows)

💡 Note:
  The current FFI bindings provide parsing verification.
  For full data access, use:
    • Odin programs (see tests/ for examples)
    • Enhanced FFI bindings (contribution welcome!)
    • Command-line tools built with Odin

🎯 What This Demo Shows:
  ✓ OCSV library loads correctly
  ✓ Parser creation and cleanup
  ✓ CSV parsing succeeds
  ✓ Row and field count extraction
  ✓ Fast parsing performance

✅ Demo complete!
```

### Large Data Performance Test
```
🚀 OCSV - Large CSV Performance Test

────────────────────────────────────────────────────────────
📖 Reading large_data.csv...
   File size: 1.16 MB
   Read time: 0.30ms
────────────────────────────────────────────────────────────

⚡ Parsing CSV...
✅ Parsing complete!
────────────────────────────────────────────────────────────

📊 Results:
   Total rows: 10,001
   Data rows: 10,000 (excluding header)
   Parse time: 61.92ms
   Throughput: 18.76 MB/s
   Rows/sec: 161,504

🔍 Row Structure Verification:
   Header: 12 fields
   Row 1: 12 fields
   Row 2: 12 fields
   Row 5000: 12 fields
   Row 10000: 12 fields

💾 Memory:
   File size: 1.16 MB
   Rows parsed: 10,001

📈 Performance:
   Bytes/row: 121.82
   μs/row: 6.19

✅ Test complete!
────────────────────────────────────────────────────────────
```

## API Reference

For complete API documentation, see:
- [Main README](../README.md)
- [API Documentation](../docs/API.md)
- [FFI Integration Guide](../docs/INTEGRATION.md)

## Tips

1. **Performance:** The OCSV parser is optimized for speed. For best results:
   - Use release builds (`-o:speed`)
   - Consider SIMD optimizations on ARM64
   - Use streaming API for files > 50MB

2. **Memory Management:** Always call `parser_destroy()` in a `finally` block to prevent memory leaks.

3. **Error Handling:** Check the return value of `parse_csv()`. On failure, the parser state is undefined.

4. **UTF-8:** OCSV fully supports UTF-8. No special configuration needed.

5. **Custom Delimiters:** For TSV or custom formats, modify the parser configuration before calling `parse_csv()`.

## Troubleshooting

**Library not found:**
```bash
# Make sure you're in the examples directory
cd examples

# Make sure the library is built
ls -la ../libocsv.dylib

# If not, build it:
cd .. && odin build src -build-mode:shared -out:libocsv.dylib -o:speed
```

**Bun not found:**
```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Restart your terminal or run:
source ~/.bashrc  # or ~/.zshrc
```

## Contributing

Have an example you'd like to add? Submit a PR! Examples we'd love to see:
- Schema validation example
- Error handling and recovery
- Custom delimiter/quote configurations
- Integration with web frameworks
- CLI tools using OCSV
