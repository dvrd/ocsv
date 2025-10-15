# PRP-16: Baseline Benchmark Results

**Date:** October 15, 2025
**Platform:** macOS 14 (Darwin arm64)
**Benchmark Tool:** `benchmarks/csv_benchmark.odin`
**Status:** ✅ **BASELINE ESTABLISHED**

---

## Executive Summary

Baseline benchmarks run on macOS ARM64 show **27.62 MB/s average parser throughput** and **18.05 MB/s writer throughput**. These results establish our starting point for PRP-16 optimizations.

**Key Findings:**
- Parser: Very consistent performance (27-28 MB/s) across all file sizes
- Writer: Variable performance (13-39 MB/s) depending on complexity
- Memory: Consistent 2.0-2.1x overhead across all tests
- Scaling: Excellent scaling from 100 rows to 200k rows

---

## Parser Benchmark Results

### Raw Data

| Benchmark | Rows | File Size | Parse Time | Rows/sec | MB/sec | Memory |
|-----------|------|-----------|------------|----------|---------|---------|
| Tiny (100 rows) | 100 | 6.7 KB | 0.27 ms | 364,964 | 24.04 | 0.01 MB |
| Small (1K rows) | 1,000 | 70.0 KB | 2.67 ms | 374,953 | 25.63 | 0.14 MB |
| Small (5K rows) | 5,000 | 365.2 KB | 13.36 ms | 374,251 | 26.70 | 0.71 MB |
| Medium (10K rows) | 10,000 | 1.50 MB | 55.40 ms | 180,496 | 26.99 | 2.99 MB |
| Medium (25K rows) | 25,000 | 3.86 MB | 140.41 ms | 178,046 | 27.49 | 7.72 MB |
| Medium (50K rows) | 50,000 | 7.84 MB | 286.80 ms | 174,338 | 27.34 | 15.68 MB |
| Large (100K rows) | 100,000 | 15.80 MB | 570.63 ms | 175,244 | 27.70 | 31.61 MB |
| Large (200K rows) | 200,000 | 32.39 MB | 1169.06 ms | 171,078 | 27.70 | 64.78 MB |

### Summary

**Total Rows Processed:** 391,100
**Total Data Processed:** 61.82 MB
**Total Parse Time:** 2,238.60 ms
**Average Throughput:** 27.62 MB/s

### Analysis

1. **Throughput Consistency**:
   - Small files (< 1K rows): 24-26 MB/s
   - Medium files (10-50K rows): 27-27.5 MB/s
   - Large files (100-200K rows): 27.7 MB/s
   - **Conclusion**: Performance is very stable across file sizes

2. **Memory Overhead**:
   - 100 rows: 0.01 MB (2.1x overhead for 6.7 KB)
   - 1K rows: 0.14 MB (2.0x overhead for 70 KB)
   - 100K rows: 31.61 MB (2.0x overhead for 15.8 MB)
   - 200K rows: 64.78 MB (2.0x overhead for 32.4 MB)
   - **Conclusion**: Consistent ~2x memory usage

3. **Small File Performance**:
   - Tiny (100 rows) shows 24 MB/s vs 27.7 MB/s for large files
   - 13% slower for tiny files (setup overhead)
   - **Opportunity**: Optimize parser initialization for small files

4. **Rows/sec Analysis**:
   - Tiny: 365k rows/sec (5 cols = 1.8M fields/sec)
   - Large: 171k rows/sec (10 cols = 1.7M fields/sec)
   - **Conclusion**: Field processing rate is consistent (~1.7-1.8M fields/sec)

---

## Writer Benchmark Results

### Raw Data

| Benchmark | Rows | File Size | Write Time | Rows/sec | MB/sec |
|-----------|------|-----------|------------|----------|---------|
| Write Simple (1K) | 1,000 | 58.1 KB | 4.28 ms | 233,863 | 13.27 |
| Write Simple (10K) | 10,000 | 1.23 MB | 86.14 ms | 116,093 | 14.27 |
| Write Simple (100K) | 100,000 | 13.25 MB | 871.91 ms | 114,691 | 15.19 |
| Write Quoted (1K) | 1,000 | 106.9 KB | 5.26 ms | 190,078 | 19.85 |
| Write Quoted (10K) | 10,000 | 2.18 MB | 103.80 ms | 96,340 | 21.03 |
| Write Escaped (1K) | 1,000 | 155.8 KB | 4.11 ms | 243,487 | 37.04 |
| Write Escaped (10K) | 10,000 | 3.14 MB | 79.65 ms | 125,543 | 39.38 |
| Write Mixed (1K) | 1,000 | 86.4 KB | 3.11 ms | 321,958 | 27.17 |
| Write Mixed (10K) | 10,000 | 1.91 MB | 66.01 ms | 151,499 | 28.88 |

