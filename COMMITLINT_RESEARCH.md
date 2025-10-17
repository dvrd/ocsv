# Commitlint Research: Comprehensive Guide for Conventional Commits Enforcement

**Research Date:** 2025-10-16
**Focus:** GitHub Actions integration for PR-level commit validation

---

## Table of Contents

1. [Package Versions](#package-versions)
2. [Conventional Commits Specification](#conventional-commits-specification)
3. [Commitlint Configuration](#commitlint-configuration)
4. [GitHub Actions Integration](#github-actions-integration)
5. [Custom Rules & Configuration](#custom-rules--configuration)
6. [Testing Locally](#testing-locally)
7. [Error Messages & Examples](#error-messages--examples)
8. [Best Practices](#best-practices)
9. [Documentation Links](#documentation-links)

---

## Package Versions

### Latest Versions (as of 2025-10-16)

- **@commitlint/cli**: `19.8.1` (published ~4 months ago)
- **@commitlint/config-conventional**: `20.0.0` (published ~21 days ago)

### Installation

```bash
# Install as dev dependencies
npm install --save-dev @commitlint/cli @commitlint/config-conventional

# Or with other package managers
yarn add -D @commitlint/cli @commitlint/config-conventional
pnpm add -D @commitlint/cli @commitlint/config-conventional
bun add -D @commitlint/cli @commitlint/config-conventional
```

### Important Note: Node v24 Compatibility

Node v24 changes module loading behavior. If your project lacks a `package.json`, commitlint may fail to load the config with the error: "Please add rules to your commitlint.config.js"

**Solutions:**
1. Add a `package.json` file (recommended): `npm init es6`
2. Rename config from `commitlint.config.js` to `commitlint.config.mjs`

---

## Conventional Commits Specification

### Official Specification (v1.0.0)

**Basic Format:**
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type (REQUIRED)

The type consists of a noun (`feat`, `fix`, etc.) followed by an OPTIONAL scope, OPTIONAL `!`, and REQUIRED colon and space.

**Required Types:**
- `feat`: Introduces a new feature (correlates with MINOR in SemVer)
- `fix`: Bug fix (correlates with PATCH in SemVer)

**Recommended Additional Types:**
- `build`: Changes to build system or dependencies
- `ci`: Changes to CI configuration
- `chore`: Maintenance tasks
- `docs`: Documentation changes
- `perf`: Performance improvements
- `refactor`: Code refactoring (neither fixes bug nor adds feature)
- `revert`: Reverts a previous commit
- `style`: Code style changes (formatting, whitespace)
- `test`: Adding or updating tests

### Scope (OPTIONAL)

Provides additional contextual information, contained within parentheses.

**Example:**
```
feat(parser): add ability to parse arrays
fix(api): resolve null pointer exception
docs(readme): update installation instructions
```

### Description (REQUIRED)

A short summary immediately following the colon and space after type/scope.

**Guidelines:**
- Use imperative, present tense ("add" not "added" or "adds")
- Don't capitalize first letter
- No period at the end

### Breaking Changes

**Two methods to indicate breaking changes:**

#### 1. Using `!` in the type/scope prefix

```
feat!: remove support for Node 12
feat(api)!: change response format
```

Breaking changes indicated with `!` immediately before `:`. The commit description SHALL be used to describe the breaking change.

#### 2. Using a BREAKING CHANGE footer

```
feat: allow config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

A breaking change MUST consist of uppercase text `BREAKING CHANGE`, followed by colon, space, and description.

**Both methods correlate with MAJOR version in SemVer.**

### Body (OPTIONAL)

Free-form text that MAY consist of any number of newline-separated paragraphs.

**Guidelines:**
- Blank line MUST separate body from description
- Use present tense
- Explain WHAT and WHY, not HOW
- Can be multiple paragraphs

**Example:**
```
feat: add streaming API

The new streaming API allows processing large CSV files without loading
them entirely into memory. This is particularly useful for files
exceeding several gigabytes.

Performance benchmarks show 70% reduction in memory usage for files
over 1GB in size.
```

### Footer (OPTIONAL)

Footers MAY be provided one blank line after the body. Each footer MUST consist of:
- A word token
- Followed by either `:<space>` or `<space>#` separator
- Followed by a string value

**Footer value MAY contain spaces and newlines.**

**Common footer tokens:**
- `BREAKING CHANGE:` - Describes breaking changes
- `Refs:` - References related commits
- `Closes:` - References closed issues
- `Fixes:` - References fixed issues
- `See-also:` - Additional references

**Examples:**
```
fix: correct calculation error

Fixes: #123
See-also: #456

---

feat: add plugin system

BREAKING CHANGE: Old plugin API is no longer supported.
Migrate to new API documented in PLUGIN_GUIDE.md

Refs: #789, #790
```

### Revert Commits

While Conventional Commits doesn't strictly define revert behavior, the recommended approach:

```
revert: let us never again speak of the noodle incident

Refs: 676104e, a215868
```

Use `revert` type with footer referencing commit SHAs.

---

## Commitlint Configuration

### Configuration File Formats

Commitlint supports multiple configuration file formats:

**Supported formats:**
- `commitlint.config.js` (CommonJS)
- `commitlint.config.mjs` (ES Module)
- `commitlint.config.cjs` (CommonJS, explicit)
- `commitlint.config.ts` (TypeScript)
- `.commitlintrc.js`
- `.commitlintrc.json`
- `.commitlintrc.yml`

**Recommended:** `commitlint.config.js` (or `.mjs` for Node v24+)

### Basic Configuration

**ES Module (Node 18+, Node v24):**
```javascript
// commitlint.config.js
export default {
  extends: ['@commitlint/config-conventional']
};
```

**CommonJS:**
```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional']
};
```

### Complete Configuration with Comments

```javascript
// commitlint.config.js
export default {
  // Extend from shared configuration
  extends: ['@commitlint/config-conventional'],

  // Parser preset (usually inherited from extended config)
  parserPreset: 'conventional-changelog-angular',

  // Custom rules (override extended config)
  rules: {
    // Type rules
    'type-enum': [
      2, // Level: 0=disable, 1=warning, 2=error
      'always', // Applicable: 'always' or 'never'
      [
        'build',
        'ci',
        'chore',
        'docs',
        'feat',
        'fix',
        'perf',
        'refactor',
        'revert',
        'style',
        'test'
      ]
    ],
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],

    // Scope rules
    'scope-case': [2, 'always', 'lower-case'],
    'scope-empty': [0], // 0 = disabled (scope is optional)
    'scope-enum': [
      0, // Disabled by default
      'always',
      [
        'parser',
        'api',
        'cli',
        'docs',
        'deps'
      ]
    ],

    // Subject rules
    'subject-case': [
      2,
      'never',
      ['sentence-case', 'start-case', 'pascal-case', 'upper-case']
    ],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],

    // Header rules
    'header-max-length': [2, 'always', 100],
    'header-trim': [2, 'always'],

    // Body rules
    'body-leading-blank': [1, 'always'], // Warning level
    'body-max-line-length': [2, 'always', 100],

    // Footer rules
    'footer-leading-blank': [1, 'always'], // Warning level
    'footer-max-line-length': [2, 'always', 100]
  },

  // Help URL shown on validation failure
  helpUrl: 'https://github.com/conventional-changelog/commitlint/#what-is-commitlint',

  // Custom prompt messages (for commitizen integration)
  prompt: {
    messages: {},
    questions: {}
  },

  // Ignore certain commits
  ignores: [
    (commit) => commit.includes('WIP'),
    (commit) => commit.includes('[skip ci]')
  ],

  // Default ignore patterns
  defaultIgnores: true
};
```

### Rule Configuration Syntax

**Rule Format:** `'rule-name': [Level, Applicable, Value]`

**Levels:**
- `0` - Disabled
- `1` - Warning (doesn't fail, logs warning)
- `2` - Error (fails commit/CI)

**Applicable:**
- `'always'` - Rule must be satisfied
- `'never'` - Inverts the rule

**Value:**
- Rule-specific value (string, array, number, etc.)

---

## GitHub Actions Integration

### Approach 1: Manual Setup (Recommended for Full Control)

**Complete workflow for PR validation:**

```yaml
name: Lint Commit Messages

# Trigger on pull requests
on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: read

jobs:
  commitlint:
    name: Validate Commit Messages
    runs-on: ubuntu-latest

    steps:
      # Checkout with full history
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # CRITICAL: Fetch all history for commit range

      # Setup Node.js
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 'lts/*' # Use latest LTS version
          cache: 'npm' # Cache npm dependencies

      # Install commitlint
      - name: Install commitlint
        run: |
          npm install -D @commitlint/cli@19.8.1 @commitlint/config-conventional@20.0.0

      # Validate all commits in PR
      - name: Validate PR commits with commitlint
        if: github.event_name == 'pull_request'
        run: |
          npx commitlint \
            --from ${{ github.event.pull_request.base.sha }} \
            --to ${{ github.event.pull_request.head.sha }} \
            --verbose
```

**Key points:**
- `fetch-depth: 0` is REQUIRED to fetch full commit history
- Uses `github.event.pull_request.base.sha` and `head.sha` for commit range
- `--verbose` flag provides detailed output for debugging
- Only runs on pull request events

### Approach 2: Using wagoid/commitlint-github-action

**Simplified workflow using pre-built action:**

```yaml
name: Lint Commit Messages

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: read

jobs:
  commitlint:
    name: Validate Commit Messages
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Still required!

      - name: Run commitlint
        uses: wagoid/commitlint-github-action@v6
```

**With custom dependencies:**

```yaml
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0

  - uses: actions/setup-node@v4
    with:
      node-version: '22'

  - name: Install dependencies
    run: npm install

  - uses: wagoid/commitlint-github-action@v6
    env:
      NODE_PATH: ${{ github.workspace }}/node_modules
```

**wagoid action inputs:**

```yaml
- uses: wagoid/commitlint-github-action@v6
  with:
    # Path to commitlint config (defaults to auto-detection)
    configFile: './commitlint.config.js'

    # Fail on warnings (default: false)
    failOnWarnings: false

    # Fail on errors (default: true)
    failOnErrors: true

    # Link to commit convention docs
    helpURL: 'https://github.com/your-org/docs/commit-convention.md'

    # Consider only latest X commits (optional)
    firstParent: false

    # GitHub token (auto-provided)
    token: ${{ secrets.GITHUB_TOKEN }}
```

**Important notes:**
- Commitlint.config.js doesn't work with wagoid action (use .mjs extension)
- If config doesn't exist, defaults to `@commitlint/config-conventional`

### Handling Different Merge Strategies

#### Squash Merge Strategy

When using "Squash and merge", GitHub suggests using the PR title as the commit message. You should also validate PR titles:

```yaml
name: Lint PR Title

on:
  pull_request:
    types: [opened, synchronize, reopened, edited]

jobs:
  lint-pr-title:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'

      - name: Install commitlint
        run: npm install -D @commitlint/cli @commitlint/config-conventional

      - name: Validate PR title
        run: echo "${{ github.event.pull_request.title }}" | npx commitlint
```

Or use dedicated action:

```yaml
- uses: dreampulse/action-commitlint-pull-request-title@v1
  with:
    configuration-path: './commitlint.config.js'
```

#### Merge Queue Support

For GitHub's merge queue feature:

```yaml
name: Lint Commits in Merge Queue

on:
  merge_group:
    types: [checks_requested]

jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.sha }}

      - uses: wagoid/commitlint-github-action@v6
```

**Note:** Merge queue validation only checks the last commit, as PR validation already validated all commits in the PR.

### Push Events

For direct pushes to branches:

```yaml
name: Lint Commits

on:
  push:
    branches:
      - main
      - develop

jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'

      - name: Install commitlint
        run: npm install -D @commitlint/cli @commitlint/config-conventional

      - name: Validate last commit
        run: npx commitlint --last --verbose
```

---

## Custom Rules & Configuration

### Common Customizations

#### 1. Custom Type Enum (Project-Specific Types)

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation
        'style',    // Code style (formatting)
        'refactor', // Code refactoring
        'perf',     // Performance improvement
        'test',     // Tests
        'build',    // Build system
        'ci',       // CI configuration
        'chore',    // Maintenance
        'revert',   // Revert commit
        'wip',      // Work in progress (optional)
        'hotfix'    // Critical production fix (optional)
      ]
    ]
  }
};
```

#### 2. Required Scope with Enum

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Scope is required
    'scope-empty': [2, 'never'],

    // Only allow specific scopes
    'scope-enum': [
      2,
      'always',
      [
        'core',
        'parser',
        'api',
        'cli',
        'docs',
        'deps',
        'config',
        'tests'
      ]
    ],

    // Scope must be lowercase
    'scope-case': [2, 'always', 'lower-case']
  }
};
```

#### 3. Subject Case Enforcement

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Allow lowercase, kebab-case
    'subject-case': [
      2,
      'always',
      ['lower-case', 'kebab-case']
    ],

    // Or prevent certain cases
    'subject-case': [
      2,
      'never',
      ['sentence-case', 'start-case', 'pascal-case', 'upper-case']
    ]
  }
};
```

**Available cases:**
- `lower-case`: all lowercase
- `upper-case`: ALL UPPERCASE
- `camel-case`: camelCase
- `kebab-case`: kebab-case
- `pascal-case`: PascalCase
- `sentence-case`: Sentence case
- `snake-case`: snake_case
- `start-case`: Start Case

#### 4. Header Length Customization

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Shorter header for GitHub UI
    'header-max-length': [2, 'always', 72],

    // Or longer for squash commits
    'header-max-length': [2, 'always', 140]
  }
};
```

**Note:** When using "Squash and merge", GitHub appends ` (#123)` to the commit message, affecting length.

#### 5. Body and Footer Requirements

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Body is required for certain types
    'body-min-length': [2, 'always', 20],

    // Body must have leading blank line
    'body-leading-blank': [2, 'always'],

    // Footer must have leading blank line
    'footer-leading-blank': [2, 'always']
  }
};
```

#### 6. Custom Plugins with Advanced Logic

```javascript
export default {
  plugins: [
    {
      rules: {
        // Custom rule: Require issue reference in footer
        'footer-must-reference-issue': (parsed) => {
          const { footer } = parsed;
          if (!footer) {
            return [false, 'Footer must reference an issue (e.g., "Refs: #123")'];
          }

          const hasIssueRef = /(?:refs|fixes|closes):\s*#\d+/i.test(footer);
          return [
            hasIssueRef,
            'Footer must reference an issue using Refs:/Fixes:/Closes: #<number>'
          ];
        },

        // Custom rule: Breaking changes must have BREAKING CHANGE footer
        'breaking-change-must-have-footer': (parsed) => {
          const { header, footer } = parsed;
          if (header && header.includes('!')) {
            const hasBreakingFooter = footer && footer.includes('BREAKING CHANGE:');
            return [
              hasBreakingFooter,
              'Commits with ! must include BREAKING CHANGE: in footer'
            ];
          }
          return [true, ''];
        }
      }
    }
  ],
  rules: {
    'footer-must-reference-issue': [1, 'always'], // Warning
    'breaking-change-must-have-footer': [2, 'always'] // Error
  }
};
```

#### 7. Ignoring Certain Commits

```javascript
export default {
  extends: ['@commitlint/config-conventional'],

  // Ignore commits matching patterns
  ignores: [
    (commit) => commit.includes('WIP'),
    (commit) => commit.includes('[skip ci]'),
    (commit) => commit.includes('Merge branch'),
    (commit) => /^Bumps \[.+]\(.+\) from .+ to .+\./.test(commit)
  ],

  // Use default ignore patterns (merge commits, revert commits)
  defaultIgnores: true
};
```

#### 8. Setting Help URL

```javascript
export default {
  extends: ['@commitlint/config-conventional'],

  // Custom help URL shown on failure
  helpUrl: 'https://github.com/your-org/your-repo/blob/main/docs/COMMIT_CONVENTION.md'
};
```

---

## Testing Locally

### Basic Testing Commands

```bash
# Test the last commit
npx commitlint --last --verbose

# Test last N commits
npx commitlint --from HEAD~3 --verbose

# Test a specific commit range
npx commitlint --from abc123 --to def456 --verbose

# Test a single commit by SHA
npx commitlint --from abc123^ --to abc123 --verbose

# Pipe a commit message directly
echo "feat: add new feature" | npx commitlint

# Test commit message from file
npx commitlint --edit path/to/commit-msg-file
```

### Testing PR Commit Range Locally

```bash
# Simulate PR validation (substitute with actual SHAs)
npx commitlint --from main --to feature-branch --verbose

# Or using git rev-parse
BASE_SHA=$(git rev-parse main)
HEAD_SHA=$(git rev-parse HEAD)
npx commitlint --from $BASE_SHA --to $HEAD_SHA --verbose
```

### Interactive Testing

```bash
# Create test commits (don't push!)
git checkout -b test-commitlint

# Test valid commit
git commit --allow-empty -m "feat: add testing feature"
npx commitlint --last

# Test invalid commit
git commit --allow-empty -m "added feature"
npx commitlint --last

# Test with body and footer
git commit --allow-empty -m "feat: add complex feature

This feature adds support for advanced parsing.

Fixes: #123"
npx commitlint --last

# Reset branch
git checkout main
git branch -D test-commitlint
```

### Debugging Configuration

```bash
# Print resolved configuration
npx commitlint --print-config

# Show version
npx commitlint --version

# Show help
npx commitlint --help
```

### Exit Codes

- **Exit code 0**: All commits valid (success)
- **Exit code 1**: Validation failed OR configuration error

**Note:** Currently, commitlint doesn't distinguish between linting errors and configuration errors. Both return exit code 1.

---

## Error Messages & Examples

### Good Commit Messages

```
feat: add CSV streaming API

fix: resolve parser crash on empty fields

docs: update API documentation with examples

perf(parser): optimize SIMD field detection

feat(api)!: change response format to JSON

BREAKING CHANGE: Response format changed from XML to JSON

refactor: extract validation logic to separate module

test: add edge cases for multiline fields

ci: add commitlint to GitHub Actions

chore(deps): update odin to latest version

revert: remove experimental lazy loading

Refs: 676104e, a215868
```

### Bad Commit Messages (with errors)

```
Added new feature
❌ type may not be empty [type-empty]
❌ subject may not be empty [subject-empty]

---

Feature: Add streaming
❌ type must be one of [feat, fix, docs, ...] [type-enum]

---

feat: Add new streaming API
❌ subject must not be sentence-case [subject-case]

---

feat add streaming
❌ header must have colon after type [header-format]

---

feat: add streaming.
❌ subject may not end with full stop [subject-full-stop]

---

feat:add streaming
❌ header must have space after colon [header-format]

---

FEAT: add streaming
❌ type must not be upper-case [type-case]

---

feat(Parser): add streaming
❌ scope must not be pascal-case [scope-case]

---

feat(unknown-module): add streaming
❌ scope must be one of [parser, api, cli, ...] [scope-enum]
(if scope-enum is configured)

---

feat: this is an extremely long commit message that exceeds the maximum allowed length and will trigger an error
❌ header must not be longer than 100 characters [header-max-length]
```

### Example Error Output

**Command:**
```bash
$ echo "added feature" | npx commitlint
```

**Output:**
```
⧗   input: added feature
✖   subject may not be empty [subject-empty]
✖   type may not be empty [type-empty]

✖   found 2 problems, 0 warnings
ⓘ   Get help: https://github.com/conventional-changelog/commitlint/#what-is-commitlint
```

**Command:**
```bash
$ echo "feat: Add new feature" | npx commitlint
```

**Output:**
```
⧗   input: feat: Add new feature
✖   subject must not be sentence-case, start-case, pascal-case, upper-case [subject-case]

✖   found 1 problems, 0 warnings
ⓘ   Get help: https://github.com/conventional-changelog/commitlint/#what-is-commitlint
```

**Command:**
```bash
$ echo "feat: add new feature" | npx commitlint
```

**Output:**
```
⧗   input: feat: add new feature
✔   found 0 problems, 0 warnings
```

### Customizing Error Messages

```javascript
export default {
  plugins: [
    {
      rules: {
        'custom-rule': (parsed) => {
          const { type, subject } = parsed;

          if (!subject) {
            return [
              false,
              'Please provide a commit subject. Example:\n' +
              '  feat: add new feature\n' +
              '  fix: resolve bug in parser'
            ];
          }

          return [true, ''];
        }
      }
    }
  ],
  rules: {
    'custom-rule': [2, 'always']
  }
};
```

---

## Best Practices

### 1. PR-Level Validation (Recommended)

**Why:** Validates all commits in a PR, not just HEAD.

```yaml
on: pull_request
```

**Use commit range:**
```bash
npx commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }}
```

### 2. Always Use `fetch-depth: 0`

**Why:** GitHub Actions by default fetches only the latest commit. Commitlint needs history.

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

### 3. Use `--verbose` Flag in CI

**Why:** Provides detailed output for debugging failed validations.

```bash
npx commitlint --last --verbose
```

### 4. Start with `@commitlint/config-conventional`

**Why:** Battle-tested configuration following Conventional Commits spec.

```javascript
export default {
  extends: ['@commitlint/config-conventional']
};
```

Override specific rules as needed rather than creating from scratch.

### 5. Keep Configuration Simple

**Why:** Complex rules are hard to maintain and confuse contributors.

**Good:**
```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'header-max-length': [2, 'always', 72]
  }
};
```

**Bad (overly complex):**
```javascript
export default {
  rules: {
    // 30+ custom rules with complex logic
  }
};
```

### 6. Document Your Convention

Create a `CONTRIBUTING.md` or `docs/COMMIT_CONVENTION.md`:

```markdown
## Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
...

