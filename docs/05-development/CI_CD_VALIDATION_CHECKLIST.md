# CI/CD Validation Checklist

**Date:** October 14, 2025
**Phase:** Phase 1 - PRP-15
**Purpose:** Validate OCSV works correctly on all platforms via GitHub Actions

---

## Pre-Validation Information

### Repository Setup
- **CI/CD File:** `.github/workflows/ci.yml`
- **Platforms:** macOS-14 (ARM64), ubuntu-latest (x86_64), windows-2022 (x86_64)
- **Jobs:** build-and-test (macOS, Linux), build-windows, lint

### Local Baseline (macOS ARM64)
- **Tests:** 202/203 passing (99.5%)
- **Memory Leaks:** 0
- **Performance:** 157.79 MB/s parser, 176.50 MB/s writer
- **Known Issue:** `test_stress_concurrent_parsers` (extreme concurrency)

---

## Validation Checklist

### 1. GitHub Actions Access
- [ ] Navigate to repository on GitHub
- [ ] Go to "Actions" tab
- [ ] Locate most recent workflow runs
- [ ] Check run status (success/failure)

### 2. macOS Build & Test Job
**Expected:** ✅ All tests passing (or 202/203)

**Checks:**
- [ ] Job completed successfully
- [ ] Library built: `libcsv.dylib`
- [ ] Tests executed: `odin test tests -all-packages`
- [ ] Memory tracking tests passed: `odin test tests -all-packages -debug`
- [ ] Artifact uploaded: `ocsv-macOS-{sha}`

**Critical Metrics:**
- [ ] Test count: 203 tests
- [ ] Pass rate: ≥ 99%
- [ ] Memory leaks: 0
- [ ] Build time: < 15 minutes

**Known Issues to Verify:**
- [ ] `test_stress_concurrent_parsers` may fail (acceptable)

### 3. Linux Build & Test Job
**Expected:** ✅ All tests passing (or 202/203)

**Checks:**
- [ ] Job completed successfully
- [ ] Library built: `libcsv.so`
- [ ] Tests executed: `odin test tests -all-packages`
- [ ] Memory tracking tests passed: `odin test tests -all-packages -debug`
- [ ] Artifact uploaded: `ocsv-Linux-{sha}`

**Critical Metrics:**
- [ ] Test count: 203 tests
- [ ] Pass rate: ≥ 99%
- [ ] Memory leaks: 0
- [ ] Build time: < 15 minutes

**Platform-Specific Checks:**
- [ ] SIMD falls back to scalar (x86_64)
- [ ] Performance acceptable (≥ 140 MB/s)
- [ ] No Linux-specific errors

### 4. Windows Build & Test Job
**Expected:** ✅ All tests passing (or 202/203)

**Checks:**
- [ ] Job completed successfully
- [ ] Library built: `csv.dll`
- [ ] Tests executed: `odin test tests -all-packages`
- [ ] Memory tracking tests passed: `odin test tests -all-packages -debug`
- [ ] Artifact uploaded: `ocsv-Windows-{sha}`

**Critical Metrics:**
- [ ] Test count: 203 tests
- [ ] Pass rate: ≥ 99%
- [ ] Memory leaks: 0
- [ ] Build time: < 15 minutes

**Platform-Specific Checks:**
- [ ] SIMD falls back to scalar (x86_64)
- [ ] Performance acceptable (≥ 140 MB/s)
- [ ] No Windows-specific errors (CRLF, paths, etc.)

### 5. Lint Job
**Expected:** ✅ All checks passing

**Checks:**
- [ ] Job completed successfully
- [ ] `odin check src -all-packages` passed
- [ ] `odin check tests -all-packages` passed
- [ ] No syntax errors
- [ ] No type errors

---

## Failure Analysis

### Common Issues

#### 1. SIMD-Related Failures
**Symptoms:** Tests fail on x86_64 (Linux/Windows) but pass on ARM64 (macOS)

**Diagnosis:**
- Check if SIMD scalar fallback is working
- Look for `when ODIN_ARCH` compilation errors
- Verify `find_byte_scalar()` is being called

**Fix:**
- Review `src/simd.odin` architecture detection
- Ensure scalar fallback functions are correct
- Test locally with `-target:linux_amd64`

#### 2. Platform-Specific Test Failures
**Symptoms:** Specific tests fail on one platform only

