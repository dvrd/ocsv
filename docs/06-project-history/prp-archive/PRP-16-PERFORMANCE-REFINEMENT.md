# PRP-16: Performance Refinement

**Date:** October 15, 2025
**Phase:** Phase 1
**Status:** 🚀 **STARTING**
**Duration:** 1-2 weeks
**Priority:** HIGH

---

## Executive Summary

PRP-16 focuses on **performance optimization through profiling and targeted improvements**. The goal is to increase parser throughput from **158 MB/s to 180-200 MB/s** (+15-25%) through non-SIMD optimizations that benefit all platforms.

**Current Baseline:**
- Parser: 157.79 MB/s (average across benchmarks)
- Writer: 176.50 MB/s (average across benchmarks)
- Memory Overhead: ~2x CSV size
- Test Pass Rate: 202/203 (99.5%)

**Target Goals:**
- Parser: 180-200 MB/s (+15-25%)
- Writer: 200+ MB/s (+13%+)
- Memory Overhead: ~1.5-1.8x (if possible)
- Test Pass Rate: Maintain 99%+

---

## Objectives

### Primary Goals
1. ✅ Profile parser to identify real bottlenecks (not assumptions)
2. ✅ Implement 3-5 targeted optimizations
3. ✅ Achieve 15%+ performance improvement overall
4. ✅ Maintain zero memory leaks
5. ✅ Maintain test pass rate (99%+)

### Secondary Goals
1. ⏳ Improve small file performance (< 1KB)
2. ⏳ Reduce memory overhead (2x → 1.5x)
3. ⏳ Optimize string operations
4. ⏳ Document optimization techniques

### Non-Goals
- ❌ SIMD optimizations (already done in PRP-13)
- ❌ Parallel processing (already done in PRP-10)
- ❌ Architectural changes (state machine stays as-is)

---

## Methodology

### Phase 1: Profiling (Day 1-2)
**Goal:** Identify actual bottlenecks through measurement

**Tools:**
- Odin's built-in profiler (`-debug`)
- Custom timing instrumentation
- Memory allocation tracking
- CPU flamegraphs (if available)

**Profiling Targets:**
1. **State machine branches** - Which states are hot?
2. **Memory allocations** - Where do we allocate most?
3. **String operations** - `strings.clone()`, concatenation
4. **Field buffer operations** - Append, resize, clear
5. **Row management** - Emit field, emit row

**CSV Test Files:**
- Small (< 1KB) - Overhead-dominated
- Medium (1-10 MB) - Typical use case
- Large (50-100 MB) - Throughput-dominated
- Wide rows (1000+ columns) - Field handling
- Many rows (100k+) - Row management

### Phase 2: Analysis (Day 3)
**Goal:** Prioritize optimizations by impact

**Questions to Answer:**
1. What percentage of time is spent in each function?
2. Which allocations happen most frequently?
3. Are there unnecessary branches in hot paths?
4. Can we use lookup tables for character classification?
5. Are string operations causing cache misses?

**Priority Matrix:**
```
High Impact, Low Effort → Do First
High Impact, High Effort → Do Second
Low Impact, Low Effort → Do If Time
Low Impact, High Effort → Skip
```

### Phase 3: Implementation (Day 4-10)
**Goal:** Implement optimizations incrementally

**Strategy:**
- One optimization at a time
- Benchmark after each change
- Revert if no improvement or regression
- Document findings

### Phase 4: Validation (Day 11-14)
**Goal:** Verify improvements and stability

**Validation Steps:**
1. Run full test suite (all 203 tests)
2. Run performance benchmarks
3. Check for memory leaks
4. Verify cross-platform compatibility
5. Update documentation

---

## Optimization Techniques (Candidates)

### 1. Lookup Table for Character Classification
**Current:** Multiple `if` checks for delimiters, quotes, newlines
**Proposed:** 256-byte lookup table for fast character classification

```odin
// Current approach
if c == config.delimiter || c == config.quote || c == '\n' || c == '\r' {
    // ...
}

// Optimized approach
Char_Class :: enum u8 {
    Normal,
    Delimiter,
    Quote,
    Newline,
    Carriage_Return,
}

char_table: [256]Char_Class

if char_table[c] != .Normal {
    // ...
}
```

**Expected Gain:** 5-10%
**Effort:** Low
**Risk:** Low

---

### 2. Branch Reduction in State Machine
**Current:** Nested if/else chains
**Proposed:** Switch statements or computed gotos (if Odin supports)

