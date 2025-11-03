#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if we're in the project root
if [[ ! -f "package.json" ]]; then
    error "Must be run from project root (package.json not found)"
fi

# Check for required tools
for cmd in jq gh npm git; do
    if ! command -v "$cmd" &> /dev/null; then
        error "Required command '$cmd' not found"
    fi
done

# Parse arguments
VERSION_TYPE="${1:-}"
if [[ -z "$VERSION_TYPE" ]]; then
    echo "Usage: $0 <major|minor|patch> [--dry-run]"
    echo ""
    echo "Examples:"
    echo "  $0 patch          # 1.2.1 -> 1.2.2"
    echo "  $0 minor          # 1.2.1 -> 1.3.0"
    echo "  $0 major          # 1.2.1 -> 2.0.0"
    echo "  $0 patch --dry-run   # Test without publishing"
    exit 1
fi

DRY_RUN=false
if [[ "${2:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    warning "DRY RUN MODE - No changes will be made"
fi

# Validate version type
if [[ ! "$VERSION_TYPE" =~ ^(major|minor|patch)$ ]]; then
    error "Version type must be 'major', 'minor', or 'patch'"
fi

# Check git status
if [[ -n $(git status --porcelain) ]]; then
    error "Working directory is not clean. Commit or stash changes first."
fi

# Get current version
CURRENT_VERSION=$(jq -r '.version' package.json)
info "Current version: $CURRENT_VERSION"

# Calculate new version
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

case "$VERSION_TYPE" in
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    minor)
        NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
        ;;
    patch)
        NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
        ;;
esac

info "New version: $NEW_VERSION"

# Confirm with user
if [[ "$DRY_RUN" == false ]]; then
    echo ""
    read -p "Continue with release $NEW_VERSION? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Release cancelled"
        exit 0
    fi
fi

# Update CHANGELOG.md
info "Updating CHANGELOG.md..."
RELEASE_DATE=$(date +%Y-%m-%d)

if [[ "$DRY_RUN" == false ]]; then
    # Move [Unreleased] content to new version
    sed -i '' "s/## \[Unreleased\]/## [Unreleased]\n\n---\n\n## [$NEW_VERSION] - $RELEASE_DATE/" CHANGELOG.md

    # Add new version link at bottom
    sed -i '' "s|\[${CURRENT_VERSION}\]: https://github.com/dvrd/ocsv/releases/tag/v${CURRENT_VERSION}|[$NEW_VERSION]: https://github.com/dvrd/ocsv/releases/tag/v$NEW_VERSION\n[$CURRENT_VERSION]: https://github.com/dvrd/ocsv/releases/tag/v$CURRENT_VERSION|" CHANGELOG.md

    success "CHANGELOG.md updated"
else
    info "Would update CHANGELOG.md"
fi

# Update package.json
info "Updating package.json..."
if [[ "$DRY_RUN" == false ]]; then
    jq --arg version "$NEW_VERSION" '.version = $version' package.json > package.json.tmp
    mv package.json.tmp package.json
    success "package.json updated to $NEW_VERSION"
else
    info "Would update package.json to $NEW_VERSION"
fi

# Create git commit
info "Creating git commit..."
COMMIT_MSG="chore(release): $NEW_VERSION"

if [[ "$DRY_RUN" == false ]]; then
    git add package.json CHANGELOG.md
    git commit -m "$COMMIT_MSG"
    success "Commit created"
else
    info "Would create commit: $COMMIT_MSG"
fi

# Create git tag
info "Creating git tag v$NEW_VERSION..."
if [[ "$DRY_RUN" == false ]]; then
    git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
    success "Tag created"
else
    info "Would create tag: v$NEW_VERSION"
fi

# Push to GitHub
info "Pushing to GitHub..."
if [[ "$DRY_RUN" == false ]]; then
    git push origin main
    git push origin "v$NEW_VERSION"
    success "Pushed to GitHub"
else
    info "Would push: main and v$NEW_VERSION"
fi

# Extract release notes from CHANGELOG
info "Extracting release notes..."
RELEASE_NOTES=$(awk "/## \[$NEW_VERSION\]/,/^## \[/" CHANGELOG.md | sed '1d;$d' | sed '/^---$/d')

