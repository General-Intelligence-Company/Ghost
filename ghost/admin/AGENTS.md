# AGENTS.md - Ghost Admin

Ember.js admin application guidance for AI assistants (Claude, Codex, etc.).

> **Important**: New features should be built in React (`apps/admin-x-*`), not Ember. Only modify existing Ember code when necessary for bug fixes or integration with React apps.

## Quick Reference

```bash
# From ghost/admin/
yarn dev              # Start Ember dev server
yarn build            # Production build
yarn build:dev        # Development build
yarn test             # Run tests (parallel with ember-exam)
yarn lint             # Lint JS and templates
yarn lint:js          # ESLint only
yarn lint:hbs         # Template lint only
```

## Project Structure

```
ghost/admin/
├── app/
│   ├── adapters/           # Ember Data API adapters
│   ├── components/         # UI components (Glimmer & classic)
│   │   ├── admin-x/        # React app integration wrappers
│   │   ├── dashboard/      # Dashboard components
│   │   ├── editor/         # Post editor components
│   │   ├── gh-*/           # Ghost-prefixed components
│   │   └── modals/         # Modal dialogs
│   ├── controllers/        # Route controllers
│   ├── decorators/         # Custom decorators (@inject)
│   ├── helpers/            # Template helpers
│   ├── mixins/             # Ember mixins (legacy)
│   ├── models/             # Ember Data models
│   ├── modifiers/          # Element modifiers (Octane)
│   ├── routes/             # Route definitions
│   ├── serializers/        # Ember Data serializers
│   ├── services/           # Singleton services
│   ├── styles/             # PostCSS stylesheets
│   ├── templates/          # Route templates
│   ├── transforms/         # Ember Data transforms
│   └── validators/         # Model validators
├── lib/
│   └── asset-delivery/     # Copies React apps to ghost/core
├── mirage/                 # API mocking
│   ├── config/             # Route handlers
│   ├── factories/          # Model factories
│   └── fixtures/           # Fixture data
├── tests/
│   ├── acceptance/         # Full app tests
│   ├── integration/        # Component tests
│   └── unit/               # Unit tests
└── config/                 # Environment config
```

## Ember.js Conventions

### Framework Version

- **Ember.js**: 3.24.0 (Octane edition)
- **Ember Data**: 3.24.0
- **ember-cli**: 3.24.0

### Component Patterns

**Glimmer Components (preferred for new code):**

```javascript
// app/components/my-component.js
import Component from '@glimmer/component';
import {action} from '@ember/object';
import {inject as service} from '@ember/service';
import {tracked} from '@glimmer/tracking';

export default class MyComponent extends Component {
    @service notifications;
    @tracked isLoading = false;

    // Args accessed via this.args.propName
    get displayName() {
        return this.args.name || 'Default';
    }

    @action
    async handleClick() {
        this.isLoading = true;
        try {
            await this.args.onSave?.();
        } finally {
            this.isLoading = false;
        }
    }
}
```

```handlebars
{{!-- app/components/my-component.hbs --}}
<div class="my-component">
    <h2>{{this.displayName}}</h2>
    <button
        type="button"
        disabled={{this.isLoading}}
        {{on "click" this.handleClick}}
    >
        {{if this.isLoading "Saving..." "Save"}}
    </button>
</div>
```

**Component Naming:**
- Ghost components use `gh-` prefix: `gh-alert`, `gh-dropdown`, `gh-textarea`
- Feature components use nested directories: `dashboard/`, `editor/`, `modals/`

### Service Pattern

```javascript
// app/services/my-service.js
import Service, {inject as service} from '@ember/service';
import {tracked} from '@glimmer/tracking';

export default class MyService extends Service {
    @service ajax;
    @service session;
    @tracked currentItem = null;

    async fetchItem(id) {
        const response = await this.ajax.request(`/items/${id}`);
        this.currentItem = response;
        return response;
    }
}
```

