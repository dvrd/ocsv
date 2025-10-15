# PRP-16: SIMD Analysis - Root Cause Found

**Date:** October 15, 2025
**Priority:** 🔴 **CRITICAL**
**Impact:** **Potential 3-5x performance improvement**

---

## Executive Summary

**ROOT CAUSE IDENTIFIED:** The CSV parser is NOT using SIMD functions despite having a complete SIMD implementation. The parser uses byte-by-byte iteration (`for ch, i in data`) instead of calling the SIMD search functions.

**Impact:**
- Current: 27.62 MB/s (scalar byte-by-byte parsing)
- Expected with SIMD: 80-150 MB/s (3-5x improvement)
- **Potential gain: +200-400% performance**

---

## Problem Analysis

### What We Have

**SIMD Implementation** (`src/simd.odin`): ✅ **COMPLETE**
- `find_delimiter_simd()` - Find delimiter using 16-byte SIMD
- `find_quote_simd()` - Find quote character using SIMD
- `find_newline_simd()` - Find newline using SIMD
- `find_any_special_simd()` - Find any of delimiter/quote/newline in one pass
- ARM64 NEON implementation: ✅ Working
- x86_64 fallback: ✅ Scalar fallback implemented

**Parser Implementation** (`src/parser.odin`): ❌ **NOT USING SIMD**
```odin
// Current implementation (line 92)
for ch, i in data {
    // Byte-by-byte processing
    switch state {
    case .Field_Start:
        if ch_byte == parser.config.quote {
            // ...
        } else if ch_byte == parser.config.delimiter {
            // ...
        }
    }
}
```

**Problem**: Parser iterates character-by-character, checking every byte individually. This is the slowest possible approach.

---

## Why SIMD Isn't Being Used

Looking at the parser code (lines 86-218 in `src/parser.odin`):

1. **Main loop uses rune iteration** (line 92):
   ```odin
   for ch, i in data {
       // Processes one rune at a time
   }
   ```

2. **No calls to SIMD functions**:
   ```bash
   $ grep -r "find_.*_simd" src/parser.odin
   # Result: No matches
   ```

3. **SIMD functions are defined but never imported or called**

### Historical Context

The SIMD functions were likely created during Phase 0 (PRP-00 or earlier) but **never integrated into the actual parser**. They exist as standalone utilities but the parser was never refactored to use them.

**Evidence from PRP-15:**
- Documentation mentions "SIMD optimization (ARM NEON) specifically for this platform"
- Performance reported as 158 MB/s in some docs, 66.67 MB/s in Phase 0
- Current benchmarks show 27.62 MB/s

**Conclusion**: The "SIMD optimization" was partially implemented but never actually used in production code.

---

## Performance Impact Analysis

### Current Performance (Scalar)

**Byte-by-byte iteration**:
- Every byte requires:
  - Load byte from memory
  - Compare with delimiter (branch)
  - Compare with quote (branch)
  - Compare with newline (branch)
  - UTF-8 decode (for non-ASCII)
  - State machine transition (branch)

**Estimated cost per byte**: ~10-15 CPU cycles
**Throughput**: 27.62 MB/s (measured)

### Expected Performance with SIMD

**SIMD batch processing** (16 bytes at a time):
- Load 16 bytes in one instruction
- Compare all 16 bytes with delimiter (parallel)
- Compare all 16 bytes with quote (parallel)
- Compare all 16 bytes with newline (parallel)
- Find first match in ~5-10 cycles
- Jump to match position

**Estimated cost per batch**: ~10-15 CPU cycles for 16 bytes = 0.6-0.9 cycles/byte
**Expected throughput**: 80-150 MB/s (3-5x faster)

### Comparison Table

| Metric | Scalar (Current) | SIMD (Expected) | Improvement |
|--------|------------------|-----------------|-------------|
| Throughput | 27.62 MB/s | 80-150 MB/s | 3-5x |
| Cycles/byte | 10-15 | 0.6-0.9 | 10-16x |
| Branch mispredicts | High (every byte) | Low (only on matches) | 10x less |
| Cache efficiency | Poor (scattered access) | Excellent (sequential batches) | 3-5x better |