### Summary

**Total Rows Generated:** 144,000
**Total Data Generated:** 22.10 MB
**Total Write Time:** 1,224.25 ms
**Average Throughput:** 18.05 MB/s

### Analysis

1. **Performance by Complexity**:
   - Simple writes: 13-15 MB/s (slowest)
   - Quoted writes: 20-21 MB/s (medium)
   - Mixed writes: 27-29 MB/s (fast)
   - Escaped writes: 37-39 MB/s (fastest)
   - **Surprising**: More complex writes are faster!

2. **Hypothesis for Escaped Performance**:
   - Escaped fields contain more data per row
   - Higher MB/sec but similar rows/sec (125k vs 115k simple)
   - Writer may be I/O bound, not CPU bound
   - More data per write call → better throughput

3. **Simple Write Issue**:
   - Simple writes are slowest (13-15 MB/s)
   - 233k rows/sec but only 13 MB/s
   - **Opportunity**: Optimize simple field writing (no quotes/escapes)

4. **Writer vs Parser Gap**:
   - Writer: 18.05 MB/s average
   - Parser: 27.62 MB/s average
   - **Gap**: Writer is 35% slower than parser
   - **Unusual**: Typically writing is faster than parsing
   - **Opportunity**: Significant optimization potential for writer

---

## Performance Targets (Revised)

### Original Targets (from PRP-16 spec)
- Parser: 158 MB/s → 180-200 MB/s (+15-25%)
- Writer: 177 MB/s → 200+ MB/s (+13%+)

**NOTE:** Original spec mentions 158 MB/s baseline, but current benchmarks show 27.62 MB/s. This discrepancy needs investigation.

**Possible Explanations:**
1. Different benchmark methodology (streaming vs full parse)
2. Different CSV file characteristics (simpler vs complex)
3. SIMD optimization regressed (ARM NEON not engaging?)
4. Memory allocator overhead increased

### Revised Targets (based on current baseline)

**Parser Optimization Goal:**
- Current: 27.62 MB/s
- Target: 35-40 MB/s (+25-45%)
- Stretch: 50+ MB/s (+80%)

**Writer Optimization Goal:**
- Current: 18.05 MB/s
- Target: 30-35 MB/s (+65-95%)
- Stretch: 40+ MB/s (+120%)

**Rationale for Higher Writer Target:**
- Writer is currently 35% slower than parser (unusual)
- Simple writes especially slow (13-15 MB/s)
- Higher optimization potential

---

## Bottleneck Hypotheses

### Parser Bottlenecks (Priority Order)

1. **State Machine Branching** (HIGH IMPACT)
   - Nested if/else chains in main parse loop
   - Character classification (delimiter, quote, newline checks)
   - **Evidence**: Consistent 27 MB/s regardless of file size suggests CPU-bound

2. **Memory Allocations** (HIGH IMPACT)
   - Dynamic array growth for field buffers
   - String cloning for every field
   - Row array allocations
   - **Evidence**: 2x memory overhead, small file overhead

3. **String Operations** (MEDIUM IMPACT)
   - `strings.clone()` for every field
   - UTF-8 encoding in `append_rune_to_buffer()`
   - **Evidence**: UTF-8 overhead for ASCII-heavy CSVs

4. **SIMD Not Engaging** (INVESTIGATE)
   - Expected 100+ MB/s with SIMD
   - Only seeing 27 MB/s
   - **Action**: Verify SIMD code paths are actually running

### Writer Bottlenecks (Priority Order)

1. **Simple Field Writing** (HIGH IMPACT)
   - Simple writes slowest (13-15 MB/s)
   - Should be fastest (no quotes/escapes needed)
   - **Evidence**: 233k rows/sec but only 13 MB/s

2. **Buffer Management** (HIGH IMPACT)
   - Multiple small writes vs batched writes
   - Possible buffer flush overhead
   - **Evidence**: Escaped writes much faster (39 MB/s)

