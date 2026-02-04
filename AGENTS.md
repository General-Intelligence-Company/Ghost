# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.

## Package Manager

**Always use `yarn` (v1) for all commands.** This repository uses yarn workspaces, not npm.

## Monorepo Structure

Ghost is a Yarn v1 + Nx monorepo with three workspace groups:

### ghost/* - Core Ghost packages
- **ghost/core** - Main Ghost application (Node.js/Express backend)
  - Core server: `ghost/core/core/server/`
  - Frontend rendering: `ghost/core/core/frontend/`
- **ghost/admin** - Ember.js admin client (legacy, being migrated to React)
- **ghost/i18n** - Centralized internationalization for all apps

### apps/* - React-based UI applications
Two categories of apps:

**Admin Apps** (embedded in Ghost Admin):
- `admin-x-settings`, `admin-x-activitypub` - Settings and integrations
- `posts`, `stats` - Post analytics and site-wide analytics
- Built with Vite + React + `@tanstack/react-query`

**Public Apps** (served to site visitors):
- `portal`, `comments-ui`, `signup-form`, `sodo-search`, `announcement-bar`
- Built as UMD bundles, loaded via CDN in site themes

**Foundation Libraries**:
- `admin-x-framework` - Shared API hooks, routing, utilities
- `admin-x-design-system` - Legacy design system (being phased out)
- `shade` - New design system (shadcn/ui + Radix UI + react-hook-form + zod)

### e2e/ - End-to-end tests
- Playwright-based E2E tests with Docker container isolation
- See `e2e/CLAUDE.md` for detailed testing guidance

## Common Commands

### Development
```bash
yarn                           # Install dependencies
yarn setup                     # First-time setup (installs deps + submodules)
yarn dev                       # Start development (Docker backend + host frontend dev servers)
yarn dev:legacy                # Local dev with legacy admin and without Docker (deprecated)
yarn dev:legacy:debug          # yarn dev:legacy with DEBUG=@tryghost*,ghost:* enabled
```

### Building
```bash
yarn build                     # Build all packages (Nx handles dependencies)
yarn build:clean               # Clean build artifacts and rebuild
```

### Testing
```bash
# Unit tests (from root)
yarn test:unit                 # Run all unit tests in all packages

# Ghost core tests (from ghost/core/)
cd ghost/core
yarn test:unit                 # Unit tests only
yarn test:integration          # Integration tests
yarn test:e2e                  # E2E API tests (not browser)
yarn test:browser              # Playwright browser tests for core
yarn test:all                  # All test types

# E2E browser tests (from root)
yarn test:e2e                  # Run e2e/ Playwright tests

# Running a single test
cd ghost/core
yarn test:single test/unit/path/to/test.test.js
```

### Linting
```bash
yarn lint                      # Lint all packages
cd ghost/core && yarn lint     # Lint Ghost core (server, shared, frontend, tests)
cd ghost/admin && yarn lint    # Lint Ember admin
```

### Database
```bash
yarn knex-migrator migrate     # Run database migrations
yarn reset:data                # Reset database with test data (1000 members, 100 posts)
yarn reset:data:empty          # Reset database with no data
```

### Docker
```bash
yarn docker:build              # Build Docker images and delete ephemeral volumes
yarn docker:dev                # Start Ghost in Docker with hot reload
yarn docker:shell              # Open shell in Ghost container
yarn docker:mysql              # Open MySQL CLI
yarn docker:test:unit          # Run unit tests in Docker
yarn docker:reset              # Reset all Docker volumes (including database) and restart
```

### How yarn dev works

The `yarn dev` command uses a **hybrid Docker + host development** setup:

**What runs in Docker:**
- Ghost Core backend (with hot-reload via mounted source)
- MySQL, Redis, Mailpit
- Caddy gateway/reverse proxy

**What runs on host:**
- Frontend dev servers (Admin, Portal, Comments UI, etc.) in watch mode with HMR
- Foundation libraries (shade, admin-x-framework, etc.)

**Setup:**
```bash
# Start everything (Docker + frontend dev servers)
yarn dev

# With optional services (uses Docker Compose file composition)
yarn dev:analytics             # Include Tinybird analytics
yarn dev:storage               # Include MinIO S3-compatible object storage
yarn dev:all                   # Include all optional services
```

