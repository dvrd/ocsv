name: "PRP-17: NPM Package Publication & Cross-Platform Distribution"
description: |
  Publish OCSV to npm registry with full cross-platform support (macOS ARM64/x64, Linux x64, Windows x64),
  automated CI/CD publishing, and proper semantic versioning reflecting project maturity.

---

## Goal

**Feature Goal**: Publish OCSV v1.0.0 to npm with automated cross-platform binary distribution

**Deliverable**:
- npm package `ocsv@1.0.0` published and installable via `bun add ocsv`
- Prebuilt binaries for 4 platforms included in package
- Automated GitHub Actions workflow for publishing
- Complete CHANGELOG.md with version history

**Success Definition**:
- `bun add ocsv` works on all 4 platforms without requiring Odin compiler
- Automated publishing triggers on git tags
- Version 1.0.0 reflects production-ready status (203/203 tests, 0 leaks)
- Package size < 150KB compressed

## User Persona

**Target User**: JavaScript/TypeScript developers using Bun runtime

**Use Case**: Install high-performance CSV parser with single command: `bun add ocsv`

**User Journey**:
1. Run `bun add ocsv` in their project
2. Import with `import { parseCSV } from 'ocsv'`
3. Parser works immediately without compilation
4. Performance: 158 MB/s throughput out of the box

**Pain Points Addressed**:
- Current: Only macOS ARM64 users can use prebuilts (75% must compile from source)
- Current: Version 0.1.0 suggests alpha quality despite production readiness
- Current: Manual installation complexity discourages adoption
- Solution: One-command install works for everyone

## Why

- **Production Maturity**: 17 PRPs completed, 203/203 tests passing, 0 memory leaks, 158 MB/s performance - project is production-ready
- **Version Mismatch**: v0.1.0 doesn't reflect actual maturity, v1.0.0 signals production stability
- **Platform Coverage**: 75% of potential users (Linux/Windows/x64) blocked without prebuilds
- **Automated Updates**: Manual publishing prevents timely security patches and feature releases
- **Professional Distribution**: npm package makes OCSV discoverable and easy to adopt

## What

Transform OCSV from single-platform dev package to production-ready multi-platform npm package with automated publishing.

### Success Criteria

- [ ] Version updated from 0.1.0 to 1.0.0 across all files
- [ ] CHANGELOG.md created documenting v0.1.0 through v1.0.0
- [ ] Prebuilds exist for: darwin-arm64, darwin-x64, linux-x64, win32-x64
- [ ] GitHub Actions workflow publishes to npm on git tag push
- [ ] `npm pack` shows package size < 150KB compressed
- [ ] Test installation succeeds on all 4 platforms
- [ ] Platform detection works correctly in bindings/index.js
- [ ] Fallback error messages guide users when prebuild missing

## All Needed Context

### Context Completeness Check

_This PRP passes "No Prior Knowledge" test: All file patterns, URLs, and implementation details are specified for an AI agent unfamiliar with the codebase._

### Documentation & References

