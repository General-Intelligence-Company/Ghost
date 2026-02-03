# AGENTS.md - AI Agent Guidelines for Ghost

This file provides guidelines for AI coding agents working on the Ghost codebase.

## Overview

Ghost is a professional publishing platform built as a **Yarn v1 + Nx monorepo**. This document helps AI agents navigate the codebase effectively and follow project conventions.

## Quick Start for AI Agents

### Package Manager
**Always use `yarn` (v1)** - never npm. This repository uses yarn workspaces.

### Repository Structure

```
ghost/
├── core/           # Main Ghost backend (Node.js/Express)
├── admin/          # Admin panel (Ember.js - legacy)
└── i18n/           # Centralized internationalization

apps/
├── admin-x-*/      # New React-based admin components
├── portal/         # Membership portal (React)
├── comments-ui/    # Comments system (React)
├── signup-form/    # Signup forms (React)
├── sodo-search/    # Site search (React)
├── announcement-bar/ # Announcement bar (React)
└── shade/          # Design system (shadcn/ui + Radix)

e2e/                # Playwright E2E tests
```

### Key Commands

```bash
# Install dependencies
yarn install

# Run full dev environment (Docker + frontend dev servers)
yarn dev

# Run tests
yarn test:unit                    # All unit tests
yarn nx affected -t test          # Tests for affected packages
cd ghost/core && yarn test:unit   # Core unit tests only

# Run linting
yarn lint                         # Lint all packages
yarn nx affected -t lint          # Lint affected packages

# Build all packages
yarn build

# Reset if things break
yarn fix                          # Clean cache + node_modules + reinstall
yarn nx reset                     # Reset Nx cache
```

## Code Review Checklist for AI Agents

### Before Submitting Changes
- [ ] Run `yarn lint` and fix all errors
- [ ] Run tests in affected packages
- [ ] Ensure TypeScript compiles without errors
- [ ] Check for unused imports and variables
- [ ] Verify no hardcoded secrets or credentials
- [ ] Follow existing patterns in each package

### Code Style Requirements
- Use single quotes for strings
- 4-space indentation
- Semicolons required
- Follow existing ESLint rules per-package
- Use TypeScript strict mode where configured

### Commit Message Format
Follow the project's commit message format:
- **1st line:** Max 80 chars, past tense, with emoji if user-facing
- **2nd line:** [blank]
- **3rd line:** `ref`, `fixes`, or `closes` with issue link
- **4th line:** Context (why this change, why now)

**Emojis for user-facing changes:**
- ✨ Feature
- 🎨 Improvement/change
- 🐛 Bug fix
- 🌐 i18n/translation
- 💡 Other user-facing changes

### Testing Requirements
- Unit tests required for new utility functions
- Integration tests for API endpoints
- E2E tests for critical user flows (see `e2e/AGENTS.md`)
- Maintain existing test coverage

## Common Pitfalls to Avoid

1. **Don't use npm** - Always use yarn
2. **Don't modify package.json in sub-packages directly** - Use root yarn workspaces commands
3. **Respect Nx cache boundaries** - Don't bypass the Nx build system
4. **Check ESLint config per-package** - Rules vary between packages
5. **Don't hardcode URLs** - Use config/environment variables
6. **Respect the monorepo structure** - Changes may affect multiple packages
7. **Don't commit submodule changes accidentally** - The pre-commit hook handles this

## Dependencies Between Packages

Key dependency relationships (Nx handles build order automatically):
1. `shade` + `admin-x-design-system` build first
2. `admin-x-framework` builds (depends on #1)
3. Admin apps build (depend on #2)
4. `ghost/admin` builds (depends on #3, copies via asset-delivery)
5. `ghost/core` serves admin build

## Navigation Tips

### Backend (ghost/core)
- **API routes:** `ghost/core/core/server/web/api/`
- **Models:** `ghost/core/core/server/models/`
- **Services:** `ghost/core/core/server/services/`
- **Database schema:** `ghost/core/core/server/data/schema/`
- **Migrations:** `ghost/core/core/server/data/migrations/`
- **Frontend rendering:** `ghost/core/core/frontend/`

### Admin UI
- **Legacy Ember admin:** `ghost/admin/app/components/`
- **New React admin apps:** `apps/admin-x-*/src/`
- **Design system:** `apps/shade/src/components/`
- **Framework utilities:** `apps/admin-x-framework/src/`

### Tests
- **Unit tests:** Look for `test/` or `__tests__/` directories in each package
- **E2E tests:** `e2e/tests/`
- **Browser tests:** `ghost/core/test/browser/`

## When Making Changes

### For Backend Changes
1. Identify affected models, services, and API routes
2. Check for existing patterns in similar code
3. Add or update unit and integration tests
4. Run `cd ghost/core && yarn test:unit` to verify

### For Admin UI Changes
- **New features:** Build in React (`apps/admin-x-*` or `apps/posts`)
- **Use:** `admin-x-framework` for API hooks (`useBrowse`, `useEdit`, etc.)
- **Use:** `shade` design system for new components (not admin-x-design-system)
- **Translations:** Add to `ghost/i18n/locales/en/ghost.json`

### For Public Apps
- **Edit:** `apps/portal`, `apps/comments-ui`, `apps/signup-form`, etc.
- **Translations:** Use separate namespaces (`portal.json`, `comments.json`)
- **Build:** UMD bundles for CDN distribution

### For Database Changes
1. Create migration in `ghost/core/core/server/data/migrations/`
2. Update schema in `ghost/core/core/server/data/schema/`
3. Run `yarn knex-migrator migrate` to apply
4. Add appropriate tests

## Environment Setup

### Development with Docker (Recommended)
```bash
yarn dev                    # Full dev environment
yarn dev:analytics          # With Tinybird analytics
yarn dev:storage            # With MinIO object storage
```

**Services available:**
- Ghost: `http://localhost:2368`
- Mailpit UI: `http://localhost:8025`
- MySQL: `localhost:3306`
- Redis: `localhost:6379`

### Required Environment Variables
- See `.env.example` files in relevant packages
- Database connection settings
- Mail configuration
- Storage configuration

## Package-Specific Guidelines

### apps/shade (Design System)
See `apps/shade/AGENTS.md` for detailed guidelines including:
- Component structure and naming
- ShadCN component installation
- Storybook documentation requirements

### e2e (E2E Tests)
See `e2e/AGENTS.md` for detailed guidelines including:
- Page object patterns
- Factory pattern for test data
- Locator strategies (semantic first, then data-testid)
- AAA test pattern

## CI/CD Information

The repository uses GitHub Actions for CI:
- **Linting:** Runs on all PRs
- **Testing:** Unit, integration, and E2E tests
- **Security scanning:** Weekly CodeQL analysis
- **Dependency updates:** Dependabot for weekly updates

## Getting Help

1. Check existing code patterns in similar files
2. Review relevant AGENTS.md files in sub-packages
3. Consult ADRs in `adr/` folder for architectural decisions
4. Run `yarn nx graph` to visualize package dependencies
