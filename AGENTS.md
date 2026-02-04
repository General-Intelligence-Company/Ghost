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

## CI/CD Pipeline

### Overview
The CI pipeline runs on every push to `main` and on all pull requests. It uses GitHub Actions with Nx-based caching for optimal performance.

### CI Jobs
The main CI workflow (`.github/workflows/ci.yml`) includes:
- **Setup**: Installs dependencies, caches node_modules and Nx cache
- **Lint**: Runs ESLint on affected packages (`yarn nx affected -t lint`)
- **Unit Tests**: Runs unit tests on affected packages
- **Acceptance Tests**: Runs integration/E2E API tests (MySQL & SQLite)
- **Browser Tests**: Playwright-based browser tests (on main or with `browser-tests` label)
- **Admin Tests**: Ember admin client tests
- **E2E Tests**: Full end-to-end tests with Docker
- **Tinybird Tests**: Analytics datafile validation

### Additional CI Workflows
- **TypeScript Check** (`.github/workflows/typecheck.yml`): Explicit type checking across all packages
- **Security Scan** (`.github/workflows/security.yml`): CodeQL analysis and npm audit
- **Migration Review**: Validates database migration files

### Fixing CI Failures

**Lint failures:**
```bash
yarn lint                      # Run linting locally
yarn nx affected -t lint       # Run on affected packages only
```

**Unit test failures:**
```bash
yarn test:unit                 # Run all unit tests
cd ghost/core && yarn test:single test/unit/path/to/test.test.js
```

**Type check failures:**
```bash
yarn nx run-many -t typecheck  # Run TypeScript checks
```

**E2E failures:**
- Check the Playwright report artifact in GitHub Actions
- Run locally: `yarn test:e2e`
- See `e2e/CLAUDE.md` for detailed debugging tips

### Dependabot
Automated dependency updates are configured via `.github/dependabot.yml`:
- **npm packages**: Weekly updates, grouped by minor/patch versions
- **GitHub Actions**: Weekly updates for action versions

## Security Guidelines

### Automated Security Scanning
- **CodeQL**: Runs weekly and on PRs to detect security vulnerabilities
- **npm audit**: Checks for known vulnerabilities in dependencies

### Security Best Practices
- **Never commit secrets**: Use environment variables for API keys, passwords, etc.
- **Review dependencies**: Check new dependencies for known vulnerabilities
- **Input validation**: Always validate and sanitize user input
- **SQL injection**: Use parameterized queries (Knex.js handles this)
- **XSS prevention**: Sanitize HTML output, use proper escaping

### Reporting Security Issues
Report security vulnerabilities via responsible disclosure to security@ghost.org

## Code Style

### Prettier Configuration
The project uses Prettier for consistent code formatting (`.prettierrc`):
- Single quotes
- 4-space indentation
- 120 character line width
- No trailing commas
- No bracket spacing

### ESLint
ESLint is configured across all packages with shared rules:
- Ghost-specific plugin (`eslint-plugin-ghost`)
- React plugin for frontend apps
- Run `yarn lint` to check all packages

### Style Guidelines
- **JavaScript/TypeScript**: Follow ESLint rules, use TypeScript for new code
- **React components**: Use functional components with hooks
- **CSS**: Use Tailwind CSS in new React apps (`shade` design system)
- **Imports**: Use absolute imports where configured, group imports logically

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

### CI-Specific Issues
- **Cache issues:** CI caches may become stale; re-run the job or wait for cache expiry
- **Flaky tests:** Add `browser-tests` label to PR to run full browser test suite
- **Dependency mismatches:** Ensure `yarn.lock` is committed and up-to-date
