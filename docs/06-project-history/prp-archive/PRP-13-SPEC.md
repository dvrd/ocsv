# PRP-13: SIMD Performance Optimization

**Status:** 📋 Planned
**Priority:** P1 (Critical)
**Duration:** 2-3 weeks
**Complexity:** High
**Risk:** Medium

---

## Executive Summary

Optimize SIMD implementation to achieve performance targets. Current SIMD performance is 5.30 MB/s on large files, significantly below the 60+ MB/s target and even slower than standard parser at 61.84 MB/s.

**Current Performance:**
- Standard parser: 61.84 MB/s average ✅
- SIMD parser: 5.30 MB/s (large files) ❌
- Target: 90-95% of C performance (65-95 MB/s)

**Critical Issue:** SIMD implementation is experimental and currently slower than non-SIMD code.

---

## Problem Statement

### Performance Gap

From test output:
```
=== Delimiter Performance Test ===
  comma: 1.75 MB/s
  semicolon: 5.55 MB/s
  tab: 9.44 MB/s
  pipe: 8.60 MB/s

Note: SIMD is experimental and not yet optimized
Target throughput: > 60 MB/s (after optimization)
⚠️  Performance below expectations - optimization needed
```

**Root Causes to Investigate:**
1. SIMD code path may have inefficient branching
2. SIMD functions not being used in hot paths
3. Data alignment issues causing fallback to scalar code
4. Odin's core:simd may not generate optimal ARM64/NEON code
5. Memory access patterns not SIMD-friendly

### Target Performance