### Examples

```
feat(parser): add streaming support
fix: resolve null pointer in validation
```
```

Set `helpUrl` in config:

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  helpUrl: 'https://github.com/your-org/your-repo/blob/main/docs/COMMIT_CONVENTION.md'
};
```

### 7. Handle Squash Merges Appropriately

If your team uses "Squash and merge", also validate PR titles:

```yaml
name: Validate PR Title
on:
  pull_request:
    types: [opened, edited, synchronize]

jobs:
  lint-pr-title:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'
      - run: npm install -D @commitlint/cli @commitlint/config-conventional
      - run: echo "${{ github.event.pull_request.title }}" | npx commitlint
```

### 8. Consider Warnings vs Errors

Use warning level (1) for nice-to-haves, error level (2) for must-haves:

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'body-leading-blank': [1, 'always'], // Warning
    'type-empty': [2, 'never'] // Error
  }
};
```

### 9. Use Ignores Sparingly

Don't over-ignore commits. Use `ignores` only for edge cases:

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  ignores: [
    (commit) => commit.includes('Merge branch'), // Merge commits
    (commit) => /^Bumps \[.+]/.test(commit) // Dependabot
  ]
};
```

### 10. Test Configuration Locally Before CI

Always test your commitlint configuration locally:

```bash
# Test last commit
npx commitlint --last --verbose

# Print resolved config
npx commitlint --print-config
```

