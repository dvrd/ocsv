# SIMD Optimization

**Last Updated:** 2025-10-15
**Status:** ✅ Implemented | ⚠️ Performance optimization ongoing

---

## Overview

OCSV includes SIMD (Single Instruction, Multiple Data) optimizations for high-performance CSV parsing on ARM64 (NEON) and x86_64 platforms. This document covers the implementation, performance characteristics, and integration strategy.

## Executive Summary

**Current Status:**
- ✅ SIMD implementation complete and functional
- ✅ All 189 tests passing with zero memory leaks
- ✅ Uses Odin's official SIMD API (`simd.lanes_eq`, `simd.select`, etc.)
- ⚠️ Performance: 0.87x (13% slower than scalar due to parser overhead)
- 🎯 Ongoing optimization to achieve 3-5x speedup target

**Key Metrics:**
- **Parser (current):** 27.62 MB/s - 61.84 MB/s (scalar baseline)
- **Writer:** 167-177 MB/s
- **SIMD functions:** Correct and tested
- **Target:** 80-150 MB/s (pending integration optimization)

---

## Implementation

### SIMD Functions Available

Located in `src/simd.odin`:

1. **`find_byte_optimized()`** - Find single byte using SIMD
   - Processes 16 bytes per iteration on ARM64 NEON
   - Falls back to scalar on unsupported platforms

2. **`find_delimiter_simd()`** - Fast delimiter search
3. **`find_quote_simd()`** - Fast quote character search
4. **`find_newline_simd()`** - Fast newline search
5. **`find_any_special_simd()`** - Find any of delimiter/quote/newline in one pass

### Core SIMD Pattern

```odin
// Load 16 bytes
chunk := intrinsics.unaligned_load(cast(^simd.u8x16)raw_data(search_data[i:]))

// Compare - returns vector of 0xFF where match, 0x00 where not
matches := simd.lanes_eq(chunk, target_vec)

// Check if any match
if simd.reduce_or(matches) > 0 {
    // Select indices where matched, sentinel where not
    sel := simd.select(matches, SCANNER_INDICES_128, SCANNER_SENTINEL_MIN_128)
    // Find first match
    off := simd.reduce_min(sel)
    return start + i + int(off)
}
```

### Key Odin SIMD APIs

Discovered from `core/bytes/bytes.odin` (official Odin examples):

1. **`simd.lanes_eq(a, b)`** - Element-wise comparison → returns `simd.u8xN` (not bool!)
2. **`simd.reduce_or(v)`** - Quick check if any lane matched
3. **`simd.select(mask, a, b)`** - Choose values based on mask
4. **`simd.reduce_min(v)` / `reduce_max(v)`** - Find first/last match index
5. **`intrinsics.unaligned_load()`** - Load without alignment requirements

**Important:** Odin's SIMD uses element-wise operations that return vectors, not booleans. This is different from C++ SIMD patterns.

---

## Investigation History

### Attempt 1: High-Level SIMD API (Failed)

Initial attempts used Odin's high-level `#simd` vectors with `==` operator:

```odin
chunk := #simd[16]u8{ ... }
target_vec := #simd[16]u8{ ... }
matches := chunk == target_vec  // ❌ Returns scalar bool, not vector!
```

**Result:** Compilation errors. The `==` operator checks if ALL elements match, not element-wise comparison.

### Attempt 2: Official Odin Examples (Success)

After reviewing `core/bytes/bytes.odin`, discovered the correct pattern using `simd.lanes_eq()`:

```odin
matches := simd.lanes_eq(chunk, target_vec)  // ✅ Returns u8x16
if simd.reduce_or(matches) > 0 {
    sel := simd.select(matches, SCANNER_INDICES_128, SCANNER_SENTINEL_MIN_128)
    off := simd.reduce_min(sel)
    return start + i + int(off)
}
```

**Result:** ✅ All tests pass, SIMD functionality verified.