Based on ACTION_PLAN.md:
- **Minimum:** 65 MB/s (90% of CISV's 71 MB/s baseline)
- **Goal:** 85-95 MB/s (90-95% of CISV's peak 104 MB/s)
- **Current:** 61.84 MB/s (below minimum when SIMD should boost this)

---

## Implementation Strategy

### Phase 1: Profiling & Analysis (3-4 days)

**Goal:** Understand why SIMD is slow

**Tasks:**
1. Profile SIMD parser with Instruments (macOS) or perf (Linux)
2. Compare instruction counts: SIMD vs standard
3. Analyze branch mispredictions
4. Check SIMD function call frequency
5. Verify SIMD instructions are actually being emitted

**Tools:**
- Xcode Instruments (Time Profiler)
- `odin build -microarch:native -show-timings`
- Custom instrumentation counters

**Deliverables:**
- Performance profile report
- Bottleneck identification
- Hypothesis document

---

### Phase 2: Quick Wins (2-3 days)

**Goal:** Low-hanging fruit optimizations

**Potential Quick Wins:**

**1. Verify SIMD Usage**
```odin
// Add counters to measure actual SIMD usage
SIMD_CALLS_COUNT := 0
SCALAR_FALLBACK_COUNT := 0

find_delimiter_simd :: proc(...) {
    SIMD_CALLS_COUNT += 1
    // ... implementation
}
```

**2. Check Data Alignment**
```odin
// Ensure data is aligned for SIMD loads
when size_of(#simd[16]u8) == 16 {
    // Use 16-byte alignment
    #assert(align_of(data) >= 16)
}
```

**3. Reduce Branch Mispredictions**
```odin
// Replace branches with branchless SIMD operations
// Before:
if ch == ',' || ch == '"' || ch == '\n' {
    // handle
}

// After (SIMD):
mask := simd_cmp_eq(chunk, comma) |
        simd_cmp_eq(chunk, quote) |
        simd_cmp_eq(chunk, newline)
first_match := simd_first_set_bit(mask)
```

---

### Phase 3: Core Optimization (5-7 days)

**Goal:** Optimize hot paths with SIMD

**Strategy Options:**

**Option A: Optimize Odin SIMD Code**
- Work within core:simd limitations
- Focus on ARM64/NEON specific optimizations
- Pros: Pure Odin, maintainable
- Cons: May not achieve full performance

**Option B: Foreign C with Hand-Tuned NEON**
```odin
foreign import neon_simd "neon_simd.a"

@(default_calling_convention="c")
foreign neon_simd {
    neon_find_delimiter :: proc(data: [^]u8, len: int, delim: u8) -> int ---
    neon_find_quote :: proc(data: [^]u8, len: int) -> int ---
}
```
- Write tight ARM64 NEON assembly or intrinsics
- Pros: Maximum performance
- Cons: More complex build, platform-specific

**Option C: Hybrid Approach** (Recommended)
- Use SIMD for simple, predictable cases
- Fall back to standard parser for complex cases
- Measure at runtime, choose best path

**Hot Paths to Optimize:**
1. Finding delimiters (80% of parse time estimated)
2. Finding quotes
3. Finding newlines
4. Validating UTF-8

---

### Phase 4: Advanced Techniques (3-5 days)

**Goal:** Squeeze out remaining performance

**Techniques:**

**1. SIMD String Scanning**
```odin
// Process 16 bytes at once
find_delimiter_simd :: proc(data: []u8, delim: u8) -> int {
    delim_vec := #simd[16]u8{delim, delim, ..., delim}

    i := 0
    for i + 16 <= len(data) {
        chunk := (cast([^]#simd[16]u8)&data[i])^
        eq := chunk == delim_vec
        mask := simd.to_bits(eq)

        if mask != 0 {
            return i + intrinsics.count_trailing_zeros(mask)
        }
        i += 16
    }

    // Handle remaining bytes
    for i < len(data) {
        if data[i] == delim do return i
        i += 1
    }
    return -1
}
```

**2. Parallel Field Parsing**
```odin
// Parse multiple fields simultaneously using SIMD
parse_fields_simd :: proc(row: string) -> []string {
    // Use SIMD to find all delimiters in one pass
    // Split string at all delimiter positions
    // Allocate slice of correct size upfront
}
```

**3. Prefetching**
```odin
// Prefetch next chunk while processing current
prefetch :: proc(addr: rawptr) {
    when ODIN_ARCH == .arm64 {
        intrinsics.prefetch_read_data(addr, locality=3)
    }
}
```

---

## Testing Strategy

### Performance Tests

**Benchmark Suite:**
```odin
SIMD_BENCHMARK_CONFIGS :: []Benchmark_Config{
    {name = "Simple CSV (SIMD)", rows = 10_000, use_simd = true},
    {name = "Simple CSV (Standard)", rows = 10_000, use_simd = false},
    {name = "Complex CSV (SIMD)", rows = 10_000, complexity = .High, use_simd = true},
    {name = "Complex CSV (Standard)", rows = 10_000, complexity = .High, use_simd = false},
}
```

**Comparison Metrics:**
- Throughput (MB/s)
- CPU cycles per byte
- Instructions per cycle
- Cache miss rate
- Branch misprediction rate

### Correctness Tests

**SIMD must match standard parser output:**
```odin
@(test)
test_simd_matches_standard :: proc(t: ^testing.T) {
    TEST_CASES :: []string{
        "simple,csv,data",
        "\"quoted, field\", normal",
        "multiline\nfield\nhere",
        // ... 50+ edge cases
    }

    for test_case in TEST_CASES {
        parser_simd := parser_create()
        parser_simd.config.use_simd = true
        defer parser_destroy(parser_simd)

        parser_std := parser_create()
        parser_std.config.use_simd = false
        defer parser_destroy(parser_std)

        ok_simd := parse_csv(parser_simd, test_case)
        ok_std := parse_csv(parser_std, test_case)

        testing.expect(t, ok_simd == ok_std)
        testing.expect(t, deep_equal(parser_simd.all_rows, parser_std.all_rows))
    }
}
```

---

## Success Criteria

### Must Have
- [ ] Throughput ≥65 MB/s on simple CSV (90% of C baseline)
- [ ] SIMD faster than standard parser for large files
- [ ] All 182 tests passing
- [ ] 0 memory leaks
- [ ] SIMD output matches standard parser exactly

### Should Have
- [ ] Throughput ≥85 MB/s on simple CSV
- [ ] Throughput ≥40 MB/s on complex CSV (quoted, multiline)
- [ ] Performance profile documented
- [ ] Optimization techniques documented

### Nice to Have
- [ ] Throughput ≥95 MB/s (matching C peak)
- [ ] Auto-selection of SIMD vs standard based on data
- [ ] Per-platform optimizations (ARM64, x86_64)

---

## Risk Mitigation

### High Risk: Cannot Achieve Target Performance

**Mitigation:**
- Set progressive targets: 50 MB/s → 65 MB/s → 85 MB/s
- If Odin SIMD insufficient, use foreign C/assembly
- If still insufficient, make SIMD optional, focus on standard parser

**Fallback Plan:**
- Optimize standard parser to 80+ MB/s
- Document SIMD as experimental/opt-in
- Revisit SIMD when Odin compiler improves

### Medium Risk: SIMD Breaks Edge Cases

**Mitigation:**
- Extensive testing with edge case suite
- Easy switch between SIMD and standard
- Guard SIMD paths with validation

---

## Metrics

### Performance Targets

| Workload | Before (MB/s) | Target (MB/s) | Stretch (MB/s) |
|----------|---------------|---------------|----------------|
| Simple CSV | 61.84 | 65+ | 90+ |
| SIMD Parser | 5.30 | 65+ | 90+ |
| Complex CSV | ~40 | 40+ | 60+ |
| Large Files (50MB+) | 64.93 | 70+ | 100+ |

### Quality Metrics

- Test pass rate: 100% (maintained)
- Memory leaks: 0 (maintained)
- Code coverage: ≥95% (maintained)

---

## Timeline

### Week 1: Analysis
- Days 1-2: Profiling and bottleneck identification
- Days 3-4: Quick wins implementation
- Day 5: Quick wins testing and validation

### Week 2: Core Optimization
- Days 1-3: Implement chosen strategy (A, B, or C)
- Days 4-5: Testing and validation

### Week 3: Advanced & Polish
- Days 1-2: Advanced techniques
- Days 3-4: Performance tuning
- Day 5: Documentation and final testing

**Total: 15 days (3 weeks)**

---

## Dependencies

**Requires:**
- PRP-12 (Code Quality) - recommended to complete first
- Profiling tools (Instruments on macOS)
- Benchmark suite (from PRP-12)

**Blocks:**
- Production deployment at scale
- Performance SLA commitments

---

## References

- ACTION_PLAN.md (PRP-05: ARM64/NEON SIMD)
- docs/PERFORMANCE.md
- Session analysis showing 5.30 MB/s SIMD performance
- Benchmark showing 61.84 MB/s standard performance

---

**Status:** 📋 Ready for Planning
**Next Action:** Complete PRP-12, then begin profiling

**Questions:**
1. Is 65 MB/s acceptable minimum or must reach 85+ MB/s?
2. Is foreign C acceptable or must be pure Odin?
3. Priority: Speed vs maintainability vs portability?