**Accessing Services:**
- Ghost: `http://localhost:2368` (database: `ghost_dev`)
- Mailpit UI: `http://localhost:8025` (email testing)
- MySQL: `localhost:3306`
- Redis: `localhost:6379`
- Tinybird: `http://localhost:7181` (when analytics enabled)
- MinIO Console: `http://localhost:9001` (when storage enabled)
- MinIO S3 API: `http://localhost:9000` (when storage enabled)

## Architecture Patterns

### Admin Apps Integration (Micro-Frontend)

**Build Process:**
1. Admin-x React apps build to `apps/*/dist` using Vite
2. `ghost/admin/lib/asset-delivery` copies them to `ghost/core/core/built/admin/assets/*`
3. Ghost admin serves from `/ghost/assets/{app-name}/{app-name}.js`

**Runtime Loading:**
- Ember admin uses `AdminXComponent` to dynamically import React apps
- React components wrapped in Suspense with error boundaries
- Apps receive config via `additionalProps()` method

### Public Apps Integration

- Built as UMD bundles to `apps/*/umd/*.min.js`
- Loaded via `<script>` tags in theme templates (injected by `{{ghost_head}}`)
- Configuration passed via data attributes

### i18n Architecture

**Centralized Translations:**
- Single source: `ghost/i18n/locales/{locale}/{namespace}.json`
- Namespaces: `ghost`, `portal`, `signup-form`, `comments`, `search`
- 60+ supported locales

### Build Dependencies (Nx)

