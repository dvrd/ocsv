# npm Trusted Publishing (OIDC) with GitHub Actions - Complete Guide

**Last Updated:** October 2025
**npm CLI Requirement:** v11.5.1 or later
**Status:** Generally Available (GA as of July 31, 2025)

---

## Table of Contents

1. [Overview](#overview)
2. [Why OIDC Over Tokens](#why-oidc-over-tokens)
3. [Step-by-Step Setup](#step-by-step-setup)
4. [GitHub Actions Workflow Configuration](#github-actions-workflow-configuration)
5. [Provenance Attestations](#provenance-attestations)
6. [Testing Without Publishing](#testing-without-publishing)
7. [Troubleshooting](#troubleshooting)
8. [npm 2025 Security Changes](#npm-2025-security-changes)
9. [Migration Checklist](#migration-checklist)
10. [Official Documentation Links](#official-documentation-links)

---

## Overview

npm Trusted Publishing uses OpenID Connect (OIDC) to securely publish npm packages directly from CI/CD workflows without storing long-lived tokens. Instead of using npm access tokens, GitHub Actions generates short-lived, cryptographically-signed tokens that are specific to your workflow and cannot be extracted or reused.

### Key Benefits

- **Eliminates token management**: No generating, rotating, or storing npm tokens in CI/CD secrets
- **Enhanced security**: Short-lived, workflow-specific credentials that cannot be exfiltrated
- **Automatic provenance**: Provenance attestations are published by default (no `--provenance` flag needed)
- **Supply chain security**: Verifiable metadata about source repository and build environment
- **Reduced attack surface**: Tokens expire immediately after publish operation

### Supported CI/CD Providers

- GitHub Actions (cloud-hosted runners only)
- GitLab CI/CD
- Self-hosted runners: Not currently supported (planned for future release)

---

## Why OIDC Over Tokens

### Granular Access Tokens vs OIDC

| Feature | Granular Access Tokens | OIDC Trusted Publishing |
|---------|------------------------|-------------------------|
| **Lifetime** | 7 days default, 90 days max (as of Oct 2025) | Seconds (publish operation only) |
| **Storage** | Stored in CI/CD secrets | No storage needed |
| **Rotation** | Manual rotation required | Automatic (no rotation needed) |
| **Exposure Risk** | Can be leaked in logs, configs | Cannot be extracted or reused |
| **Management** | Manual generation, distribution | One-time setup via npm web UI |
| **Provenance** | Manual `--provenance` flag | Automatic provenance by default |
| **Scope** | Package-level permissions | Workflow-specific authentication |

### Security Comparison

**Classic/Granular Tokens:**
- Can be accidentally exposed in CI logs or configuration files
- Persist until manually revoked
- Primary vector for supply chain attacks
- Require manual distribution to multiple repositories

**OIDC Trusted Publishing:**
- Uses temporary, job-specific credentials from CI/CD provider
- Valid only for the specific publishing operation
- Cannot be exfiltrated or reused
- Trust relationship established once with public information only

---

## Step-by-Step Setup

### Prerequisites

1. **npm CLI version**: v11.5.1 or later
   ```bash
   npm --version  # Check your version
   npm install -g npm@latest  # Update if needed
   ```

2. **GitHub repository**: With Actions enabled
3. **npm account**: With package publishing permissions
4. **Cloud-hosted runner**: Self-hosted runners not yet supported

### Step 1: Configure Trusted Publisher on npmjs.com

1. **Navigate to package settings**:
   - Go to [npmjs.com](https://www.npmjs.com/)
   - Sign in to your account
   - Navigate to your package (or create new package first)
   - Click on the package name → Settings tab

2. **Find the "Trusted Publisher" section**:
   - Scroll down to the "Trusted Publisher" configuration area
   - Click "Select your publisher"

3. **Choose GitHub Actions**:
   - Click the "GitHub Actions" button

4. **Configure publisher details** (exact fields required):
   - **Organization/User**: Your GitHub username or organization (e.g., `yourusername`)
   - **Repository**: Repository name without owner (e.g., `my-package`)
   - **Workflow filename**: Exact filename of your workflow (e.g., `publish.yml`)
   - **Environment name**: (Optional) GitHub environment name if you use deployment environments

   **Example Configuration**:
   ```
   Organization/User: octocat
   Repository: awesome-package
   Workflow filename: publish.yml
   Environment name: production  (optional)
   ```

5. **Save configuration**:
   - Click "Add" or "Save" to create the trust relationship
   - Note: Each package can only have ONE trusted publisher configured at a time

### Step 2: Update package.json (Optional but Recommended)

Add package configuration for clarity:

```json
{
  "name": "your-package-name",
  "version": "1.0.0",
  "publishConfig": {
    "access": "public",
    "registry": "https://registry.npmjs.org/"
  }
}
```

### Step 3: Remove npm Token Secrets (After Verification)

Once OIDC publishing is working, you can remove `NPM_TOKEN` from your GitHub repository secrets:
- Go to repository Settings → Secrets and variables → Actions
- Delete `NPM_TOKEN` (or keep as fallback during transition)

---

## GitHub Actions Workflow Configuration

### Minimal Working Example

```yaml
name: Publish to npm

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest

    # REQUIRED: These permissions are critical for OIDC
    permissions:
      contents: read      # To checkout code
      id-token: write     # To generate OIDC tokens (REQUIRED)

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'  # REQUIRED

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Publish to npm
        run: npm publish
        # NOTE: No NODE_AUTH_TOKEN env var needed!
        # npm CLI automatically detects OIDC and uses it
```

### Complete Example with Provenance

```yaml
name: Publish Package

on:
  release:
    types: [published]
  workflow_dispatch:  # Manual trigger

jobs:
  publish:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - name: Install dependencies
        run: npm ci

      - name: Build package
        run: npm run build

      - name: Run tests
        run: npm test

      - name: Publish with automatic provenance
        run: npm publish --access public
        # Provenance is automatically included with OIDC
        # No --provenance flag needed
        # No NODE_AUTH_TOKEN env var needed
```

### Example with GitHub Environments

If you use GitHub deployment environments for additional protection:

```yaml
name: Publish to npm

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: production  # Must match npmjs.com configuration

    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - run: npm ci
      - run: npm test
      - run: npm publish
```

### Key Workflow Requirements

| Requirement | Value | Notes |
|-------------|-------|-------|
| **Permission: `id-token`** | `write` | **REQUIRED** - Allows GitHub to generate OIDC tokens |
| **Permission: `contents`** | `read` | Needed to checkout code |
| **`registry-url`** | `https://registry.npmjs.org` | **REQUIRED** in `setup-node` action |
| **Runner** | Cloud-hosted (e.g., `ubuntu-latest`) | Self-hosted not yet supported |
| **npm CLI** | v11.5.1+ | Older versions don't support OIDC |
| **Node version** | 20+ recommended | Includes npm v10.5.0+ |

### What's NOT Needed

- ❌ `NODE_AUTH_TOKEN` environment variable
- ❌ `NPM_TOKEN` secret
- ❌ `.npmrc` file configuration (setup-node creates it)
- ❌ `--provenance` flag (automatic with OIDC)
- ❌ Manual token rotation scripts

---

## Provenance Attestations

### What is Provenance?

Provenance attestations are cryptographically signed metadata that prove:
- Where the package was built (CI/CD platform, runner)
- What source code was used (git commit SHA, repository)
- When it was published (timestamp)
- Who authorized it (workflow, actor)

This creates a verifiable chain of custody from source code to published package.

### Automatic Provenance with OIDC

When using trusted publishing, npm CLI automatically:
1. Generates provenance attestations during `npm publish`
2. Signs them cryptographically
3. Uploads them to [Sigstore's Rekor](https://rekor.sigstore.dev/) (public transparency log)
4. Attaches them to the package on npm registry

**No `--provenance` flag needed!**

### Manual Provenance (Without OIDC)

If you're using tokens instead of OIDC, you must add the `--provenance` flag:

```yaml
- name: Publish with provenance
  run: npm publish --provenance --access public
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

Requirements for manual provenance:
- `id-token: write` permission
- `registry-url` in setup-node
- GitHub Actions or GitLab CI/CD
- Cloud-hosted runner

### Viewing Provenance

After publishing, provenance is visible on the npm package page:
1. Go to `https://www.npmjs.com/package/your-package-name`
2. Click on a specific version
3. Look for "Provenance" section showing:
   - Build badge (e.g., "Built and signed on GitHub Actions")
   - Source repository link
   - Commit SHA
   - Workflow file link
   - Public transparency log link

### Verifying Provenance

Use npm CLI to verify all installed packages:

```bash
# Install your dependencies first
npm ci

# Verify provenance attestations
npm audit signatures
```

**Expected output** (all valid):
```
audited 1640 packages in 2s
1640 packages have verified registry signatures
1640 packages have verified attestations
```

**Error example** (missing signatures):
```
ERROR: Some packages are missing registry signatures or attestations
```

### Provenance Benefits

- **Supply chain security**: Detect tampering after publication
- **Build reproducibility**: Verify packages match source code
- **Compliance**: Meet SLSA (Supply chain Levels for Software Artifacts) requirements
- **Trust**: Consumers can verify package authenticity
- **Transparency**: Public log prevents post-publication modification

---

## Testing Without Publishing

### Dry Run with OIDC

Test your publish workflow without actually publishing:

```bash
npm publish --dry-run
```

This command:
- Validates package.json
- Shows what files will be included
- Tests OIDC authentication (if in CI/CD)
- Reports package size and contents
- **Does NOT publish to registry**

**Example output:**
```
npm notice
npm notice package: your-package@1.0.0
npm notice === Tarball Contents ===
npm notice 1.2kB  package.json
npm notice 543B   index.js
npm notice 2.1kB  README.md
npm notice === Tarball Details ===
npm notice name:          your-package
npm notice version:       1.0.0
npm notice filename:      your-package-1.0.0.tgz
npm notice package size:  2.1 kB
npm notice unpacked size: 3.8 kB
npm notice total files:   3
npm notice
+ your-package@1.0.0
```

### Test in GitHub Actions

Add a test job before actual publish:

```yaml
jobs:
  test-publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - run: npm ci
      - run: npm test

      - name: Dry run publish (test OIDC)
        run: npm publish --dry-run

  publish:
    needs: test-publish
    runs-on: ubuntu-latest
    # ... actual publish job
```

### Verification Steps After First Publish

1. **Check npm package page**: Visit `https://www.npmjs.com/package/your-package`
2. **Verify provenance badge**: Look for "Built and signed on GitHub Actions"
3. **Check version**: Ensure correct version was published
4. **Audit signatures**: Run `npm audit signatures` after installing
5. **Review Rekor log**: Click transparency log link on package page

### npm whoami Limitation

**Important**: `npm whoami` will NOT show OIDC authentication status:

```bash
npm whoami
# Error: need auth
```

This is expected! OIDC authentication only occurs during the `npm publish` operation, not for general authentication. The `npm whoami` command requires a long-lived token.

---

## Troubleshooting

### Decision Tree

```
npm publish fails?
│
├─ Error: "ENEEDAUTH"
│  ├─ Check: registry-url in setup-node?
│  │  └─ Add: registry-url: 'https://registry.npmjs.org'
│  │
│  ├─ Check: id-token: write permission?
│  │  └─ Add to permissions: id-token: write
│  │
│  └─ Check: npm CLI version >= 11.5.1?
│     └─ Update: npm install -g npm@latest
│
├─ Error: "404 Not Found"
│  ├─ Check: Package exists on npmjs.com?
│  │  └─ First publish: Use npm publish (not possible with OIDC for first publish)
│  │
│  └─ Check: Trusted publisher configured correctly?
│     └─ Verify: org/repo/workflow name matches exactly
│
├─ Error: "Workflow name mismatch"
│  ├─ Check: Using workflow_call or workflow_dispatch?
│  │  └─ Known issue: OIDC validates calling workflow name
│  │  └─ Workaround: Put publish in main workflow, not reusable workflow
│  │
│  └─ Check: Workflow filename matches npmjs.com config?
│     └─ Exact match required: publish.yml not publish.yaml
│
└─ OIDC works but no provenance?
   ├─ Check: npm CLI version >= 11.5.1?
   │  └─ Automatic provenance requires 11.5.1+
   │
   └─ Check: Cloud-hosted runner?
      └─ Self-hosted runners don't support provenance yet
```

### Common Errors and Solutions

#### 1. ENEEDAUTH Error

**Error:**
```
npm error code ENEEDAUTH
npm error need auth This command requires you to be logged in to https://registry.npmjs.org/
npm error need auth You need to authorize this machine using `npm adduser`
```

**Causes:**
- Missing `registry-url` in setup-node action
- Missing `id-token: write` permission
- npm CLI version < 11.5.1
- Not running on cloud-hosted runner

**Solutions:**

```yaml
# Solution 1: Add registry-url
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    registry-url: 'https://registry.npmjs.org'  # ADD THIS

# Solution 2: Add permission
permissions:
  contents: read
  id-token: write  # ADD THIS

# Solution 3: Ensure modern Node/npm
- uses: actions/setup-node@v4
  with:
    node-version: '20'  # Includes npm 10.5.0+
```

#### 2. 404 Not Found

**Error:**
```
npm error code E404
npm error 404 Not Found - PUT https://registry.npmjs.org/your-package
```

**Causes:**
- Package doesn't exist yet (first publish)
- Trusted publisher configuration doesn't match workflow
- Package name typo

**Solutions:**

```bash
# First publish must use token (OIDC only works for updates)
# After first publish, configure trusted publisher

# Verify package name in package.json matches
cat package.json | grep '"name"'

# Check npmjs.com trusted publisher config:
# - Organization: yourusername (exact match)
# - Repository: your-repo (exact match)
# - Workflow: publish.yml (exact filename, not publish.yaml)
```

#### 3. Workflow Name Mismatch

**Error:**
```
npm error Workflow name validation failed
```

**Cause:**
Using `workflow_call` or `workflow_dispatch` - OIDC validates the *calling* workflow name, not the workflow with the publish step.

**Solution:**
Put the publish step directly in the workflow file specified in npmjs.com configuration, don't use reusable workflows:

```yaml
# ❌ DON'T: Reusable workflow
# .github/workflows/main.yml
jobs:
  publish:
    uses: ./.github/workflows/reusable-publish.yml

# ✅ DO: Direct publish in main workflow
# .github/workflows/publish.yml (matches npmjs.com config)
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - run: npm publish
```

#### 4. Self-Hosted Runner Not Supported

**Error:**
```
npm error Trusted publishing requires cloud-hosted runner
```

**Cause:**
Self-hosted runners are not yet supported for OIDC publishing.

**Solution:**
Use cloud-hosted runners:
```yaml
jobs:
  publish:
    runs-on: ubuntu-latest  # Not self-hosted
```

#### 5. Token Still Being Used

**Issue:**
OIDC is configured but workflow still uses `NODE_AUTH_TOKEN`.

**Solution:**
Remove the environment variable:

```yaml
# ❌ DON'T: Mix OIDC and tokens
- run: npm publish
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

# ✅ DO: Let npm CLI auto-detect OIDC
- run: npm publish
```

npm CLI automatically tries OIDC first, then falls back to tokens.

#### 6. Yarn Interferes with OIDC

**Error:**
OIDC fails when using Yarn in CI.

**Cause:**
Yarn sets `NPM_CONFIG_REGISTRY` environment variable, which overrides `.npmrc` created by setup-node.

**Solution:**
Use npm/npx instead of yarn in CI:
```yaml
# ❌ DON'T
- run: yarn publish

# ✅ DO
- run: npm publish
# or
- run: npx npm publish
```

### Debug Checklist

- [ ] npm CLI version >= 11.5.1: `npm --version`
- [ ] Node.js version 18+: `node --version`
- [ ] Cloud-hosted runner: `runs-on: ubuntu-latest`
- [ ] Permission `id-token: write` in workflow
- [ ] `registry-url` in setup-node action
- [ ] Workflow filename matches npmjs.com exactly (including `.yml` vs `.yaml`)
- [ ] Organization/repository name matches exactly
- [ ] Not using `workflow_call` to invoke publish
- [ ] No `NODE_AUTH_TOKEN` in publish step
- [ ] Package already published once (OIDC doesn't work for first publish)
- [ ] Trusted publisher configured on npmjs.com

---

## npm 2025 Security Changes

### Timeline

| Date | Change |
|------|--------|
| **Early October 2025** | Token lifetime limits and TOTP changes took effect |
| **Mid-October 2025** | New tokens default to 7-day expiration |
| **Mid-November 2025** | Classic tokens revoked and generation disabled |

### 1. Token Expiration Changes

**New Granular Access Tokens** (starting mid-October 2025):
- Default expiration: **7 days** (reduced from 30 days)
- Maximum expiration: **90 days** (reduced from unlimited)
- Applies to: All newly created write-enabled granular access tokens

**Existing Tokens:**
- Continue working with current expiration dates
- Grace period provided for transition
- Should be migrated to OIDC or shorter-lived tokens

### 2. TOTP 2FA Phase-Out

**Timeline:**
- New TOTP setups: **Permanently disabled** (October 2025)
- Existing TOTP configs: **Continue working** but will be phased out
- Recommended migration: **WebAuthn/Passkeys**

**Action Required:**
```
1. Disable TOTP 2FA in npm account settings
2. Enable WebAuthn/Passkey authentication
3. Register hardware security key or device biometrics
```

### 3. Classic Token Sunset

**Classic npm tokens:**
- Generation disabled: **Mid-November 2025**
- Existing tokens revoked: **Mid-November 2025**
- Permanent change: No re-enabling

**Migration path:**
```
Classic tokens → Granular access tokens → OIDC trusted publishing
(deprecated)      (short-lived)           (recommended)
```

### 4. Mandatory 2FA for Publishers

**Requirement:**
All npm package publishers must enable two-factor authentication (2FA).

**Recommended methods:**
1. **WebAuthn/Passkeys** (most secure)
2. **Authenticator app** (fallback)

### 5. Recommended Actions

**Immediate (October 2025):**
- [ ] Migrate from classic tokens to granular tokens or OIDC
- [ ] Enable 2FA with WebAuthn/passkeys
- [ ] Update CI/CD workflows to use OIDC

**Long-term:**
- [ ] Adopt OIDC trusted publishing for all packages
- [ ] Remove all long-lived tokens from CI/CD
- [ ] Implement automated provenance verification
- [ ] Regular security audits with `npm audit signatures`

### Why These Changes?

**Supply chain security concerns:**
- Long-lived tokens are primary attack vector
- Token exposure in logs, config files
- Difficulty tracking token usage
- Manual rotation burden

**OIDC advantages:**
- Eliminates token storage entirely
- Automatic credential management
- Workflow-specific authentication
- Built-in provenance attestations

---

## Migration Checklist

### Phase 1: Preparation

- [ ] Verify npm CLI version >= 11.5.1 locally
- [ ] Ensure Node.js 18+ in GitHub Actions
- [ ] Review existing publish workflows
- [ ] Identify all packages to migrate
- [ ] Document current token usage
- [ ] Enable 2FA with WebAuthn/passkey on npm account

### Phase 2: Configure Trusted Publishing

For each package:
- [ ] Log in to npmjs.com
- [ ] Navigate to package settings
- [ ] Find "Trusted Publisher" section
- [ ] Select "GitHub Actions"
- [ ] Enter exact configuration:
  - [ ] Organization/User: `_________`
  - [ ] Repository: `_________`
  - [ ] Workflow filename: `_________.yml`
  - [ ] Environment (optional): `_________`
- [ ] Save configuration
- [ ] Document configuration for team

### Phase 3: Update GitHub Actions Workflow

- [ ] Add `permissions` block with `id-token: write`
- [ ] Add `permissions` block with `contents: read`
- [ ] Ensure `registry-url` in setup-node action
- [ ] Remove `NODE_AUTH_TOKEN` from publish step (comment out first)
- [ ] Verify no `.npmrc` is committed in repository
- [ ] Test workflow with `--dry-run` first
- [ ] Update documentation/README

### Phase 4: Test Publish

- [ ] Create test release or trigger workflow manually
- [ ] Monitor workflow logs for OIDC authentication
- [ ] Verify publish succeeds without token
- [ ] Check provenance on npm package page
- [ ] Run `npm audit signatures` on installed package
- [ ] Verify transparency log link works

### Phase 5: Cleanup

- [ ] Remove `NPM_TOKEN` from GitHub secrets (or rename as backup)
- [ ] Revoke granular access tokens on npmjs.com
- [ ] Update team documentation
- [ ] Share migration guide with team
- [ ] Schedule review of other repositories

### Phase 6: Monitor and Maintain

- [ ] Set up alerts for publish failures
- [ ] Review provenance on each release
- [ ] Keep npm CLI updated
- [ ] Periodic `npm audit signatures` checks
- [ ] Monitor GitHub security advisories

---

## Official Documentation Links

### npm Documentation
- **Trusted Publishing**: https://docs.npmjs.com/trusted-publishers/
- **Generating Provenance**: https://docs.npmjs.com/generating-provenance-statements/
- **Viewing Provenance**: https://docs.npmjs.com/viewing-package-provenance/
- **npm Audit**: https://docs.npmjs.com/cli/v10/commands/npm-audit/
- **Creating Access Tokens**: https://docs.npmjs.com/creating-and-viewing-access-tokens/
- **2FA Requirements**: https://docs.npmjs.com/requiring-2fa-for-package-publishing-and-settings-modification/

### GitHub Documentation
- **OIDC in GitHub Actions**: https://docs.github.com/en/actions/security-guides/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- **Artifact Attestations**: https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds
- **Workflow Syntax**: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- **Permissions for GITHUB_TOKEN**: https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token

### Changelogs and Announcements
- **npm Trusted Publishing GA**: https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/
- **npm Security Changes**: https://github.blog/changelog/2025-09-29-strengthening-npm-security-important-changes-to-authentication-and-token-management/
- **npm CLI Releases**: https://github.com/npm/cli/releases

### Related Resources
- **Sigstore Rekor**: https://rekor.sigstore.dev/ (Transparency log)
- **SLSA Framework**: https://slsa.dev/ (Supply chain security levels)
- **npm Provenance Details**: https://github.com/npm/provenance

### Community Discussions
- **npm OIDC Feature Discussion**: https://github.com/orgs/community/discussions/127011
- **GitHub Actions Examples**: https://github.com/marketplace/actions/npm-publish

---

## Quick Reference

### Minimal OIDC Workflow

```yaml
name: Publish
on: [release]
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci
      - run: npm publish
```

### Key Commands

```bash
# Check npm version
npm --version

# Dry run publish
npm publish --dry-run

# Verify provenance
npm audit signatures

# View package provenance online
https://www.npmjs.com/package/YOUR-PACKAGE-NAME
```

### Required Fields on npmjs.com

- **Organization/User**: GitHub username or org
- **Repository**: Repo name (no owner prefix)
- **Workflow filename**: Exact filename (e.g., `publish.yml`)
- **Environment**: (Optional) GitHub environment name

### Required in GitHub Actions

```yaml
permissions:
  id-token: write  # REQUIRED for OIDC
  contents: read   # Needed for checkout

uses: actions/setup-node@v4
with:
  registry-url: 'https://registry.npmjs.org'  # REQUIRED
```

---

**Questions or Issues?**

- Check [npm docs](https://docs.npmjs.com/trusted-publishers/)
- Ask in [GitHub Community Discussions](https://github.com/orgs/community/discussions)
- File issues at [npm/cli repository](https://github.com/npm/cli/issues)

---

**Document Version:** 1.0
**Generated:** October 2025
