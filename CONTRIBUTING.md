# Contributing to OCSV

Thank you for your interest in contributing to OCSV!

## Commit Message Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and changelog generation. All commits must follow this format:

```
<type>(<scope>): <subject>
```

### Commit Types

- **feat**: A new feature (triggers minor release)
- **fix**: A bug fix (triggers patch release)
- **perf**: Performance improvement (triggers patch release)
- **docs**: Documentation only changes
- **style**: Code style changes (formatting, semicolons, etc.)
- **refactor**: Code refactoring without behavior change
- **test**: Adding or updating tests
- **chore**: Maintenance tasks, dependency updates
- **ci**: CI/CD pipeline changes

### Examples

```bash
# Feature (minor version bump)
git commit -m "feat: add lazy parsing mode for large files"
git commit -m "feat(parser): support custom delimiters"

# Bug fix (patch version bump)
git commit -m "fix: handle quoted newlines correctly"
git commit -m "fix(ffi): prevent memory leak in parser cleanup"

# Breaking change (major version bump)
git commit -m "feat!: remove deprecated API methods

BREAKING CHANGE: parseSync() has been removed. Use parse() instead."

# Non-releasing changes
git commit -m "docs: update API examples"
git commit -m "chore: update dependencies"
git commit -m "test: add edge case coverage for empty fields"
```

### Scope (Optional)

Scopes help organize changes by area:
- `parser`: Core parsing logic
- `ffi`: FFI bindings and exports
- `config`: Configuration system
- `streaming`: Streaming API
- `plugin`: Plugin system
- `docs`: Documentation
- `ci`: CI/CD workflows

### Rules

1. **Type must be lowercase**
2. **Subject must not end with period**
3. **Maximum header length: 100 characters**
4. **Use imperative mood** ("add" not "added")
5. **Body and footer separated by blank line**

### Validation

Commits are validated by commitlint in CI. If your commit message doesn't follow the format, the CI will fail.

**Test locally:**
```bash
npm install
echo "feat: test commit message" | npx commitlint
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes with proper commit messages
4. Run tests: `odin test tests -all-packages`
5. Push to your fork: `git push origin feature/my-feature`
6. Open a pull request

### PR Checks

All PRs must pass:
- ✅ Commit message validation (commitlint)
- ✅ Code linting (odin check)
- ✅ Tests (all platforms)
- ✅ Memory leak detection (tracking allocator)

## Questions?

Open an issue at https://github.com/dvrd/ocsv/issues