Critical build order (Nx handles automatically):
1. `shade` + `admin-x-design-system` build
2. `admin-x-framework` builds (depends on #1)
3. Admin apps build (depend on #2)
4. `ghost/admin` builds (depends on #3, copies via asset-delivery)
5. `ghost/core` serves admin build

## Code Guidelines

### Commit Messages
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

Example:
```
✨ Added dark mode toggle to admin settings

fixes https://github.com/TryGhost/Ghost/issues/12345
Users requested ability to switch themes for better accessibility
```

### When Working on Admin UI
- **New features:** Build in React (`apps/admin-x-*` or `apps/posts`)
- **Use:** `admin-x-framework` for API hooks (`useBrowse`, `useEdit`, etc.)
- **Use:** `shade` design system for new components (not admin-x-design-system)
- **Translations:** Add to `ghost/i18n/locales/en/ghost.json`

### When Working on Public UI
- **Edit:** `apps/portal`, `apps/comments-ui`, etc.
- **Translations:** Separate namespaces (`portal.json`, `comments.json`)
- **Build:** UMD bundles for CDN distribution

### When Working on Backend
- **Core logic:** `ghost/core/core/server/`
- **Database Schema:** `ghost/core/core/server/data/schema/`
- **API routes:** `ghost/core/core/server/api/`
- **Services:** `ghost/core/core/server/services/`
- **Models:** `ghost/core/core/server/models/`
- **Frontend & theme rendering:** `ghost/core/core/frontend/`

### Design System Usage
- **New components:** Use `shade` (shadcn/ui-inspired)
- **Legacy:** `admin-x-design-system` (being phased out, avoid for new work)

### Analytics (Tinybird)
- **Local development:** `yarn docker:dev:analytics` (starts Tinybird + MySQL)
- **Config:** Add Tinybird config to `ghost/core/config.development.json`
- **Scripts:** `ghost/core/core/server/data/tinybird/scripts/`
- **Datafiles:** `ghost/core/core/server/data/tinybird/`

## Testing Patterns

### Test File Naming Conventions

| Location | Pattern | Example |
|----------|---------|---------|
| ghost/core unit tests | `*.test.js` | `date.test.js` |
| ghost/core integration | `*.test.js` | `posts.test.js` |
| React apps (Vitest) | `*.test.ts` | `analytics.test.ts` |
| E2E tests | `*.test.ts` | `posts.test.ts` |
| Playwright acceptance | `*.test.ts` | `stripe.test.ts` |

### Unit Tests (ghost/core - Mocha)

Located in `ghost/core/test/unit/`. Uses Mocha + Sinon + Should.js:

```javascript
const assert = require('assert/strict');
const sinon = require('sinon');
const should = require('should');

// Import the module being tested
const myModule = require('../../../../core/server/services/my-module');

describe('MyModule', function () {
    afterEach(function () {
        sinon.restore();
    });

    it('should do something specific', function () {
        const stub = sinon.stub(dependency, 'method').returns('value');

        const result = myModule.doSomething();

        result.should.equal('expected');
        stub.calledOnce.should.be.true();
    });
});
```

**Running unit tests:**
```bash
cd ghost/core
yarn test:unit                              # All unit tests
yarn test:single test/unit/path/to/test.js  # Single test file
```

### Unit Tests (React Apps - Vitest)

Located in `apps/*/test/unit/`. Uses Vitest:

```typescript
import {describe, it, expect} from 'vitest';
import {myFunction} from '../../src/utils/my-function';

describe('myFunction', () => {
    it('should return expected value', () => {
        const result = myFunction('input');
        expect(result).toBe('expected');
    });
});
```

**Running Vitest tests:**
```bash
cd apps/admin-x-settings
yarn test                    # Run all tests
yarn test -- --watch         # Watch mode
```

### E2E Tests (Playwright)

Located in `e2e/tests/`. See `e2e/CLAUDE.md` for comprehensive guidance.

**Test structure follows AAA pattern (Arrange-Act-Assert):**

```typescript
import {PostFactory, createPostFactory} from '@/data-factory';
import {PostsPage} from '@/helpers/pages';
import {expect, test} from '@/helpers/playwright';

test.describe('Ghost Admin - Posts', () => {
    test('lists posts', async ({page}) => {
        // Arrange
        const postFactory: PostFactory = createPostFactory(page.request);
        const postsPage = new PostsPage(page);

        // Act
        await postsPage.goto();
        await postFactory.create({title: 'Test Post'});
        await postsPage.refreshData();

        // Assert
        await expect(postsPage.postsListItem).toHaveCount(2);
    });
});
```

**Running E2E tests:**
```bash
# From repository root
yarn test:e2e                                    # All E2E tests
yarn test:e2e -- tests/admin/posts/posts.test.ts # Specific test

# From e2e/ directory
cd e2e
yarn test                                        # All tests
yarn test tests/admin/posts/posts.test.ts        # Specific test
yarn test --debug                                # Debug mode (visible browser)
PRESERVE_ENV=true yarn test                      # Keep containers after failure
```

### Mocking Patterns

**Sinon (ghost/core):**
```javascript
// Stub a method
const stub = sinon.stub(object, 'method').returns('value');

// Spy on a method
const spy = sinon.spy(object, 'method');

// Mock timers
const clock = sinon.useFakeTimers();
clock.tick(1000);

// Always restore in afterEach
afterEach(function () {
    sinon.restore();
});
```

**Vitest (React apps):**
```typescript
import {vi, describe, it, expect, beforeEach} from 'vitest';

// Mock a module
vi.mock('../../src/api/client', () => ({
    fetchData: vi.fn().mockResolvedValue({data: 'mocked'})
}));

// Spy on a function
const spy = vi.spyOn(object, 'method');
```

## Database Migrations

### Migration File Location

Migrations are located in `ghost/core/core/server/data/migrations/versions/`.

Organized by Ghost version:
```
migrations/versions/
├── 5.87/
├── 5.89/
├── ...
├── 6.14/
├── 6.15/
└── 6.16/
    └── 2026-01-27-12-55-51-add-discount-start-end-to-subscriptions.js
```

### Migration File Naming Convention

Format: `YYYY-MM-DD-HH-mm-ss-description.js`

Example: `2026-01-27-12-55-51-add-discount-start-end-to-subscriptions.js`

- **Timestamp:** When the migration was created
- **Description:** Kebab-case description of what the migration does

### Creating a New Migration

**1. Use the migration utilities:**

```javascript
const {createAddColumnMigration, combineNonTransactionalMigrations} = require('../../utils');

module.exports = combineNonTransactionalMigrations(
    createAddColumnMigration('table_name', 'column_name', {
        type: 'string',
        maxlength: 191,
        nullable: true
    })
);
```

**2. Common migration helpers:**

| Helper | Use Case |
|--------|----------|
| `createAddColumnMigration` | Add a new column to a table |
| `createDropColumnMigration` | Remove a column from a table |
| `createAddTableMigration` | Create a new table |
| `createSetNullableMigration` | Change column nullability |
| `combineNonTransactionalMigrations` | Combine multiple migrations |

**3. For complex migrations:**

```javascript
const logging = require('@tryghost/logging');

module.exports = {
    async up(knex) {
        const hasColumn = await knex.schema.hasColumn('posts', 'new_column');
        if (!hasColumn) {
            logging.info('Adding new_column to posts table');
            await knex.schema.table('posts', (table) => {
                table.string('new_column', 191).nullable();
            });
        }
    },

    async down(knex) {
        const hasColumn = await knex.schema.hasColumn('posts', 'new_column');
        if (hasColumn) {
            logging.info('Removing new_column from posts table');
            await knex.schema.table('posts', (table) => {
                table.dropColumn('new_column');
            });
        }
    }
};
```

### Testing Migrations

```bash
# Run all pending migrations
yarn knex-migrator migrate

# Reset database and run migrations from scratch
yarn knex-migrator reset

# Run migrations in CI (from ghost/core)
cd ghost/core
NODE_ENV=testing yarn knex-migrator migrate
```

## Environment Variables

### Core Configuration

Ghost uses `config.{environment}.json` files in `ghost/core/` for configuration:

| File | Purpose |
|------|---------|
| `config.development.json` | Local development settings |
| `config.testing.json` | Test environment settings |
| `config.production.json` | Production settings (not in repo) |

### Key Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode | `development` |
| `database__connection__host` | MySQL host | `localhost` |
| `database__connection__user` | MySQL user | `root` |
| `database__connection__password` | MySQL password | - |
| `database__connection__database` | Database name | `ghost_dev` |
| `url` | Site URL | `http://localhost:2368` |
| `server__port` | Server port | `2368` |
| `logging__level` | Log level | `info` |

### Local Development Setup

**1. Basic setup (using Docker - recommended):**
```bash
yarn setup        # Install deps + init submodules
yarn dev          # Start Docker backend + frontend dev servers
```

**2. Legacy setup (without Docker):**
```bash
yarn setup
yarn dev:legacy   # Requires local MySQL
```

**3. With optional services:**
```bash
yarn dev:analytics   # Include Tinybird
yarn dev:storage     # Include MinIO S3
yarn dev:all         # Include all optional services
```

### Test Environment Variables

For running tests, these are commonly used:

```bash
# SQLite (faster, in-memory)
NODE_ENV=testing yarn test:unit

# MySQL
NODE_ENV=testing-mysql database__connection__password=root yarn test:integration
```

## Troubleshooting

### Build Issues
```bash
yarn fix                       # Clean cache + node_modules + reinstall
yarn build:clean               # Clean build artifacts
yarn nx reset                  # Reset Nx cache
```

### Test Issues
- **E2E failures:** Check `e2e/CLAUDE.md` for debugging tips
- **Docker issues:** `yarn docker:clean && yarn docker:build`

### Common CI Failures and Fixes

| Failure | Cause | Fix |
|---------|-------|-----|
| `yarn lint` fails | ESLint errors | Run `yarn lint` locally, fix errors |
| Unit tests timeout | Async test not completing | Ensure all promises resolve, check `done()` callbacks |
| E2E tests flaky | Race conditions | Use Playwright's auto-waiting, avoid `waitForTimeout` |
| Build fails | Missing dependencies | Run `yarn` to install, check for circular deps |
| Type errors | TypeScript issues | Run `yarn nx run-many -t build:tsc` to check |
| Migration fails | Schema mismatch | Reset database: `yarn knex-migrator reset` |

### Port Conflicts

Default ports used by Ghost development:

| Port | Service | Fix if in use |
|------|---------|---------------|
| 2368 | Ghost | `lsof -i :2368` then kill process |
| 3306 | MySQL | Stop local MySQL or change Docker port |
| 6379 | Redis | Stop local Redis or change Docker port |
| 8025 | Mailpit | Usually not conflicting |
| 4200 | Ember Admin | Kill other Ember processes |
| 4173 | Vite preview | Kill other Vite processes |
| 5173 | Vite dev | Kill other Vite processes |

**Kill process on port:**
```bash
lsof -ti :2368 | xargs kill -9
```

### Memory Issues

**Node.js heap out of memory:**
```bash
# Increase Node memory limit
NODE_OPTIONS="--max-old-space-size=4096" yarn build

# For persistent fix, add to shell profile:
export NODE_OPTIONS="--max-old-space-size=4096"
```

**Docker memory issues:**
- Increase Docker Desktop memory allocation (Settings → Resources)
- Minimum recommended: 4GB RAM for Docker

### Debugging Tips

**Enable debug logging:**
```bash
DEBUG=@tryghost*,ghost:* yarn dev:legacy
```

**Debug a specific test:**
```bash
# Mocha (ghost/core)
cd ghost/core
yarn test:single test/unit/path/to/test.js --inspect-brk

# Playwright E2E
cd e2e
yarn test --debug tests/admin/posts/posts.test.ts
```

## CI/CD Pipeline

### GitHub Workflows Overview

Ghost uses 6 GitHub workflows in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PRs, pushes to main/release branches | Main CI pipeline - lint, test, build, deploy |
| `create-release-branch.yml` | Manual | Creates release branches from latest tag |
| `label-actions.yml` | Issue/PR events | Automated labeling |
| `migration-review.yml` | PRs with migrations | Adds migration review checklist |
| `stale-i18n.yml` | Schedule | Closes stale i18n PRs |
| `stale.yml` | Schedule | Closes stale issues/PRs |

### Key CI Jobs on Pull Requests

The main `ci.yml` workflow runs these jobs:

| Job | Condition | What it checks |
|-----|-----------|----------------|
| `job_lint` | Any code changes | ESLint across affected packages |
| `job_unit-tests` | Any code changes | Unit tests via `yarn nx affected -t test:unit` |
| `job_admin-tests` | Admin changes | Ember admin tests (Chrome) |
| `job_acceptance-tests` | Core changes | Integration + E2E API tests (MySQL + SQLite) |
| `job_browser-tests` | Main/release or label | Playwright browser tests for ghost/core |
| `job_e2e_tests` | Always | Full E2E Playwright tests (8 parallel shards) |
| `job_admin_x_settings` | Settings app changes | Admin-X Settings Playwright tests |
| `job_comments_ui` | Comments UI changes | Comments-UI Playwright tests |
| `job_signup_form` | Signup form changes | Signup-form E2E tests |
| `job_docker_build` | Always | Builds Docker image |

### CI Job Dependencies

```
job_setup (install deps, detect changes)
    ├── job_lint
    ├── job_unit-tests
    ├── job_admin-tests
    ├── job_acceptance-tests
    ├── job_browser-tests
    ├── job_e2e_tests (depends on job_docker_build)
    └── ...
         └── job_required_tests (gate for merge)
              └── canary (deploy to staging)
```

### Debugging CI Failures Locally

**1. Reproduce the exact CI environment:**
```bash
# Use the same Node version as CI
nvm use 22.18.0

# Install dependencies fresh
rm -rf node_modules
yarn

# Run the same commands as CI
yarn nx affected -t lint --base=main
yarn nx affected -t test:unit --base=main
```

**2. Run specific CI jobs locally:**
```bash
# Lint (same as job_lint)
yarn lint

# Unit tests (same as job_unit-tests)
yarn test:unit

# E2E tests with Docker (same as job_e2e_tests)
yarn docker:build
yarn test:e2e

# Acceptance tests (same as job_acceptance-tests)
cd ghost/core
yarn test:ci:e2e
yarn test:ci:integration
```

**3. Debug E2E test failures:**
```bash
# Download Playwright report from CI artifacts, then:
npx playwright show-report path/to/playwright-report

# Or run locally with debug mode
cd e2e
yarn test --debug tests/path/to/failing.test.ts
PRESERVE_ENV=true yarn test  # Keep containers for inspection
```

### Code Coverage (Codecov)

CI uploads coverage reports to Codecov for:
- Admin tests (`admin-coverage`)
- Unit tests (`unit-coverage`)
- E2E tests (`e2e-coverage`)

Coverage files are in Cobertura XML format at:
- `ghost/*/coverage/cobertura-coverage.xml`
- `ghost/*/coverage-e2e/cobertura-coverage.xml`
- `ghost/*/coverage-integration/cobertura-coverage.xml`

### Required Checks for Merge

The `job_required_tests` job gates PR merges. It requires all these jobs to pass or be skipped:
- `job_lint`
- `job_i18n`
- `job_unit-tests`
- `job_admin-tests`
- `job_acceptance-tests`
- `job_legacy-tests`
- `job_browser-tests`
- `job_e2e_tests`
- All app-specific test jobs

### Triggering Additional CI Jobs

Some jobs only run with specific labels:
- Add `browser-tests` label to run browser tests on PRs
- Add `perf-tests` label to run performance tests
- Add `deploy-to-staging` label to deploy PR to staging