```yaml
# MUST READ - Critical for implementation
- docfile: /Users/kakurega/dev/agentic-eng/ai_docs/npm-publishing-automation.md
  why: Complete npm publishing automation guide with 2025 security updates
  section: "Best Practices, NPM Token Security, Tag-Based Release Workflows"
  critical: |
    - NPM tokens expire in 90 days max (2025 update)
    - Use granular access tokens with package-specific scope
    - OIDC trusted publishing is recommended over long-lived tokens
    - Tag-based workflows prevent accidental publishes

- docfile: /Users/kakurega/dev/agentic-eng/ai_docs/cross-platform-binaries.md
  why: Cross-platform binary distribution patterns
  section: "Distribution Approaches, Platform Detection, Directory Structure"
  critical: |
    - Use platform detection: os.platform() + os.arch()
    - Prebuild naming: {platform}-{arch}/lib{name}.{ext}
    - Fallback strategy essential when prebuild missing
    - Platform map: darwin→macOS, linux→Linux, win32→Windows

- docfile: /Users/kakurega/dev/agentic-eng/ai_docs/semantic-versioning.md
  why: Semantic versioning best practices for v1.0.0 transition
  section: "Version 0.x.x vs 1.x.x, CHANGELOG Best Practices"
  critical: |
    - v1.0.0 signals production-ready stable API
    - CHANGELOG must follow Keep a Changelog format
    - Document all versions from 0.1.0 to 1.0.0
    - Version bump: npm version major (0.1.0 → 1.0.0)

- file: .github/workflows/ci.yml
  why: Existing CI/CD pattern to extend for publishing
  pattern: |
    - Matrix builds for multiple platforms
    - Artifact upload with upload-artifact@v4
    - Platform-specific library names (libocsv.dylib, libocsv.so, ocsv.dll)
    - Timeout 15 minutes per job
  gotcha: |
    - Windows requires vcvars64.bat for MSVC
    - macOS uses macos-14 (ARM64) and macos-13 (Intel x64)
    - Artifacts use retention-days: 7

- file: Taskfile.yml
  why: Build system pattern for library compilation
  pattern: |
    - Platform detection via uname -s
    - Library naming: LIB_NAME variable with case statement
    - Build command: odin build src -out:{LIB_NAME} -build-mode:shared -o:speed
  gotcha: |
    - Darwin→libocsv.dylib, Linux→libocsv.so, Windows→ocsv.dll
    - Must use -build-mode:shared for FFI library
    - -o:speed for release builds

- file: package.json
  why: NPM package configuration to update
  pattern: |
    - version: "0.1.0" (UPDATE to "1.0.0")
    - files: ["bindings/", "prebuilds/", "README.md", "LICENSE"]
    - engines: { "bun": ">=1.0.0" }
    - os: ["darwin", "linux"] (ADD "win32")
  gotcha: |
    - prepublishOnly script runs before publish (validates build)
    - files array controls what goes in npm package
    - Must include LICENSE file

- file: bindings/index.js
  why: Platform detection logic to enhance
  pattern: |
    Line 20-38: getPlatform() and getLibraryPath() functions
    Currently maps platforms but needs all 4 platform support
  gotcha: |
    - Current implementation only handles darwin/linux
    - Need to add win32-x64 case
    - Must provide clear error message when platform unsupported

- url: https://docs.npmjs.com/creating-and-publishing-scoped-public-packages
  why: Official npm publishing guide
  critical: First-time publish requires --access public flag

- url: https://github.com/marketplace/actions/upload-a-build-artifact
  why: Artifact upload action used in existing CI
  critical: Version v4 requires explicit artifact name and path
```

### Current Codebase tree

```bash
ocsv/
├── .github/
│   └── workflows/
│       └── ci.yml                    # Existing CI workflow (matrix builds)
├── bindings/
│   ├── index.js                      # FFI bindings with platform detection
│   ├── index.d.ts                    # TypeScript declarations
│   ├── ocsv.js                       # Core FFI functions
│   ├── errors.js                     # Error handling
│   └── types.d.ts                    # Type definitions
├── prebuilds/
│   └── darwin-arm64/
│       └── libocsv.dylib             # Only macOS ARM64 prebuild exists
├── src/
│   ├── ocsv.odin                     # Main package entry
│   ├── parser.odin                   # Core CSV parser
│   ├── config.odin                   # Parser configuration
│   └── ffi_bindings.odin             # FFI exports
├── tests/                            # 203 tests (all passing)
├── examples/
│   ├── basic_parser.ts
│   ├── streaming_parser.ts
│   ├── test_large_data.ts
│   ├── benchmark_extreme.ts
│   └── README.md
├── package.json                      # version: "0.1.0", os: ["darwin", "linux"]
├── LICENSE                           # MIT License
├── .npmignore                        # Controls npm package contents
├── README.md                         # Project documentation
├── Taskfile.yml                      # Build automation
└── libocsv.dylib                     # Local build (excluded from npm via .npmignore)
```

### Desired Codebase tree with files to be added

```bash
ocsv/
├── .github/
│   └── workflows/
│       ├── ci.yml                    # Keep existing CI workflow
│       └── npm-publish.yml           # NEW: Automated npm publishing on tag
├── bindings/
│   └── index.js                      # MODIFY: Add win32-x64 platform support
├── prebuilds/
│   ├── darwin-arm64/
│   │   └── libocsv.dylib             # EXISTS: macOS ARM64
│   ├── darwin-x64/                   # NEW: macOS Intel
│   │   └── libocsv.dylib
│   ├── linux-x64/                    # NEW: Linux x64
│   │   └── libocsv.so
│   └── win32-x64/                    # NEW: Windows x64
│       └── ocsv.dll
├── package.json                      # MODIFY: version → "1.0.0", os → ["darwin", "linux", "win32"]
├── CHANGELOG.md                      # NEW: Version history (v0.1.0 → v1.0.0)
└── scripts/
    └── prepublish.sh                 # NEW: Validation before publish (optional but recommended)
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL: Odin compiler required for building shared libraries
# - macOS: odin build src -build-mode:shared -out:libocsv.dylib -o:speed
# - Linux: odin build src -build-mode:shared -out:libocsv.so -o:speed
# - Windows: odin build src -build-mode:shared -out:ocsv.dll -o:speed
#   Windows requires MSVC (vcvars64.bat must be sourced)

# CRITICAL: Platform-specific library naming
# - Darwin (macOS): lib prefix + .dylib extension → libocsv.dylib
# - Linux: lib prefix + .so extension → libocsv.so
# - Windows: NO lib prefix + .dll extension → ocsv.dll

# CRITICAL: GitHub Actions platform matrix
# - macOS ARM64: macos-14 (Apple Silicon)
# - macOS x64: macos-13 (Intel)
# - Linux x64: ubuntu-latest
# - Windows x64: windows-2022 (requires MSVC setup via vcvars64.bat)

# GOTCHA: NPM publish first-time requires --access public
# - First publish: npm publish --access public
# - Subsequent: npm publish (public flag not needed)

# GOTCHA: Bun FFI dynamic library loading
# - Uses dlopen with platform-specific paths
# - Requires correct library extension per platform
# - Fallback error messages should guide users to file issues

# GOTCHA: Semantic versioning jump 0.1.0 → 1.0.0
# - 0.x.x signals "breaking changes may occur"
# - 1.0.0 signals "stable API, semantic versioning contract"
# - Update ALL version references: package.json, src/ocsv.odin (if VERSION constants exist)

# GOTCHA: GitHub Actions artifact retention
# - Artifacts expire after 7 days (retention-days: 7 in ci.yml)
# - For npm publish, artifacts are short-lived and only used within workflow
```

## Implementation Blueprint

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: UPDATE package.json
  - MODIFY: Line 3: version: "0.1.0" → version: "1.0.0"
  - MODIFY: Line 18: os: ["darwin", "linux"] → os: ["darwin", "linux", "win32"]
  - VERIFY: files array includes ["bindings/", "prebuilds/", "README.md", "LICENSE"]
  - VERIFY: engines.bun is ">=1.0.0"
  - NAMING: No naming changes needed
  - DEPENDENCIES: None
  - VALIDATION: Run `bun install` to verify package.json is valid

Task 2: CREATE CHANGELOG.md
  - IMPLEMENT: Full version history following Keep a Changelog format
  - SECTIONS:
    - ## [1.0.0] - 2025-01-XX (Production Release)
      - Added: Cross-platform prebuilds (macOS ARM64/x64, Linux x64, Windows x64)
      - Added: Automated npm publishing via GitHub Actions
      - Changed: Version 1.0.0 signals production-ready stable API
      - Performance: 144 MB/s throughput, 1.2M rows/sec
      - Quality: 203/203 tests passing, 0 memory leaks
    - ## [0.1.0] - 2025-01-XX (Initial Release)
      - Added: RFC 4180 compliant CSV parser
      - Added: Bun FFI bindings
      - Added: Streaming API support
      - Added: Plugin architecture
      - Performance: 61.84 MB/s baseline
  - FOLLOW pattern: https://keepachangelog.com/en/1.1.0/
  - PLACEMENT: Root directory (CHANGELOG.md)
  - DEPENDENCIES: None