**Diagnosis:**
- Check test output for platform differences
- Look for file path issues (Windows uses `\`)
- Check for line ending issues (CRLF vs LF)

**Fix:**
- Use platform-agnostic file paths
- Handle CRLF in parser (already done)
- Update tests if needed

#### 3. Memory Tracking Failures
**Symptoms:** Tests pass normally but fail with `-debug` flag

**Diagnosis:**
- Look for "bad free" errors
- Check for memory leaks
- Review allocator usage

**Fix:**
- Review memory management in failed tests
- Check for missing `defer delete()` or `defer parser_destroy()`
- Ensure proper cleanup in error paths

#### 4. Concurrency Failures
**Symptoms:** Thread-related tests fail

**Expected:** `test_stress_concurrent_parsers` may fail (known issue)

**Diagnosis:**
- Check if it's the known 100-thread test
- Verify other concurrency tests pass
- Check thread creation success rate

**Action:**
- Document if new concurrency issues found
- Update known issues section
- Consider reducing thread count if excessive

#### 5. Build Failures
**Symptoms:** Compilation errors, linker errors

**Diagnosis:**
- Check Odin version compatibility
- Look for missing dependencies
- Check for platform-specific syntax

**Fix:**
- Update CI to use compatible Odin version
- Add missing dependencies
- Fix platform-specific code

---

## Performance Validation

### Expected Performance (by Platform)

| Platform | Architecture | SIMD | Expected Parser | Expected Writer |
|----------|--------------|------|-----------------|-----------------|
| macOS    | ARM64        | NEON | 155-160 MB/s    | 175-180 MB/s    |
| Linux    | x86_64       | Scalar | 140-150 MB/s  | 160-170 MB/s    |
| Windows  | x86_64       | Scalar | 140-150 MB/s  | 160-170 MB/s    |

**Acceptance Criteria:**
- All platforms ≥ 65 MB/s (original target)
- x86_64 platforms within 10-15% of ARM64
- No severe regressions

### How to Check Performance
1. Look for performance test output in CI logs
2. Check `test_performance_*` test results
3. Look for throughput numbers (MB/s)
4. Compare against baseline

---

## Documentation Updates Needed

### After Successful Validation

1. **README.md**
   - [x] Update platform support status
   - [ ] Add Linux test badge
   - [ ] Add Windows test badge
   - [ ] Document platform-specific notes

2. **PRP-15-CROSS-PLATFORM-VALIDATION.md**
   - [ ] Mark as COMPLETE
   - [ ] Add CI/CD test results
   - [ ] Document platform-specific findings
   - [ ] Update completion date

3. **PHASE_1_PROGRESS.md**
   - [ ] Update PRP-15 status to 100%
   - [ ] Add cross-platform metrics
   - [ ] Update overall progress (20% → 30%)

4. **PERFORMANCE.md**
   - [ ] Add cross-platform benchmarks
   - [ ] Document SIMD vs scalar performance
   - [ ] Add platform-specific notes

### After Failures (if any)

1. **PRP-15-CROSS-PLATFORM-VALIDATION.md**
   - [ ] Document failures
   - [ ] Add troubleshooting section
   - [ ] Update known issues

2. **GitHub Issue**
   - [ ] Create issue for each failure
   - [ ] Link to CI run
   - [ ] Assign priority

---

## Decision Tree

```
Start CI/CD Validation
         |
         v
   Check Latest Run
         |
    ┌────┴────┐
    |         |
  Pass      Fail
    |         |
    v         v
 All 3?   Which one?
    |         |
   Yes    ┌───┴───┐
    |     |       |
    v    Mac  Linux/Win
Complete  |       |
 PRP-15   v       v
        Debug   Debug
          |       |
          v       v
        Fix    SIMD?
          |       |
          v       v
       Re-run  Platform?
                 |
                 v
              Re-run
```

---

## Success Criteria

### Minimum (Phase 1 Unblocked)
- [x] macOS: 202/203 tests passing ✅
- [ ] Linux: 200/203 tests passing (98%+)
- [ ] Windows: 200/203 tests passing (98%+)
- [ ] All platforms: 0 memory leaks
- [ ] All platforms: ≥ 65 MB/s performance

### Ideal (Ready for Release)
- [ ] macOS: 202/203 tests passing
- [ ] Linux: 202/203 tests passing
- [ ] Windows: 202/203 tests passing
- [ ] All platforms: 0 memory leaks
- [ ] All platforms: Performance documented

### Stretch (Excellence)
- [ ] All platforms: 203/203 tests passing (100%)
- [ ] All platforms: Performance within 10% of macOS
- [ ] Zero platform-specific workarounds needed

---

## Next Steps After Validation

### If All Pass (Success Path)
1. ✅ Mark PRP-15 as COMPLETE
2. 📝 Update all documentation
3. 🎉 Celebrate cross-platform success!
4. 🚀 Begin PRP-16 (Performance Refinement) or PRP-18 (Package Publishing)

### If Some Fail (Debug Path)
1. 📊 Analyze failures
2. 🔍 Reproduce locally (if possible)
3. 🛠️ Fix issues
4. ✅ Re-run CI
5. 📝 Document findings

### If Many Fail (Escalation Path)
1. ⚠️ Assess severity
2. 🤔 Consider reverting changes
3. 🔬 Deep investigation needed
4. 📅 Adjust Phase 1 timeline

---

## Commands to Run Locally (for debugging)

### Test on Different Architectures
```bash
# Test with x86_64 target (simulate Linux)
odin test tests -target:linux_amd64

# Test with Windows target
odin test tests -target:windows_amd64

# Check for platform-specific issues
odin check src -target:linux_amd64
odin check src -target:windows_amd64
```

### Performance Testing
```bash
# Run performance tests only
odin test tests -define:ODIN_TEST_NAMES=test_performance*

# Run with timing
time odin test tests
```

### Memory Testing
```bash
# Run with tracking allocator
odin test tests -debug

# Run stress tests
odin test tests -define:ODIN_TEST_NAMES=test_stress*
```

---

## Contact Information

**For CI/CD Issues:**
- Check `.github/workflows/ci.yml`
- Review GitHub Actions documentation
- Check Odin CI examples: https://github.com/odin-lang/Odin/tree/master/.github/workflows

**For Platform Issues:**
- Odin Discord: https://discord.gg/odin
- Odin GitHub Issues: https://github.com/odin-lang/Odin/issues

---

**Last Updated:** October 14, 2025
**Status:** Ready for validation
**Owner:** PRP-15 Cross-Platform Validation
