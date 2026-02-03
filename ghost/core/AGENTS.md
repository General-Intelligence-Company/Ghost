# AGENTS.md - Ghost Core

Backend development guidance for AI assistants (Claude, Codex, etc.) working with Ghost's Node.js core.

## Quick Reference

```bash
# From ghost/core/
yarn dev                    # Start with hot reload (use yarn dev from root instead)
yarn test:unit              # Run unit tests with coverage
yarn test:integration       # Run integration tests
yarn test:e2e               # Run E2E API tests
yarn test:single <file>     # Run a single test file
yarn lint                   # Lint all code (server, shared, frontend, tests)
yarn knex-migrator migrate  # Run database migrations
```

## Project Structure

```
ghost/core/
├── core/
│   ├── server/             # Backend API, services, models
│   │   ├── api/            # API framework and endpoints
│   │   ├── data/           # Database schema, migrations, settings
│   │   ├── models/         # Bookshelf ORM models
│   │   ├── services/       # Business logic services
│   │   └── web/            # Express routes and middleware
│   ├── frontend/           # Theme rendering, helpers, SSR
│   │   ├── helpers/        # Handlebars template helpers
│   │   ├── services/       # Frontend services (routing, sitemap, RSS)
│   │   └── web/            # Frontend Express middleware
│   └── shared/             # Utilities shared between server/frontend
│       ├── config/         # Configuration management
│       ├── events/         # Domain events
│       └── settings-cache/ # Settings caching
├── test/                   # Test suites
│   ├── unit/               # Unit tests (Mocha)
│   ├── integration/        # Integration tests
│   ├── e2e-api/            # API E2E tests
│   ├── e2e-browser/        # Playwright browser tests
│   └── utils/              # Test utilities and framework
└── content/                # Runtime content (themes, images, data)
```

## API Architecture

### Three API Types

| API | Path | Auth | Purpose |
|-----|------|------|---------|
| **Admin API** | `/ghost/api/admin/` | Session/Staff token | Full CRUD for admin operations |
| **Content API** | `/ghost/api/content/` | Content API key | Read-only public data for themes |
| **Members API** | `/ghost/api/members/` | Member session | Member-specific operations |

### API Endpoint Pattern

Endpoints are defined in `core/server/api/endpoints/`. Each endpoint follows this structure:

```javascript
// core/server/api/endpoints/posts.js
const controller = {
    docName: 'posts',

    browse: {
        headers: {
            cacheInvalidate: false
        },
        options: ['include', 'filter', 'fields', 'limit', 'order', 'page'],
        validation: {
            options: {
                include: {
                    values: allowedIncludes
                }
            }
        },
        permissions: {
            unsafeAttrs: unsafeAttrs
        },
        query(frame) {
            return postsService.browsePosts(frame.options);
        }
    },

    add: {
        statusCode: 201,
        headers: {
            cacheInvalidate: true
        },
        options: ['include'],
        validation: {
            data: {
                posts: {
                    type: 'array',
                    maxlength: 1
                }
            }
        },
        permissions: {
            unsafeAttrs: unsafeAttrs
        },
        query(frame) {
            return postsService.createPost(frame.data.posts[0], frame.options);
        }
    }
};

module.exports = controller;
```

### API Request Pipeline

1. **Routing** (`core/server/web/api/`) - Express routes map URLs to endpoints
2. **Middleware** - Authentication, permissions, rate limiting
3. **Frame** - Request data is normalized into a "frame" object
4. **Validation** - Input validation based on endpoint config
5. **Permissions** - Role-based access control
6. **Query** - Business logic execution via services
7. **Serialization** - Response formatting

### Adding a New API Endpoint

1. Create endpoint in `core/server/api/endpoints/`
2. Register in `core/server/api/endpoints/index.js`
3. Add route in `core/server/web/api/endpoints/admin/` or `content/`
4. Add permissions in `core/server/services/permissions/`
5. Write tests in `test/e2e-api/admin/` or `content/`

## Service Layer

Services contain business logic and are located in `core/server/services/`. Key services:

| Service | Purpose |
|---------|---------|
| `posts/` | Post CRUD, revisions, publishing |
| `members/` | Member management, authentication |
| `email-service/` | Email sending, analytics |
| `stripe/` | Payment integration |
| `themes/` | Theme management and validation |
| `newsletters/` | Newsletter operations |
| `settings/` | Site settings management |
| `permissions/` | Role-based access control |

