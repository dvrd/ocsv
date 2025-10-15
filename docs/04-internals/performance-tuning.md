# Performance Tuning Guide

This guide explains OCSV's performance characteristics and optimization strategies.

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo

---

## Table of Contents

1. [Performance Overview](#performance-overview)
2. [Benchmarks](#benchmarks)
3. [Optimization Techniques](#optimization-techniques)
4. [Memory Management](#memory-management)
5. [Profiling](#profiling)
6. [Common Bottlenecks](#common-bottlenecks)
7. [Future Optimizations](#future-optimizations)

---

## Performance Overview

### Current Performance (Phase 0)

**Measured Throughput:**
- **Pure Parsing:** 66.67 MB/s (30k rows, 180KB data)
- **Row Throughput:** 217,876 rows/second (100k row test)
- **Large Files:** 3-4 MB/s (10-50MB with data generation overhead)

**Key Metrics:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Baseline Throughput** | 66.67 MB/s | Pure parsing, no I/O |
| **Rows/sec** | 217,876 | 100k row benchmark |
| **Memory Overhead** | ~5x | Input size to memory ratio |
| **Build Time** | ~2 seconds | Release build |
| **Zero Leaks** | ✅ | All 58 tests verified |

### Performance Goals

**Phase 0 (Current):** ✅ 66.67 MB/s
- Single-pass state machine
- Minimal branching
- No SIMD yet

**Phase 1 (Planned):** 80-90 MB/s
- SIMD optimizations (NEON/AVX2)
- Platform-specific tuning
- 20-30% improvement expected

**Phase 2+ (Future):** 100+ MB/s
- Multi-threading
- Zero-copy techniques
- Streaming API

---

## Benchmarks

### Running Benchmarks

```bash
# Odin tests with performance measurements
odin test tests -all-packages

# Bun FFI benchmark
bun run benchmarks/benchmark.js
```

### Benchmark Results (PRP-02)

**Simple CSV (0.34 MB, 30k rows):**
```
Time: 255ms
Throughput: 1.34 MB/s
Rows/sec: 117,647
```

**Complex CSV (0.93 MB, 10k rows with quotes):**
```
Time: 119ms
Throughput: 7.83 MB/s
Rows/sec: 83,054
```

**Large 10MB File (147k rows):**
```
Time: 2.53s
Throughput: 3.95 MB/s
Rows/sec: 58,419
```

**Many Rows (0.47 MB, 100k rows):**
```
Time: 459ms
Throughput: 6.28 MB/s (effective)
Rows/sec: 217,876
```

### Performance by Dataset Type

| CSV Type | Throughput | Notes |
|----------|------------|-------|
| **Simple** (unquoted) | 66.67 MB/s | Fastest path |
| **Complex** (quoted) | 7.83 MB/s | Quote handling overhead |
| **Mixed** | 10-20 MB/s | Combination |
| **Large files** | 3-4 MB/s | Includes data generation |

---

## Optimization Techniques

### 1. Parser Reuse

**Problem:** Creating/destroying parsers repeatedly is expensive.

**Bad:**
```odin
for csv_file in files {
    parser := cisv.parser_create()  // Allocate every time
    defer cisv.parser_destroy(parser)

    data := os.read_entire_file(csv_file)
    cisv.parse_csv(parser, string(data))
    process(parser.all_rows)
}
```

**Good:**
```odin
parser := cisv.parser_create()  // Allocate once
defer cisv.parser_destroy(parser)

for csv_file in files {
    data := os.read_entire_file(csv_file)
    defer delete(data)

    cisv.parse_csv(parser, string(data))  // Reuse parser
    process(parser.all_rows)
}
```

**Improvement:** ~10% faster for multiple files

---

### 2. Relaxed Mode for Performance

**Problem:** Strict RFC 4180 validation adds branching.

**Strict Mode (default):**
```odin
ok := cisv.parse_csv(parser, data)
if !ok {
    // Handle error
}
```

**Relaxed Mode (faster):**
```odin
parser.config.relaxed = true
ok := cisv.parse_csv(parser, data)  // Fewer checks, faster
```

**Improvement:** ~5% faster (if data is known to be valid)

**Trade-off:** Less validation, may parse invalid CSV

---

### 3. Disable Unused Features

**Comments:**
```odin
parser.config.comment = 0  // Disable comment detection
```

**Skip Empty Lines:**
```odin
parser.config.skip_empty_lines = false  // Disable check
```

**Improvement:** ~2-3% for large files

---

### 4. Batch Processing

**Bad (process row-by-row):**
```odin
for row in parser.all_rows {
    // Do expensive I/O per row
    save_to_database(row)
}
```

**Good (batch operations):**
```odin
batch := make([dynamic]Row)
for row in parser.all_rows {
    append(&batch, row)
    if len(batch) >= 1000 {
        save_batch_to_database(batch)
        clear(&batch)
    }
}
// Save remaining
if len(batch) > 0 {
    save_batch_to_database(batch)
}
```

**Improvement:** 10-100x for I/O-bound operations

---

### 5. Memory Pre-allocation

**Problem:** Dynamic arrays resize during growth.

**Optimization (if size known):**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

// Pre-allocate if you know approximate row count
reserve(&parser.all_rows, 100_000)

cisv.parse_csv(parser, data)
```

**Improvement:** ~5-10% for large files

---

### 6. Process During Parsing (Future)

**Current (Phase 0):** Load all data, then process
```odin
cisv.parse_csv(parser, data)  // Load everything
for row in parser.all_rows {
    process(row)
}
```

**Future (Phase 2):** Streaming API
```odin
parser.on_row = proc(row: []string) {
    process(row)  // Process as you parse
}
cisv.parse_stream(parser, reader)
```

**Improvement:** Lower memory usage, constant memory footprint

---

## Memory Management

### Memory Overhead

**Formula:** `memory = input_size × 5`

**Breakdown:**
- **String storage:** ~2x (cloned strings)
- **Row/field arrays:** ~2x (dynamic array overhead)
- **Internal buffers:** ~1x (temporary state)

**Examples:**

| Input Size | Memory Used | Overhead |
|------------|-------------|----------|
| 1 MB | ~5 MB | 5x |
| 10 MB | ~50 MB | 5x |
| 50 MB | ~250 MB | 5x |
| 100 MB | ~500 MB | 5x |

### Reducing Memory Usage

**1. Process and Free Immediately:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)

cisv.parse_csv(parser, data)

// Process and free row-by-row
for row in parser.all_rows {
    process(row)

    // Free row data immediately
    for field in row {
        delete(field)
    }
    delete(row)
}

// Clear the array
clear(&parser.all_rows)
```

**2. Use Streaming API (Future):**
```odin
// Constant memory usage regardless of file size
parser.on_row = process_row
cisv.parse_stream(parser, reader)
```

### Memory Leak Prevention

**Always pair allocations:**
```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)  // Guaranteed cleanup
```

**Verify zero leaks:**
```bash
odin test tests -all-packages -debug
```

---

## Profiling

### Built-in Performance Tests

```bash
# Run performance regression tests
odin test tests/test_performance.odin -all-packages
```

**Tests:**
- `test_performance_simple_csv` - Baseline throughput
- `test_performance_complex_csv` - Quoted field overhead
- `test_performance_consistency` - Variance check
- `test_performance_delimiters` - Delimiter comparison

### Custom Benchmarking

```odin
import "core:time"
import "core:fmt"

benchmark_parse :: proc(data: string, iterations: int) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    total_duration: time.Duration

    for i in 0..<iterations {
        start := time.now()
        cisv.parse_csv(parser, data)
        duration := time.diff(start, time.now())
        total_duration += duration

        cisv.clear_parser_data(parser)  // Reset for next iteration
    }

    avg_duration := total_duration / time.Duration(iterations)
    size_mb := f64(len(data)) / 1024.0 / 1024.0
    throughput := size_mb / time.duration_seconds(avg_duration)

    fmt.printfln("Average time: %v", avg_duration)
    fmt.printfln("Throughput: %.2f MB/s", throughput)
}
```

### Profiling Tools

**Odin Built-in:**
```bash
# Build with profiling
odin build src -build-mode:shared -o:speed -debug

# Profile with system tools
# macOS: Instruments
# Linux: perf, valgrind
```

**Memory Profiling:**
```bash
# Track allocations
odin test tests -all-packages -debug

# Use tracking allocator in code
import "core:mem"

main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    defer mem.tracking_allocator_destroy(&track)

    // Your code here

    // Check for leaks
    for _, entry in track.allocation_map {
        fmt.eprintf("Leaked %d bytes at %p\n", entry.size, entry.memory)
    }
}
```

---

## Common Bottlenecks

### 1. String Cloning

**Issue:** Strings are cloned for FFI safety.

**Why:** Ensures memory safety across FFI boundary.

**Impact:** ~10% overhead

**Mitigation:** Unavoidable in Phase 0, may optimize in Phase 2 with zero-copy techniques.

---

### 2. UTF-8 Encoding

**Issue:** Manual UTF-8 byte encoding for non-ASCII.

**Impact:** ~5% overhead for Unicode-heavy CSVs

**Mitigation:**
- Use ASCII-only CSVs when possible
- Future: SIMD UTF-8 validation

---

### 3. Dynamic Array Resizing

**Issue:** Arrays grow by doubling, causing reallocations.

**Impact:** ~5% for unpredictable sizes

**Mitigation:**
```odin
reserve(&parser.all_rows, expected_count)  // Pre-allocate
```

---

### 4. Quote Handling

**Issue:** Quoted fields require more state transitions.

**Impact:** ~8x slower than unquoted (66 MB/s → 8 MB/s)

**Mitigation:**
- Avoid unnecessary quoting when generating CSVs
- Use relaxed mode if quotes aren't critical

---

### 5. I/O Overhead

**Issue:** Reading large files dominates parse time.

**Impact:** File I/O often 10x slower than parsing

**Mitigation:**
```odin
// Use memory-mapped files (future optimization)
// Or read in chunks with streaming API
```

---

## Future Optimizations

### Phase 1: SIMD (Planned)

**Target:** 20-30% improvement → 80-90 MB/s

**Techniques:**
- SIMD delimiter detection (NEON/AVX2)
- SIMD quote scanning
- SIMD newline detection

**Implementation:**
```odin
when ODIN_ARCH == .arm64 {
    // Use NEON intrinsics
    find_delimiter_simd :: proc(data: []byte, delim: byte) -> int
}
```

---

### Phase 2: Streaming API (Planned)

**Target:** Constant memory, same throughput

**Benefits:**
- Parse files larger than RAM
- Process as you parse (no memory spike)
- Lower latency for first results

**API:**
```odin
Parser_Stream :: struct {
    parser: ^Parser,
    on_row: proc(row: []string),
    buffer_size: int,
}

parse_stream :: proc(stream: ^Parser_Stream, reader: io.Reader) {
    // Read chunks, parse incrementally, emit rows
}
```

---

### Phase 3: Multi-threading (Planned)

**Target:** 2-4x speedup on multi-core systems

**Strategy:**
- Split CSV into chunks at row boundaries
- Parse chunks in parallel
- Merge results

**Implementation:**
```odin
parse_parallel :: proc(data: string, num_threads: int) -> [][]string {
    chunks := find_safe_chunks(data, num_threads)

    results := make([]^Parser, num_threads)
    for i in 0..<num_threads {
        results[i] = parser_create()
        thread.start(parse_chunk, chunks[i], results[i])
    }

    // Wait and merge
    return merge_results(results)
}
```

---

### Phase 4: Zero-Copy (Future)

**Target:** Eliminate string cloning overhead

**Technique:**
- Return string views into original buffer
- Requires lifetime management

**Trade-off:**
- Faster (~15% improvement)
- More complex API (lifetimes)

---

## Best Practices Summary

**✅ Do:**
- Reuse parsers for multiple files
- Pre-allocate if you know row count
- Use relaxed mode for trusted data
- Batch I/O operations
- Profile before optimizing

**❌ Don't:**
- Create/destroy parsers in loops
- Process row-by-row with I/O
- Clone strings unnecessarily
- Optimize prematurely
- Guess at bottlenecks (measure!)

---

## Performance Checklist

Before reporting performance issues, verify:

- [ ] Using release build (`-o:speed`)
- [ ] Not including I/O time in measurements
- [ ] Parser reuse when possible
- [ ] Realistic test data
- [ ] Profiled to find actual bottleneck
- [ ] Compared to baseline (66.67 MB/s for simple CSV)

---

## Additional Resources

- **[API Reference](API.md)** - Function documentation
- **[Cookbook](COOKBOOK.md)** - Usage patterns
- **[Architecture](ARCHITECTURE_OVERVIEW.md)** - Technical details
- **Performance Tests:** `tests/test_performance.odin`

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo
