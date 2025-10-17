# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2025-10-17

### 🐛 Bug Fixes & Improvements

This patch release addresses critical memory corruption issues and significantly improves CI performance.

### Fixed
- **Memory Corruption**: Fixed string ownership model in Error_Info structures
  - `make_error()` now always clones strings for consistent ownership
  - `make_error_result()` independently clones error strings to prevent double-free
  - Added `error_info_destroy()` helper for proper cleanup
- **Platform-Specific Memory Management**: Implemented conditional cleanup for Windows (VirtualAlloc stricter than Unix mmap)
- **Test Memory Leaks**: Fixed cleanup in `destroy_test_context()` to free Error_Info strings
- **Empty Input Error**: Fixed orphaned error string in empty input handling

### Changed
- **CI Performance**: Reduced workflow time from ~18 min to 8m 28s (53% improvement)
  - Implemented comprehensive caching (LLVM, Odin compiler)
  - Added fail-fast lint job before matrix builds
  - Platform-specific cache keys for better hit rates

### Added
- **Cross-Platform Prebuilds**: All platforms now available in npm package
  - macOS ARM64: `libocsv.dylib` (69 KB)
  - Linux x64: `libocsv.so` (39 KB)
  - Windows x64: `ocsv.dll` (122 KB)
- **Test Coverage**: Re-enabled 31 additional tests (+69% increase)
  - `test_stress.odin` (14 stress tests)
  - `test_error_handling.odin` (20 error handling tests)
  - `test_streaming.odin` (17 streaming tests)

### Quality Metrics
- ✅ **Tests**: 75/76 passing (98.7%)
- ✅ **Memory**: 0 leaks, 0 "bad free" warnings
- ✅ **Platforms**: macOS ARM64, Linux x64, Windows x64
- ⚠️ **Known Issue**: 1 flaky concurrent test (passes in isolation)

---

## [1.0.0] - 2025-01-16

### 🎉 Production Release

Version 1.0.0 marks the first stable release of OCSV with comprehensive features and testing.

### Added
- **npm Package**: macOS ARM64 prebuild available via npm
- **CHANGELOG.md**: Complete version history and release notes following Keep a Changelog format
- **Package Structure**: Optimized npm package with bindings and prebuilds

### Changed
- **Version Bump**: Upgraded from v0.1.0 to v1.0.0, signaling stable API
- **Semantic Versioning Commitment**: From this point forward, all changes will follow strict semantic versioning

### Quality
- **Test Coverage**: ~201 tests passing (100% pass rate)
- **Memory Safety**: Zero memory leaks across all tests
- **RFC Compliance**: Full RFC 4180 compliance with all edge cases covered

### Documentation
- **Core Documentation**: README, CHANGELOG, examples, and usage guides
- **Platform Support**: Documented build and installation instructions for macOS ARM64

---

## [0.1.0] - 2025-01-15

### 🚀 Initial Release

First functional release of OCSV with comprehensive CSV parsing capabilities.

### Added

#### Core Functionality
- **RFC 4180 Compliant Parser**: Full CSV specification support with state machine implementation
- **Quoted Fields**: Support for embedded delimiters (`"field, with, commas"`)
- **Nested Quotes**: Proper handling of doubled quotes (`""` → `"`)
- **Multiline Fields**: Newlines inside quoted fields
- **Line Endings**: Both CRLF (Windows) and LF (Unix) support
- **Empty Fields**: Correct handling of consecutive delimiters and trailing delimiters
- **Comments**: Lines starting with `#` (configurable)
- **UTF-8 Support**: Full Unicode support including CJK characters and emojis

#### Bun FFI Integration
- **Native Bindings**: FFI integration with Bun runtime
- **`parseCSV()`**: Convenience function for parsing CSV strings
- **`parseCSVFile()`**: Async function for parsing CSV files
- **`Parser` Class**: Manual parser management with `parse()`, `parseFile()`, and `destroy()` methods
- **TypeScript Declarations**: Full TypeScript support with `.d.ts` files

#### Configuration Options
- **`delimiter`**: Custom field delimiter (default: `,`)
- **`quote`**: Custom quote character (default: `"`)
- **`escape`**: Custom escape character (default: `"`)
- **`comment`**: Comment line prefix (default: `#`)
- **`relaxed`**: Allow RFC violations (default: `false`)
- **`hasHeader`**: Treat first row as headers (default: `false`)

#### Advanced Features
- **Error Handling & Recovery**: Multiple error types and recovery strategies
- **Schema Validation**: Type checking and validation rules
- **Streaming API**: Chunk-based processing for large files
- **Transform System**: Built-in transforms and pipelines
- **Plugin Architecture**: Extensible plugin system
- **Parallel Processing**: Multi-threaded parsing (experimental)
- **SIMD Optimization**: ARM NEON byte search implementation

#### Testing & Quality
- **~201 Tests**: Comprehensive test coverage across multiple suites
- **100% Pass Rate**: All tests passing with zero failures
- **Zero Memory Leaks**: Verified across all tests
- **RFC Compliance**: Full RFC 4180 edge case coverage

### Technical Details

#### Architecture
- **Language**: Odin (core parser) + JavaScript/TypeScript (FFI bindings)
- **Build System**: Taskfile for automated builds
- **Memory Management**: Explicit memory management with defer pattern
- **State Machine**: RFC 4180 compliant state machine parser
- **FFI**: Bun FFI for integration

#### Dependencies
- **Runtime**: Bun v1.0+ (for FFI)
- **Build**: Odin compiler (latest)
- **Platform**: macOS ARM64 (primary support)

#### Package Structure
```
ocsv/
├── bindings/         # FFI bindings and TypeScript declarations
├── prebuilds/        # Platform-specific prebuilt binaries
│   └── darwin-arm64/ # macOS ARM64 prebuild
├── src/              # Odin source code
├── tests/            # Test suites
├── README.md         # Documentation
└── LICENSE           # MIT License
```

### Known Limitations

- **Platform Coverage**: v0.1.0 only includes macOS ARM64 prebuild
- **Parallel Processing**: Experimental feature, needs optimization
- **SIMD Support**: Currently ARM NEON only

---

## Links

- [Repository](https://github.com/dvrd/ocsv)
- [Issues](https://github.com/dvrd/ocsv/issues)
- [NPM Package](https://www.npmjs.com/package/ocsv)

[1.1.1]: https://github.com/dvrd/ocsv/releases/tag/v1.1.1
[1.0.0]: https://github.com/dvrd/ocsv/releases/tag/v1.0.0
[0.1.0]: https://github.com/dvrd/ocsv/releases/tag/v0.1.0