### Service Pattern

```javascript
// core/server/services/posts/posts-service.js
class PostsService {
    constructor({urlUtils, models, isSet, stats, emailService}) {
        this.urlUtils = urlUtils;
        this.models = models;
        // Dependency injection pattern
    }

    async createPost(data, options = {}) {
        // Business logic here
        const post = await this.models.Post.add(data, options);

        // Emit domain events
        DomainEvents.dispatch(PostCreatedEvent.create({post}));

        return post;
    }
}

// Singleton instance with dependencies
const getPostServiceInstance = () => {
    return new PostsService({
        urlUtils: require('../../../shared/url-utils'),
        models: require('../../models'),
        isSet: flag => labs.isSet(flag),
        stats: postStats,
        emailService: emailService.service
    });
};
```

## Models (Bookshelf ORM)

Models are in `core/server/models/` and extend Bookshelf.js.

### Model Pattern

```javascript
// core/server/models/post.js
const Post = ghostBookshelf.Model.extend({
    tableName: 'posts',

    // Action tracking for audit log
    actionsCollectCRUD: true,
    actionsResourceType: 'post',

    // Default values for new records
    defaults: function defaults() {
        return {
            uuid: crypto.randomUUID(),
            status: 'draft',
            featured: false,
            type: 'post'
        };
    },

    // Relationship definitions
    relationships: ['tags', 'authors', 'post_revisions'],
    relationshipConfig: {
        tags: {editable: true},
        authors: {editable: true}
    },

    // Eager-loaded relations
    tags() {
        return this.belongsToMany('Tag');
    },

    authors() {
        return this.belongsToMany('User', 'posts_authors', 'post_id', 'author_id');
    }
}, {
    // Static methods
    orderDefaultOptions: function () {
        return {
            status: 'ASC',
            published_at: 'DESC'
        };
    },

    // Allowed filter fields
    filterRelations: ['tags', 'authors'],
    filterExpansions: [
        {key: 'primary_tag', replacement: 'tags.slug'}
    ]
});
```

### Key Model Conventions

- **IDs**: 24-character hex strings (ObjectId format)
- **Timestamps**: `created_at`, `updated_at` as dateTime
- **Soft Deletes**: Not used - records are hard deleted
- **Slugs**: Unique per resource type
- **Status**: Usually `draft`/`published`/`scheduled` or `active`/`archived`

### Transactions

```javascript
await ghostBookshelf.transaction(async (transacting) => {
    await models.Post.add(data, {transacting});
    await models.Tag.add(tagData, {transacting});
    // Both succeed or both fail
});
```

## Database Migrations

Migrations are in `core/server/data/migrations/versions/`.

### Creating Migrations

Use the provided utilities from `core/server/data/migrations/utils/`:

```javascript
// Adding a column
const {createAddColumnMigration} = require('../../utils');

module.exports = createAddColumnMigration('users', 'new_column', {
    type: 'string',
    maxlength: 191,
    nullable: true
});
```

```javascript
// Adding a setting
const {addSetting} = require('../../utils');

module.exports = addSetting({
    key: 'my_setting',
    value: 'default_value',
    type: 'string',
    group: 'site'
});
```

```javascript
// Complex migration
const {createTransactionalMigration} = require('../../utils');

module.exports = createTransactionalMigration(
    async function up(knex) {
        await knex('posts').where('status', 'old').update({status: 'new'});
    },
    async function down(knex) {
        await knex('posts').where('status', 'new').update({status: 'old'});
    }
);
```

### Migration Types

| Type | Use Case |
|------|----------|
| `createTransactionalMigration` | Data changes (runs in transaction) |
| `createNonTransactionalMigration` | Schema changes (no transaction) |
| `createIrreversibleMigration` | One-way migrations (no down) |
| `combineNonTransactionalMigrations` | Multiple schema changes |
| `createAddColumnMigration` | Add single column helper |
| `createDropColumnMigration` | Remove column helper |
| `createAddIndexMigration` | Add index helper |

### Migration Naming

```
YYYY-MM-DD-HH-mm-ss-description.js
# Example: 2024-01-15-12-30-00-add-threads-column-to-users.js
```

### Running Migrations

```bash
yarn knex-migrator migrate           # Run pending migrations
yarn knex-migrator migrate --force   # Force run (use carefully)
yarn knex-migrator reset             # Reset and re-run all migrations
```