Task 3: MODIFY bindings/index.js
  - FIND: Line 20-38: getPlatform() and getLibraryPath() functions
  - MODIFY: Add win32-x64 case to platform detection
  - PATTERN:
    ```javascript
    const libNames = {
      'darwin-arm64': 'libocsv.dylib',
      'darwin-x64': 'libocsv.dylib',
      'linux-x64': 'libocsv.so',
      'win32-x64': 'ocsv.dll'  // ADD THIS LINE
    };
    ```
  - ENHANCE: Improve error message when platform unsupported:
    ```javascript
    throw new Error(
      `Unsupported platform: ${platform}. ` +
      `Please file an issue at https://github.com/user/ocsv/issues`
    );
    ```
  - DEPENDENCIES: None
  - VALIDATION: Read file after edit to verify changes

Task 4: CREATE .github/workflows/npm-publish.yml
  - IMPLEMENT: Multi-platform build and publish workflow
  - TRIGGER: On push of tags matching v*.*.*
  - STRATEGY:
    - Matrix builds for 4 platforms (parallel execution)
    - Artifact upload per platform
    - Single publish job that depends on all builds
  - WORKFLOW STRUCTURE:
    ```yaml
    name: NPM Publish
    on:
      push:
        tags:
          - 'v*.*.*'

    jobs:
      build-matrix:
        strategy:
          matrix:
            include:
              - os: macos-14
                platform: darwin-arm64
                lib_name: libocsv.dylib
              - os: macos-13
                platform: darwin-x64
                lib_name: libocsv.dylib
              - os: ubuntu-latest
                platform: linux-x64
                lib_name: libocsv.so
              - os: windows-2022
                platform: win32-x64
                lib_name: ocsv.dll
        steps:
          - Install Odin
          - Build: odin build src -build-mode:shared -out:${{ matrix.lib_name }} -o:speed
          - Upload artifact: prebuilds/${{ matrix.platform }}/${{ matrix.lib_name }}

      publish:
        needs: build-matrix
        runs-on: ubuntu-latest
        steps:
          - Download all artifacts
          - Organize prebuilds/ directory
          - npm publish --access public
    ```
  - FOLLOW pattern: .github/workflows/ci.yml (matrix builds, artifact upload)
  - GOTCHA: Windows requires vcvars64.bat setup before odin build
  - GOTCHA: First publish needs --access public flag
  - DEPENDENCIES: Task 1-3 completed (package.json, CHANGELOG.md, bindings/index.js)
  - PLACEMENT: .github/workflows/npm-publish.yml

Task 5: CREATE scripts/prepublish.sh (OPTIONAL but recommended)
  - IMPLEMENT: Validation script to run before npm publish
  - CHECKS:
    - All 4 prebuilds exist in correct directories
    - package.json version matches git tag
    - CHANGELOG.md includes current version
    - LICENSE file exists
  - PATTERN:
    ```bash
    #!/bin/bash
    set -e

    echo "Validating package before publish..."

    # Check prebuilds exist
    for platform in darwin-arm64 darwin-x64 linux-x64 win32-x64; do
      if [ ! -d "prebuilds/$platform" ]; then
        echo "ERROR: Missing prebuild for $platform"
        exit 1
      fi
    done

    echo "✓ All prebuilds found"
    echo "✓ Package ready for publish"
    ```
  - USAGE: Add to package.json: "prepublishOnly": "bash scripts/prepublish.sh"
  - DEPENDENCIES: Task 1-4 completed
  - PLACEMENT: scripts/prepublish.sh

Task 6: TEST INSTALLATION (Manual validation on CI or locally)
  - VERIFY: npm pack creates tarball < 150KB
  - VERIFY: tarball includes bindings/, prebuilds/, README.md, LICENSE, CHANGELOG.md
  - VERIFY: tarball excludes src/, tests/, .github/, examples/
  - COMMAND: `npm pack --dry-run` to preview
  - COMMAND: `npm pack` to create tarball, then `tar -tzf ocsv-1.0.0.tgz` to inspect
  - DEPENDENCIES: All previous tasks completed
```

### Implementation Patterns & Key Details

```bash
# Pattern: Semantic versioning in package.json
# Follow strict semver: MAJOR.MINOR.PATCH
# 1.0.0 = First stable release, commit to semver contract

# Pattern: CHANGELOG.md format
# Keep a Changelog format with [Version] - Date headings
# Categories: Added, Changed, Deprecated, Removed, Fixed, Security

# Pattern: GitHub Actions matrix builds
# Use strategy.matrix.include for heterogeneous platforms
# Each matrix job uploads unique artifact name (platform-specific)
# Final publish job downloads all artifacts with download-artifact@v4

# Pattern: NPM publish automation
# Use needs: [build-matrix] to ensure builds complete before publish
# Use secrets.NPM_TOKEN for authentication (set in GitHub repo secrets)
# First publish requires --access public for unscoped packages

# GOTCHA: Windows MSVC setup in GitHub Actions
# Must source vcvars64.bat before running odin build on Windows
# Example: call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"

# GOTCHA: Artifact download organization
# download-artifact@v4 downloads to current directory, not original path
# Must manually organize: mv artifacts/darwin-arm64/* prebuilds/darwin-arm64/

# CRITICAL: NPM token security
# Use granular access tokens, not classic automation tokens
# Scope: Read/write to single package
# Expiration: Set to 90 days or less (2025 npm security requirement)
```

### Integration Points