---

## Documentation Links

### Official Documentation

- **Commitlint Official Site:** https://commitlint.js.org/
- **Getting Started Guide:** https://commitlint.js.org/guides/getting-started.html
- **Configuration Reference:** https://commitlint.js.org/reference/configuration.html
- **Rules Reference:** https://commitlint.js.org/reference/rules.html
- **Rules Configuration:** https://commitlint.js.org/reference/rules-configuration.html
- **CI Setup Guide:** https://commitlint.js.org/guides/ci-setup.html
- **Local Setup Guide:** https://commitlint.js.org/guides/local-setup.html

### Packages

- **@commitlint/cli (npm):** https://www.npmjs.com/package/@commitlint/cli
- **@commitlint/config-conventional (npm):** https://www.npmjs.com/package/@commitlint/config-conventional
- **GitHub Repository:** https://github.com/conventional-changelog/commitlint
- **Releases:** https://github.com/conventional-changelog/commitlint/releases

### Conventional Commits

- **Official Specification (v1.0.0):** https://www.conventionalcommits.org/en/v1.0.0/
- **GitHub Source:** https://github.com/conventional-commits/conventionalcommits.org

### GitHub Actions

- **wagoid/commitlint-github-action:** https://github.com/wagoid/commitlint-github-action
- **actions/checkout:** https://github.com/actions/checkout
- **actions/setup-node:** https://github.com/actions/setup-node