## Database Schema

Schema definitions are in `core/server/data/schema/schema.js`.

### Column Type Guidelines

| Type | Max Length | Use Case |
|------|------------|----------|
| Small string | 50 | Enums, short codes |
| Medium string | 191 | Slugs, usernames, emails |
| Large string | 2000 | Titles, excerpts |
| Text | 65535 | Content blocks |
| Long text | 1000000000 | Full post content, HTML |

### Schema Definition

```javascript
posts: {
    id: {type: 'string', maxlength: 24, nullable: false, primary: true},
    uuid: {type: 'string', maxlength: 36, nullable: false, validations: {isUUID: true}},
    title: {type: 'string', maxlength: 2000, nullable: false},
    status: {
        type: 'string',
        maxlength: 50,
        nullable: false,
        defaultTo: 'draft',
        validations: {isIn: [['published', 'draft', 'scheduled', 'sent']]}
    },
    visibility: {
        type: 'string',
        maxlength: 50,
        nullable: false,
        defaultTo: 'public',
        validations: {isIn: [['public', 'members', 'paid', 'tiers']]}
    },
    '@@INDEXES@@': [
        ['type', 'status', 'updated_at']
    ],
    '@@UNIQUE_CONSTRAINTS@@': [
        ['slug', 'type']
    ]
}
```

## Error Handling

Uses `@tryghost/errors` package for standardized errors:

```javascript
const errors = require('@tryghost/errors');

// Not found
throw new errors.NotFoundError({
    message: 'Post not found',
    context: `Post with id ${id} does not exist`
});

// Validation error
throw new errors.ValidationError({
    message: 'Validation failed',
    context: 'Title is required'
});

// Permission denied
throw new errors.NoPermissionError({
    message: 'Access denied'
});

// Internal error
throw new errors.InternalServerError({
    message: 'Something went wrong',
    err: originalError  // Wrap original error
});

// Incorrect usage (developer error)
throw new errors.IncorrectUsageError({
    message: 'Cannot call X without Y',
    help: 'See documentation at...'
});
```

### Error Types

| Type | HTTP Code | Use Case |
|------|-----------|----------|
| `NotFoundError` | 404 | Resource doesn't exist |
| `ValidationError` | 422 | Invalid input data |
| `UnauthorizedError` | 401 | Not authenticated |
| `NoPermissionError` | 403 | Authenticated but not allowed |
| `BadRequestError` | 400 | Malformed request |
| `InternalServerError` | 500 | Unexpected server error |
| `IncorrectUsageError` | 500 | Developer/code error |

## Configuration

Configuration uses `nconf` and is in `core/shared/config/`.

### Config Sources (priority order)

1. Command line arguments
2. Environment variables
3. `config.{env}.json` files
4. `defaults.json`

### Accessing Config

```javascript
const config = require('../shared/config');

const dbConfig = config.get('database');
const url = config.get('url');
const isProduction = config.get('env') === 'production';
```

### Feature Flags (Labs)

```javascript
const labs = require('../shared/labs');

if (labs.isSet('featureName')) {
    // Feature is enabled
}
```

## Testing

### Test Structure

```
test/
├── unit/                  # Fast, isolated tests
│   ├── server/            # Server unit tests
│   ├── frontend/          # Frontend unit tests
│   └── shared/            # Shared utility tests
├── integration/           # Component integration tests
├── e2e-api/               # API endpoint tests
│   ├── admin/             # Admin API tests
│   ├── content/           # Content API tests
│   └── members/           # Members API tests
├── e2e-browser/           # Playwright browser tests
└── utils/                 # Test framework and helpers
```

### E2E API Test Pattern

```javascript
const {agentProvider, fixtureManager, mockManager, matchers} =
    require('../../utils/e2e-framework');

describe('Posts API', function () {
    let agent;

    before(async function () {
        agent = await agentProvider.getAdminAPIAgent();
        await fixtureManager.init('posts', 'users');
        await agent.loginAsOwner();
    });

    after(async function () {
        await mockManager.restore();
    });

    it('can browse posts', async function () {
        await agent
            .get('/posts/')
            .expectStatus(200)
            .matchHeaderSnapshot({etag: matchers.anyEtag})
            .matchBodySnapshot({
                posts: [{
                    id: matchers.anyObjectId,
                    created_at: matchers.anyISODateTime
                }]
            });
    });

    it('can create a post', async function () {
        const post = {
            title: 'Test Post',
            status: 'draft'
        };

        await agent
            .post('/posts/')
            .body({posts: [post]})
            .expectStatus(201)
            .matchBodySnapshot();
    });
});
```