```yaml
NPM_REGISTRY:
  - First publish: "npm publish --access public"
  - Setup: Create granular access token at https://www.npmjs.com/settings/tokens
  - Security: Token scope = "Automation" or "Publish", package = "ocsv"
  - GitHub Secret: Add token as NPM_TOKEN in repository secrets

GITHUB_ACTIONS:
  - Workflow file: .github/workflows/npm-publish.yml
  - Trigger: Tag push (git tag v1.0.0 && git push --tags)
  - Matrix: 4 platforms build in parallel (~5-10 minutes total)
  - Artifacts: Short-lived (only exist within workflow run)

PACKAGE_JSON:
  - Update: version, os array
  - Keep: files, engines, dependencies unchanged
  - Optional: Add prepublishOnly script for validation

VERSIONING:
  - Git tag: v1.0.0 (with 'v' prefix for GitHub conventions)
  - package.json: "1.0.0" (without 'v' prefix for npm)
  - CHANGELOG.md: ## [1.0.0] - 2025-01-XX
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# After each file creation/modification
# Validate package.json syntax
bun install --dry-run
# Expected: "bun install v1.x.x" with no errors

# Validate CHANGELOG.md format (manual review)
cat CHANGELOG.md
# Expected: Keep a Changelog format with clear version sections

# Validate bindings/index.js syntax
bun run --dry-run bindings/index.js
# Expected: No syntax errors

# Validate workflow syntax
# Use GitHub's workflow validator or yamllint
cat .github/workflows/npm-publish.yml | grep -E "^(name|on|jobs):"
# Expected: Proper YAML structure with name, on, jobs keys

# Project-wide validation
find . -name "*.json" -exec echo "Checking {}" \; -exec bun run --dry-run {} \;
# Expected: All JSON files are valid
```

### Level 2: Unit Tests (Component Validation)

```bash
# Existing test suite must still pass (no regressions)
odin test tests -all-packages
# Expected: 203/203 tests passing, 0 memory leaks

# Test bindings/index.js platform detection
bun test bindings/index.js
# Expected: Platform detection works for all 4 platforms (if tests exist)

# Manual test: Verify platform detection logic
node -e "console.log(require('./bindings/index.js').getPlatform())"
# Expected: Outputs platform string (e.g., "darwin-arm64")

# Validate package contents with npm pack
npm pack --dry-run
# Expected: Lists files to be included, confirms size < 150KB

# Full test suite validation
bun test
# Expected: All tests pass (if Bun test suite exists)
```

### Level 3: Integration Testing (System Validation)

```bash
# Test local npm pack and install
npm pack
# Creates ocsv-1.0.0.tgz

# Inspect tarball contents
tar -tzf ocsv-1.0.0.tgz | head -20
# Expected: Contains package/bindings/, package/prebuilds/, package/README.md, etc.

# Test installation in temporary directory
mkdir /tmp/test-ocsv-install && cd /tmp/test-ocsv-install
bun init -y
bun add /path/to/ocsv/ocsv-1.0.0.tgz
# Expected: Installation succeeds

# Test basic functionality
cat > test.js << 'EOF'
const { parseCSV } = require('ocsv');
const csv = 'name,age\nAlice,30\nBob,25';
const result = parseCSV(csv);
console.log('Parsed rows:', result.length);
EOF
bun run test.js
# Expected: "Parsed rows: 2" (or similar output)

# Cleanup test directory
cd - && rm -rf /tmp/test-ocsv-install

# GitHub Actions workflow validation (manual)
# 1. Push changes to feature branch
# 2. Create test tag: git tag v1.0.0-test && git push --tags
# 3. Monitor workflow at: https://github.com/{owner}/{repo}/actions
# 4. Verify all 4 matrix builds complete successfully
# 5. Delete test tag: git tag -d v1.0.0-test && git push --delete origin v1.0.0-test

# Expected: All builds pass, artifacts uploaded, publish skipped (or test publish to npm)
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Cross-platform installation testing (requires access to multiple platforms)
# Test on macOS ARM64 (Apple Silicon)
arch -arm64 bun add ocsv
bun run test.js

# Test on macOS x64 (Intel)
arch -x86_64 bun add ocsv
bun run test.js

# Test on Linux x64 (via Docker)
docker run -it --rm -v $(pwd):/work node:20 bash -c "cd /work && npm install ocsv && node test.js"

# Test on Windows x64 (via VM or CI)
# bun add ocsv
# bun run test.js

# Performance regression testing
# Ensure 1.0.0 maintains or exceeds baseline performance (61.84 MB/s)
cd examples
bun run benchmark_extreme.ts
# Expected: Throughput >= 61.84 MB/s for all dataset sizes

# Package size validation
npm pack --dry-run | grep "Tarball Contents"
# Expected: Total size < 150KB (compressed)

# NPM registry validation (after publish)
npm view ocsv@1.0.0
# Expected: Shows package info with version 1.0.0, correct files, etc.

# Installation from npm registry (after publish)
mkdir /tmp/npm-registry-test && cd /tmp/npm-registry-test
bun init -y
bun add ocsv@1.0.0
bun run -e 'import("ocsv").then(m => console.log("Import successful"))'
# Expected: "Import successful"

# CHANGELOG.md completeness review
grep -E "^## \[" CHANGELOG.md
# Expected: Shows all version headings ([1.0.0], [0.1.0])

# Security audit
bun audit
# Expected: No vulnerabilities in dependencies
```