```odin
// Current
if state == .Field_Start {
    if c == quote {
        // ...
    } else if c == delimiter {
        // ...
    }
}

// Optimized
switch state {
case .Field_Start:
    switch c {
    case quote:
        // ...
    case delimiter:
        // ...
    }
}
```

**Expected Gain:** 5-10%
**Effort:** Medium
**Risk:** Medium (careful testing needed)

---

### 3. Preallocate Field Buffer
**Current:** Dynamic growth with frequent reallocs
**Proposed:** Preallocate based on average field size

```odin
// Current
field_buffer: [dynamic]u8

// Optimized
reserve(&field_buffer, 256) // Preallocate for typical field
```

**Expected Gain:** 5-15%
**Effort:** Low
**Risk:** Low (more memory usage)

---

### 4. String Interning for Repeated Values
**Current:** `strings.clone()` for every field
**Proposed:** Intern common strings (e.g., "true", "false", empty string)

```odin
String_Pool :: struct {
    empty: string,
    true_str: string,
    false_str: string,
    // Common values
}

// Check if field matches common value before cloning
if field == "true" {
    return pool.true_str
}
```

**Expected Gain:** 5-10% (dataset dependent)
**Effort:** Medium
**Risk:** Low

---

### 5. Fast Path for Simple CSVs
**Current:** Full state machine for all inputs
**Proposed:** Detect simple CSVs (no quotes, no escapes) and use fast path

```odin
// Check if CSV is "simple" (no quotes in first N bytes)
if is_simple_csv(data[0:min(len(data), 1024)]) {
    return parse_simple_fast(parser, data)
}
```

**Expected Gain:** 20-30% for simple files
**Effort:** High
**Risk:** Medium (must handle edge cases)

---

### 6. Reduce String Clones
**Current:** Clone every field string
**Proposed:** Use string slices where possible, arena allocator

```odin
// Current
field_str := strings.clone(string(field_buffer[:]))

// Optimized (arena allocator)
arena: mem.Arena
field_str := mem.arena_alloc(&arena, len(field_buffer))
copy(field_str, field_buffer[:])
```

**Expected Gain:** 10-20%
**Effort:** High
**Risk:** Medium (memory management complexity)

---

### 7. Inline Small Functions
**Current:** Function calls for small operations
**Proposed:** Inline hot functions

```odin
// Mark small functions for inlining
@(optimization_mode="speed")
append_byte :: #force_inline proc(buf: ^[dynamic]u8, b: byte) {
    append(buf, b)
}
```

**Expected Gain:** 2-5%
**Effort:** Low
**Risk:** Low

---

## Benchmarking Strategy

### Benchmark Suite
1. **Simple CSV** (30k rows, 3 columns) - 0.34 MB
2. **Complex CSV** (10k rows, 10 columns with quotes) - 0.93 MB
3. **Large 10MB** - 147k rows
4. **Large 50MB** - 738k rows
5. **Wide Row** (1000 columns) - 1 row
6. **Many Rows** (100k rows, 5 columns) - 0.47 MB

### Metrics to Track
- **Throughput (MB/s)** - Primary metric
- **Rows per second** - For row-heavy workloads
- **Memory allocations** - Count and total size
- **Peak memory usage** - Maximum RSS
- **Time per operation** - Microseconds per parse

### Baseline (Before Optimizations)
```
Simple CSV:    1.34 MB/s  (30k rows in 255ms)
Complex CSV:   7.83 MB/s  (10k rows in 119ms)
Large 10MB:    3.95 MB/s  (147k rows in 2.5s)
Large 50MB:    3.40 MB/s  (738k rows in 14.3s)
Wide Row:      N/A       (1 row, 1000 columns)
Many Rows:     217k rows/s (100k rows in 459ms)

Average:       157.79 MB/s (parser)
               176.50 MB/s (writer)
```

### Target (After Optimizations)
```
Simple CSV:    >1.5 MB/s  (+12%)
Complex CSV:   >9.0 MB/s  (+15%)
Large 10MB:    >4.5 MB/s  (+14%)
Large 50MB:    >4.0 MB/s  (+18%)
Many Rows:     >250k rows/s (+15%)

Average:       180-200 MB/s (+15-25%)
```

---

## Implementation Plan

### Week 1 (Days 1-7)

**Day 1-2: Profiling**
- [ ] Set up profiling infrastructure
- [ ] Create benchmark CSV files (small, medium, large, wide, many-rows)
- [ ] Run baseline profiling
- [ ] Identify top 5 bottlenecks
- [ ] Create priority list

