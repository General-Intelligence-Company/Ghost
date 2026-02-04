# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Reference

**Package Manager:** Always use `yarn` (v1), never npm.

**Project Type:** Yarn v1 + Nx monorepo with three workspace groups:
- `ghost/*` - Core Ghost packages (Node.js/Express backend, Ember admin)
- `apps/*` - React-based UI applications (Vite + React)
- `e2e/` - Playwright E2E tests

## Essential Commands

```bash
yarn setup                     # First-time setup
yarn dev                       # Start development (Docker + frontend dev servers)
yarn build                     # Build all packages
yarn lint                      # Lint all packages
yarn test:unit                 # Run unit tests
yarn test:e2e                  # Run E2E tests
```

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `ghost/core/core/server/` | Backend API, services, models |
| `ghost/core/core/frontend/` | Theme rendering, helpers |
| `ghost/admin/` | Ember.js admin (legacy) |
| `apps/admin-x-settings/` | React settings app |
| `apps/shade/` | New design system (shadcn/ui) |
| `e2e/tests/` | Playwright E2E tests |

## Before Committing

Always run these checks:
```bash
yarn lint                      # Fix any linting errors
yarn test:unit                 # Ensure tests pass
```

## Detailed Documentation

For comprehensive guidance including:
- Monorepo structure and architecture
- Testing patterns (Mocha, Vitest, Playwright)
- Database migrations
- CI/CD pipeline details
- Environment configuration
- Troubleshooting

**See [AGENTS.md](./AGENTS.md)** for the complete developer guide.

## E2E Testing

For E2E test-specific guidance, see [e2e/CLAUDE.md](./e2e/CLAUDE.md).
