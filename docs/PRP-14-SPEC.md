# PRP-14: Enhanced Testing & Validation

**Status:** 📋 Planned
**Priority:** P2 (Medium-High)
**Duration:** 1-2 weeks
**Complexity:** Medium
**Risk:** Low

---

## Executive Summary

Expand test coverage to address identified gaps, add stress testing, concurrent access patterns, and improve test infrastructure.

**Current State:**
- ✅ 182 tests passing (100%)
- ✅ 0 memory leaks
- ✅ Excellent coverage of core functionality

**Gaps Identified:**
- ❌ No CSV writer tests
- ❌ No concurrent access tests
- ❌ Limited memory exhaustion tests
- ❌ No stress tests (24h continuous)
- ❌ Plugin lifecycle edge cases incomplete

**Target:** 200+ tests, >95% coverage maintained

---

## Problem Statement

### Current Test Coverage

**Well Covered:**
- ✅ Parser functionality (58 tests)
- ✅ Edge cases (25 tests)
- ✅ Integration workflows (13 tests)
- ✅ Schema validation (15 tests)
- ✅ Transforms (12 tests)
- ✅ Plugins (20 tests)
- ✅ Streaming (14 tests)
- ✅ Large files (6 tests)
- ✅ Performance (4 tests)

**Under Covered:**
- ❌ CSV writing (0 dedicated tests)
- ❌ Concurrent access (0 tests)
- ❌ Memory limits (1 basic test)
- ❌ Plugin failures (2 tests, need more)
- ❌ Error recovery edge cases (3 tests, need more)
- ❌ Platform-specific behavior (0 tests)

### Impact

**Without Enhanced Testing:**
- Writer bugs may slip into production
- Concurrent usage bugs discovered by users
- Memory issues under load
- Plugin ecosystem fragility

**With Enhanced Testing:**
- Confidence in all code paths
- Safe concurrent usage
- Predictable behavior under stress
- Robust plugin system

---

## Implementation Plan

### Task 1: CSV Writer Test Suite

**Duration:** 2-3 days

**Goal:** Comprehensive tests for writer.odin (currently untested)

**Test Categories:**

**1. Basic Writing**
```odin
@(test)
test_writer_simple :: proc(t: ^testing.T) {
    rows := [][]string{
        {"name", "age", "city"},
        {"Alice", "30", "NYC"},
        {"Bob", "25", "LA"},
    }

    output := write_csv(rows)
    defer delete(output)

    expected := "name,age,city\nAlice,30,NYC\nBob,25,LA\n"
    testing.expect_value(t, output, expected)
}
```

**2. Quoted Field Writing**
```odin
@(test)
test_writer_quoted_fields :: proc(t: ^testing.T) {
    rows := [][]string{
        {"field, with comma", "normal", "\"already quoted\""},
    }

    output := write_csv(rows)
    defer delete(output)

    // Should quote fields with commas, quotes, newlines
    testing.expect(t, strings.contains(output, "\"field, with comma\""))
}
```

**3. Edge Cases**
- Empty rows
- Empty fields
- Rows with different column counts (jagged)
- Very long fields (>10KB)
- Special characters (UTF-8, control chars)
- All delimiters (comma, tab, semicolon, pipe)

**4. Roundtrip Tests**
```odin
@(test)
test_write_parse_roundtrip :: proc(t: ^testing.T) {
    original_rows := [][]string{
        {"a", "b,c", "d\"e"},
        {"1", "2\n3", "4"},
    }

    // Write
    csv := write_csv(original_rows)
    defer delete(csv)

    // Parse
    parser := parser_create()
    defer parser_destroy(parser)
    ok := parse_csv(parser, csv)
    testing.expect(t, ok)

    // Verify roundtrip
    testing.expect(t, deep_equal(parser.all_rows, original_rows))
}
```

**Test Count:** ~15 new tests

---

### Task 2: Concurrent Access Tests

**Duration:** 3-4 days

**Goal:** Verify thread-safety and concurrent usage patterns

**Test Categories:**