**Day 3: Analysis**
- [ ] Analyze profiling results
- [ ] Estimate impact of each optimization
- [ ] Select 3-5 optimizations to implement
- [ ] Create implementation order

**Day 4-5: Optimization #1 (Highest Impact)**
- [ ] Implement first optimization
- [ ] Benchmark improvement
- [ ] Run tests to verify correctness
- [ ] Document findings

**Day 6-7: Optimization #2**
- [ ] Implement second optimization
- [ ] Benchmark improvement
- [ ] Run tests to verify correctness
- [ ] Document findings

### Week 2 (Days 8-14)

**Day 8-9: Optimization #3**
- [ ] Implement third optimization
- [ ] Benchmark improvement
- [ ] Run tests to verify correctness
- [ ] Document findings

**Day 10-11: Additional Optimizations (If Time)**
- [ ] Implement 4th/5th optimizations if targets not met
- [ ] Or polish and refine existing optimizations

**Day 12-13: Validation**
- [ ] Run full test suite (all 203 tests)
- [ ] Verify zero memory leaks
- [ ] Cross-platform testing (via CI/CD)
- [ ] Performance regression checks

**Day 14: Documentation**
- [ ] Update PRP-16 results document
- [ ] Update PERFORMANCE.md
- [ ] Add optimization notes to ARCHITECTURE_OVERVIEW.md
- [ ] Create blog post draft (optional)

---

## Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Optimizations cause regressions | Medium | High | Incremental approach, benchmark after each |
| Memory leaks introduced | Low | High | Run tracking allocator after each change |
| Test failures | Low | High | Run full suite after each optimization |
| Cross-platform issues | Low | Medium | Test on all platforms via CI/CD |
| Time estimates too optimistic | High | Low | Focus on high-impact optimizations first |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Profiling takes longer than expected | Medium | Low | Start with simple profiling, add detail later |
| Optimizations harder than expected | Medium | Medium | Have backup list of simpler optimizations |
| Target performance not reached | Low | Medium | Document actual improvements, adjust targets |

---

## Success Criteria

### Must Have (Phase 1 Completion)
- ✅ 10%+ overall performance improvement
- ✅ Zero new memory leaks
- ✅ 99%+ test pass rate maintained
- ✅ Cross-platform compatibility verified
- ✅ Optimizations documented

### Nice to Have (Stretch Goals)
- ⏳ 20%+ performance improvement
- ⏳ Small file performance 2x faster
- ⏳ Memory overhead reduced to 1.5x
- ⏳ Optimization guide written

### Future Work (Phase 2)
- ⏳ x86 SIMD implementation (SSE2/AVX2)
- ⏳ Zero-copy parsing (string views)
- ⏳ Streaming optimizations

---

## Deliverables

### Code Deliverables
- ✅ Optimized parser implementation
- ✅ Benchmark suite with before/after results
- ✅ Updated test suite (all passing)

### Documentation Deliverables
- ✅ PRP-16-RESULTS.md (detailed findings)
- ✅ PERFORMANCE.md updates
- ✅ Optimization techniques guide
- ✅ Profiling methodology documentation

### Performance Deliverables
- ✅ Baseline benchmarks
- ✅ Optimized benchmarks
- ✅ Performance comparison table
- ✅ Flamegraphs/profiling data

---

## Next Steps (Immediate)

1. **Create benchmark CSV files**
   - Generate representative test data
   - Small (1KB), Medium (1-10MB), Large (50-100MB)
   - Different characteristics (simple, complex, wide, many-rows)

2. **Set up profiling**
   - Add timing instrumentation to key functions
   - Create profiling harness
   - Establish baseline measurements

3. **Initial profiling run**
   - Profile all benchmarks
   - Identify top bottlenecks
   - Create optimization priority list

4. **Begin implementation**
   - Start with highest-impact, lowest-effort optimization
   - Measure improvement
   - Document findings

---

## Conclusion

PRP-16 aims to **boost parser performance by 15-25%** through systematic profiling and targeted optimizations. By focusing on real bottlenecks (not assumptions) and validating incrementally, we can achieve significant gains while maintaining correctness and cross-platform compatibility.

**Timeline:** 1-2 weeks
**Status:** READY TO START
**Next Action:** Create benchmark files and begin profiling

---

**Last Updated:** October 15, 2025
**Author:** Claude Code (PRP-16 Specification)
**Status:** 🚀 READY TO START
