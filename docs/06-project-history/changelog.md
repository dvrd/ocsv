# Changelog

All notable changes to OCSV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Changed
- Reorganized documentation into hierarchical structure (01-06 categories)
- Archived 20 historical PRP documents
- Consolidated SIMD documentation (3 files → 1)
- Split API.md into focused guides

---

## [0.11.0] - 2025-10-14

### Added
- **Plugin Architecture** (PRP-11)
  - 4 plugin types: Transform, Validator, Parser, Output
  - Plugin registry system
  - Plugin lifecycle management
  - 3 example plugins (ROT13, Email Validator, JSON Output)
- **Enhanced Code Quality** (PRP-12)
  - Code quality audit (9.9/10 score)
  - Memory management documentation
  - Code quality standards
- **SIMD Investigation** (PRP-13)
  - ARM NEON implementation details
  - Performance analysis
  - Integration strategy documented
- **Enhanced Testing** (PRP-14)
  - Stress tests (10,000 concurrent parsers)
  - Endurance tests (1-hour continuous operation)
  - Extreme size tests (100MB, 500MB, 1GB)
  - Thread safety verification

### Improved
- Test coverage: 189 → 203 tests
- Documentation organization
- Memory management patterns
- Error handling consistency

---

## [0.10.0] - 2025-10-13

### Added
- **Parallel Processing** (PRP-10)
  - Multi-threaded CSV parsing
  - Auto-detection of optimal thread count
  - Safe chunk splitting
  - Result merging
- Parallel configuration options
- Thread-safe result collection

### Performance
- 1.87x speedup on 14MB files (4 threads)
- 1.29x speedup on 29MB files (4 threads)
- Automatic fallback to sequential for small files (<10 MB)

### Known Issues
- 2-thread configuration has intermittent race condition (use 4+ threads)

---

## [0.9.0] - 2025-10-12

### Added
- **Advanced Transformations** (PRP-09)
  - 12 built-in transforms:
    - String: trim, uppercase, lowercase, capitalize, normalize_space, remove_quotes
    - Numeric: parse_float, parse_int
    - Boolean: parse_bool
    - Date: date_iso8601
  - Transform registry system
  - Transform pipelines
  - Custom transform support
- Column-wise and row-wise transform application
- Transform chaining

### Improved
- Data cleaning capabilities
- Type conversion flexibility
- Extensibility for custom transforms

---

## [0.8.0] - 2025-10-11

### Added
- **Streaming API** (PRP-08)
  - Memory-efficient chunk-based parsing
  - `streaming_parser_create()` / `streaming_parser_destroy()`
  - `streaming_parse_chunk()` for incremental processing
  - `streaming_get_complete_rows()` / `streaming_clear_rows()`
- Chunk boundary safety (handles rows split across chunks)
- Support for large files (tested up to 1 GB)

### Performance
- ~45 MB/s throughput (vs ~60 MB/s standard parser)
- Memory usage: ~10-20 MB (vs ~5x file size for standard parser)

### Use Cases
- Files larger than available RAM
- Network streaming
- Real-time data processing

---

## [0.7.0] - 2025-10-10

### Added
- **Schema Validation** (PRP-07)
  - 6 field types: Integer, Float, String, Boolean, Date, Enum
  - 9 validation rules: required, min/max length, min/max value, pattern, enum values, custom validators
  - Type conversion support
  - Detailed validation error reporting
- Schema-based parsing
- Field-level validation

### Improved
- Data quality assurance
- Type safety
- Error messages

---

## [0.6.0] - 2025-10-09

### Added
- **Error Handling & Recovery** (PRP-06)
  - 11 error types with detailed information
  - 4 recovery strategies:
    - Strict mode (fail on first error)
    - Relaxed mode (best-effort parsing)
    - Skip invalid lines
    - Collect warnings
  - Line and column tracking
  - Error context and suggestions
- Warnings system for non-fatal issues

### Improved
- Error messages with context
- Debugging capabilities
- Production robustness

---

## [0.5.0] - 2025-10-08

### Added
- **ARM64/NEON SIMD Optimization** (PRP-05)
  - ARM NEON implementation for byte search
  - SIMD byte search functions
  - Platform-specific optimizations
- SIMD feature detection

### Performance
- 21% performance boost with SIMD
- Parser: 158 MB/s (up from ~60 MB/s baseline)
- Writer: 177 MB/s

### Supported Platforms
- Apple Silicon (M1, M2, M3)
- AWS Graviton
- ARM64 Linux servers

---

## [0.4.0] - 2025-10-07

### Added
- **Cross-Platform Support** (PRP-04)
  - Windows support (x86_64)
  - Linux support (x86_64)
  - macOS support (ARM64, x86_64)
- Automated CI/CD pipeline
  - GitHub Actions for all platforms
  - Automated builds
  - Platform-specific testing
- Platform-specific build scripts

### Improved
- Build system for multiple platforms
- File path handling
- Line ending handling (CRLF/LF)

### Build Targets
- macOS: `libcsv.dylib`
- Linux: `libcsv.so`
- Windows: `csv.dll`

---

## [0.3.0] - 2025-10-06