### Current Challenge: Parser Integration

**Root Cause:** Parser uses byte-by-byte iteration (`for ch, i in data`) instead of calling SIMD functions.

**Evidence:**
```bash
$ grep -r "find_.*_simd" src/parser.odin
# Result: No matches - SIMD functions never called!
```

The SIMD functions exist and work, but the main parser in `src/parser.odin` doesn't use them. This explains why performance hasn't improved despite having a working SIMD implementation.

---

## Performance Analysis

### Why SIMD Is Currently Slower

Despite correct implementation, SIMD shows 0.87x performance (13% slower) in standalone tests:

**Benchmark Results:**
```
Standard parser: 693.66 ms
SIMD parser:     800.54 ms
Speedup:         0.87x (slower)
```

**Possible Reasons:**

1. **Parser overhead dominates** - CSV parsing involves state machine logic, memory allocation, string copying, not just byte search
2. **Branch misprediction** - SIMD check `if simd.reduce_or(matches) > 0` may have poor prediction when matches are sparse
3. **Multiple comparisons cost** - `find_any_special_optimized()` does 3 separate `lanes_eq()` calls + OR, vs. tight scalar loop
4. **Small chunk size** - 16-byte chunks have high loop overhead; `core/bytes` uses 64-128 byte chunks
5. **Not integrated into parser** - SIMD functions tested standalone, not in actual parser hot path

### Expected Performance with Integration

Once SIMD is properly integrated into the parser state machine:

| Metric | Current (Scalar) | SIMD (Conservative) | SIMD (Optimistic) |
|--------|------------------|---------------------|-------------------|
| Throughput | 27.62 MB/s | 80-100 MB/s | 120-150 MB/s |
| Improvement | Baseline | +190-260% | +335-443% |
| Cycles/byte | 10-15 | 2-4 | 1-2 |

**Key Insight:** SIMD can skip over simple regions fast (unquoted fields), even if state machine overhead prevents full 16x speedup.

---

## Integration Strategy

### Hybrid Approach (Recommended)

**Use SIMD for fast skipping, scalar for state transitions:**

#### Phase 1: Simple Fields Fast Path

Add SIMD to `.In_Field` state (unquoted fields):

```odin
case .In_Field:
    // Fast path: find next delimiter/newline with SIMD
    next_pos, found_byte := find_any_special_simd(
        transmute([]byte)data,
        parser.config.delimiter,
        '\n',
        i
    )

    if next_pos != -1 {
        // Copy bytes from i to next_pos to field buffer
        for j in i..<next_pos {
            append(&parser.field_buffer, data[j])
        }
        i = next_pos - 1  // Will be incremented by for loop

        // Handle found character with state machine
        if found_byte == parser.config.delimiter {
            emit_field(parser)
            state = .Field_Start
        }
    }
```

**Expected gain:** 3-5x for simple CSVs (80-90% of use cases)

#### Phase 2: Quoted Fields Fast Path

Add SIMD to `.In_Quoted_Field` state:

```odin
case .In_Quoted_Field:
    // Fast path: skip to next quote with SIMD
    next_quote := find_quote_simd(
        transmute([]byte)data,
        parser.config.quote,
        i
    )

    if next_quote != -1 {
        // Copy everything from i to next_quote
        for j in i..<next_quote {
            append(&parser.field_buffer, data[j])
        }
        i = next_quote - 1
        state = .Quote_In_Quote
    }
```

**Expected gain:** 2-3x for quoted fields

---

## Implementation Challenges

### Challenge 1: Rune vs Byte Iteration

**Current:** `for ch, i in data` iterates runes (UTF-8 decode)
**SIMD:** Requires `[]byte` slice

**Solution:**
```odin
data_bytes := transmute([]byte)data
for i := 0; i < len(data_bytes); {
    // Use SIMD to find next special char
    // Jump i to that position
}
```

### Challenge 2: State Machine Control Flow