3. **Quote/Escape Logic** (LOW IMPACT)
   - Actually faster than simple writes!
   - Not a bottleneck
   - **Evidence**: 37-39 MB/s for escaped writes

---

## Next Steps

### Immediate Actions (Day 1-2)

1. **Investigate SIMD Status** (HIGH PRIORITY)
   - Verify `find_byte_optimized()` is being called
   - Check if SIMD instructions are actually used
   - Compare with pure scalar implementation
   - **Expected**: If SIMD is broken, this could explain 100+ MB/s gap

2. **Profile Parser** (HIGH PRIORITY)
   - Add timing instrumentation to key functions:
     - `parse_csv()` state machine
     - `emit_field()` and `emit_row()`
     - `strings.clone()` calls
     - `append()` operations
   - Identify actual bottleneck (not assumptions)

3. **Profile Writer** (HIGH PRIORITY)
   - Investigate why simple writes are slowest
   - Check buffer flush behavior
   - Compare write call patterns (simple vs escaped)

### Week 1 Plan (Days 1-7)

**Day 1-2: Investigation & Profiling**
- [ ] Verify SIMD is working (or disabled)
- [ ] Add profiling instrumentation
- [ ] Run detailed profiling with different CSV patterns
- [ ] Create priority list based on actual bottlenecks

**Day 3-4: First Optimization**
- [ ] Implement highest-impact optimization
- [ ] Benchmark improvement
- [ ] Verify tests still pass (202/203)

**Day 5-7: Second Optimization**
- [ ] Implement second optimization
- [ ] Benchmark improvement
- [ ] Document findings

---

## Benchmark Environment

**Platform Details:**
- OS: macOS 14 (Darwin)
- Architecture: arm64 (Apple Silicon)
- Odin Version: dev-2025-01
- Compiler Flags: `-o:speed` (release optimization)
- Build Mode: Shared library (`.dylib`)

**Hardware:**
- CPU: Apple M-series (ARM64)
- Memory: Sufficient (no swapping observed)
- Storage: SSD (I/O not a bottleneck)

**Test Conditions:**
- Clean system (no background load)
- Warm cache (benchmarks run multiple times)
- Memory tracking disabled for benchmarks (overhead removed)

---

## Comparison with Phase 0 Results

**From PROJECT_ANALYSIS_SUMMARY.md (Phase 0):**
- Parser: 66.67 MB/s average (reported)
- Writer: Not reported

**Current Results:**
- Parser: 27.62 MB/s (-58% vs Phase 0)
- Writer: 18.05 MB/s (new baseline)

**Regression Analysis:**

The 58% performance drop from Phase 0 suggests:
1. **SIMD regression**: ARM NEON may not be engaging properly
2. **Test methodology change**: Different CSV files or benchmark approach
3. **Code changes**: Recent refactoring (cisv→ocsv rename) may have affected optimization
4. **Compiler flags**: Possible difference in build configuration

**Action Required:**
- Review Phase 0 benchmark methodology
- Verify SIMD implementation status
- Compare with Phase 0 codebase if regression is real

---

## Success Criteria

### Must Have (PRP-16 Completion)
- [ ] Parser: 35+ MB/s (+25%)
- [ ] Writer: 30+ MB/s (+65%)
- [ ] 202/203 tests still passing
- [ ] Zero memory leaks maintained
- [ ] Optimizations documented

### Stretch Goals
- [ ] Parser: 50+ MB/s (+80%)
- [ ] Writer: 40+ MB/s (+120%)
- [ ] Investigate and fix SIMD regression
- [ ] Match or exceed Phase 0 performance (66.67 MB/s)

---

## Conclusion

Baseline benchmarks establish **27.62 MB/s parser** and **18.05 MB/s writer** throughput on macOS ARM64. Key findings:

1. **Parser**: Very consistent performance, possibly CPU-bound in state machine
2. **Writer**: Variable performance with significant optimization potential
3. **SIMD**: Possible regression from Phase 0 (66.67 MB/s → 27.62 MB/s)
4. **Memory**: Stable 2x overhead across all file sizes

**Priority 1:** Investigate SIMD status - could explain 2.4x performance gap vs Phase 0.

---

**Last Updated:** October 15, 2025
**Author:** Claude Code (PRP-16 Baseline Analysis)
**Status:** ✅ BASELINE ESTABLISHED | 🔍 PROFILING PHASE NEXT