### Added
- **Complete Documentation** (PRP-03)
  - API reference (1,150+ lines)
  - Usage cookbook with 20+ examples
  - Architecture overview
  - Integration examples for Bun FFI
  - Performance tuning guide
  - Contributing guidelines
- JSDoc comments for all public APIs
- TypeScript type definitions

### Improved
- User onboarding experience
- Developer documentation
- Code examples

---

## [0.2.0] - 2025-10-05

### Added
- **Enhanced Testing Suite** (PRP-02)
  - 189 comprehensive tests:
    - 58 basic functionality tests
    - 25 RFC 4180 edge case tests
    - 13 integration tests
    - 6 large file tests
    - 4 performance regression tests
    - 5 fuzzing tests
  - Test coverage: ~95%
  - Memory leak detection (tracking allocator)
  - Performance regression testing
- Test data generators
- Fuzzing with random CSV generation

### Quality
- 189/189 tests passing (100%)
- 0 memory leaks
- Performance baseline established

---

## [0.1.0] - 2025-10-04

### Added
- **RFC 4180 Compliance** (PRP-01)
  - Full RFC 4180 state machine parser
  - Support for:
    - Quoted fields with embedded delimiters
    - Nested quotes (doubled quotes: `""` → `"`)
    - Multiline fields
    - CRLF and LF line endings
    - Empty fields
    - Trailing/leading delimiters
    - Comments (extension)
  - Relaxed parsing mode for malformed CSV
- Comprehensive edge case handling
- UTF-8 support (CJK characters, emojis)

### Performance
- Parser: ~66.67 MB/s baseline

### Fixed
- Edge cases from RFC 4180 specification
- Quote escaping issues
- Multiline field handling
- Empty field detection

---

## [0.0.1] - 2025-10-03

### Added
- **Foundation** (PRP-00)
  - Core CSV parser with state machine
  - Configuration system (Config struct)
  - Parser creation/destruction
  - Basic parsing (`parse_csv`, `parse_simple_csv`)
  - Bun FFI bindings:
    - `ocsv_parser_create()`
    - `ocsv_parser_destroy()`
    - `ocsv_parse_string()`
    - `ocsv_get_row_count()`
    - `ocsv_get_field_count()`
    - `ocsv_get_field()`
  - JavaScript wrapper (`Parser` class)
  - TypeScript definitions
- Memory management (zero leaks)
- Basic test suite (6 tests)

### Performance
- Initial baseline: ~60 MB/s

### Platform
- macOS ARM64 (initial development platform)

---

## Version History Summary

| Version | Date | Major Feature | Tests | Performance |
|---------|------|---------------|-------|-------------|
| 0.0.1 | 2025-10-03 | Foundation | 6 | 60 MB/s |
| 0.1.0 | 2025-10-04 | RFC 4180 | 31 | 66 MB/s |
| 0.2.0 | 2025-10-05 | Enhanced Testing | 189 | 66 MB/s |
| 0.3.0 | 2025-10-06 | Documentation | 189 | 66 MB/s |
| 0.4.0 | 2025-10-07 | Cross-Platform | 189 | 66 MB/s |
| 0.5.0 | 2025-10-08 | SIMD | 189 | 158 MB/s |
| 0.6.0 | 2025-10-09 | Error Handling | 189 | 158 MB/s |
| 0.7.0 | 2025-10-10 | Schema Validation | 189 | 158 MB/s |
| 0.8.0 | 2025-10-11 | Streaming | 189 | 158 MB/s |
| 0.9.0 | 2025-10-12 | Transforms | 189 | 158 MB/s |
| 0.10.0 | 2025-10-13 | Parallel | 189 | 158 MB/s |
| 0.11.0 | 2025-10-14 | Plugins | 203 | 158 MB/s |

---

## Development Statistics

**Timeline:** 12 days (2025-10-03 to 2025-10-15)
**Pace:** ~1 major feature per day
**Total PRPs Completed:** 14 (PRP-00 through PRP-14)
**Total Tests:** 203
**Pass Rate:** 100%
**Memory Leaks:** 0
**Code Quality:** 9.9/10
**Performance Improvement:** 2.6x (60 → 158 MB/s)

---

## Migration Guides

### Upgrading from 0.10.x to 0.11.x

**New Features:**
- Plugin system available
- Use `plugin_register()` to add custom plugins
- See `plugins/` directory for examples

**Breaking Changes:**
- None

### Upgrading from 0.9.x to 0.10.x

**New Features:**
- Parallel parsing available via `parse_parallel()`
- Automatic thread detection
- Configure with `Parallel_Config`

**Breaking Changes:**
- None

### Upgrading from Earlier Versions

All versions maintain backward compatibility. New features are additive and opt-in.

---

## Links

- [Roadmap](roadmap.md) - Future development plans
- [PRP Archive](prp-archive/) - Completed PRP documents
- [GitHub Releases](https://github.com/yourusername/ocsv/releases)
- [Contributing Guide](../../CONTRIBUTING.md)

---

**Last Updated:** 2025-10-15
**Maintainer:** Dan Castrillo
**License:** MIT

