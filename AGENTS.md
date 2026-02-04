# AGENTS.md - AI Agent Guidelines for Ghost

This document provides guidelines for AI agents working with the Ghost codebase.

## Quick Navigation

### Primary Entry Points
- **Backend API**: `ghost/core/core/server/` - Express.js server
- **Admin Panel**: `ghost/admin/` - Ember.js admin interface (legacy, being migrated)
- **React Apps**: `apps/` - Modern React applications (admin-x-*, comments-ui, portal, etc.)
- **Shared Libraries**: `ghost/` - Core packages and utilities

### Key Configuration Files
- `package.json` - Root workspace configuration
- `nx.json` - Nx build system configuration
- `yarn.lock` - Dependency lock file
- `.github/workflows/ci.yml` - Main CI pipeline

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

## Testing Requirements

### Before Submitting Changes
1. **Run linting**: `yarn lint` or `yarn nx affected -t lint`
2. **Run type checking**: `yarn nx affected -t typecheck`
3. **Run relevant tests**: `yarn nx affected -t test`
4. **For Ghost core changes**: Run integration tests in `ghost/core/test/`

### Test Categories
| Category | Command | When to Run |
|----------|---------|-------------|
| Unit Tests | `yarn test:unit` | All code changes |
| Integration Tests | `cd ghost/core && yarn test:integration` | API/database changes |
| E2E Browser | `yarn test:browser` | UI/frontend changes |
| E2E API | `cd ghost/core && yarn test:e2e` | API endpoint changes |

### Test File Locations
- Unit tests: Adjacent to source files or in `test/unit/`
- Integration tests: `ghost/core/test/integration/`
- E2E tests: `ghost/core/test/e2e-*` and `e2e/`

### Running a Single Test
```bash
cd ghost/core
yarn test:single test/unit/path/to/test.test.js
```

## Code Review Checklist

### General
- [ ] Code follows existing patterns in the codebase
- [ ] No console.log statements in production code
- [ ] Error handling is appropriate
- [ ] Comments explain "why" not "what"

### Backend (Node.js/Express)
- [ ] API endpoints follow RESTful conventions
- [ ] Database queries are optimized (check for N+1)
- [ ] Proper error responses with appropriate status codes
- [ ] Input validation on all endpoints

### Frontend (React/Ember)
- [ ] Components are properly typed (TypeScript)
- [ ] No inline styles (use CSS modules or existing classes)
- [ ] Accessibility considerations (ARIA labels, keyboard nav)
- [ ] Responsive design checked

### Database/Migrations
- [ ] Migrations are reversible
- [ ] Indexes added for frequently queried columns
- [ ] Foreign key constraints where appropriate

## Common Pitfalls

### 1. Monorepo Dependencies
- Always use `yarn workspace` commands for adding dependencies
- Check which package you're adding deps to
- Shared dependencies go in root `package.json`

### 2. Build Order
- The Nx build system handles dependency ordering
- Use `yarn nx affected` to build/test only changed packages
- Don't bypass Nx for builds

### 3. Environment Variables
- Never commit secrets
- Use `.env.example` as a template
- Ghost core uses `config/` directory for configuration

### 4. Testing Database
- Integration tests use a separate test database
- Always clean up test data
- Don't depend on test execution order

## Architecture Patterns

### Ghost Core API Structure
```
ghost/core/core/server/
├── api/          # API endpoints (versioned)
├── data/         # Database layer (Bookshelf ORM)
├── models/       # Data models
├── services/     # Business logic
└── web/          # Express routes and middleware
```

### React App Structure (apps/*)
```
apps/admin-x-*/
├── src/
│   ├── components/  # React components
│   ├── hooks/       # Custom hooks
│   ├── utils/       # Utility functions
│   └── api/         # API client code
└── test/            # Test files
```

## Workflow Commands

### Development
```bash
yarn dev              # Start all dev servers (Docker + host)
yarn dev:legacy       # Start without Docker (deprecated)
yarn dev:analytics    # Include Tinybird analytics
yarn dev:storage      # Include MinIO S3-compatible storage
yarn dev:all          # Include all optional services
```

### Testing
```bash
yarn test             # Run all tests
yarn test:unit        # Unit tests only
yarn lint             # Run linting
yarn nx affected -t lint      # Lint affected packages only
yarn nx affected -t typecheck # Type check affected packages only
```

### Building
```bash
yarn build            # Build all packages
yarn build:clean      # Clean and rebuild
yarn nx affected -t build     # Build affected only
```

### Docker
```bash
yarn docker:build     # Build Docker images
yarn docker:dev       # Start Ghost in Docker
yarn docker:shell     # Open shell in Ghost container
yarn docker:mysql     # Open MySQL CLI
yarn docker:reset     # Reset all Docker volumes and restart
```

## Dependencies Between Packages

Key dependency relationships to be aware of:
- `ghost/core` depends on most other ghost/* packages
- `apps/admin-x-*` apps are standalone React apps
- `ghost/admin` (Ember) is being gradually replaced by admin-x apps
- Shared types in `ghost/ghost/` packages

Critical build order (Nx handles automatically):
1. `shade` + `admin-x-design-system` build
2. `admin-x-framework` builds (depends on #1)
3. Admin apps build (depend on #2)
4. `ghost/admin` builds (depends on #3, copies via asset-delivery)
5. `ghost/core` serves admin build

## Security Considerations

1. **Input Validation**: All user input must be validated
2. **SQL Injection**: Use Bookshelf ORM, never raw queries
3. **XSS Prevention**: Sanitize all rendered content
4. **CSRF Protection**: Built into Ghost's API
5. **Rate Limiting**: Configured per endpoint

## CI/CD Pipelines

### Main CI Workflow (`.github/workflows/ci.yml`)
- Runs on all PRs and pushes to main
- Jobs: lint, unit tests, integration tests, E2E tests, browser tests
- Uses Nx affected commands for efficiency

### Security Scanning (`.github/workflows/security.yml`)
- CodeQL analysis for JavaScript/TypeScript
- npm audit for dependency vulnerabilities
- Runs weekly and on PRs to main

### TypeScript Check (`.github/workflows/typecheck.yml`)
- Explicit type checking for all TypeScript packages
- Uses `yarn nx affected -t typecheck`

### Dependency Management
- **Renovate** (`.github/renovate.json5`): Automated dependency updates with custom rules
- **Dependabot** (`.github/dependabot.yml`): Additional automated updates for npm and GitHub Actions

### Pre-commit Hooks
- Configured via Husky (`.husky/`)
- Runs lint-staged on main branch
- Validates commit message format
- Auto-removes submodules from commits

### Code Formatting
- **Prettier** (`.prettierrc`): Code formatting configuration
- **ESLint**: Linting configuration per package (extends `eslint-plugin-ghost`)

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

## Troubleshooting

### Build Issues
```bash
yarn fix              # Clean cache + node_modules + reinstall
yarn build:clean      # Clean build artifacts
yarn nx reset         # Reset Nx cache
```

### Test Issues
- **E2E failures:** Check `e2e/CLAUDE.md` for debugging tips
- **Docker issues:** `yarn docker:clean && yarn docker:build`

## Getting Help

- Check existing code for patterns
- Review tests for expected behavior
- Ghost documentation: https://ghost.org/docs/
- API documentation: https://docs.ghost.org/
- See `CLAUDE.md` for additional guidance