---

## Integration Strategy

### Challenge: State Machine Complexity

The parser uses a complex RFC 4180 state machine that handles:
- Quoted fields with embedded delimiters
- Escaped quotes (`""` → `"`)
- Multiline fields (newlines inside quotes)
- Comments
- Relaxed mode (RFC violations)

**Key insight**: SIMD can't handle all cases, but it can **skip over simple regions fast**.

### Hybrid Approach (Recommended)

**Use SIMD for fast skipping, scalar for state transitions**:

1. **Unquoted fields** (most common):
   - Use `find_any_special_simd()` to skip to next delimiter/quote/newline
   - Process 16 bytes at a time
   - Only drop to scalar when special character found
   - **Expected speedup**: 5-10x for simple CSVs

2. **Quoted fields**:
   - Use `find_quote_simd()` to skip to next quote
   - Handle `""` escapes with scalar (rare)
   - **Expected speedup**: 3-5x for quoted fields

3. **Field boundaries**:
   - Use scalar for state transitions (quote → delimiter, etc.)
   - SIMD skips between boundaries
   - **Overhead**: Minimal (only at field boundaries)

### Implementation Plan

#### Phase 1: Simple Fields Fast Path (Day 1-2)

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
        i = next_pos - 1 // Will be incremented by for loop

        // Handle found character
        if found_byte == parser.config.delimiter {
            emit_field(parser)
            state = .Field_Start
        } else if found_byte == '\n' {
            emit_field(parser)
            emit_row(parser)
            state = .Field_Start
        }
    } else {
        // No more special chars - rest of data is field content
        for j in i..<len(data) {
            append(&parser.field_buffer, data[j])
        }
        break
    }
```

**Expected gain**: 3-5x for simple CSVs (80-90% of use cases)

#### Phase 2: Quoted Fields Fast Path (Day 3-4)

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
    } else {
        // No closing quote found (error or end of data)
        // ... handle error
    }
```

**Expected gain**: 2-3x for quoted fields

#### Phase 3: Field Start Optimization (Day 5)

Optimize `.Field_Start` to detect empty fields:

```odin
case .Field_Start:
    // Check if next char is delimiter (empty field)
    if i + 1 < len(data) {
        next_char := data[i]
        if next_char == parser.config.delimiter {
            emit_empty_field(parser)
            continue
        } else if next_char == parser.config.quote {
            state = .In_Quoted_Field
            continue
        }
    }

    // Otherwise, start unquoted field
    state = .In_Field
    // Fall through to In_Field case (use SIMD there)
```

---

## Implementation Challenges

### Challenge 1: Rune vs Byte Iteration

**Current**: `for ch, i in data` iterates runes (UTF-8 decode)
**SIMD**: Requires `[]byte` slice, not `string`

**Solution**:
```odin
data_bytes := transmute([]byte)data
for i := 0; i < len(data_bytes); {
    // Use SIMD to find next special char
    // Jump i to that position
}
```

### Challenge 2: State Machine Control Flow

**Current**: Single loop with switch statement
**SIMD**: Needs to skip ahead, not sequential iteration

**Solution**:
- Change from `for-range` to `for i := 0; i < len` with manual increment
- SIMD functions return positions, so `i` can jump forward
- Keep state machine logic for transitions

### Challenge 3: UTF-8 Handling

**Current**: Rune iteration automatically decodes UTF-8
**SIMD**: Works on bytes, needs manual UTF-8 handling

**Solution**:
- Delimiters, quotes, newlines are always ASCII (< 128)
- SIMD searches for ASCII characters only
- For field content, copy bytes directly (UTF-8 intact)
- Only decode UTF-8 for display/validation (not in hot path)

### Challenge 4: Testing Compatibility

**Current**: 202/203 tests passing
**SIMD**: Must maintain exact same behavior

**Solution**:
- Incremental integration (one state at a time)
- Run full test suite after each change
- Compare output byte-by-byte with old implementation
- Add SIMD-specific tests (verify same results)

---

## Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SIMD breaks RFC compliance | Medium | High | Extensive testing, byte-by-byte output comparison |
| Performance doesn't improve | Low | Medium | Benchmark after each change, rollback if regression |
| UTF-8 handling bugs | Medium | High | Add UTF-8 specific tests, validate with CJK/emoji CSVs |
| State machine logic errors | Medium | High | Keep state machine logic unchanged, only add skipping |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Integration takes longer than expected | High | Low | Incremental approach, simple fields first |
| Test failures require debugging | Medium | Medium | Run tests after each small change |
| Need to rewrite parser structure | Low | High | Hybrid approach keeps existing structure |

---

## Expected Results

### Performance Targets (Revised)

**Before SIMD Integration**:
- Parser: 27.62 MB/s
- Writer: 18.05 MB/s

**After SIMD Integration** (Conservative):
- Parser: 80-100 MB/s (+190-260%)
- Writer: 18.05 MB/s (unchanged)

**After SIMD Integration** (Optimistic):
- Parser: 120-150 MB/s (+335-443%)
- Writer: 18.05 MB/s (unchanged)

**Stretch Goal** (Phase 0 parity):
- Parser: 160+ MB/s (+480%)
- Match or exceed Phase 0 reported 158 MB/s

### Benchmark Predictions

| Benchmark | Current | SIMD (Conservative) | SIMD (Optimistic) |
|-----------|---------|---------------------|-------------------|
| Tiny (100 rows) | 24.04 MB/s | 60 MB/s | 80 MB/s |
| Small (1K) | 25.63 MB/s | 80 MB/s | 120 MB/s |
| Medium (10K) | 26.99 MB/s | 90 MB/s | 140 MB/s |
| Large (100K) | 27.70 MB/s | 100 MB/s | 150 MB/s |
| **Average** | **27.62 MB/s** | **82.5 MB/s** | **122.5 MB/s** |
| **Improvement** | **Baseline** | **+199%** | **+343%** |

---

## Recommended Action Plan

### Immediate Next Steps (This Session)

1. **Create feature branch** for SIMD integration
2. **Implement Phase 1**: Simple fields fast path
3. **Run benchmarks**: Verify 2-3x improvement
4. **Run tests**: Ensure 202/203 still pass
5. **Commit & document**: Save progress

### Week 1 Plan (Updated)

**Day 1-2: Simple Fields SIMD** (This)
- [x] Identify root cause (DONE)
- [ ] Implement `.In_Field` SIMD fast path
- [ ] Benchmark improvement
- [ ] Verify tests pass

**Day 3-4: Quoted Fields SIMD**
- [ ] Implement `.In_Quoted_Field` SIMD fast path
- [ ] Benchmark improvement
- [ ] Verify tests pass

**Day 5-6: Optimization & Polish**
- [ ] Optimize `.Field_Start`
- [ ] Add UTF-8 boundary checks
- [ ] Performance tuning
- [ ] Documentation

**Day 7: Validation**
- [ ] Full benchmark suite
- [ ] Memory leak checks
- [ ] Cross-platform testing (CI/CD)
- [ ] Update PRP-16 results

---

## Success Criteria

### Must Have
- [ ] Parser: 80+ MB/s (+190%)
- [ ] 202/203 tests still passing
- [ ] Zero memory leaks
- [ ] Same RFC compliance

### Stretch Goals
- [ ] Parser: 120+ MB/s (+335%)
- [ ] Match Phase 0 performance (160 MB/s)
- [ ] Document SIMD techniques for community

---

## Conclusion

**ROOT CAUSE**: Parser never calls SIMD functions despite complete implementation.

**OPPORTUNITY**: Integrating SIMD can provide **3-5x performance improvement** with minimal risk. The SIMD functions already exist and are tested - we just need to call them from the parser.

**PRIORITY**: This is the **highest-impact optimization** in PRP-16. All other optimizations are secondary.

**NEXT ACTION**: Implement `.In_Field` SIMD fast path immediately.

---

**Last Updated:** October 15, 2025
**Author:** Claude Code (PRP-16 SIMD Investigation)
**Status:** 🔴 **CRITICAL FINDING** | 🚀 **READY TO IMPLEMENT**