**1. Parallel Parser Creation**
```odin
@(test)
test_concurrent_parser_creation :: proc(t: ^testing.T) {
    import "core:thread"

    NUM_THREADS :: 10
    threads := make([dynamic]^thread.Thread, 0, NUM_THREADS)
    defer delete(threads)

    worker :: proc(t: ^testing.T) {
        for i in 0..<100 {
            parser := parser_create()
            ok := parse_csv(parser, "a,b,c\n1,2,3\n")
            testing.expect(t, ok)
            parser_destroy(parser)
        }
    }

    for i in 0..<NUM_THREADS {
        th := thread.create(worker, t)
        thread.start(th)
        append(&threads, th)
    }

    for th in threads {
        thread.join(th)
    }
}
```

**2. Concurrent Parsing (Different Parsers)**
```odin
@(test)
test_concurrent_parsing_different_parsers :: proc(t: ^testing.T) {
    // Each thread uses its own parser - should be safe
    // Parse different CSV files simultaneously
}
```

**3. Concurrent Registry Access**
```odin
@(test)
test_concurrent_transform_registration :: proc(t: ^testing.T) {
    // Multiple threads registering/using transforms
    // Should detect race conditions
}
```

**4. Concurrent Plugin Access**
```odin
@(test)
test_concurrent_plugin_usage :: proc(t: ^testing.T) {
    // Multiple threads using same plugin simultaneously
    // Plugins should be stateless/thread-safe
}
```

**Test Count:** ~10 new tests

**Note:** May require atomic counters or race detectors

---

### Task 3: Memory Stress Tests

**Duration:** 2 days

**Goal:** Validate behavior under memory pressure

**Test Categories:**

**1. Large Field Limits**
```odin
@(test)
test_field_size_limit :: proc(t: ^testing.T) {
    // Create CSV with 1MB field
    large_field := strings.repeat("x", 1024 * 1024)
    defer delete(large_field)

    csv := fmt.tprintf("\"%s\"", large_field)

    parser := parser_create()
    defer parser_destroy(parser)

    ok := parse_csv(parser, csv)
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0][0]), len(large_field))
}
```

**2. Many Rows**
```odin
@(test)
test_million_rows :: proc(t: ^testing.T) {
    // Generate CSV with 1 million rows
    // Verify memory usage is reasonable
    // Should not exceed ~500MB for this workload
}
```

**3. Many Columns**
```odin
@(test)
test_thousand_columns :: proc(t: ^testing.T) {
    // CSV with 1000 columns
    // Verify parser handles wide rows
}
```

**4. Memory Limit Enforcement**
```odin
@(test)
test_max_row_size_enforcement :: proc(t: ^testing.T) {
    config := default_config()
    config.max_row_size = 1024 // 1KB limit

    parser := parser_create()
    parser.config = config
    defer parser_destroy(parser)

    // Try to parse row exceeding limit
    large_row := strings.repeat("x", 2048)
    defer delete(large_row)

    ok, err := parse_csv_safe(parser, large_row)
    testing.expect(t, !ok)
    testing.expect_value(t, err.code, .Max_Row_Size_Exceeded)
}
```

**Test Count:** ~8 new tests

---

### Task 4: Plugin Lifecycle Edge Cases

**Duration:** 2 days

**Goal:** Robust plugin system with graceful failure handling

**Test Categories:**

**1. Init Failure Handling**
```odin
@(test)
test_plugin_init_returns_false :: proc(t: ^testing.T) {
    // Plugin init returns false
    // Should not be registered
    // Registry should remain consistent
}

@(test)
test_plugin_init_panics :: proc(t: ^testing.T) {
    // Plugin init panics
    // Should be caught and logged
    // Should not crash registry
}
```

**2. Cleanup Failure Handling**
```odin
@(test)
test_plugin_cleanup_panics :: proc(t: ^testing.T) {
    // Plugin cleanup panics
    // Should continue cleaning up other plugins
    // Should not leak memory
}
```

**3. Transform Failure Handling**
```odin
@(test)
test_plugin_transform_panics :: proc(t: ^testing.T) {
    // Plugin transform panics during execution
    // Should be caught
    // Should not corrupt parser state
}
```