### Key Services

| Service | Purpose |
|---------|---------|
| `session` | Authentication state (ember-simple-auth) |
| `settings` | Ghost site settings |
| `feature` | Feature flags and labs |
| `notifications` | Toast/alert notifications |
| `ajax` | HTTP requests with error handling |
| `modals` | Modal dialog management |
| `state-bridge` | **Critical**: Ember ↔ React state sync |
| `ui` | UI state (navigation, fullscreen) |
| `koenig` | Lexical editor integration |

### Route Pattern

```javascript
// app/routes/posts.js
import AuthenticatedRoute from 'ghost-admin/routes/authenticated';

export default class PostsRoute extends AuthenticatedRoute {
    queryParams = {
        type: {refreshModel: true},
        order: {refreshModel: true}
    };

    model(params) {
        return this.store.query('post', {
            filter: `type:${params.type}`,
            order: params.order
        });
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        controller.set('posts', model);
    }
}
```

### Controller Pattern (with ember-concurrency)

```javascript
// app/controllers/posts.js
import Controller from '@ember/controller';
import {action} from '@ember/object';
import {inject as service} from '@ember/service';
import {task} from 'ember-concurrency';
import {tracked} from '@glimmer/tracking';

export default class PostsController extends Controller {
    @service notifications;
    @service store;
    @tracked selectedPost = null;

    queryParams = ['type', 'order'];
    @tracked type = 'post';
    @tracked order = 'published_at desc';

    @task
    *deletePostTask(post) {
        try {
            yield post.destroyRecord();
            this.notifications.showNotification('Post deleted');
        } catch (error) {
            this.notifications.showAPIError(error);
        }
    }

    @action
    selectPost(post) {
        this.selectedPost = post;
    }
}
```

## React Integration (Admin-X)

Ghost Admin embeds React apps as micro-frontends. Understanding this integration is critical.

### Architecture Overview

1. **React apps** are built in `apps/admin-x-*`
2. **Asset delivery** copies builds to `ghost/core/core/built/admin/assets/`
3. **Ember wrappers** dynamically import and render React components
4. **State bridge** keeps Ember Data and React Query in sync

### Admin-X Component Wrapper

```javascript
// app/components/admin-x/settings.js
import AdminXComponent from './admin-x-component';

export default class Settings extends AdminXComponent {
    static packageName = '@tryghost/admin-x-settings';
}
```

### Base Admin-X Component

The base component (`app/components/admin-x/admin-x-component.js`) handles:
- Dynamic import of React app bundles
- Error boundaries and loading states
- Passing framework config to React
- State bridge integration

### State Bridge Service

The `state-bridge` service (`app/services/state-bridge.js`) synchronizes:
- Ember Data model changes → React Query cache invalidation
- React mutations → Ember Data store updates

```javascript
// When React updates data, Ember Data is notified
stateBridge.onUpdate('setting', (responseType, response) => {
    this.store.pushPayload(responseType, response);
});

// When Ember Data changes, React Query is invalidated
stateBridge.onInvalidate('post', () => {
    queryClient.invalidateQueries(['posts']);
});
```

### Adding a New React App Integration

1. Create wrapper component in `app/components/admin-x/`
2. Register in `app/components/admin-x/index.js`
3. Add route/template to display the component
4. Configure state bridge for shared data types

## Data Layer (Ember Data)

### Model Definition

```javascript
// app/models/post.js
import Model, {attr, belongsTo, hasMany} from '@ember-data/model';
import ValidationEngine from 'ghost-admin/mixins/validation-engine';

export default class Post extends Model.extend(ValidationEngine) {
    validationType = 'post';

    @attr('string') title;
    @attr('string') status;
    @attr('moment-utc') publishedAt;
    @attr('json-string') lexical;

    @hasMany('tag', {embedded: 'always', async: false}) tags;
    @belongsTo('user') author;

    get isPublished() {
        return this.status === 'published';
    }
}
```