### Additional Resources

- **Conventional Commits Cheatsheet:** https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13
- **FreeCodeCamp Tutorial:** https://www.freecodecamp.org/news/how-to-use-commitlint-to-write-good-commit-messages/
- **LogRocket Blog:** https://blog.logrocket.com/commitlint-write-more-organized-code/

---

## Summary & Quick Start

### Minimal Setup (3 steps)

1. **Install packages:**
   ```bash
   npm install -D @commitlint/cli @commitlint/config-conventional
   ```

2. **Create config:**
   ```bash
   echo "export default {extends: ['@commitlint/config-conventional']};" > commitlint.config.js
   ```

3. **Add GitHub Action:**
   ```yaml
   name: Lint Commit Messages
   on: pull_request
   jobs:
     commitlint:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
           with:
             fetch-depth: 0
         - uses: actions/setup-node@v4
           with:
             node-version: 'lts/*'
         - run: npm install -D @commitlint/cli @commitlint/config-conventional
         - run: npx commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }} --verbose
   ```

### Testing Locally

```bash
# Test last commit
npx commitlint --last --verbose

# Test a message
echo "feat: add new feature" | npx commitlint
```

### Key Takeaways

- Use `fetch-depth: 0` in GitHub Actions (critical!)
- Validate commit range in PRs: `--from base.sha --to head.sha`
- Start with `@commitlint/config-conventional`, customize as needed
- Use `--verbose` flag for detailed output in CI
- Exit code 1 = validation failure, exit code 0 = success
- Consider validating PR titles for squash merge workflows
- Document your commit convention for contributors

---

**End of Research Document**
