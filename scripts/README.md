# Release Scripts

Automated tools for managing releases of the OCSV project.

## 📦 `release.sh`

Automated release management script that handles versioning, changelog updates, git tags, GitHub releases, and npm publishing.

### Prerequisites

```bash
# Required tools
brew install jq gh

# npm authentication
npm login

# gh authentication
gh auth login
```

### Usage

```bash
./scripts/release.sh <major|minor|patch> [--dry-run]
```

### Examples

```bash
# Patch release (1.2.1 -> 1.2.2)
./scripts/release.sh patch

# Minor release (1.2.1 -> 1.3.0)
./scripts/release.sh minor

# Major release (1.2.1 -> 2.0.0)
./scripts/release.sh major

# Dry run (test without making changes)
./scripts/release.sh patch --dry-run
```

### What it does

1. **Validation**
   - ✅ Checks for required tools (jq, gh, npm, git)
   - ✅ Verifies clean working directory
   - ✅ Validates version type

2. **Version Calculation**
   - Reads current version from `package.json`
   - Calculates new version based on type (major/minor/patch)
   - Displays current → new version

3. **File Updates**
   - Updates `CHANGELOG.md` with new version and date
   - Updates `package.json` version field
   - Adds version link to CHANGELOG

4. **Git Operations**
   - Creates commit: `chore(release): X.Y.Z`
   - Creates annotated tag: `vX.Y.Z`
   - Pushes commit and tag to GitHub

5. **GitHub Release**
   - Extracts release notes from CHANGELOG
   - Downloads latest build artifacts if available
   - Creates GitHub release with binaries
   - Attaches platform-specific builds:
     - macOS ARM64 (`libocsv-darwin-arm64.dylib`)
     - macOS x64 (`libocsv-darwin-x64.dylib`)
     - Linux x64 (`libocsv-linux-x64.so`)
     - Windows x64 (`ocsv-win32-x64.dll`)

6. **npm Publishing**
   - Verifies npm authentication
   - Shows package contents
   - Prompts for confirmation
   - Publishes to npm registry

### Workflow

```
┌─────────────────┐
│  Clean Check    │  Verify no uncommitted changes
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Version Bump   │  Update package.json & CHANGELOG.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Git Commit     │  chore(release): X.Y.Z
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Git Tag        │  vX.Y.Z
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Push GitHub    │  main + tag
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  GitHub Release │  Extract notes, attach binaries
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  npm Publish    │  Interactive confirmation
└─────────────────┘
```

### CHANGELOG Format

The script expects CHANGELOG.md to follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

---

## [1.2.1] - 2025-10-27

### Fixed
- Bug fix description

---

## [1.2.0] - 2025-10-27

### Added
- New feature description

[1.2.1]: https://github.com/dvrd/ocsv/releases/tag/v1.2.1
[1.2.0]: https://github.com/dvrd/ocsv/releases/tag/v1.2.0
```

The script will:
1. Add new version section under `[Unreleased]`
2. Add release date automatically
3. Add version link at the bottom

### Error Handling

The script will exit with an error if:
- Not in project root (no `package.json` found)
- Required tools missing (jq, gh, npm, git)
- Invalid version type (not major/minor/patch)
- Working directory is not clean (uncommitted changes)
- npm authentication fails

### Dry Run Mode

Test the entire release process without making any changes:

```bash
./scripts/release.sh patch --dry-run
```

Output:
```
⚠️  DRY RUN MODE - No changes will be made
ℹ️  Current version: 1.2.1
ℹ️  New version: 1.2.2
ℹ️  Would update CHANGELOG.md
ℹ️  Would update package.json to 1.2.2
ℹ️  Would create commit: chore(release): 1.2.2
ℹ️  Would create tag: v1.2.2
ℹ️  Would push: main and v1.2.2
ℹ️  Would create GitHub Release with notes:
  [extracted notes]
ℹ️  Would publish to npm
```

### Manual Override

If you need to manually intervene:

1. **Skip npm publish:**
   - The script prompts for confirmation
   - Answer `n` to skip npm publishing

2. **Add binaries manually:**
   ```bash
   gh release upload v1.2.2 \
     /path/to/libocsv-darwin-arm64.dylib \
     /path/to/libocsv-darwin-x64.dylib \
     /path/to/libocsv-linux-x64.so \
     /path/to/ocsv-win32-x64.dll
   ```

3. **Publish to npm manually:**
   ```bash
   npm publish --provenance false
   ```

### Troubleshooting

**"Working directory is not clean"**
```bash
git status
git add .
git commit -m "fix: your changes"
# OR
git stash
```

**"Not logged in to npm"**
```bash
npm login
```

**"gh: command not found"**
```bash
brew install gh
gh auth login
```

**"Failed to download artifacts"**
- This is not fatal - release continues without binaries
- Binaries can be added manually later
- Or trigger a new build and re-run

### Best Practices

1. **Before releasing:**
   - Update CHANGELOG.md with all changes under `[Unreleased]`
   - Run tests: `odin test tests -all-packages`
   - Run dry-run: `./scripts/release.sh patch --dry-run`

2. **Version selection:**
   - **patch**: Bug fixes, documentation updates
   - **minor**: New features, backwards-compatible changes
   - **major**: Breaking changes

3. **After releasing:**
   - Verify GitHub release: https://github.com/dvrd/ocsv/releases
   - Verify npm package: https://www.npmjs.com/package/ocsv
   - Test installation: `npm install ocsv@latest`

### See Also

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
