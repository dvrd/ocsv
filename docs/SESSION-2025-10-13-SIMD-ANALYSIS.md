# Session 2025-10-13: SIMD Implementation Analysis

## Executive Summary

**Status**: SIMD implementation delegated to standard parser
**Reason**: Manual SIMD had overhead issues (0.44-0.68x slower than standard)
**Outcome**: All 162 tests passing, 0 memory leaks
**Next Steps**: Implement true SIMD with hardware intrinsics

## Problem Analysis

### Original SIMD Implementation Issues

The initial SIMD implementation in `src/simd.odin` and `src/parser_simd.odin` had fundamental design flaws:

#### 1. **Pseudo-SIMD Operations** (src/simd.odin:14-65)

```odin
// PROBLEM: Loading SIMD vectors but not using vectorized operations
for i + 16 <= len(search_data) {
    // Load 16 bytes into SIMD vector
    chunk := simd.i8x16{
        i8(search_data[i+0]), i8(search_data[i+1]), ...
    }

    // BUT then comparing byte-by-byte in scalar loop!
    for j in 0..<16 {
        if search_data[i+j] == delim {
            return start + i + j
        }
    }
}
```

**Issue**: The code created SIMD vectors (`simd.i8x16`) but then compared bytes one-by-one in a scalar loop. This added overhead without any SIMD benefit.

**What it should do**: Use true vectorized compare operations that check all 16 bytes simultaneously, then use bit manipulation to find the first match.

#### 2. **Function Call Overhead** (src/parser_simd.odin)

```odin
// Every field requires multiple function calls:
next_pos, found_byte := find_any_special_simd(data_bytes, delim, quote, pos)
next_quote := find_quote_simd(data_bytes, quote, pos)
next_nl := find_newline_simd(data_bytes, pos)
```

**Issue**: The parser state machine called these functions repeatedly, adding overhead:
- Function call/return overhead
- Parameter passing
- Stack frame setup/teardown

**Comparison with standard parser**:
```odin
// Standard parser: ultra-efficient inline loop
for ch, i in data {
    // All operations inline, no function calls
    if ch_is_ascii && ch_byte == delimiter {
        // ...
    }
}
```

#### 3. **Manual Position Tracking**

```odin
// SIMD parser
for pos < len(data) {
    ch := rune(data[pos])
    // ... manual position handling
    pos += 1
}

vs

// Standard parser
for ch, i in data {
    // Odin handles position efficiently
}
```

**Issue**: Odin's `for ch, i in data` iterator is highly optimized by the compiler. Manual position tracking adds overhead.

### Performance Results

| Implementation | Time (ms) | Speedup | Status |
|----------------|-----------|---------|--------|
| Standard Parser | 408-512 | 1.00x (baseline) | ✅ Fast |
| Manual SIMD v1 | 1147 | 0.44x | ❌ Slower |
| Simplified SIMD | 730-798 | 0.56-0.64x | ❌ Still slower |
| Delegated to Standard | ~same | ~1.00x | ✅ Fixed |

Even after simplifications, the manual SIMD approach was consistently slower.

## Root Cause

The fundamental issue: **Odin's `core:simd` package doesn't expose low-level operations needed for efficient SIMD**.

What's needed for real SIMD:
1. Vectorized compare operations (`vcmp` in NEON, `_mm_cmpeq_epi8` in SSE)
2. Bitmask extraction from compare results
3. Count trailing zeros (CTZ) to find first match
4. Horizontal OR to check if any lanes matched

What Odin provides:
- Basic vector types (`i8x16`)
- High-level operations (limited)
- **Not enough for efficient byte scanning**

## Solution: Delegation

Implemented in `src/parser_simd.odin:14-19`:

```odin
parse_csv_simd :: proc(parser: ^Parser, data: string) -> bool {
    // TEMPORARY: Delegating to standard parser until true SIMD is implemented
    // The previous manual SIMD implementation had function call overhead
    // that made it slower than the standard parser's optimized loop
    return parse_csv(parser, data)
}
```

### Why This Works

1. **Correctness**: parse_csv is fully tested and RFC 4180 compliant
2. **Performance**: Standard parser is already fast (66.67 MB/s)
3. **No Regression**: 162/162 tests still passing
4. **Clear Path Forward**: Marked as experimental with TODO comments

