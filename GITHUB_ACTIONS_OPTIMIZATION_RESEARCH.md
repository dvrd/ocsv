# GitHub Actions Workflow Optimization Research Report
## Cross-Platform CI/CD for Compiled Language Projects (2025)

**Project Context:** OCSV - High-performance CSV parser in Odin
**Date:** 2025-10-16
**Focus:** Cross-platform builds (macOS, Linux, Windows) with cost and performance optimization

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Reusable Workflows](#reusable-workflows)
3. [Composite Actions](#composite-actions)
4. [Matrix Strategy Optimization](#matrix-strategy-optimization)
5. [Artifact Sharing Between Jobs](#artifact-sharing-between-jobs)
6. [Fail-Fast vs Complete Testing](#fail-fast-vs-complete-testing)
7. [Parallel vs Sequential Execution](#parallel-vs-sequential-execution)
8. [Resource and Cost Optimization](#resource-and-cost-optimization)
9. [Real-World Examples](#real-world-examples)
10. [Recommendations for OCSV](#recommendations-for-ocsv)

---

## Executive Summary

### Key Findings

- **Cost Savings:** Self-hosted runners can reduce costs by 30-90% vs GitHub-hosted, but require infrastructure management
- **Performance Gains:** Proper caching and concurrency controls can improve workflow speed by 50-92%
- **Best Practice:** Use reusable workflows for cross-repository standardization, composite actions for step-level reuse
- **Matrix Optimization:** Strategic use of `include`/`exclude` with fail-fast control provides best balance
- **Artifact Management:** v4 artifacts now support cross-workflow sharing with improved validation

### Recommended Strategy for OCSV

1. Use reusable workflows for build/test patterns shared across platforms
2. Implement composite actions for Odin toolchain setup
3. Leverage matrix strategy with platform-specific configurations
4. Use fail-fast: false for comprehensive cross-platform testing
5. Implement aggressive caching for build dependencies
6. Use concurrency groups to prevent duplicate runs on rapid commits

---

## Reusable Workflows

### What They Are

Reusable workflows are complete workflow files that can be called from other workflows, enabling standardization and DRY principles across repositories.

**Key Characteristics:**
- Located in `.github/workflows/` directory
- Must include `workflow_call` in the `on:` trigger
- Can accept inputs, secrets, and produce outputs
- Scoped to repository, organization, or enterprise

### Official Documentation

- **Primary Docs:** https://docs.github.com/en/actions/using-workflows/reusing-workflows
- **Tutorial:** https://resources.github.com/learn/pathways/automation/intermediate/create-reusable-workflows-in-github-actions/
- **Best Practices:** https://earthly.dev/blog/github-actions-reusable-workflows/

### Syntax and Structure

#### Creating a Reusable Workflow

```yaml
# .github/workflows/reusable-build.yml
name: Reusable Build

on:
  workflow_call:
    inputs:
      os:
        required: true
        type: string
      build-mode:
        required: false
        type: string
        default: 'release'
      odin-version:
        required: false
        type: string
        default: 'latest'
    outputs:
      artifact-name:
        description: "Name of the compiled artifact"
        value: ${{ jobs.build.outputs.artifact }}
    secrets:
      deploy-token:
        required: false

jobs:
  build:
    runs-on: ${{ inputs.os }}
    outputs:
      artifact: ${{ steps.upload.outputs.artifact-id }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Odin
        uses: ./.github/actions/setup-odin
        with:
          version: ${{ inputs.odin-version }}

      - name: Build Library
        run: |
          odin build src -build-mode:shared \
            -out:libocsv.dylib \
            -o:${{ inputs.build-mode == 'debug' && 'minimal' || 'speed' }}

      - name: Upload Artifact
        id: upload
        uses: actions/upload-artifact@v4
        with:
          name: ocsv-${{ inputs.os }}
          path: libocsv.*
          retention-days: 7
```

#### Calling a Reusable Workflow

```yaml
# .github/workflows/ci.yml
name: Cross-Platform CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  build-macos:
    uses: ./.github/workflows/reusable-build.yml
    with:
      os: macos-14
      build-mode: release
      odin-version: 'dev-2025-10'
    secrets: inherit

  build-linux:
    uses: ./.github/workflows/reusable-build.yml
    with:
      os: ubuntu-latest
      build-mode: release

  build-windows:
    uses: ./.github/workflows/reusable-build.yml
    with:
      os: windows-latest
      build-mode: release
```

### Best Practices

1. **Parameterization:** Make workflows generic through extensive use of inputs
2. **Versioning:** Use semantic versioning (v1.x.x) and avoid breaking changes
3. **Organization:** Store centralized workflows in a dedicated `.github` repository
4. **Nesting Limits:** Maximum 4 levels of nested reusable workflows
5. **Call Limits:** Maximum 20 reusable workflows per workflow file
6. **Secrets:** Use `secrets: inherit` for same-organization workflows
7. **Timeouts:** Set explicit `timeout-minutes` (default is 6 hours!)

### When to Use Reusable Workflows

- **✅ Use for:** Complete build/test/deploy processes
- **✅ Use for:** Organization-wide CI/CD standards
- **✅ Use for:** Complex multi-job workflows
- **❌ Don't use for:** Simple step sequences (use composite actions instead)
- **❌ Don't use for:** Single-repository workflows with no reuse potential

### Example: OCSV Build Matrix with Reusable Workflow

```yaml
# .github/workflows/reusable-ocsv-test.yml
name: Reusable Test Suite

on:
  workflow_call:
    inputs:
      os:
        required: true
        type: string
      arch:
        required: false
        type: string
        default: 'x86_64'

jobs:
  test:
    runs-on: ${{ inputs.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Odin
        uses: ./.github/actions/setup-odin
        with:
          arch: ${{ inputs.arch }}

      - name: Build
        run: odin build src -build-mode:shared -out:libocsv.dylib -o:speed

      - name: Run Tests
        run: odin test tests -all-packages

      - name: Memory Leak Check
        run: odin test tests -all-packages -debug -define:USE_TRACKING_ALLOCATOR=true

# .github/workflows/cross-platform-ci.yml
name: Cross-Platform CI

on: [push, pull_request]

jobs:
  test-matrix:
    strategy:
      matrix:
        include:
          - name: macOS ARM
            os: macos-14
            arch: arm64
          - name: macOS Intel
            os: macos-13
            arch: x86_64
          - name: Ubuntu
            os: ubuntu-latest
            arch: x86_64
          - name: Windows
            os: windows-latest
            arch: x86_64
    uses: ./.github/workflows/reusable-ocsv-test.yml
    with:
      os: ${{ matrix.os }}
      arch: ${{ matrix.arch }}
```

---

## Composite Actions

### What They Are

Composite actions bundle multiple workflow steps into a single reusable action, combining shell commands and other actions into a modular unit.

**Key Characteristics:**
- Defined with `action.yml` in a directory
- Uses `runs.using: 'composite'`
- Can combine shell scripts and other actions
- Supports inputs and outputs
- Requires `shell:` specification for run steps

### Official Documentation

- **Primary Docs:** https://docs.github.com/en/actions/creating-actions/creating-a-composite-action
- **In-Depth Guide:** https://earthly.dev/blog/composite-actions-github/
- **Best Practices:** https://wallis.dev/blog/composite-github-actions

### Syntax and Structure

#### Creating a Composite Action

```yaml
# .github/actions/setup-odin/action.yml
name: 'Setup Odin Compiler'
description: 'Install and configure the Odin compiler for CI builds'

inputs:
  version:
    description: 'Odin version to install'
    required: false
    default: 'latest'
  arch:
    description: 'Architecture (x86_64, arm64)'
    required: false
    default: 'x86_64'
  cache:
    description: 'Enable caching of Odin installation'
    required: false
    default: 'true'

outputs:
  odin-version:
    description: 'Installed Odin version'
    value: ${{ steps.version.outputs.version }}
  install-path:
    description: 'Path to Odin installation'
    value: ${{ steps.install.outputs.path }}

runs:
  using: 'composite'
  steps:
    - name: Get OS type
      id: os
      shell: bash
      run: |
        if [[ "$RUNNER_OS" == "macOS" ]]; then
          echo "type=macos" >> $GITHUB_OUTPUT
        elif [[ "$RUNNER_OS" == "Linux" ]]; then
          echo "type=linux" >> $GITHUB_OUTPUT
        elif [[ "$RUNNER_OS" == "Windows" ]]; then
          echo "type=windows" >> $GITHUB_OUTPUT
        fi

    - name: Cache Odin Installation
      if: inputs.cache == 'true'
      uses: actions/cache@v4
      with:
        path: |
          ~/odin
          ~/.odin
        key: odin-${{ steps.os.outputs.type }}-${{ inputs.arch }}-${{ inputs.version }}
        restore-keys: |
          odin-${{ steps.os.outputs.type }}-${{ inputs.arch }}-
          odin-${{ steps.os.outputs.type }}-

    - name: Download Odin
      id: install
      shell: bash
      run: |
        # Installation logic here
        if [[ "${{ inputs.version }}" == "latest" ]]; then
          VERSION=$(curl -s https://api.github.com/repos/odin-lang/Odin/releases/latest | grep tag_name | cut -d '"' -f 4)
        else
          VERSION="${{ inputs.version }}"
        fi

        echo "Installing Odin $VERSION for ${{ steps.os.outputs.type }}"
        # Download and install logic...
        echo "version=$VERSION" >> $GITHUB_OUTPUT
        echo "path=$HOME/odin" >> $GITHUB_OUTPUT

    - name: Add to PATH
      shell: bash
      run: echo "$HOME/odin/bin" >> $GITHUB_PATH

    - name: Verify Installation
      id: version
      shell: bash
      run: |
        odin version
        VERSION=$(odin version | head -n1 | awk '{print $2}')
        echo "version=$VERSION" >> $GITHUB_OUTPUT
```

#### Using a Composite Action

```yaml
# .github/workflows/build.yml
name: Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Odin
        uses: ./.github/actions/setup-odin
        with:
          version: 'dev-2025-10'
          arch: 'x86_64'
          cache: 'true'

      - name: Build
        run: odin build src -build-mode:shared -out:libocsv.dylib
```

### Best Practices

1. **Location:** Store in `.github/actions/` for local actions
2. **File Naming:** Always name the file `action.yml` (no custom names)
3. **Shell Requirement:** Always specify `shell:` for run steps
4. **Context Access:** Can access `${{ github }}` and other contexts
5. **Inputs/Outputs:** Use typed inputs and always document outputs
6. **Versioning:** Tag public actions with semantic versions
7. **Modularity:** Keep actions focused on a single responsibility

### Composite Actions vs Reusable Workflows

| Feature | Composite Actions | Reusable Workflows |
|---------|------------------|-------------------|
| **Scope** | Multiple steps | Complete workflow |
| **Location** | Any directory | `.github/workflows/` |
| **File Name** | `action.yml` | Any `.yml` |
| **Trigger** | Used in `steps:` | Used in `jobs:` |
| **Jobs** | N/A (steps only) | Multiple jobs |
| **Secrets** | Pass explicitly | Can use `inherit` |
| **Matrix** | N/A | Full support |
| **Use Case** | Setup/build patterns | End-to-end processes |

### When to Use Composite Actions

- **✅ Use for:** Repeated setup steps (toolchain installation, environment config)
- **✅ Use for:** Build/test patterns within a single job
- **✅ Use for:** Custom actions shared across workflows
- **❌ Don't use for:** Multi-job workflows (use reusable workflows)
- **❌ Don't use for:** Platform-specific runners (use reusable workflows)

### Example: OCSV Testing Composite Action

```yaml
# .github/actions/run-ocsv-tests/action.yml
name: 'Run OCSV Tests'
description: 'Execute OCSV test suite with memory leak detection'

inputs:
  test-suite:
    description: 'Test suite to run (all, parser, edge-cases, fuzzing)'
    required: false
    default: 'all'
  memory-check:
    description: 'Enable memory leak detection'
    required: false
    default: 'true'
  coverage:
    description: 'Enable coverage reporting'
    required: false
    default: 'false'

outputs:
  test-result:
    description: 'Test execution result (pass/fail)'
    value: ${{ steps.test.outputs.result }}
  leak-count:
    description: 'Number of memory leaks detected'
    value: ${{ steps.leak-check.outputs.count }}

runs:
  using: 'composite'
  steps:
    - name: Build Tests
      shell: bash
      run: |
        echo "Building test suite: ${{ inputs.test-suite }}"
        odin build tests -debug

    - name: Run Tests
      id: test
      shell: bash
      run: |
        if [[ "${{ inputs.test-suite }}" == "all" ]]; then
          odin test tests -all-packages
        else
          odin test tests -define:ODIN_TEST_NAMES=tests.test_${{ inputs.test-suite }}
        fi
        echo "result=$?" >> $GITHUB_OUTPUT

    - name: Memory Leak Check
      id: leak-check
      if: inputs.memory-check == 'true'
      shell: bash
      run: |
        echo "Running memory leak detection..."
        odin test tests -all-packages -debug -define:USE_TRACKING_ALLOCATOR=true | tee leak-report.txt
        LEAKS=$(grep -c "memory leak" leak-report.txt || echo 0)
        echo "count=$LEAKS" >> $GITHUB_OUTPUT
        if [[ $LEAKS -gt 0 ]]; then
          echo "::error::Detected $LEAKS memory leak(s)"
          exit 1
        fi

    - name: Generate Coverage
      if: inputs.coverage == 'true'
      shell: bash
      run: |
        echo "Generating coverage report..."
        # Coverage logic here

    - name: Upload Results
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: test-results-${{ runner.os }}
        path: |
          leak-report.txt
          coverage/
```

---

## Matrix Strategy Optimization

### Overview

Matrix strategies allow running jobs across multiple configurations simultaneously, essential for cross-platform compiled language projects.

**Key Concepts:**
- Automatic job multiplication across matrix variables
- Support for multi-dimensional matrices
- Fine-grained control via `include` and `exclude`
- Fail-fast and max-parallel controls

### Official Documentation

- **Primary Docs:** https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstrategy
- **Tutorial:** https://codefresh.io/learn/github-actions/github-actions-matrix/
- **Advanced Guide:** https://depot.dev/blog/github-actions-matrix-strategy

### Basic Matrix Configuration

```yaml
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        odin-version: ['dev-2025-10', 'dev-2025-09']
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: odin build src -o:speed
```

This creates **6 jobs** (3 OS × 2 versions)

### Multi-Dimensional Matrices

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-14, windows-latest]
    arch: [x86_64, arm64]
    build-mode: [debug, release]
    # This creates 3 × 2 × 2 = 12 jobs
```

### Include and Exclude Controls

#### Include: Add Specific Configurations

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-14]
    arch: [x86_64]
    include:
      # Add ARM build only for macOS
      - os: macos-14
        arch: arm64
        runner: macos-14-xlarge
      # Add FreeBSD with specific runner
      - os: freebsd
        arch: x86_64
        runner: ubuntu-latest
        use-emulator: true
```

#### Exclude: Remove Invalid Combinations

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-13, macos-14, windows-latest]
    arch: [x86_64, arm64]
    exclude:
      # No ARM Windows builds
      - os: windows-latest
        arch: arm64
      # No ARM Ubuntu (use emulator instead)
      - os: ubuntu-latest
        arch: arm64
      # macOS 13 is Intel only
      - os: macos-13
        arch: arm64
```

### Optimization Strategies

#### 1. Strategic Platform Selection

```yaml
strategy:
  matrix:
    include:
      # Tier 1: Primary platforms (fast feedback)
      - name: macOS ARM (Primary)
        os: macos-14
        arch: arm64
        odin-flags: "-o:speed"

      - name: Ubuntu LTS (Primary)
        os: ubuntu-22.04
        arch: x86_64
        odin-flags: "-o:speed"

      # Tier 2: Secondary platforms (comprehensive testing)
      - name: macOS Intel
        os: macos-13
        arch: x86_64
        odin-flags: "-o:speed"

      - name: Windows x64
        os: windows-latest
        arch: x86_64
        odin-flags: "-o:speed"

      # Tier 3: Extended platforms (nightly/release only)
      - name: FreeBSD (Emulated)
        os: ubuntu-latest
        arch: x86_64
        emulator: true
        odin-flags: "-o:speed"
```

#### 2. Conditional Matrix Based on Event

```yaml
jobs:
  determine-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        run: |
          if [[ "${{ github.event_name }}" == "pull_request" ]]; then
            # PR: Fast feedback only
            echo 'matrix={"os":["ubuntu-latest","macos-14"]}' >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            # Main: Full cross-platform
            echo 'matrix={"os":["ubuntu-latest","macos-14","macos-13","windows-latest"]}' >> $GITHUB_OUTPUT
          else
            # Feature branches: Single platform
            echo 'matrix={"os":["ubuntu-latest"]}' >> $GITHUB_OUTPUT
          fi

  build:
    needs: determine-matrix
    strategy:
      matrix: ${{ fromJSON(needs.determine-matrix.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
```

#### 3. Max Parallel Control

```yaml
strategy:
  max-parallel: 2  # Limit concurrent jobs (cost control)
  matrix:
    os: [ubuntu-latest, macos-13, macos-14, windows-latest]
```

**Use Cases for max-parallel:**
- **Cost control:** Limit GitHub-hosted runner minutes
- **Resource limits:** Shared self-hosted runners
- **Rate limiting:** External API calls during tests
- **License limits:** Tools with concurrent user limits

#### 4. Fail-Fast Configuration

```yaml
strategy:
  fail-fast: false  # Continue all jobs even if one fails
  matrix:
    os: [ubuntu-latest, macos-14, windows-latest]
```

See [Fail-Fast vs Complete Testing](#fail-fast-vs-complete-testing) section for details.

### Real-World Example: Odin Language CI Matrix

Based on the official Odin repository workflow:

```yaml
name: Cross-Platform CI

on: [push, pull_request, workflow_dispatch]

jobs:
  # Tier 1: Emulated platforms (extended testing)
  test-bsd:
    strategy:
      matrix:
        include:
          - name: NetBSD
            os: ubuntu-latest
            emulator: netbsd
          - name: FreeBSD
            os: ubuntu-latest
            emulator: freebsd
          - name: Linux RISC-V64
            os: ubuntu-latest
            emulator: riscv64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Test with Emulator
        uses: cross-platform-actions/action@v0.23.0
        with:
          operating_system: ${{ matrix.emulator }}
          run: |
            odin build src
            odin test tests -all-packages

  # Tier 2: Primary platforms (matrix)
  test-main:
    strategy:
      fail-fast: false
      matrix:
        include:
          - name: macOS ARM
            os: macos-14
            arch: arm64
          - name: macOS Intel
            os: macos-13
            arch: x86_64
          - name: Ubuntu
            os: ubuntu-latest
            arch: x86_64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Build Compiler
        run: |
          odin build src
          odin version

      - name: Run Core Tests
        run: odin test tests -all-packages

      - name: Test Examples
        run: |
          cd examples
          odin build . -o:speed

  # Tier 3: Windows (separate job)
  test-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - run: odin build src
      - run: odin test tests -all-packages
```

### Dynamic Matrix Generation

For advanced scenarios, generate matrices programmatically:

```yaml
jobs:
  generate-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.generate.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - id: generate
        run: |
          # Read from file or generate based on conditions
          MATRIX=$(cat .github/test-matrix.json)
          echo "matrix=$MATRIX" >> $GITHUB_OUTPUT

  test:
    needs: generate-matrix
    strategy:
      matrix: ${{ fromJSON(needs.generate-matrix.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
```

### Best Practices

1. **Start Small:** Begin with 2-3 platforms, expand as needed
2. **Use Include/Exclude:** More maintainable than complex conditionals
3. **Name Your Builds:** Use `name:` in include for clear identification
4. **Platform-Specific Flags:** Add custom variables per configuration
5. **Conditional Matrix:** Scale testing based on trigger event
6. **Fail-Fast Decision:** See dedicated section below
7. **Cost Management:** Use max-parallel for expensive runners

---

## Artifact Sharing Between Jobs

### Overview

Artifacts enable sharing files between jobs in a workflow and persisting data after workflow completion. Critical for multi-job cross-platform builds.

**Version 4 Features (2024+):**
- Cross-workflow artifact sharing
- Improved validation and integrity checks
- Updated to Node.js 20
- Immutable artifacts (must use unique names)

### Official Documentation

- **Primary Docs:** https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts
- **Actions Repo:** https://github.com/actions/upload-artifact and https://github.com/actions/download-artifact
- **Best Practices:** https://cicube.io/blog/github-actions-outputs/

### Basic Usage

#### Upload Artifact

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Library
        run: odin build src -build-mode:shared -out:libocsv.so

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ocsv-linux-x64
          path: libocsv.so
          retention-days: 7  # Default: repository setting
          compression-level: 6  # 0 (none) to 9 (best), default: 6
          if-no-files-found: error  # error, warn, or ignore
```

#### Download Artifact (Same Workflow)

```yaml
jobs:
  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Artifact
        uses: actions/download-artifact@v4
        with:
          name: ocsv-linux-x64
          path: ./dist  # Downloads to ./dist/libocsv.so

      - name: Run Tests
        run: |
          ls -lh ./dist/
          ./run-tests.sh
```

#### Download Artifact (Cross-Workflow) - v4 Feature

```yaml
- name: Download from Different Workflow
  uses: actions/download-artifact@v4
  with:
    name: ocsv-linux-x64
    github-token: ${{ secrets.GITHUB_TOKEN }}
    run-id: ${{ inputs.build-run-id }}  # From trigger workflow
```

### Artifact Patterns for Multi-Platform Builds

#### Pattern 1: Build Matrix → Single Test Job

```yaml
jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            artifact: ocsv-linux-x64
            ext: so
          - os: macos-14
            artifact: ocsv-macos-arm64
            ext: dylib
          - os: windows-latest
            artifact: ocsv-windows-x64
            ext: dll
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: odin build src -build-mode:shared -out:libocsv.${{ matrix.ext }}

      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: libocsv.${{ matrix.ext }}

  test:
    needs: build
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/download-artifact@v4
        with:
          name: ocsv-${{ runner.os }}-${{ runner.arch }}

      - name: Run Tests
        run: odin test tests -all-packages
```

#### Pattern 2: Merge Artifacts from Multiple Builds

```yaml
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - run: odin build src -build-mode:shared
      - uses: actions/upload-artifact@v4
        with:
          name: libs-${{ runner.os }}
          path: libocsv.*

  package:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download All Artifacts
        uses: actions/download-artifact@v4
        with:
          path: ./all-libs

      - name: Create Release Package
        run: |
          cd all-libs
          tar -czf ../ocsv-multi-platform.tar.gz *

      - uses: actions/upload-artifact@v4
        with:
          name: ocsv-release-bundle
          path: ocsv-multi-platform.tar.gz
```

#### Pattern 3: Conditional Artifact Upload (Save Costs)

```yaml
- name: Upload Artifacts (Main Branch Only)
  if: github.ref == 'refs/heads/main'
  uses: actions/upload-artifact@v4
  with:
    name: ocsv-${{ runner.os }}
    path: libocsv.*
    retention-days: 30

- name: Upload Artifacts (PR)
  if: github.event_name == 'pull_request'
  uses: actions/upload-artifact@v4
  with:
    name: ocsv-${{ runner.os }}-pr${{ github.event.number }}
    path: libocsv.*
    retention-days: 7  # Shorter retention for PRs
```

### Job Outputs vs Artifacts

Use job outputs for small data, artifacts for large files.

#### Job Outputs (Small Data)

```yaml
jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.value }}
      build-flags: ${{ steps.flags.outputs.value }}
    steps:
      - id: version
        run: echo "value=1.1.0" >> $GITHUB_OUTPUT
      - id: flags
        run: echo "value=-o:speed -debug" >> $GITHUB_OUTPUT

  build:
    needs: setup
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building version ${{ needs.setup.outputs.version }}"
      - run: odin build src ${{ needs.setup.outputs.build-flags }}
```

#### Artifacts (Large Files)

Use for binaries, libraries, test reports, coverage data, deployment packages.

### Best Practices

1. **Unique Names:** v4 requires unique artifact names per upload
2. **Descriptive Naming:** Include OS, arch, version in artifact names
3. **Retention Management:** Use shorter retention for PRs (7 days), longer for releases (30+ days)
4. **Compression:** Adjust `compression-level` based on file types (already compressed files: use 0)
5. **Error Handling:** Set `if-no-files-found` appropriately
6. **Size Limits:** 10GB per repository, plan accordingly
7. **Cleanup:** Old artifacts count toward storage quota
8. **Integrity:** v4 automatically validates checksums
9. **Security:** Artifacts are accessible to anyone with repo access

### Example: OCSV Cross-Platform Build & Release

```yaml
name: Release Build

on:
  push:
    tags: ['v*']

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-22.04
            name: linux-x64
            ext: so
          - os: macos-14
            name: macos-arm64
            ext: dylib
          - os: macos-13
            name: macos-x64
            ext: dylib
          - os: windows-latest
            name: windows-x64
            ext: dll
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Odin
        uses: ./.github/actions/setup-odin

      - name: Build Release
        run: odin build src -build-mode:shared -out:libocsv.${{ matrix.ext }} -o:speed

      - name: Run Tests
        run: odin test tests -all-packages

      - name: Package
        run: |
          mkdir ocsv-${{ matrix.name }}
          cp libocsv.${{ matrix.ext }} ocsv-${{ matrix.name }}/
          cp README.md LICENSE ocsv-${{ matrix.name }}/
          tar -czf ocsv-${{ matrix.name }}.tar.gz ocsv-${{ matrix.name }}

      - uses: actions/upload-artifact@v4
        with:
          name: ocsv-${{ matrix.name }}
          path: ocsv-${{ matrix.name }}.tar.gz
          retention-days: 90

  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: ./artifacts

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: artifacts/**/*.tar.gz
          draft: false
          prerelease: false
```

---

## Fail-Fast vs Complete Testing

### Overview

The `fail-fast` strategy controls whether GitHub Actions cancels remaining matrix jobs when one fails. Critical decision for cross-platform testing.

**Default Behavior:** `fail-fast: true` (cancel all jobs on first failure)

### Official Documentation

- **Primary Docs:** https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstrategyfail-fast
- **Best Practices:** https://codefresh.io/learn/github-actions/github-actions-matrix/

### Configuration

```yaml
strategy:
  fail-fast: true  # Default: cancel on first failure
  # OR
  fail-fast: false  # Run all jobs regardless of failures
  matrix:
    os: [ubuntu-latest, macos-14, windows-latest]
```

### Decision Matrix

| Scenario | Fail-Fast Setting | Reasoning |
|----------|------------------|-----------|
| **PR Builds** | `true` | Fast feedback, save resources |
| **Main Branch** | `false` | Need complete platform coverage |
| **Release Tags** | `false` | Must know all platform issues |
| **Nightly Builds** | `false` | Comprehensive testing |
| **Development** | `true` | Quick iteration |
| **Security Patches** | `false` | Verify all platforms |

### Use Cases

#### Fail-Fast: True (Quick Feedback)

**Best for:**
- Pull request validation
- Development branches
- Rapid iteration workflows
- Cost-sensitive CI (save runner minutes)
- Obvious failures (syntax errors, compilation failures)

**Advantages:**
- **Fast feedback:** Developers know immediately something is wrong
- **Cost savings:** Stop wasting minutes on doomed builds
- **Resource efficiency:** Free up runners for other workflows

**Example:**
```yaml
name: PR Validation

on:
  pull_request:
    branches: [main]

jobs:
  quick-check:
    strategy:
      fail-fast: true  # Stop immediately on any failure
      matrix:
        os: [ubuntu-latest, macos-14]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Quick Build
        run: odin build src
      - name: Smoke Tests
        run: odin test tests -define:ODIN_TEST_NAMES=tests.test_parser
```

#### Fail-Fast: False (Complete Coverage)

**Best for:**
- Main/production branch commits
- Release builds
- Comprehensive testing
- Platform-specific bugs
- Cross-platform validation
- Debugging flaky tests

**Advantages:**
- **Complete picture:** See all platform failures, not just the first
- **Platform-specific issues:** macOS might pass while Windows fails
- **Debugging:** Compare failure patterns across platforms
- **Comprehensive reports:** All results available for analysis

**Example:**
```yaml
name: Comprehensive CI

on:
  push:
    branches: [main, develop]
  release:
    types: [created]

jobs:
  full-test:
    strategy:
      fail-fast: false  # Test all platforms even if one fails
      matrix:
        include:
          - os: ubuntu-22.04
            name: Linux x64
          - os: macos-14
            name: macOS ARM
          - os: macos-13
            name: macOS Intel
          - os: windows-latest
            name: Windows x64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Odin
        uses: ./.github/actions/setup-odin

      - name: Build
        run: odin build src -build-mode:shared

      - name: Full Test Suite
        run: odin test tests -all-packages

      - name: Memory Leak Check
        run: odin test tests -all-packages -debug

      - name: Upload Results (Always)
        if: always()  # Run even if tests fail
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.name }}
          path: |
            test-output/
            leak-report.txt
```

### Hybrid Approach: Two-Stage Testing

Combine both strategies for optimal balance:

```yaml
name: Hybrid CI

on: [push, pull_request]

jobs:
  # Stage 1: Fast feedback (fail-fast)
  quick-validation:
    strategy:
      fail-fast: true
      matrix:
        os: [ubuntu-latest]  # Single platform for speed
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Quick Build
        run: odin build src -o:speed
      - name: Smoke Tests
        run: odin test tests -define:ODIN_TEST_NAMES=tests.test_parser,tests.test_edge_cases

  # Stage 2: Comprehensive testing (no fail-fast)
  full-cross-platform:
    needs: quick-validation  # Only run if quick validation passes
    if: github.ref == 'refs/heads/main' || github.event_name == 'release'
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-14, macos-13, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Full Build
        run: odin build src -build-mode:shared -o:speed
      - name: Complete Test Suite
        run: odin test tests -all-packages
```

### Important Note: Continue-on-Error vs Fail-Fast

**DO NOT confuse these two settings:**

```yaml
# WRONG: This marks failures as success
jobs:
  test:
    continue-on-error: true  # BAD: Job shows green even if it fails
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14]

# RIGHT: Use fail-fast for matrix control
jobs:
  test:
    strategy:
      fail-fast: false  # GOOD: Job shows red on failure, others continue
      matrix:
        os: [ubuntu-latest, macos-14]
```

**Key Difference:**
- `continue-on-error: true` → Failed job reports as successful (green check)
- `fail-fast: false` → Failed job reports as failed (red X), but doesn't cancel others

### Real-World Example: OCSV Testing Strategy

```yaml
name: OCSV CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  # Quick PR validation
  pr-check:
    if: github.event_name == 'pull_request'
    strategy:
      fail-fast: true  # Fast feedback for PRs
      matrix:
        os: [ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-odin
      - run: odin build src
      - run: odin test tests -all-packages

  # Comprehensive main branch testing
  main-branch-test:
    if: github.ref == 'refs/heads/main'
    strategy:
      fail-fast: false  # Complete platform coverage
      matrix:
        include:
          - os: ubuntu-22.04
            name: Linux
          - os: macos-14
            name: macOS-ARM
          - os: macos-13
            name: macOS-Intel
          - os: windows-latest
            name: Windows
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: ./.github/actions/setup-odin

      - name: Build Library
        run: odin build src -build-mode:shared -o:speed

      - name: Run All Tests
        run: odin test tests -all-packages

      - name: Memory Leak Detection
        run: odin test tests -all-packages -debug -define:USE_TRACKING_ALLOCATOR=true

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.name }}
          path: test-output/
```

### Performance Impact

**Fail-Fast: True**
- Best case: 1 job runtime (if first job fails)
- Worst case: Full matrix runtime (if all pass)
- Cost savings: 50-90% on failed builds

**Fail-Fast: False**
- Best case: Full matrix runtime
- Worst case: Full matrix runtime
- Cost savings: 0% (always runs all jobs)
- Benefit: Complete test coverage

### Recommendations for OCSV

1. **PR Builds:** Use `fail-fast: true` with single platform (Ubuntu) for speed
2. **Main Branch:** Use `fail-fast: false` with all platforms
3. **Release Tags:** Always use `fail-fast: false`
4. **Development Branches:** Use `fail-fast: true` with 1-2 platforms
5. **Nightly Builds:** Use `fail-fast: false` with extended platform matrix

---

## Parallel vs Sequential Execution

### Overview

GitHub Actions jobs run in parallel by default unless explicitly configured with dependencies. Understanding when to parallelize vs serialize is crucial for performance and correctness.

**Default Behavior:** Jobs run in parallel
**Sequential Control:** Use `needs:` keyword

### Official Documentation

- **Primary Docs:** https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds
- **Concurrency Control:** https://docs.github.com/en/actions/using-jobs/using-concurrency

### Parallel Execution (Default)

```yaml
jobs:
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building Linux"

  build-macos:
    runs-on: macos-14
    steps:
      - run: echo "Building macOS"

  build-windows:
    runs-on: windows-latest
    steps:
      - run: echo "Building Windows"

# All three jobs run simultaneously
```

**Best for:**
- Independent builds (different platforms)
- Parallel testing (different test suites)
- Unrelated workflows
- Maximum speed

### Sequential Execution (Dependencies)

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Linting code"

  build:
    needs: lint  # Waits for lint to complete
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building"

  test:
    needs: build  # Waits for build to complete
    runs-on: ubuntu-latest
    steps:
      - run: echo "Testing"

  deploy:
    needs: test  # Waits for test to complete
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying"

# Execution order: lint → build → test → deploy
```

**Best for:**
- Pipeline stages (lint → build → test → deploy)
- Dependencies between jobs
- Artifact-dependent workflows
- Resource-constrained environments

### Hybrid: Parallel + Sequential

```yaml
jobs:
  # Stage 1: Parallel builds
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - run: odin build src -out:libocsv.so

  build-macos:
    runs-on: macos-14
    steps:
      - run: odin build src -out:libocsv.dylib

  build-windows:
    runs-on: windows-latest
    steps:
      - run: odin build src -out:libocsv.dll

  # Stage 2: Test after all builds complete
  test:
    needs: [build-linux, build-macos, build-windows]
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - run: odin test tests -all-packages

  # Stage 3: Deploy after all tests pass
  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying to production"
```

### Concurrency Groups (Prevent Duplicate Runs)

Concurrency groups prevent multiple instances of the same workflow from running simultaneously, critical for preventing race conditions and wasted resources.

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

# Prevent multiple concurrent runs on the same branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancel older runs when new one starts

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: odin build src
```

#### Concurrency Group Patterns

**Pattern 1: Per-PR Concurrency**
```yaml
concurrency:
  group: ci-${{ github.head_ref }}  # PR branch name
  cancel-in-progress: true
```

**Pattern 2: Per-Branch Concurrency**
```yaml
concurrency:
  group: ci-${{ github.ref }}  # Branch ref
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}  # Only cancel PRs
```

**Pattern 3: Global Workflow Concurrency**
```yaml
concurrency:
  group: ${{ github.workflow }}  # One run at a time, globally
  cancel-in-progress: false
```

**Pattern 4: Per-Matrix Concurrency**
```yaml
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
    concurrency:
      group: build-${{ matrix.os }}-${{ github.ref }}
      cancel-in-progress: true
    runs-on: ${{ matrix.os }}
```

### Cost Optimization with Concurrency

**Scenario:** Developer pushes 5 commits in rapid succession

**Without concurrency control:**
```
Commit 1: Starts CI (10 min)
Commit 2: Starts CI (10 min)  ← Wasted
Commit 3: Starts CI (10 min)  ← Wasted
Commit 4: Starts CI (10 min)  ← Wasted
Commit 5: Starts CI (10 min)  ← Only this matters
Total: 50 minutes
```

**With cancel-in-progress:**
```
Commit 1: Starts CI (canceled after 30s)
Commit 2: Starts CI (canceled after 20s)
Commit 3: Starts CI (canceled after 15s)
Commit 4: Starts CI (canceled after 10s)
Commit 5: Starts CI (10 min)
Total: ~11 minutes (78% savings!)
```

### Max-Parallel Control

Limit number of jobs running concurrently within a matrix:

```yaml
jobs:
  build:
    strategy:
      max-parallel: 2  # Only 2 jobs at a time
      matrix:
        os: [ubuntu-latest, macos-13, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
```

**Use cases:**
- **Cost control:** Limit GitHub-hosted runner usage
- **Resource limits:** Shared self-hosted runners
- **Rate limiting:** External API calls
- **License constraints:** Tools with concurrent user limits

### Account Concurrency Limits

GitHub imposes account-level limits on concurrent jobs:

| Account Type | Linux/Windows Jobs | macOS Jobs |
|--------------|-------------------|------------|
| Free | 20 | 5 |
| Pro | 40 | 5 |
| Team | 60 | 5 |
| Enterprise | 500 | 50 |

**Self-hosted runners:** No concurrency limits (but 1 job per runner instance)

### Decision Tree: Parallel vs Sequential

```
Should Job B wait for Job A?
├─ Yes: Job B needs artifacts from Job A
│  └─ Use `needs: job-a`
├─ Yes: Job B should only run if Job A succeeds
│  └─ Use `needs: job-a`
├─ Yes: Limited runners/licenses
│  └─ Use `needs:` or `max-parallel:`
├─ No: Jobs are independent
│  └─ Run in parallel (no `needs:`)
└─ Maybe: Want to prevent duplicate runs
   └─ Use `concurrency:` group
```

### Real-World Example: OCSV Optimized CI

```yaml
name: OCSV Optimized CI

on:
  push:
    branches: [main, develop]
  pull_request:

# Prevent duplicate runs on same PR/branch
concurrency:
  group: ocsv-ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  # Stage 1: Quick validation (gates later stages)
  quick-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-odin
      - name: Lint & Format Check
        run: odin fmt -check src tests
      - name: Quick Build
        run: odin build src -o:speed
      - name: Smoke Test
        run: odin test tests -define:ODIN_TEST_NAMES=tests.test_parser

  # Stage 2: Parallel cross-platform builds
  build:
    needs: quick-check  # Only if validation passes
    strategy:
      fail-fast: false
      max-parallel: 4  # All platforms at once
      matrix:
        include:
          - os: ubuntu-22.04
            name: linux
            ext: so
          - os: macos-14
            name: macos-arm64
            ext: dylib
          - os: macos-13
            name: macos-x64
            ext: dylib
          - os: windows-latest
            name: windows
            ext: dll
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: ./.github/actions/setup-odin
        with:
          cache: true

      - name: Build Library
        run: odin build src -build-mode:shared -out:libocsv.${{ matrix.ext }} -o:speed

      - uses: actions/upload-artifact@v4
        with:
          name: ocsv-${{ matrix.name }}
          path: libocsv.${{ matrix.ext }}

  # Stage 3: Parallel testing (after all builds complete)
  test:
    needs: build
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-22.04
            name: linux
          - os: macos-14
            name: macos-arm64
          - os: windows-latest
            name: windows
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/download-artifact@v4
        with:
          name: ocsv-${{ matrix.name }}

      - uses: ./.github/actions/setup-odin

      - name: Run Full Test Suite
        run: odin test tests -all-packages

      - name: Memory Leak Check
        run: odin test tests -all-packages -debug -define:USE_TRACKING_ALLOCATOR=true

  # Stage 4: Integration tests (after platform tests pass)
  integration:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Integration Tests
        run: ./scripts/integration-tests.sh

  # Stage 5: Deployment (only on main, after everything passes)
  deploy:
    needs: [test, integration]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to NPM
        run: echo "Deploying..."
```

**Execution Flow:**
```
quick-check (1 job, ~2 min)
    ↓
build (4 parallel jobs, ~5 min)
    ↓
test (3 parallel jobs, ~8 min)
    ↓
integration (1 job, ~5 min)
    ↓
deploy (1 job, ~2 min)

Total wall time: ~22 minutes
Total compute time: ~60 minutes (4+3+1+1+1 jobs)
```

### Best Practices

1. **Default to Parallel:** Unless dependencies exist
2. **Use Concurrency Groups:** Prevent duplicate runs (can save 10%+ of CI costs)
3. **Gate Stages:** Quick checks before expensive operations
4. **Balance max-parallel:** Consider cost vs speed
5. **Fail-Fast Strategy:** Use with parallel jobs for cost control
6. **Cancel-in-Progress:** Enable for PRs, consider disabling for main branch
7. **Job Names:** Use descriptive names for debugging

---

## Resource and Cost Optimization

### Overview

GitHub Actions costs can escalate quickly for compiled language projects with cross-platform builds. Strategic optimization can reduce costs by 30-90% while maintaining or improving performance.

### Cost Structure (GitHub-Hosted Runners)

**Per-Minute Pricing (Private Repositories):**
- **Linux:** $0.008/minute
- **Windows:** $0.016/minute (2x Linux)
- **macOS:** $0.08/minute (10x Linux!)

**Free Tier Allowances:**
- **GitHub Free:** 2,000 minutes/month
- **GitHub Pro:** 3,000 minutes/month
- **GitHub Team:** 3,000 minutes/month
- **GitHub Enterprise:** 50,000 minutes/month

**Public repositories:** Unlimited minutes for all account types

### Cost Comparison: GitHub-Hosted vs Self-Hosted

#### GitHub-Hosted Runners

**Advantages:**
- Zero infrastructure management
- Always up-to-date
- Automatic scaling
- No maintenance overhead

**Disadvantages:**
- Expensive at scale (especially macOS)
- Limited to GitHub's runner configurations
- No customization
- Network egress costs

**Example Monthly Cost:**
```
Project: 100 builds/month
Each build: 3 platforms × 10 minutes = 30 minutes

Linux only:   100 × 30min × $0.008 = $24/month
Mixed (LMW):  100 × (10×$0.008 + 10×$0.008 + 10×$0.08) = $96/month
macOS heavy:  100 × 20×$0.08 + 10×$0.008 = $1,608/month
```

#### Self-Hosted Runners

**Advantages:**
- 85-90% cost savings at scale
- Full customization
- No per-minute charges from GitHub
- Faster builds with caching/local resources
- Control over hardware specifications

**Disadvantages:**
- Infrastructure management overhead
- Security responsibilities
- Setup complexity
- Maintenance burden
- Hidden costs (network, storage, time)

**Cost Analysis:**
```
AWS EC2 c6i.2xlarge (8 vCPU, 16GB): ~$0.34/hour = $250/month (24/7)
AWS Spot Instance: ~$0.10/hour = $73/month (24/7)
GitHub-hosted equivalent: ~$2,500/month for same usage

Savings: 70-90% (but add 10-20% for management overhead)
```

**When Self-Hosted Makes Sense:**
- **High volume:** >10,000 build minutes/month
- **Existing infrastructure:** Already managing servers
- **Compliance needs:** Data residency requirements
- **Heavy macOS usage:** Biggest savings opportunity
- **Custom hardware:** GPU, ARM, exotic platforms

**Official Guidance:** https://github.blog/enterprise-software/ci-cd/when-to-choose-github-hosted-runners-or-self-hosted-runners-with-github-actions/

### Optimization Strategies

#### 1. Caching Dependencies

**Impact:** 50-92% build time reduction

```yaml
- name: Cache Odin Compiler
  uses: actions/cache@v4
  with:
    path: |
      ~/odin
      ~/.odin
    key: ${{ runner.os }}-odin-${{ hashFiles('.odin-version') }}
    restore-keys: |
      ${{ runner.os }}-odin-

- name: Cache Build Artifacts
  uses: actions/cache@v4
  with:
    path: |
      target/
      .build-cache/
    key: ${{ runner.os }}-build-${{ hashFiles('src/**/*.odin') }}
    restore-keys: |
      ${{ runner.os }}-build-
```

**Best Practices:**
- **Specific Keys:** Include OS, architecture, dependency versions
- **Restore Keys:** Provide fallback patterns
- **Limit Size:** 10GB per repository total
- **Expire Old Caches:** Use date-based keys for periodic refresh
- **Cache Hit Rate:** Monitor and optimize key patterns

**Language-Specific Caching:**

**Rust:**
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      target/
    key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
```

**Go:**
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/go/pkg/mod
      ~/.cache/go-build
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
```

#### 2. Concurrency Groups

**Impact:** 10-30% cost reduction from preventing duplicate runs

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Scenario:** 5 rapid commits to PR branch
- **Without concurrency:** 5 full builds = 50 minutes
- **With cancel-in-progress:** 1 full build + 4 canceled = ~12 minutes (76% savings)

#### 3. Matrix Optimization

**Strategy:** Tier your testing based on importance

```yaml
jobs:
  # Tier 1: Fast feedback (always run)
  quick-check:
    runs-on: ubuntu-latest  # Cheapest runner
    steps:
      - run: odin build src -o:minimal

  # Tier 2: Full cross-platform (main branch only)
  full-test:
    if: github.ref == 'refs/heads/main'
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
```

**Cost Comparison:**
```
Every commit (PRs + main):
  Option A: Always test all 3 platforms = 30 min/commit
  Option B: PRs test Linux only (2 min), main tests all (30 min)

100 commits/month (80 PRs, 20 main):
  Option A: 100 × 30 = 3,000 minutes
  Option B: 80 × 2 + 20 × 30 = 760 minutes (75% savings)
```

#### 4. Conditional Job Execution

```yaml
jobs:
  expensive-job:
    if: |
      github.ref == 'refs/heads/main' ||
      contains(github.event.head_commit.message, '[full-ci]')
    runs-on: macos-14  # Expensive runner
```

**Triggers:**
- `[full-ci]` in commit message
- `[skip-ci]` to skip CI entirely
- File path filters: `paths: ['src/**', 'tests/**']`

#### 5. Workflow Path Filters

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'tests/**'
      - '.github/workflows/**'
    paths-ignore:
      - 'docs/**'
      - '**.md'
```

**Savings:** Avoid running CI on documentation changes

#### 6. Artifact Retention

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/
    retention-days: 7  # Default: 90 days
```

**Cost Impact:**
- Artifacts count toward storage quota
- Shorter retention = lower costs
- Recommended: 7 days for PRs, 30 days for releases

#### 7. Optimized Timeouts

```yaml
jobs:
  build:
    timeout-minutes: 30  # Default: 360 (6 hours!)
    runs-on: ubuntu-latest
```

**Best Practice:** Set to ~3x average runtime to prevent runaway jobs

#### 8. Selective Dependency Installation

```bash
# Bad: Install everything
npm install

# Good: Install only production dependencies
npm ci --production

# Better: Install specific packages
npm ci --only=production --omit=dev
```

#### 9. Docker Layer Caching (for containerized builds)

```yaml
- name: Build Docker Image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: false
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

#### 10. Fail-Fast Strategy

```yaml
strategy:
  fail-fast: true  # Stop expensive jobs on first failure
  matrix:
    os: [ubuntu-latest, macos-14, windows-latest]
```

**Cost Savings:** Stop wasting minutes when build is already broken

### Cost Monitoring

**GitHub Actions Metrics:** https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/about-monitoring-and-troubleshooting

**Key Metrics to Track:**
- Workflow run time (by job, by platform)
- Cache hit rates
- Canceled vs completed runs
- Runner utilization
- Monthly minutes used

**Tools:**
- GitHub Actions Usage API
- `workflow-telemetry-action` for resource monitoring
- Third-party: BuildPulse, Blacksmith

### OCSV Cost Optimization Example

**Before Optimization:**
```yaml
# Every commit builds all platforms: ~25 min
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-13, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - run: odin build src  # No caching
      - run: odin test tests -all-packages

# 100 commits/month × 25 min = 2,500 minutes
# Cost: ~$400/month (with macOS)
```

**After Optimization:**
```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    paths: ['src/**', 'tests/**', '.github/**']

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quick-check:
    runs-on: ubuntu-latest  # Cheap!
    steps:
      - uses: actions/cache@v4  # Cache Odin
        with:
          path: ~/odin
          key: ${{ runner.os }}-odin-${{ hashFiles('.odin-version') }}
      - run: odin build src -o:minimal
      - run: odin test tests -define:ODIN_TEST_NAMES=tests.test_parser

  full-test:
    if: github.ref == 'refs/heads/main'  # Only on main
    strategy:
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/cache@v4
      - run: odin build src -o:speed
      - run: odin test tests -all-packages

# 80 PRs × 2 min + 20 main × 25 min = 660 minutes
# Cost: ~$105/month (74% savings!)
```

### Best Practices Summary

1. **Cache Aggressively:** Dependencies, compilers, build outputs
2. **Use Concurrency Groups:** Prevent duplicate runs
3. **Tier Testing:** Quick checks on PRs, full tests on main
4. **Choose Runners Wisely:** Linux for most tasks, macOS only when necessary
5. **Set Timeouts:** Prevent runaway jobs
6. **Monitor Usage:** Track metrics and optimize bottlenecks
7. **Conditional Execution:** Use path filters and branch conditions
8. **Artifact Retention:** Short for PRs, longer for releases
9. **Fail-Fast Strategy:** Don't waste minutes on broken builds
10. **Self-Host at Scale:** Consider for >10k minutes/month

---

## Real-World Examples

### 1. Odin Language Official CI

**Source:** https://github.com/odin-lang/Odin/blob/master/.github/workflows/ci.yml

**Key Features:**
- Multi-platform testing (macOS ARM, macOS Intel, Ubuntu, Windows)
- Emulated platform support (NetBSD, FreeBSD, RISC-V)
- Comprehensive testing: core tests, vendor tests, examples compilation
- Cross-compilation validation (WASM, alternative architectures)
- Strict compiler flags (warnings as errors, address sanitization)

**Architecture:**
```yaml
# Simplified structure
on: [push, pull_request, workflow_dispatch]

jobs:
  # Emulated platforms
  test-bsd:
    strategy:
      matrix:
        platform: [netbsd, freebsd, riscv64]
    uses: cross-platform-actions/action@v0.23.0

  # Main platforms
  test-main:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: macos-14     # ARM
          - os: macos-13     # Intel
          - os: ubuntu-latest
    steps:
      - Build compiler
      - Run core tests
      - Test vendor libraries
      - Compile examples

  # Windows (separate)
  test-windows:
    runs-on: windows-latest
```

**Lessons for OCSV:**
- Separate jobs for emulated platforms
- Platform-specific optimizations
- Comprehensive test coverage across architectures

### 2. Rust Cross-Compilation with actions-rust-cross

**Source:** https://github.com/houseabsolute/actions-rust-cross

**Key Features:**
- Automatic `cross` vs `cargo` selection
- Extensive target support (Linux, Windows, macOS, FreeBSD, ARM)
- Built-in caching with `rust-cache`
- Strip binaries for size optimization

**Example Workflow:**
```yaml
jobs:
  release:
    strategy:
      matrix:
        platform:
          - os-name: Linux-x86_64
            runs-on: ubuntu-24.04
            target: x86_64-unknown-linux-musl
          - os-name: Windows-x86_64
            runs-on: windows-latest
            target: x86_64-pc-windows-msvc
          - os-name: macOS-x86_64
            runs-on: macos-latest
            target: x86_64-apple-darwin
          - os-name: macOS-aarch64
            runs-on: macos-latest
            target: aarch64-apple-darwin
    runs-on: ${{ matrix.platform.runs-on }}
    steps:
      - uses: actions/checkout@v4
      - uses: houseabsolute/actions-rust-cross@v1
        with:
          command: build
          target: ${{ matrix.platform.target }}
          args: "--locked --release"
          strip: true
```

**Lessons for OCSV:**
- Matrix includes for platform-specific configuration
- Separate target and runner OS
- Artifact naming with platform identifiers

### 3. Go with GoReleaser

**Source:** Multiple sources including https://carlosbecker.com/posts/multi-platform-docker-images-goreleaser-gh-actions/

**Key Features:**
- Single tool for multi-platform builds
- Automated GitHub release creation
- Docker multi-arch image support
- Changelog generation

**Example Workflow:**
```yaml
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v5
        with:
          go-version: "1.x"

      - uses: goreleaser/goreleaser-action@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          args: release --clean

# .goreleaser.yaml defines build matrix
builds:
  - goos: [linux, freebsd, darwin]
    goarch: [amd64, arm64, arm, ppc64le]
```

**Lessons for OCSV:**
- Tag-based release automation
- Centralized build configuration
- Automatic GitHub release creation

### 4. Reusable Workflow Repository (BretFisher)

**Source:** https://github.com/BretFisher/github-actions-templates

**Key Features:**
- Centralized reusable workflows
- Separate calling templates for projects
- Docker build patterns
- Security scanning integration

**Structure:**
```
.github/
  workflows/
    reusable-docker-build.yaml    # Reusable workflow
    reusable-super-linter.yaml
    reusable-trivy-scan.yaml

templates/
  call-docker-build.yaml          # Copy to project repos
  call-super-linter.yaml
  call-trivy-scan.yaml
```

**Example Reusable Workflow:**
```yaml
# reusable-docker-build.yaml
name: Reusable Docker Build

on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
      platforms:
        required: false
        type: string
        default: "linux/amd64,linux/arm64"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          context: .
          platforms: ${{ inputs.platforms }}
          tags: ${{ inputs.image-name }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Lessons for OCSV:**
- Separate reusable workflows from calling templates
- Organization-level standardization
- Parameterized workflows for flexibility

### 5. Composite Action Template

**Source:** https://github.com/cloudposse-github-actions/composite-template

**Key Features:**
- Template repository for creating composite actions
- Pre-configured README, LICENSE
- Automated testing
- Version management

**Structure:**
```
action.yml              # Main composite action
README.md              # Documentation
LICENSE
.github/
  workflows/
    test.yml           # Test the action
```

**Example Composite Action:**
```yaml
# action.yml
name: 'Setup Build Environment'
description: 'Install and configure build tools'

inputs:
  version:
    description: 'Tool version'
    required: false
    default: 'latest'

runs:
  using: 'composite'
  steps:
    - shell: bash
      run: |
        echo "Setting up build environment"
        # Installation logic
```

**Lessons for OCSV:**
- Create reusable setup actions
- Test composite actions independently
- Version and document thoroughly

### 6. Performance Optimization Case Study

**Source:** GitHub Blog - https://github.blog/engineering/architecture-optimization/how-we-tripled-max-concurrent-jobs-to-boost-performance-of-github-actions/

**Key Findings:**
- **Cache Enablement:** CPU usage reduced by 50%
- **Orchestration Improvements:** 3x concurrent job capacity
- **Postback Optimization:** Reduced redundant API calls

**Before:**
```
Workflow time: 10 minutes
Cache misses: 100%
Redundant postbacks: 3 per job
CPU utilization: High
```

**After:**
```
Workflow time: 3 minutes (70% faster)
Cache hits: 80%
Postback optimization: 1 per job
CPU utilization: 50% lower
```

**Optimization Techniques:**
1. Enable caching for all dependencies
2. Deduplicate API calls
3. Batch status updates
4. Optimize workflow orchestration

**Lessons for OCSV:**
- Caching can provide 70%+ speedup
- Workflow design impacts performance
- Monitor and optimize postback patterns

### 7. Cost Optimization Case Study

**Source:** Medium articles on self-hosted runner migration

**Scenario:** High-volume CI/CD for startup

**Before (GitHub-Hosted):**
```
Monthly builds: 1,000
Average duration: 20 minutes
Platform mix: 50% Linux, 30% macOS, 20% Windows

Cost breakdown:
  Linux: 1000 × 0.5 × 20 × $0.008 = $80
  macOS: 1000 × 0.3 × 20 × $0.08 = $480
  Windows: 1000 × 0.2 × 20 × $0.016 = $64

Total: $624/month
```

**After (Self-Hosted on AWS):**
```
Infrastructure:
  c6i.2xlarge (Linux): $250/month
  mac1.metal (macOS): $650/month (reserved instance)
  c6i.large (Windows): $125/month

Management overhead: $100/month (engineer time)

Total: $1,125/month

Wait, that's MORE expensive!
```

**Actual Optimization:**
```
Hybrid approach:
  Linux: Self-hosted ($250/month)
  macOS: GitHub-hosted (limited to essential tests) = $100/month
  Windows: Self-hosted with spot instances ($40/month)

Total: $390/month (37% savings)
```

**Lessons for OCSV:**
- macOS is the cost driver
- Hybrid approach often best
- Self-hosting isn't always cheaper
- Consider spot instances
- Factor in management time

---

## Recommendations for OCSV

### Immediate Actions

#### 1. Create Composite Action for Odin Setup

```yaml
# .github/actions/setup-odin/action.yml
name: 'Setup Odin Compiler'
description: 'Install and configure Odin for CI builds'

inputs:
  version:
    description: 'Odin version (dev-YYYY-MM or latest)'
    required: false
    default: 'latest'
  cache:
    description: 'Enable caching'
    required: false
    default: 'true'

outputs:
  odin-version:
    description: 'Installed Odin version'
    value: ${{ steps.install.outputs.version }}

runs:
  using: 'composite'
  steps:
    - name: Cache Odin Installation
      if: inputs.cache == 'true'
      uses: actions/cache@v4
      with:
        path: ~/odin
        key: ${{ runner.os }}-${{ runner.arch }}-odin-${{ inputs.version }}
        restore-keys: |
          ${{ runner.os }}-${{ runner.arch }}-odin-

    - name: Install Odin
      id: install
      shell: bash
      run: |
        # Download and install Odin
        echo "version=dev-2025-10" >> $GITHUB_OUTPUT

    - name: Add to PATH
      shell: bash
      run: echo "$HOME/odin/bin" >> $GITHUB_PATH
```

#### 2. Optimize Matrix Strategy

```yaml
# .github/workflows/ci.yml
name: OCSV CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'tests/**'
      - '.github/**'
  pull_request:
    paths:
      - 'src/**'
      - 'tests/**'
      - '.github/**'

concurrency:
  group: ocsv-ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  # Quick PR validation (Linux only)
  quick-check:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4

      - uses: ./.github/actions/setup-odin
        with:
          cache: true

      - name: Build Library
        run: odin build src -build-mode:shared -out:libocsv.so -o:speed

      - name: Run Core Tests
        run: |
          odin test tests -define:ODIN_TEST_NAMES=tests.test_parser
          odin test tests -define:ODIN_TEST_NAMES=tests.test_edge_cases

      - name: Quick Memory Check
        run: odin test tests -debug -define:USE_TRACKING_ALLOCATOR=true

  # Full cross-platform testing (main branch)
  full-test:
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    strategy:
      fail-fast: false
      matrix:
        include:
          - name: Linux x64
            os: ubuntu-22.04
            ext: so
          - name: macOS ARM
            os: macos-14
            ext: dylib
          - name: macOS Intel
            os: macos-13
            ext: dylib
          - name: Windows x64
            os: windows-latest
            ext: dll
    runs-on: ${{ matrix.os }}
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: ./.github/actions/setup-odin
        with:
          cache: true

      - name: Build Library
        run: odin build src -build-mode:shared -out:libocsv.${{ matrix.ext }} -o:speed

      - name: Run Full Test Suite
        run: odin test tests -all-packages

      - name: Memory Leak Detection
        run: odin test tests -all-packages -debug -define:USE_TRACKING_ALLOCATOR=true

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ocsv-${{ matrix.name }}
          path: libocsv.${{ matrix.ext }}
          retention-days: 7

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.name }}
          path: test-output/
          retention-days: 7
```

#### 3. Add Release Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  build-all:
    strategy:
      matrix:
        include:
          - os: ubuntu-22.04
            name: linux-x64
            ext: so
          - os: macos-14
            name: macos-arm64
            ext: dylib
          - os: macos-13
            name: macos-x64
            ext: dylib
          - os: windows-latest
            name: windows-x64
            ext: dll
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: ./.github/actions/setup-odin

      - name: Build Release
        run: odin build src -build-mode:shared -out:libocsv.${{ matrix.ext }} -o:speed

      - name: Run Tests
        run: odin test tests -all-packages

      - name: Package
        shell: bash
        run: |
          mkdir ocsv-${{ matrix.name }}
          cp libocsv.${{ matrix.ext }} ocsv-${{ matrix.name }}/
          cp README.md LICENSE CHANGELOG.md ocsv-${{ matrix.name }}/
          tar -czf ocsv-${{ matrix.name }}.tar.gz ocsv-${{ matrix.name }}

      - uses: actions/upload-artifact@v4
        with:
          name: ocsv-${{ matrix.name }}
          path: ocsv-${{ matrix.name }}.tar.gz
          retention-days: 90

  create-release:
    needs: build-all
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - uses: actions/download-artifact@v4
        with:
          path: ./artifacts

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: artifacts/**/*.tar.gz
          draft: false
          prerelease: ${{ contains(github.ref, 'alpha') || contains(github.ref, 'beta') }}
          generate_release_notes: true
```

### Medium-Term Improvements

#### 4. Add Dependabot for Action Updates

```yaml
# .github/dependabot.yml
version: 2
updates:
  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"
    reviewers:
      - "your-username"
```

#### 5. Implement Workflow Telemetry

```yaml
- name: Workflow Telemetry
  uses: runforesight/workflow-telemetry-action@v1
  with:
    comment-on-pr: ${{ github.event_name == 'pull_request' }}
```

#### 6. Add Nightly Extended Tests

```yaml
# .github/workflows/nightly.yml
name: Nightly Extended Tests

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:

jobs:
  extended:
    strategy:
      fail-fast: false
      matrix:
        include:
          # Standard platforms
          - os: ubuntu-22.04
            name: Linux x64
          - os: macos-14
            name: macOS ARM
          - os: windows-latest
            name: Windows x64
          # Extended platforms (emulated)
          - os: ubuntu-latest
            name: FreeBSD (emulated)
            emulator: freebsd
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Run Extended Tests
        run: |
          odin test tests -all-packages
          # Additional stress tests, fuzzing, etc.
```

### Long-Term Optimizations

#### 7. Consider Self-Hosted Runner for Linux

**When to implement:**
- CI usage exceeds 10,000 minutes/month
- Budget constraints
- Need faster builds

**Setup:**
```yaml
# .github/workflows/ci-hybrid.yml
jobs:
  linux-build:
    runs-on: self-hosted  # Self-hosted Linux runner
    steps:
      - uses: actions/checkout@v4
      - run: odin build src

  macos-build:
    runs-on: macos-14  # Still use GitHub-hosted for macOS
    steps:
      - uses: actions/checkout@v4
      - run: odin build src
```

#### 8. Implement Build Cache Service

For very large projects, consider external caching:
- **BuildKit cache:** Docker layer caching
- **Cachix:** Nix-style caching
- **Buildkite:** Distributed caching

#### 9. Create Organization-Level Reusable Workflows

If managing multiple Odin projects:

```
organization/.github/
  workflows/
    reusable-odin-build.yml
    reusable-odin-test.yml
    reusable-odin-release.yml
```

### Metrics to Track

1. **Workflow Duration:** Track per-platform, optimize slowest
2. **Cache Hit Rate:** Aim for >80%
3. **Monthly Minutes:** Monitor cost trends
4. **Failure Rate:** Identify flaky tests
5. **Queue Time:** Optimize concurrency settings

### Expected Performance

**Current State (estimated):**
- PR build time: ~25 minutes (all platforms)
- Main build time: ~25 minutes (all platforms)
- Monthly minutes: ~2,500

**After Optimization:**
- PR build time: ~5 minutes (Linux only, cached)
- Main build time: ~20 minutes (all platforms, parallel)
- Monthly minutes: ~800 (68% reduction)
- Cost savings: ~$400 → $100/month (75% reduction)

---

## Summary of Key URLs

### Official Documentation
- **Reusable Workflows:** https://docs.github.com/en/actions/using-workflows/reusing-workflows
- **Composite Actions:** https://docs.github.com/en/actions/creating-actions/creating-a-composite-action
- **Workflow Syntax:** https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- **Caching:** https://github.com/actions/cache
- **Artifacts:** https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts
- **Concurrency:** https://docs.github.com/en/actions/using-jobs/using-concurrency
- **Usage Limits:** https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration

### Best Practice Guides
- **Earthly - Reusable Workflows:** https://earthly.dev/blog/github-actions-reusable-workflows/
- **Earthly - Composite Actions:** https://earthly.dev/blog/composite-actions-github/
- **Matrix Strategy:** https://codefresh.io/learn/github-actions/github-actions-matrix/
- **Caching Dependencies:** https://earthly.dev/blog/caching-dependencies-github-actions/
- **Cost Optimization:** https://www.blacksmith.sh/blog/how-to-reduce-spend-in-github-actions

### Real-World Examples
- **Odin CI:** https://github.com/odin-lang/Odin/blob/master/.github/workflows/ci.yml
- **Rust Cross-Compilation:** https://github.com/houseabsolute/actions-rust-cross
- **Reusable Templates:** https://github.com/BretFisher/github-actions-templates
- **Composite Template:** https://github.com/cloudposse-github-actions/composite-template

### Case Studies
- **GitHub Performance:** https://github.blog/engineering/architecture-optimization/how-we-tripled-max-concurrent-jobs-to-boost-performance-of-github-actions/
- **Self-Hosted Runners:** https://github.blog/enterprise-software/ci-cd/when-to-choose-github-hosted-runners-or-self-hosted-runners-with-github-actions/
- **Cost Savings:** https://itsjan.medium.com/cost-savings-our-journey-migrating-to-self-hosted-runners-from-github-runners-53e3e3f1df23

---

## Conclusion

This research demonstrates that GitHub Actions can be highly optimized for cross-platform compiled language projects like OCSV. The key strategies are:

1. **Modularize with Reusable Workflows:** Share complete build/test pipelines
2. **Simplify with Composite Actions:** Package repeated setup steps
3. **Optimize Matrix Strategy:** Smart platform selection and fail-fast controls
4. **Cache Aggressively:** 50-92% build time reduction
5. **Use Concurrency Groups:** Prevent duplicate runs (10-30% cost savings)
6. **Tier Testing:** Quick checks on PRs, full tests on main
7. **Monitor and Iterate:** Track metrics and continuously optimize

**Expected Impact for OCSV:**
- **Build Time:** 25 min → 5 min for PRs (80% faster)
- **Cost:** ~$400/month → ~$100/month (75% cheaper)
- **Maintainability:** Reusable components, easier updates
- **Quality:** Comprehensive cross-platform testing with fail-fast safety

The optimizations are practical, well-documented, and proven in production environments. Implementation can be phased, starting with quick wins (caching, concurrency) and progressing to advanced patterns (reusable workflows, self-hosted runners) as needed.
