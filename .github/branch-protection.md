# Branch Protection Configuration

This document outlines the required branch protection rules for the NixOS configuration repository.

## Branch Protection Rules

### Main Branch (Production)
**Branch:** `main`

**Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Require a pull request before merging
  - ✅ Require approvals: **2** (minimum)
  - ✅ Dismiss stale PR approvals when new commits are pushed
  - ✅ Require review from code owners
  - ✅ Restrict approvals to users with write access
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - **Required status checks:**
    - `validate / Validate Configuration`
    - `integration-tests / Integration Tests`
    - `load-tests / Load Tests`
    - `approval-gate / Manual Approval Required`
- ✅ Require conversation resolution before merging
- ✅ Require signed commits
- ✅ Require linear history
- ✅ Include administrators (enforce for admins too)
- ✅ Restrict force pushes
- ✅ Allow deletions: **NO**

### Staging Branch
**Branch:** `staging`

**Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Require a pull request before merging (only for PRs to main)
- ✅ Require status checks to pass before merging
  - **Required status checks:**
    - `pre-flight / Pre-flight Checks`
    - `integration-tests / Integration Tests`
- ✅ Require signed commits
- ✅ Restrict force pushes from non-admins
- ✅ Allow deletions: **YES** (for branch management)

### Dev Branch
**Branch:** `dev`

**Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Require status checks to pass before merging
  - **Required status checks:**
    - `validate / Pre-deployment Validation`
    - `smoke-tests / Smoke Tests`
- ✅ Allow force pushes from admins
- ✅ Allow deletions: **YES**

## Required Secrets

Configure the following repository secrets:

### SSH Keys
- `DEV_VM_SSH_KEY` - SSH private key for dev VM access
- `STAGING_VM_SSH_KEY` - SSH private key for staging VM access  
- `PRODUCTION_SSH_KEY` - SSH private key for production bare metal access

### Optional Integration Secrets
- `CACHIX_AUTH_TOKEN` - Cachix authentication token (for faster builds)
- `SLACK_WEBHOOK_URL` - Slack webhook for deployment notifications

## Environment Protection Rules

### Production Environment
**Environment:** `production`

**Settings:**
- ✅ Required reviewers: **2** (minimum)
- ✅ Wait timer: **5 minutes** (cooling-off period)
- ✅ Deployment protection rules:
  - Only deploy from `main` branch
  - Require passing status checks
  - Require manual approval

### Production Approval Environment  
**Environment:** `production-approval`

**Settings:**
- ✅ Required reviewers: **1** (senior team member)
- ✅ Deployment protection rules:
  - Only allow specific users/teams to approve
  - Require all status checks to pass

## Workflow Files Security

Ensure workflow files have proper permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  actions: read
  checks: write
```

## Code Owners File

Create `.github/CODEOWNERS`:

```
# Global ownership
* @your-username

# Critical configuration files
/hosts/nixos/default.nix @senior-team-member @infrastructure-team
/flake.nix @senior-team-member
/.github/workflows/ @devops-team @senior-team-member

# Security-sensitive files
/modules/*/security/ @security-team @senior-team-member
```

## Auto-merge Configuration

For automated dependency updates, configure auto-merge rules:

1. Create a separate workflow for dependency PRs
2. Allow auto-merge only for:
   - Minor version updates
   - Security patches
   - After all checks pass
   - With specific labels (e.g., `dependencies`, `auto-merge`)

## Manual Setup Instructions

### 1. Configure Branch Protection (GitHub UI)

1. Go to **Settings** → **Branches**
2. Add rules for each branch using settings above
3. Ensure "Include administrators" is checked for main branch

### 2. Create Environments (GitHub UI)

1. Go to **Settings** → **Environments**
2. Create `production` and `production-approval` environments
3. Configure protection rules as specified above

### 3. Add Repository Secrets (GitHub UI)

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add all required secrets listed above
3. Ensure secrets are properly scoped to environments

### 4. Set Up Code Owners

1. Create `.github/CODEOWNERS` file with appropriate team assignments
2. Update teams/usernames to match your organization

### 5. Enable Security Features

1. Go to **Settings** → **Security**
2. Enable:
   - Dependency graph
   - Dependabot alerts
   - Dependabot security updates
   - Secret scanning
   - Code scanning (if available)

## Testing the Setup

After configuration, test the workflow:

1. Create a feature branch
2. Make a small change
3. Push to `dev` branch
4. Verify dev deployment workflow runs
5. Check that staging promotion happens automatically
6. Create PR from staging to main
7. Verify all required checks run
8. Test manual approval process

The branch protection is now configured for safe, automated NixOS deployments!