### Test Agents

| Agent | Purpose |
|-------|---------|
| `getAdminAPIAgent()` | Admin API testing (authenticated) |
| `getContentAPIAgent()` | Content API testing (API key) |
| `getMembersAPIAgent()` | Members API testing |
| `getGhostAPIAgent()` | General Ghost API |

### Unit Test Pattern

```javascript
const sinon = require('sinon');
const should = require('should');
const PostsService = require('../../../../core/server/services/posts');

describe('Posts Service', function () {
    let postsService;
    let modelsStub;

    beforeEach(function () {
        modelsStub = {
            Post: {
                add: sinon.stub().resolves({id: '1', title: 'Test'})
            }
        };
        postsService = new PostsService({models: modelsStub});
    });

    afterEach(function () {
        sinon.restore();
    });

    it('creates a post', async function () {
        const result = await postsService.createPost({title: 'Test'});

        should(result.title).equal('Test');
        modelsStub.Post.add.calledOnce.should.be.true();
    });
});
```

### Running Tests

```bash
# Unit tests with coverage
yarn test:unit

# Integration tests
yarn test:integration

# E2E API tests
yarn test:e2e

# Single test file
yarn test:single test/unit/server/services/posts.test.js

# With debug output
DEBUG=ghost:* yarn test:single test/e2e-api/admin/posts.test.js

# Browser tests
yarn test:browser
```

## Domain Events

Ghost uses domain events for loose coupling between services.

```javascript
const DomainEvents = require('@tryghost/domain-events');
const {MemberCreatedEvent} = require('@tryghost/member-events');

// Dispatching an event
DomainEvents.dispatch(MemberCreatedEvent.create({
    memberId: member.id,
    source: 'import'
}));

// Subscribing to an event
DomainEvents.subscribe(MemberCreatedEvent, async (event) => {
    await sendWelcomeEmail(event.data.memberId);
});
```

### Common Events

| Event | Triggered When |
|-------|----------------|
| `MemberCreatedEvent` | New member signup |
| `MemberSubscribeEvent` | Member subscribes to newsletter |
| `SubscriptionCreatedEvent` | New paid subscription |
| `SubscriptionCancelledEvent` | Subscription cancelled |
| `PostScheduledEvent` | Post scheduled for publishing |

## Common Patterns

### Filtering and Pagination

```javascript
// In API endpoint
const options = {
    filter: 'status:published+tag:news',
    order: 'published_at DESC',
    limit: 15,
    page: 1,
    include: 'tags,authors'
};

const result = await models.Post.findPage(options);
// Returns: {data: [...], meta: {pagination: {...}}}
```

### NQL (Ghost Query Language)

```javascript
// Filter syntax
'status:published'                    // Exact match
'status:-draft'                       // Not equal
'created_at:>2024-01-01'             // Greater than
'tag:news+tag:featured'               // AND
'tag:news,tag:featured'               // OR
'title:~test'                         // Contains
```

## Best Practices

### DO

- Use services for business logic, not models directly
- Use transactions for multi-model operations
- Use domain events for cross-service communication
- Write E2E tests for API endpoints
- Use snapshot testing for API responses
- Follow existing patterns in the codebase

### DON'T

- Put business logic in API endpoints
- Use raw SQL without knex query builder
- Skip migrations for schema changes
- Ignore error handling
- Use `console.log` (use `logging` module)
- Modify config at runtime

## Logging

```javascript
const logging = require('@tryghost/logging');

logging.info('Operation completed');
logging.warn('Deprecation warning');
logging.error('Operation failed', {err: error});

// Debug logging (enable with DEBUG=ghost:*)
const debug = require('@tryghost/debug')('service-name');
debug('Debug message', {data: someData});
```

## Useful Links

- [Ghost API Documentation](https://ghost.org/docs/api/)
- [Content API Reference](https://ghost.org/docs/content-api/)
- [Admin API Reference](https://ghost.org/docs/admin-api/)
- [NQL Syntax](https://ghost.org/docs/content-api/#filtering)
