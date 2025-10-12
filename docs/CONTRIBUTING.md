# Contributing to OCSV

Thank you for your interest in contributing to OCSV! This guide will help you get started.

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Project Structure](#project-structure)
5. [Development Workflow](#development-workflow)
6. [Testing Guidelines](#testing-guidelines)
7. [Code Style](#code-style)
8. [Commit Guidelines](#commit-guidelines)
9. [Pull Request Process](#pull-request-process)
10. [Documentation](#documentation)
11. [Performance Considerations](#performance-considerations)
12. [Reporting Issues](#reporting-issues)

---

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and beginners
- Focus on constructive feedback
- Prioritize project quality over personal preferences
- Respect maintainer decisions

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or inflammatory comments
- Publishing private information
- Spam or advertising

---

## Getting Started

### Prerequisites

- **Odin:** Latest stable version ([odin-lang.org](https://odin-lang.org))
- **Bun:** v1.0+ ([bun.sh](https://bun.sh))
- **Git:** For version control
- **Task:** (Optional) For build automation

### Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/ocsv.git
cd ocsv

# Build library
odin build src -build-mode:shared -out:libcsv.dylib -o:speed

# Run tests
odin test tests -all-packages

# Check for memory leaks
odin test tests -all-packages -debug
```

---

## Development Setup

### 1. Fork and Clone

```bash
# Fork on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/ocsv.git
cd ocsv
git remote add upstream https://github.com/originalowner/ocsv.git
```

### 2. Install Dependencies

```bash
# Install Odin (macOS example)
brew install odin

# Install Bun
curl -fsSL https://bun.sh/install | bash

# (Optional) Install Task
brew install go-task/tap/go-task
```

### 3. Verify Setup

```bash
# Check Odin version
odin version

# Check Bun version
bun --version

# Build and test
odin build src -build-mode:shared -out:libcsv.dylib -o:speed
odin test tests -all-packages
```

---

## Project Structure

```
ocsv/
├── src/                    # Odin source code
│   ├── cisv.odin          # Main module (re-exports)
│   ├── parser.odin        # Parser implementation
│   ├── config.odin        # Configuration types
│   └── ffi_bindings.odin  # Bun FFI exports
├── tests/                  # Test suites
│   ├── test_parser.odin         # Basic tests (6)
│   ├── test_edge_cases.odin     # RFC 4180 tests (25)
│   ├── test_fuzzing.odin        # Property-based tests (5)
│   ├── test_large_files.odin    # Large file tests (6)
│   ├── test_performance.odin    # Performance tests (4)
│   └── test_integration.odin    # Integration tests (13)
├── docs/                   # Documentation
│   ├── API.md
│   ├── COOKBOOK.md
│   ├── CONTRIBUTING.md    # This file
│   └── ...
├── bindings/               # JavaScript/Bun bindings
│   ├── cisv.js
│   └── types.d.ts
└── benchmarks/             # Performance benchmarks
    └── benchmark.js
```

---

## Development Workflow

### 1. Create a Branch

```bash
# Update main
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Write code following [Code Style](#code-style)
- Add tests for new features
- Update documentation if needed
- Run tests frequently

### 3. Test Your Changes

```bash
# Run all tests
odin test tests -all-packages

# Run specific test
odin test tests -define:ODIN_TEST_NAMES=tests.test_your_test

# Check for memory leaks
odin test tests -all-packages -debug

# Run benchmarks
bun run benchmarks/benchmark.js
```

### 4. Commit and Push

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: add support for custom escape characters"

# Push to your fork
git push origin feature/your-feature-name
```

### 5. Open Pull Request

- Go to GitHub and open a PR
- Fill out the PR template
- Link related issues
- Wait for review

---

## Testing Guidelines

### Test Requirements

**All contributions must:**
- ✅ Include tests for new features
- ✅ Pass all existing tests
- ✅ Have zero memory leaks
- ✅ Maintain or improve performance

### Writing Tests

**Test file structure:**

```odin
package tests

import "core:testing"
import cisv "../src"

@(test)
test_your_feature :: proc(t: ^testing.T) {
    // Setup
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    // Exercise
    ok := cisv.parse_csv(parser, "test,data\n1,2\n")

    // Verify
    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 2)
    testing.expect_value(t, parser.all_rows[0][0], "test")
}
```

### Test Categories

**Unit Tests** (`test_parser.odin`)
- Test individual functions
- Fast execution (<1ms each)
- No external dependencies

**Edge Case Tests** (`test_edge_cases.odin`)
- RFC 4180 compliance
- Malformed input handling
- Boundary conditions

**Property-Based Tests** (`test_fuzzing.odin`)
- Randomized input generation
- Invariant testing
- Crash resistance

**Integration Tests** (`test_integration.odin`)
- End-to-end workflows
- Parser reuse
- Real-world scenarios

### Running Tests

```bash
# All tests
odin test tests -all-packages

# Specific test file
odin test tests/test_parser.odin

# Specific test function
odin test tests -define:ODIN_TEST_NAMES=tests.test_basic_csv

# With memory tracking
odin test tests -all-packages -debug

# Verbose output
odin test tests -all-packages -verbose
```

---

## Code Style

### Odin Style Guide

**Follow official Odin conventions:**

```odin
// Good: snake_case for procedures
parse_csv :: proc(parser: ^Parser, data: string) -> bool {
    // ...
}

// Good: PascalCase for types
Parse_State :: enum {
    Field_Start,
    In_Field,
    In_Quoted_Field,
}

// Good: snake_case for variables
field_buffer: [dynamic]u8
current_row: [dynamic]string

// Good: SCREAMING_SNAKE_CASE for constants
MAX_FIELD_SIZE :: 1024 * 1024
DEFAULT_DELIMITER :: ','
```

### Formatting

```bash
# Format code before committing
odin fmt src
odin fmt tests
```

### Documentation Comments

```odin
// parse_csv parses CSV data according to RFC 4180.
//
// The parser must be created with parser_create() before calling this function.
// Returns true on success, false on parse error.
//
// Example:
//     parser := parser_create()
//     defer parser_destroy(parser)
//     ok := parse_csv(parser, "a,b,c\n1,2,3\n")
//
parse_csv :: proc(parser: ^Parser, data: string) -> bool {
    // Implementation
}
```

### Error Handling

```odin
// Good: Return bool for success/failure
parse_csv :: proc(parser: ^Parser, data: string) -> bool {
    if parser == nil do return false
    // ...
    return true
}

// Good: Use multiple return values for errors
parse_file :: proc(path: string) -> (data: []string, ok: bool) {
    // ...
    return data, true
}
```

### Memory Management

```odin
// ALWAYS pair allocations with cleanup

// Good: Use defer
parser := parser_create()
defer parser_destroy(parser)

// Good: Free dynamic arrays
buffer := make([dynamic]u8)
defer delete(buffer)

// Good: Document ownership
// parser_create allocates memory that must be freed with parser_destroy
parser_create :: proc() -> ^Parser {
    parser := new(Parser)
    // ...
    return parser
}
```

---

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Test additions/changes
- `refactor:` Code refactoring
- `perf:` Performance improvement
- `chore:` Build/tooling changes

### Examples

```bash
# Feature
git commit -m "feat(parser): add support for custom escape characters"

# Bug fix
git commit -m "fix(parser): handle trailing newlines correctly"

# Documentation
git commit -m "docs(cookbook): add example for TSV parsing"

# Test
git commit -m "test(edge-cases): add test for nested quotes"

# Performance
git commit -m "perf(parser): optimize field buffer allocation"
```

---

## Pull Request Process

### Before Submitting

**Checklist:**
- [ ] Code compiles without warnings
- [ ] All tests pass (`odin test tests -all-packages`)
- [ ] Zero memory leaks (`odin test tests -all-packages -debug`)
- [ ] Code is formatted (`odin fmt src tests`)
- [ ] Documentation updated (if applicable)
- [ ] Commits follow guidelines
- [ ] Branch is up to date with main

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update

## Testing
- [ ] Added new tests
- [ ] All tests passing
- [ ] Zero memory leaks verified

## Performance Impact
- [ ] No performance regression
- [ ] Performance improved by X%
- [ ] N/A

## Related Issues
Closes #123
```

### Review Process

1. **Automated checks run** (tests, build)
2. **Maintainer review** (code quality, design)
3. **Feedback addressed**
4. **Approval and merge**

### After Merge

```bash
# Update your fork
git checkout main
git pull upstream main
git push origin main

# Delete feature branch
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

---

## Documentation

### When to Update Docs

Update documentation when:
- Adding new public API
- Changing behavior
- Adding features
- Fixing bugs that were documented incorrectly

### Documentation Files

- **`README.md`** - Project overview, quick start
- **`docs/API.md`** - Complete API reference
- **`docs/COOKBOOK.md`** - Usage examples
- **`docs/RFC4180.md`** - RFC compliance details
- **`docs/PERFORMANCE.md`** - Performance tuning
- **`docs/INTEGRATION.md`** - FFI examples

### Code Comments

```odin
// Public API: Document thoroughly
// parse_csv parses CSV data according to RFC 4180.
// Returns true on success, false on error.
parse_csv :: proc(parser: ^Parser, data: string) -> bool

// Internal: Brief comments for clarity
emit_field :: proc(parser: ^Parser) {
    // Clone string for memory safety across FFI boundary
    field_copy := strings.clone(field)
    append(&parser.current_row, field_copy)
}
```

---

## Performance Considerations

### Performance Requirements

**Contributions must:**
- ✅ Not regress performance by >5%
- ✅ Include benchmark results for perf changes
- ✅ Document optimization rationale

### Running Benchmarks

```bash
# Run benchmark
bun run benchmarks/benchmark.js

# Expected output:
# Throughput: 66.67 MB/s
# Rows/sec: 217,876
```

### Optimization Guidelines

1. **Profile first** - Measure before optimizing
2. **Avoid premature optimization** - Clarity first
3. **Document tradeoffs** - Explain why
4. **Test thoroughly** - Ensure correctness

### Memory Efficiency

```odin
// Good: Preallocate when size is known
reserve(&parser.all_rows, expected_count)

// Good: Reuse buffers
clear(&parser.field_buffer)  // Don't delete and recreate

// Good: Free memory promptly
cisv.clear_parser_data(parser)  // Before reuse
```

---

## Reporting Issues

### Before Creating an Issue

1. **Search existing issues** - Check if already reported
2. **Update to latest** - Verify bug exists in latest version
3. **Minimal reproduction** - Create smallest example
4. **Check documentation** - Ensure not user error

### Issue Template

**Bug Report:**
```markdown
## Description
Brief description of the bug

## Steps to Reproduce
1. Create parser
2. Parse data: "a,b,c\n1,2,3\n"
3. Observe behavior

## Expected Behavior
Should parse 2 rows

## Actual Behavior
Parses 0 rows

## Environment
- OS: macOS 14.0
- Odin: dev-2025-01
- OCSV: v0.3.0

## Minimal Reproduction
\```odin
parser := cisv.parser_create()
defer cisv.parser_destroy(parser)
ok := cisv.parse_csv(parser, "a,b,c\n1,2,3\n")
// Bug occurs here
\```
```

**Feature Request:**
```markdown
## Feature Description
Add support for custom quote escaping

## Use Case
Need to parse CSV with backslash escapes: "field\"with\"quotes"

## Proposed API
parser.config.escape_char = '\\'
parser.config.escape_mode = .Backslash

## Alternatives Considered
- Using relaxed mode (doesn't work for this case)
- Pre-processing CSV (too slow)
```

---

## Additional Resources

### Documentation
- [Odin Language Reference](https://odin-lang.org/docs/)
- [Bun FFI Guide](https://bun.sh/docs/api/ffi)
- [RFC 4180 Specification](https://www.rfc-editor.org/rfc/rfc4180)

### Project Links
- [Project README](../README.md)
- [API Reference](API.md)
- [Usage Cookbook](COOKBOOK.md)
- [Architecture Overview](ARCHITECTURE_OVERVIEW.md)

### Community
- GitHub Discussions (coming soon)
- Issue Tracker
- Pull Requests

---

## Questions?

If you have questions:
1. Check [documentation](API.md)
2. Search [existing issues](https://github.com/username/ocsv/issues)
3. Ask in discussions
4. Open a new issue

---

**Thank you for contributing to OCSV!** 🎉

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Dan Castrillo