**Current:** Single loop with switch statement
**SIMD:** Needs to skip ahead, not sequential iteration

**Solution:**
- Change from `for-range` to `for i := 0; i < len` with manual increment
- SIMD functions return positions, so `i` can jump forward
- Keep state machine logic for transitions

### Challenge 3: UTF-8 Handling

**Current:** Rune iteration automatically decodes UTF-8
**SIMD:** Works on bytes

**Solution:**
- Delimiters, quotes, newlines are always ASCII (< 128)
- SIMD searches for ASCII characters only
- For field content, copy bytes directly (UTF-8 intact)
- Only decode UTF-8 for display/validation (not in hot path)

---

## Lessons Learned

1. **High-level SIMD abstractions have limits** - Odin's `#simd` is great for math but lacks low-level control for complex byte algorithms

2. **Official examples are essential** - `core/bytes/bytes.odin` showed the correct patterns (`lanes_eq`, `select`, `reduce_min`)

3. **Integration matters more than standalone functions** - Having SIMD functions isn't enough; they must be called in the hot path

4. **Profile before optimizing** - SIMD isn't always faster; parser overhead can dominate

5. **Hybrid approach works best** - Use SIMD for skipping, scalar for complex state transitions

---

## Comparison: OCSV vs core/bytes

**Why `core/bytes` SIMD works well:**
- Processes pure byte arrays (no parser overhead)
- Uses larger chunks (64-128 bytes with unrolling)
- Simple search patterns (single byte)
- Memory-bound workload benefits from vectorization

**Why OCSV SIMD is harder:**
- Interleaved with state machine logic
- Searches for 3 different characters simultaneously
- Context switches between byte search and field processing
- More compute-bound due to parser overhead

**Takeaway:** CSV parsing benefits less from SIMD than pure byte search, but 2-3x gains are still achievable.

---

## Current Recommendations

### Short-term (Active Work)

- ✅ Keep current SIMD implementation (correct and doesn't hurt)
- 🎯 **Priority:** Integrate SIMD into parser state machine (Phase 1-2 above)
- 📊 Profile the parser to find actual bottlenecks
- 🧪 Add SIMD-specific tests comparing output byte-by-byte

### Medium-term (After Integration)

- Try larger chunk sizes (32-64 bytes)
- Unroll loops like `core/bytes` does (`#unroll for j in 0..<4`)
- Reduce number of comparisons in `find_any_special`
- Optimize memory allocation patterns (field buffer)

### Long-term (Phase 2+)

- Consider AVX2 (256-bit) on x86_64 when available
- Parallel processing for multi-core systems
- Explore non-SIMD optimizations (branch reduction, lookup tables)
- Accept that CSV parsing isn't perfectly suited for SIMD

---

## References

- **Source Code:** `src/simd.odin`, `src/parser_simd.odin`
- **Tests:** `tests/test_performance.odin`, `tests/test_simd.odin`
- **Odin Examples:** `core/bytes/bytes.odin` (official SIMD patterns)
- **Historical Analysis:** `docs.backup-2025-10-15/SIMD_INVESTIGATION.md`
- **Root Cause Analysis:** `docs.backup-2025-10-15/PRP-16-SIMD-ANALYSIS.md`

---

## Success Criteria

### Must Have
- [ ] Parser uses SIMD functions in hot path
- [ ] 80+ MB/s throughput (+190% improvement)
- [ ] 202/203 tests still passing
- [ ] Zero memory leaks
- [ ] Same RFC 4180 compliance

### Stretch Goals
- [ ] 120+ MB/s throughput (+335% improvement)
- [ ] Match Phase 0 reported 158 MB/s
- [ ] Document SIMD techniques for Odin community

---

**Status:** Implementation complete, integration pending
**Next Action:** Integrate SIMD into parser state machine (`.In_Field` first)
**Expected Result:** 3-5x performance improvement for typical CSVs
