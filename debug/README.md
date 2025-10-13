# Debug Test Files

This directory contains temporary test files and debugging scripts used during development.

## Contents

These files are **NOT** part of the production test suite. They are ad-hoc debugging tools created during development:

- `test_*.odin` - Standalone test programs for debugging specific issues
- `*.sh` - Shell scripts for running test combinations
- Binary executables - Compiled test programs

## Usage

These files are typically run directly with:

```bash
# Compile and run an Odin test file
odin run test_example.odin -file

# Run shell scripts
./test_script.sh
```

## Note

- These files may be outdated
- They may not compile without modifications
- They are kept for reference during debugging sessions
- Production tests are in `/tests` directory

## Cleanup

These files can be safely deleted when no longer needed:

```bash
# From project root
rm -rf debug/*
```