### Adapter Pattern

Adapters in `app/adapters/` customize API communication:

```javascript
// app/adapters/post.js
import ApplicationAdapter from './application';

export default class PostAdapter extends ApplicationAdapter {
    buildIncludeURL(store, modelName, id, snapshot, requestType, query) {
        // Customize included relations
        return super.buildIncludeURL(...arguments);
    }
}
```

### Custom Transforms

Located in `app/transforms/`:
- `moment-utc` - Date handling with moment.js
- `json-string` - JSON serialization
- `navigation-settings` - Navigation items

## Validation

### ValidationEngine Mixin

Models using `ValidationEngine` mixin get automatic validation:

```javascript
// app/validators/post.js
import BaseValidator from './base';

export default BaseValidator.create({
    properties: ['title', 'status'],

    title(model) {
        if (!model.title?.trim()) {
            model.errors.add('title', 'Title is required');
            this.invalidate();
        }
    }
});
```

### Using Validation

```javascript
// In controller or component
const post = this.store.createRecord('post', {title: ''});
const isValid = await post.validate();
if (!isValid) {
    // post.errors contains validation errors
}
```

## Testing

### Test Framework

- **Mocha/Chai** (not QUnit)
- **ember-exam** for parallel execution
- **ember-cli-mirage** for API mocking

### Acceptance Test Pattern

```javascript
// tests/acceptance/posts-test.js
import {describe, it, beforeEach} from 'mocha';
import {expect} from 'chai';
import {setupApplicationTest} from 'ember-mocha';
import {setupMirage} from 'ember-cli-mirage/test-support';
import {authenticateSession} from 'ember-simple-auth/test-support';
import {visit, click, fillIn} from '@ember/test-helpers';

describe('Acceptance: Posts', function () {
    let hooks = setupApplicationTest();
    setupMirage(hooks);

    beforeEach(async function () {
        this.server.loadFixtures('configs');
        this.server.loadFixtures('settings');

        const role = this.server.create('role', {name: 'Owner'});
        this.server.create('user', {roles: [role]});

        await authenticateSession();
    });

    it('can view posts list', async function () {
        this.server.createList('post', 5);

        await visit('/posts');

        expect(document.querySelectorAll('[data-test-post]')).to.have.length(5);
    });

    it('can create a new post', async function () {
        await visit('/editor/post');
        await fillIn('[data-test-editor-title]', 'New Post');
        await click('[data-test-button="publish"]');

        expect(this.server.db.posts).to.have.length(1);
    });
});
```

### Component Integration Test

```javascript
// tests/integration/components/gh-alert-test.js
import {describe, it} from 'mocha';
import {expect} from 'chai';
import {setupRenderingTest} from 'ember-mocha';
import {render, click} from '@ember/test-helpers';
import hbs from 'htmlbars-inline-precompile';

describe('Integration: GhAlert', function () {
    setupRenderingTest();

    it('renders alert message', async function () {
        this.set('message', 'Test alert');

        await render(hbs`<GhAlert @message={{this.message}} />`);

        expect(this.element.textContent).to.include('Test alert');
    });

    it('calls onClose when dismissed', async function () {
        let closeCalled = false;
        this.set('onClose', () => closeCalled = true);

        await render(hbs`<GhAlert @onClose={{this.onClose}} />`);
        await click('[data-test-button="close"]');

        expect(closeCalled).to.be.true;
    });
});
```

### Mirage Configuration

**Route handlers** (`mirage/config/posts.js`):
```javascript
export default function mockPosts(server) {
    server.get('/posts/', function ({posts}, {queryParams}) {
        let collection = posts.all();
        if (queryParams.filter) {
            // Apply filtering
        }
        return collection;
    });

    server.post('/posts/', function ({posts}, {requestBody}) {
        const data = JSON.parse(requestBody);
        return posts.create(data.posts[0]);
    });
}
```

