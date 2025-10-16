#!/usr/bin/env bash
#
# Pre-publish validation script for OCSV npm package
#
# This script validates that the package is ready for npm publication by checking:
# 1. Version consistency between package.json and git tag
# 2. Required files exist
# 3. All platform prebuilds are present
# 4. Package.json syntax is valid
# 5. Package contents are correct
#
# Usage:
#   ./scripts/prepublish.sh [--tag v1.0.0]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

# Configuration
REQUIRED_PLATFORMS=("darwin-arm64" "darwin-x64" "linux-x64" "win32-x64")
REQUIRED_FILES=("package.json" "README.md" "LICENSE" "CHANGELOG.md")
REQUIRED_DIRS=("bindings" "prebuilds")

# Parse command line arguments
GIT_TAG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            GIT_TAG="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--tag v1.0.0]"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Validation steps

validate_commands() {
    log_info "Checking required commands..."

    local missing_commands=()

    for cmd in node npm jq; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
            log_error "Missing required command: $cmd"
        else
            log_success "Found: $cmd ($(command -v "$cmd"))"
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
}

validate_required_files() {
    log_info "Checking required files..."

    local missing_files=()

    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
            log_error "Missing required file: $file"
        else
            log_success "Found: $file"
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing required files: ${missing_files[*]}"
        return 1
    fi
}

validate_required_dirs() {
    log_info "Checking required directories..."

    local missing_dirs=()

    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            missing_dirs+=("$dir")
            log_error "Missing required directory: $dir"
        else
            log_success "Found: $dir/"
        fi
    done

    if [ ${#missing_dirs[@]} -gt 0 ]; then
        log_error "Missing required directories: ${missing_dirs[*]}"
        return 1
    fi
}

validate_package_json() {
    log_info "Validating package.json syntax..."

    if ! jq empty package.json 2>/dev/null; then
        log_error "package.json has invalid JSON syntax"
        return 1
    fi

    log_success "package.json syntax is valid"
}

validate_version() {
    log_info "Checking version consistency..."

    # Get version from package.json
    local pkg_version
    pkg_version=$(jq -r '.version' package.json)

    if [ -z "$pkg_version" ] || [ "$pkg_version" = "null" ]; then
        log_error "Could not read version from package.json"
        return 1
    fi

    log_success "package.json version: $pkg_version"

    # If git tag provided, validate it matches package.json version
    if [ -n "$GIT_TAG" ]; then
        local tag_version="${GIT_TAG#v}"  # Remove 'v' prefix

        if [ "$pkg_version" != "$tag_version" ]; then
            log_error "Version mismatch: package.json ($pkg_version) != git tag ($tag_version)"
            return 1
        fi

        log_success "Git tag ($GIT_TAG) matches package.json version"
    else
        log_warning "No git tag provided for version validation"
    fi
}

validate_prebuilds() {
    log_info "Checking prebuilt binaries..."

    local missing_prebuilds=()

    for platform in "${REQUIRED_PLATFORMS[@]}"; do
        local prebuild_dir="prebuilds/$platform"

        if [ ! -d "$prebuild_dir" ]; then
            missing_prebuilds+=("$platform (directory missing)")
            log_error "Missing prebuild directory: $prebuild_dir"
            continue
        fi

        # Check if directory has any files
        local file_count
        file_count=$(find "$prebuild_dir" -type f | wc -l)

        if [ "$file_count" -eq 0 ]; then
            missing_prebuilds+=("$platform (empty directory)")
            log_error "Prebuild directory is empty: $prebuild_dir"
            continue
        fi

        # Show what's in the directory
        local files
        files=$(ls -lh "$prebuild_dir" | tail -n +2)
        log_success "Found $platform prebuild(s):"
        echo "$files" | while read -r line; do
            echo "    $line"
        done
    done

    if [ ${#missing_prebuilds[@]} -gt 0 ]; then
        log_error "Missing or empty prebuilds: ${missing_prebuilds[*]}"
        return 1
    fi
}

validate_bindings() {
    log_info "Checking FFI bindings..."

    local required_binding_files=("bindings/index.js" "bindings/index.d.ts" "bindings/errors.js")
    local missing_bindings=()

    for file in "${required_binding_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_bindings+=("$file")
            log_error "Missing binding file: $file"
        else
            log_success "Found: $file"
        fi
    done

    if [ ${#missing_bindings[@]} -gt 0 ]; then
        log_error "Missing binding files: ${missing_bindings[*]}"
        return 1
    fi
}

dry_run_npm_pack() {
    log_info "Running npm pack dry-run..."

    if ! npm pack --dry-run; then
        log_error "npm pack dry-run failed"
        return 1
    fi

    log_success "npm pack dry-run succeeded"
}

check_package_size() {
    log_info "Checking package size..."

    # Create a temporary tarball to check size
    local tarball
    tarball=$(npm pack 2>/dev/null | tail -n 1)

    if [ ! -f "$tarball" ]; then
        log_error "Failed to create test tarball"
        return 1
    fi

    # Get size in KB
    local size_kb
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS stat
        size_kb=$(($(stat -f%z "$tarball") / 1024))
    else
        # Linux stat
        size_kb=$(($(stat -c%s "$tarball") / 1024))
    fi

    log_success "Package size: ${size_kb} KB (compressed)"

    # Warn if package is too large (>150KB per PRP requirements)
    if [ "$size_kb" -gt 150 ]; then
        log_warning "Package size exceeds recommended 150KB limit"
    fi

    # Clean up tarball
    rm -f "$tarball"
}

# Main validation flow
main() {
    echo ""
    echo "======================================"
    echo "  OCSV npm Package Validation"
    echo "======================================"
    echo ""

    local failed_checks=()

    # Run all validation checks
    validate_commands || failed_checks+=("commands")
    echo ""

    validate_required_files || failed_checks+=("required_files")
    echo ""

    validate_required_dirs || failed_checks+=("required_dirs")
    echo ""

    validate_package_json || failed_checks+=("package_json")
    echo ""

    validate_version || failed_checks+=("version")
    echo ""

    validate_prebuilds || failed_checks+=("prebuilds")
    echo ""

    validate_bindings || failed_checks+=("bindings")
    echo ""

    dry_run_npm_pack || failed_checks+=("npm_pack")
    echo ""

    check_package_size || failed_checks+=("package_size")
    echo ""

    # Summary
    echo "======================================"
    if [ ${#failed_checks[@]} -eq 0 ]; then
        log_success "All validation checks passed!"
        echo ""
        log_info "Package is ready for publication to npm"
        echo ""
        return 0
    else
        log_error "Validation failed: ${#failed_checks[@]} check(s) failed"
        echo ""
        log_error "Failed checks: ${failed_checks[*]}"
        echo ""
        return 1
    fi
}

# Run main validation
main "$@"