**4. Concurrent Plugin Registration**
```odin
@(test)
test_concurrent_plugin_registration :: proc(t: ^testing.T) {
    // Multiple threads registering plugins
    // Should be thread-safe or documented as not thread-safe
}
```

**Test Count:** ~8 new tests

---

### Task 5: Error Recovery Edge Cases

**Duration:** 1-2 days

**Goal:** Comprehensive error recovery testing

**Test Categories:**

**1. Partial Parse Recovery**
```odin
@(test)
test_error_recovery_skip_bad_rows :: proc(t: ^testing.T) {
    input := `good,row,1
bad"row,2
good,row,3`

    parser := parser_create()
    parser.config.recovery_mode = .Skip_Row
    defer parser_destroy(parser)

    ok := parse_csv(parser, input)
    testing.expect(t, ok) // Should succeed
    testing.expect_value(t, len(parser.all_rows), 2) // 2 good rows
}
```

**2. Error Context Accuracy**
```odin
@(test)
test_error_context_line_column :: proc(t: ^testing.T) {
    input := `line 1
line 2
line 3 with "error at col 15`

    parser := parser_create()
    defer parser_destroy(parser)

    ok, err := parse_csv_safe(parser, input)
    testing.expect(t, !ok)
    testing.expect_value(t, err.line, 3)
    testing.expect_value(t, err.column, 15)
}
```

**3. Multiple Errors**
```odin
@(test)
test_multiple_errors_reported :: proc(t: ^testing.T) {
    // CSV with 3 different error types
    // Verify all errors are collected (not just first)
}
```

**Test Count:** ~6 new tests

---

### Task 6: Stress & Endurance Tests

**Duration:** 2 days (setup) + 24h (run)

**Goal:** Validate stability under continuous load

**Test Categories:**

**1. 24-Hour Continuous Parsing**
```odin
@(test)
test_24h_continuous_parsing :: proc(t: ^testing.T) {
    start_time := time.now()
    duration := 24 * time.Hour
    iterations := 0

    for time.since(start_time) < duration {
        parser := parser_create()
        ok := parse_csv(parser, TEST_CSV_1MB)
        testing.expect(t, ok)
        parser_destroy(parser)

        iterations += 1

        if iterations % 1000 == 0 {
            fmt.println("Iterations:", iterations)
            // Check memory usage hasn't grown
        }
    }

    fmt.println("Total iterations:", iterations)
    // Should complete without crashes or leaks
}
```

**2. Rapid Create/Destroy Cycles**
```odin
@(test)
test_rapid_parser_churn :: proc(t: ^testing.T) {
    for i in 0..<1_000_000 {
        parser := parser_create()
        parser_destroy(parser)
    }
    // Should complete quickly
    // Should not leak memory
}
```

**3. Large File Streaming**
```odin
@(test)
test_stream_10gb_file :: proc(t: ^testing.T) {
    // Generate or use 10GB CSV file
    // Stream parse entire file
    // Verify memory usage stays constant (streaming)
}
```

**Test Count:** ~5 tests (but long-running)

---

## Testing Infrastructure Improvements

### 1. Test Organization

**Current:** All tests in `tests/` directory
**Proposed:** Organize by category

```
tests/
├── unit/
│   ├── test_parser.odin
│   ├── test_writer.odin
│   ├── test_transforms.odin
├── integration/
│   ├── test_workflows.odin
│   ├── test_roundtrip.odin
├── stress/
│   ├── test_memory.odin
│   ├── test_concurrency.odin
│   ├── test_endurance.odin
├── performance/
│   ├── test_benchmarks.odin
│   ├── test_regression.odin
└── test_data/
    ├── simple.csv
    ├── complex.csv
    └── large.csv
```

### 2. Test Utilities

**Create Helpers:**
```odin
// tests/test_utils.odin

// Compare parser results deeply
deep_equal_parsers :: proc(a, b: ^Parser) -> bool { ... }

// Generate test CSV with configurable complexity
generate_test_csv :: proc(config: Test_CSV_Config) -> string { ... }

