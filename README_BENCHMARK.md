# OCSV Lazy Mode Benchmark

## Quick Start

```bash
# 1. Generate test data (10M rows, ~662 MB)
bun examples/generate_data.js 10000000

# 2. Run benchmark
bun benchmark.js
```

## Expected Results

- **Parse Time:** ~5-6 seconds
- **Throughput:** 120-130 MB/s
- **Memory:** ~1.3 GB (includes CSV string in memory)
- **Random Access:** < 0.2ms

## Usage

The benchmark tests lazy mode performance with a large CSV file:
- Measures parse time and throughput
- Tests random access speed
- Validates memory usage
- Shows sample rows

Exit code: 0 on success, 1 on failure