if [[ -z "$RELEASE_NOTES" ]]; then
    warning "No release notes found in CHANGELOG.md"
    RELEASE_NOTES="Release v$NEW_VERSION"
fi

# Create GitHub Release
info "Creating GitHub Release..."
if [[ "$DRY_RUN" == false ]]; then
    # Download artifacts from last successful build if available
    LATEST_RUN=$(gh run list --workflow build.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")

    if [[ -n "$LATEST_RUN" ]]; then
        info "Downloading artifacts from run #$LATEST_RUN..."
        mkdir -p /tmp/ocsv-release-artifacts
        gh run download "$LATEST_RUN" -D /tmp/ocsv-release-artifacts 2>/dev/null || true

        # Create release with binaries if downloaded
        if [[ -d "/tmp/ocsv-release-artifacts" ]] && [[ -n "$(ls -A /tmp/ocsv-release-artifacts 2>/dev/null)" ]]; then
            # Copy and rename binaries
            cp /tmp/ocsv-release-artifacts/prebuild-darwin-arm64/libocsv.dylib /tmp/libocsv-darwin-arm64.dylib 2>/dev/null || true
            cp /tmp/ocsv-release-artifacts/prebuild-darwin-x64/libocsv.dylib /tmp/libocsv-darwin-x64.dylib 2>/dev/null || true
            cp /tmp/ocsv-release-artifacts/prebuild-linux-x64/libocsv.so /tmp/libocsv-linux-x64.so 2>/dev/null || true
            cp /tmp/ocsv-release-artifacts/prebuild-win32-x64/ocsv.dll /tmp/ocsv-win32-x64.dll 2>/dev/null || true

            # Create release with binaries
            gh release create "v$NEW_VERSION" \
                --title "v$NEW_VERSION" \
                --notes "$RELEASE_NOTES" \
                /tmp/libocsv-darwin-arm64.dylib \
                /tmp/libocsv-darwin-x64.dylib \
                /tmp/libocsv-linux-x64.so \
                /tmp/ocsv-win32-x64.dll 2>/dev/null || \
            gh release create "v$NEW_VERSION" \
                --title "v$NEW_VERSION" \
                --notes "$RELEASE_NOTES"

            # Cleanup
            rm -rf /tmp/ocsv-release-artifacts
            rm -f /tmp/libocsv-*.dylib /tmp/libocsv-*.so /tmp/ocsv-*.dll
        else
            # Create release without binaries
            gh release create "v$NEW_VERSION" \
                --title "v$NEW_VERSION" \
                --notes "$RELEASE_NOTES"
        fi
    else
        # Create release without binaries
        gh release create "v$NEW_VERSION" \
            --title "v$NEW_VERSION" \
            --notes "$RELEASE_NOTES"
    fi

    success "GitHub Release created: https://github.com/dvrd/ocsv/releases/tag/v$NEW_VERSION"
else
    info "Would create GitHub Release with notes:"
    echo "$RELEASE_NOTES" | sed 's/^/  /'
fi

# Publish to npm
info "Publishing to npm..."
if [[ "$DRY_RUN" == false ]]; then
    # Check npm authentication
    if ! npm whoami &>/dev/null; then
        error "Not logged in to npm. Run 'npm login' first."
    fi

    # Verify package contents
    info "Package contents:"
    npm pack --dry-run 2>&1 | grep -E "^npm notice (📦|Tarball|package size)" || true

    echo ""
    read -p "Publish to npm? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm publish --provenance false
        success "Published to npm: https://www.npmjs.com/package/ocsv/v/$NEW_VERSION"
    else
        warning "Skipped npm publish"
    fi
else
    info "Would publish to npm"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "Release v$NEW_VERSION completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "Summary:"
echo "  • Version: $CURRENT_VERSION → $NEW_VERSION"
echo "  • Commit: $COMMIT_MSG"
echo "  • Tag: v$NEW_VERSION"
echo "  • GitHub: https://github.com/dvrd/ocsv/releases/tag/v$NEW_VERSION"
echo "  • npm: https://www.npmjs.com/package/ocsv/v/$NEW_VERSION"
echo ""