**Factories** (`mirage/factories/post.js`):
```javascript
import {Factory} from 'miragejs';

export default Factory.extend({
    title: (i) => `Post ${i}`,
    status: 'draft',
    createdAt: () => new Date().toISOString()
});
```

### Running Tests

```bash
yarn test                    # All tests (parallel)
yarn test --server           # With live reload
yarn test --filter "Posts"   # Filter by name
yarn lint                    # Lint all files
```

## Styles

### Organization

```
app/styles/
├── app.css              # Main entry (imports all)
├── app-dark.css         # Dark mode overrides
├── components/          # Component styles
├── layouts/             # Layout styles
├── patterns/            # Reusable patterns
└── spirit/              # Design tokens
```

### Conventions

- PostCSS with nesting support
- BEM-like naming for classes
- Ghost uses `gh-` prefix for component classes
- Dark mode via `app-dark.css` overrides

## Custom Decorators

### @inject Decorator

Used for injecting non-service singletons (e.g., config):

```javascript
import {inject} from 'ghost-admin/decorators/inject';

export default class MyComponent extends Component {
    @inject config;  // Not a service, uses custom decorator

    get baseUrl() {
        return this.config.blogUrl;
    }
}
```

## Element Modifiers

### react-render Modifier

Mounts React components to DOM elements:

```handlebars
<div {{react-render this.ReactComponent props=this.reactProps}}></div>
```

### Other Modifiers

Located in `app/modifiers/`:
- `autofocus` - Focus element on insert
- `on-resize` - Respond to element resize
- `scroll-to` - Scroll element into view

## Build Configuration

### ember-cli-build.js Highlights

- PostCSS for CSS processing
- SVG Jar for icon management
- Fingerprinting for cache busting
- Webpack for auto-import
- React JSX transform via Babel

### Asset Delivery

The `lib/asset-delivery` addon copies React app builds:
- Watches for changes in development
- Generates content hashes for production
- Copies to `ghost/core/core/built/admin/assets/`

## Common Patterns

### Handling Unsaved Changes

```javascript
// In route
actions: {
    willTransition(transition) {
        if (this.controller.model.hasDirtyAttributes) {
            transition.abort();
            this.controller.showUnsavedChangesModal(transition);
        }
    }
}
```

### Async Operations with ember-concurrency

```javascript
import {task, timeout} from 'ember-concurrency';

@task({restartable: true})
*searchTask(query) {
    yield timeout(300);  // Debounce
    return yield this.ajax.request('/search', {data: {q: query}});
}
```

### Modal Management

```javascript
// Using modals service
async confirmDelete() {
    const confirmed = await this.modals.open('modals/confirm-delete', {
        item: this.post
    });
    if (confirmed) {
        await this.post.destroyRecord();
    }
}
```

## Best Practices

### DO

- Use `@tracked` and Glimmer components for new code
- Use `ember-concurrency` tasks for async operations
- Update state-bridge when adding shared data types
- Write acceptance tests for new features
- Use Mirage for API mocking in tests
- Follow existing naming conventions

### DON'T

- Build new features in Ember (use React in `apps/admin-x-*`)
- Use classic components for new code
- Use observers (use `@tracked` instead)
- Skip authentication in tests
- Put selectors in test files (use `data-test-*` attributes)

## Migration Path to React

When working on Admin features:

1. **New features**: Build in `apps/admin-x-*` using React
2. **Existing features**: Keep in Ember unless doing major refactor
3. **Shared state**: Use state-bridge service
4. **Gradual migration**: Replace Ember routes with React apps over time

## Useful Links

- [Ember.js Guides](https://guides.emberjs.com/v3.24.0/)
- [Ember Data Guides](https://guides.emberjs.com/v3.24.0/models/)
- [ember-concurrency Docs](http://ember-concurrency.com/)
- [Glimmer Components](https://guides.emberjs.com/v3.24.0/upgrading/current-edition/glimmer-components/)