// Measure memory usage
measure_memory_usage :: proc(fn: proc()) -> Memory_Stats { ... }

// Concurrent test helper
run_concurrent_test :: proc(workers: int, fn: proc(id: int)) { ... }
```

### 3. CI/CD Integration

**GitHub Actions Workflow:**
```yaml
name: OCSV Tests

on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        arch: [x64, arm64]

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v3
      - name: Install Odin
        run: ./scripts/install_odin.sh
      - name: Run Unit Tests
        run: odin test tests/unit -all-packages
      - name: Run Integration Tests
        run: odin test tests/integration -all-packages
      - name: Run Performance Tests
        run: odin test tests/performance -all-packages
      - name: Check Memory Leaks
        run: odin test tests -all-packages -define:USE_TRACKING_ALLOCATOR=true
```

---

## Success Criteria

### Must Have
- [ ] 200+ total tests passing
- [ ] Writer.odin has ≥90% test coverage
- [ ] Concurrent access tests passing
- [ ] 0 memory leaks (including stress tests)
- [ ] All tests pass on macOS ARM64

### Should Have
- [ ] Memory stress tests passing
- [ ] Plugin lifecycle edge cases covered
- [ ] Error recovery comprehensive
- [ ] 24-hour endurance test passes
- [ ] CI/CD running all test suites

### Nice to Have
- [ ] Tests pass on Linux x64
- [ ] Tests pass on Windows
- [ ] Performance regression tests automated
- [ ] Fuzz testing integrated

---

## Timeline

### Week 1
- Day 1-2: Writer tests (15 tests)
- Day 3-4: Concurrent access tests (10 tests)
- Day 5: Memory stress tests start (8 tests)

### Week 2
- Day 1: Memory stress tests complete
- Day 2-3: Plugin lifecycle tests (8 tests)
- Day 4: Error recovery tests (6 tests)
- Day 5: Stress test setup + infrastructure improvements

**Total:** 10 days (2 weeks) + 24h endurance run

---

## Metrics

### Test Coverage Target

| Module | Current Tests | Target Tests | Coverage |
|--------|---------------|--------------|----------|
| parser.odin | 58 | 60 | 95%+ |
| writer.odin | 0 | 15 | 90%+ |
| transform.odin | 12 | 15 | 95%+ |
| plugin.odin | 20 | 28 | 95%+ |
| schema.odin | 15 | 18 | 95%+ |
| error.odin | 8 | 14 | 95%+ |
| streaming.odin | 14 | 18 | 95%+ |
| **TOTAL** | **182** | **210+** | **95%+** |

---

## Dependencies

**Requires:**
- None (can start immediately)
- Can run parallel with PRP-12

**Blocks:**
- Production deployment confidence
- Concurrent usage documentation

**Related:**
- PRP-12 (memory patterns needed for stress tests)
- PRP-13 (performance tests validate optimizations)

---

## Risk Assessment

### Low Risk: Test Complexity

**Risk:** Concurrent tests may be flaky
- Mitigation: Use deterministic test patterns
- Mitigation: Run multiple times to verify stability
- Impact: Low (retries can handle flakiness)

### Medium Risk: Long-Running Tests

**Risk:** 24h tests delay CI/CD feedback
- Mitigation: Separate fast/slow test suites
- Mitigation: Run endurance tests nightly, not on every commit
- Impact: Medium (workflow adjustment needed)

---

## Future Work

After PRP-14:
1. Property-based testing (fuzzing)
2. Mutation testing (test quality validation)
3. Coverage-guided test generation
4. Cross-platform test expansion (Windows, Linux)

---

## References

- Current test suite: tests/*.odin
- Testing best practices: docs/CONTRIBUTING.md
- Test gaps identified in PRP-12 analysis

---

**Status:** 📋 Ready for Planning
**Next Action:** Can start immediately (parallel with PRP-12)

**Questions:**
1. Should endurance tests run in CI or separately?
2. Priority: Writer tests or concurrent tests first?
3. Is 200+ tests sufficient or target higher?