## Future SIMD Implementation

To achieve the target 1.2-1.5x speedup, we need **true hardware SIMD**:

### Option 1: Native Intrinsics (Recommended)

Use platform-specific intrinsics via `foreign` blocks:

```odin
when ODIN_ARCH == .arm64 {
    foreign import "system:System"

    @(default_calling_convention="c")
    foreign System {
        // ARM NEON intrinsics
        vld1q_u8 :: proc(ptr: ^u8) -> uint8x16_t ---
        vceqq_u8 :: proc(a, b: uint8x16_t) -> uint8x16_t ---
        vorrq_u8 :: proc(a, b: uint8x16_t) -> uint8x16_t ---
        // ... etc
    }
}
```

### Option 2: Inline Assembly

```odin
when ODIN_ARCH == .arm64 {
    find_delimiter_neon :: proc(data: []byte, delim: byte) -> int {
        // ARM NEON assembly
        // ld1 {v0.16b}, [x0]
        // dup v1.16b, w1
        // cmeq v2.16b, v0.16b, v1.16b
        // ...
    }
}
```

### Option 3: External C Library

Implement SIMD in C and link via FFI (most portable but adds complexity).

### Recommended Approach

**Hybrid Strategy**:
1. Keep standard parser as primary (already fast)
2. Add SIMD **only** for very large files (>10MB)
3. Use native intrinsics for hot paths:
   - Finding line boundaries (for parallel processing)
   - Skipping unquoted fields (bulk scanning)
   - NOT for the main state machine (too complex)

## Testing Impact

All tests passing with delegated implementation:

```bash
$ odin test tests -all-packages -o:speed
Finished 162 tests in 30.406s. All tests were successful.
```

SIMD-specific tests still work because parse_csv_simd now calls parse_csv:
- ✅ test_simd_parser_simple
- ✅ test_simd_parser_quoted_fields
- ✅ test_simd_parser_nested_quotes
- ✅ test_simd_parser_multiline_field
- ⚠️ test_simd_vs_standard_performance (informational, not failing)
- ⚠️ test_simd_large_file_performance (informational, not failing)

## Lessons Learned

1. **Don't assume SIMD is faster**: Overhead can outweigh benefits
2. **Profile first**: The standard parser's `for ch, i in data` loop is already well-optimized by LLVM
3. **Compiler auto-vectorization**: Modern compilers can sometimes vectorize simple loops automatically
4. **Odin's limits**: core:simd is high-level; real performance needs intrinsics
5. **Simplicity wins**: Standard parser is simpler, faster, and more maintainable

## Files Modified

1. **src/simd.odin** - Simplified to compiler-optimizable loops
2. **src/parser_simd.odin** - Delegated to parse_csv
3. **docs/SESSION-2025-10-13-FIXES.md** - Documented testing improvements
4. **docs/SESSION-2025-10-13-SIMD-ANALYSIS.md** - This document

## Performance Baselines (Unchanged)

Standard parser performance maintained:
- Simple CSV: 4.97 MB/s (-o:speed)
- Large 10MB: 3.17 MB/s
- Large 50MB: 2.60 MB/s
- Consistency: <250% variance

## Recommendations

### Short Term (Phase 1)
- ✅ Keep SIMD delegated to standard parser
- ✅ Focus on parallel processing (already implemented)
- ✅ Document SIMD as experimental/future work

### Medium Term (Phase 2-3)
- Investigate LLVM auto-vectorization (check assembly output)
- Profile to find real bottlenecks (may not be parsing)
- Consider SIMD for line-boundary finding only

### Long Term (Phase 4+)
- Implement true SIMD with NEON/AVX2 intrinsics
- Target: 1.2-1.5x speedup on files >10MB
- Maintain standard parser for small files (<1MB)

## References

- Original SIMD code (pre-simplification): git history
- Standard parser: `src/parser.odin`
- Parallel processing (already optimized): `src/parallel.odin`
- Test results: `docs/SESSION-2025-10-13-FIXES.md`

---

**Status**: SIMD optimization deferred to Phase 4+
**Priority**: Low (standard parser already meets requirements)
**Risk**: None (delegating to tested code)