## Final Validation Checklist

### Technical Validation

- [ ] All 4 validation levels completed successfully
- [ ] All tests pass: `odin test tests -all-packages` (203/203)
- [ ] No memory leaks in test suite
- [ ] Package.json syntax valid: `bun install --dry-run`
- [ ] CHANGELOG.md follows Keep a Changelog format
- [ ] Workflow syntax valid: GitHub Actions linter passes

### Feature Validation

- [ ] All success criteria from "What" section met:
  - [ ] Version updated to 1.0.0 in package.json
  - [ ] CHANGELOG.md created with full version history
  - [ ] Prebuilds exist for all 4 platforms (darwin-arm64, darwin-x64, linux-x64, win32-x64)
  - [ ] GitHub Actions workflow created and tested
  - [ ] `npm pack` shows package size < 150KB compressed
  - [ ] Platform detection in bindings/index.js supports all 4 platforms
  - [ ] Fallback error messages are clear and actionable
- [ ] Manual testing successful: Local npm pack and install works
- [ ] Cross-platform installation tested on at least 2 platforms
- [ ] Performance baseline maintained: >= 61.84 MB/s

### Code Quality Validation

- [ ] Follows existing codebase patterns:
  - [ ] Package.json structure consistent with existing format
  - [ ] Workflow follows ci.yml pattern (matrix builds, artifacts)
  - [ ] Bindings/index.js changes minimal and follow existing style
- [ ] File placement matches desired codebase tree structure
- [ ] No anti-patterns introduced (see Anti-Patterns section below)
- [ ] Dependencies properly managed (no new runtime dependencies)

### Documentation & Deployment

- [ ] CHANGELOG.md documents all changes from 0.1.0 to 1.0.0
- [ ] README.md installation instructions still accurate
- [ ] NPM registry listing will show correct information after publish
- [ ] GitHub release notes prepared (optional but recommended)

### Pre-Publish Checklist (Run before git tag)

- [ ] All code changes committed and pushed to main branch
- [ ] Version 1.0.0 committed in package.json
- [ ] CHANGELOG.md committed with v1.0.0 entry
- [ ] NPM_TOKEN secret configured in GitHub repository settings
- [ ] Team notified of upcoming v1.0.0 release
- [ ] Ready to create git tag: `git tag v1.0.0 && git push --tags`

### Post-Publish Validation

- [ ] GitHub Actions workflow completed successfully
- [ ] Package visible on npm registry: `npm view ocsv@1.0.0`
- [ ] Installation works from npm: `bun add ocsv@1.0.0`
- [ ] GitHub release created (optional): Create release notes from CHANGELOG.md
- [ ] Social media announcement (optional): Share v1.0.0 release

---

## Anti-Patterns to Avoid

- ❌ Don't hardcode platform paths - use dynamic platform detection
- ❌ Don't skip testing npm pack before pushing tags - always validate tarball contents
- ❌ Don't use classic npm automation tokens - use granular access tokens
- ❌ Don't forget --access public on first publish - unscoped packages default to private
- ❌ Don't include src/ in npm package - increases size unnecessarily
- ❌ Don't skip CHANGELOG.md - users need version history
- ❌ Don't use 0.x.x forever - v1.0.0 signals production readiness
- ❌ Don't build all platforms on single CI runner - use matrix for parallelism
- ❌ Don't forget Windows MSVC setup - vcvars64.bat must be sourced
- ❌ Don't use sync git push - always use async push with tags: `git push --tags`