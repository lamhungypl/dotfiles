---
name: playwright-e2e
description: Use when creating or modifying Playwright E2E tests. Documents the Page Object Model with AppPage interface, fixture chain pattern, API mocking via route classes, and test naming conventions.
---

# Playwright E2E Testing Pattern

## Overview

Tests use a layered fixture chain for authentication and feature setup, Page Object Models (POMs) implementing the `AppPage` interface, and per-page API mocking via route classes. Mock data is co-located with each feature module under `__mocks__/`.

## Directory Structure

**Spec files and POMs/fixtures live in separate trees.** This is the canonical layout:

```
src/
  app.page.ts              ← AppPage interface
  baseTest.ts              ← merges all fixtures, re-exports test/expect
  e2e/                     ← ALL spec files go here (testDir in playwright.config.ts)
    <feature>/
      <feature>.spec.ts    ← test cases — imports from ../../baseTest
      <sub-feature>.spec.ts
  modules/                 ← POMs, fixtures, routes, mocks — NO spec files
    <feature>/
      <feature>.page.ts       ← POM implementing AppPage
      <feature>.routes.ts     ← API mock routes using page.route()
      <feature>.fixtures.ts   ← Playwright fixtures extending base or permissions
      <feature>.types.ts      ← TypeScript types (optional)
      <feature>.utils.ts      ← Response generators (optional)
      <feature>.constants.ts  ← Constants (optional)
      __mocks__/              ← Static mock response data
  fixtures/                ← Static test assets (images, CSV files, etc.)
  setups/
    auth.setup.ts           ← Generates .auth/user.json storageState
```

**Key rule**: spec files are never inside `modules/`. The `testDir` in `playwright.config.ts` points to `./src/e2e`.

### Import path from a spec file

Spec files live two levels deep under `e2e/`, so they import `baseTest` like this:

```typescript
// src/e2e/tasks/task-create.spec.ts
import { test, expect } from '../../baseTest';
import { TaskListPage } from '../../modules/tasks/task-list.page';
```

### playwright.config.ts — testDir

```typescript
export default defineConfig({
  testDir: './src/e2e',          // ← spec files only
  projects: [
    {
      name: 'setup',
      testDir: './src/setups',   // ← auth setup lives here, not in e2e/
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
    },
  ],
});
```

## AppPage Interface

Every POM implements this contract:

```typescript
export interface AppPage {
  getStarted: () => Promise<void>;
  verifyPageAccessible: () => Promise<void>;
  goto: () => Promise<void>;
}
```

## Page Object Model

```typescript
export class LoginPage implements AppPage {
  page: Page;
  emailInput: Locator;
  passwordInput: Locator;
  signInBtn: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel('Email').first();
    this.passwordInput = page.getByLabel('Password').first();
    this.signInBtn = page.getByRole('button', { name: 'Sign in' }).first();
  }

  async getStarted() {
    await this.goto();
    await this.verifyPageAccessible();
  }

  async goto() { await this.page.goto('/login'); }

  async verifyPageAccessible() {
    await expect(this.emailInput).toBeVisible();
  }
}
```

- Use `getByRole`, `getByLabel`, `getByText` for locators — never CSS class selectors.
- `verifyPageAccessible` is the only assertion allowed inside a POM.

## baseTest.ts

Merges all feature fixtures into one `test` export:

```typescript
import { expect as baseExpect, mergeTests } from '@playwright/test';
import { authFixtures } from './modules/auth/auth.fixtures';
import { tasksFixture } from './modules/tasks/tasks.fixtures';

export const test = mergeTests(authFixtures, tasksFixture, ...);
export const expect = baseExpect;
```

All spec files import `test` and `expect` from `baseTest.ts`, not from `@playwright/test`.

## Fixture Chain

```
base (@playwright/test)
  └─ permissionsFixtures (browser context with storageState, global route mocks)
       └─ feature fixtures (feature-specific mocks + POMs)
```

### Permissions Fixture (base auth layer)

```typescript
export const permissionsFixtures = base.extend<{ authenticatedPage: AuthenticatedPage }>({
  authenticatedPage: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: '.auth/user.json',
    });
    const page = await context.newPage();
    const routes = new PermissionsRoutes(page);
    await routes.mockUserData();
    await use(new AuthenticatedPage(page));
    await context.close();
  },
});
```

### Feature Fixture (extends permissions)

```typescript
export const tasksFixture = permissionsFixtures.extend<TasksFixture>({
  taskListPage: async ({ authenticatedPage }, use) => {
    const routes = new TasksRoutes(authenticatedPage.page);
    await routes.mockTasksList();
    await use(new TaskListPage(authenticatedPage.page));
  },
});
```

## API Mocking

### Route Class

Each feature defines a routes class that uses `page.route()` for per-page-instance mocking:

```typescript
export class AuthRoutes {
  constructor(private readonly page: Page) {}

  async mockLoginResponse(option?: LoginResponseOption) {
    await this.page.route(getPath('login'), async (route) => {
      if (route.request().method() === 'POST') {
        const responseJson = generateAuthResponse(option);
        await route.fulfill({ status: 200, json: responseJson });
      }
    });
  }
}
```

### Route Path Utils

Centralized path map keeps URL patterns in one place:

```typescript
export const pathMap = {
  login: () => '**/auth/login',
  me: () => '**/users/me',
  tasks: () => new RegExp('tasks(\\?.*)?$'),
} as const;

export const getPath = <TRoute extends keyof PathMap>(
  route: TRoute,
  ...params: Parameters<PathMap[TRoute]>
) => {
  const pathCb = pathMap[route];
  return pathCb(...params);
};
```

## Test Naming Convention

Test IDs use a `[C######]` prefix for traceability:

```typescript
test('[C00001] - Verify login page renders', async ({ loginPage }) => {
  await loginPage.getStarted();
  await expect(loginPage.emailInput).toBeVisible();
});
```

## Config Highlights

- **Setup project**: generates auth `storageState` before test runs.
- **Chromium project** depends on `setup`.
- **dotenv**: loads `APP_URL`/`BASE_URL` from `.env`.
- **Timeouts**: 60s for action/navigation/expect, 5 min per test.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Using `beforeEach` for env setup | Use fixtures — they compose and isolate correctly |
| CSS class selectors | Use `getByRole`/`getByText`/`getByLabel` |
| `page.waitForTimeout()` | Use auto-waiting assertions (`await expect(...).toBeVisible()`) |
| Assertions inside POMs | Keep in spec files; only `verifyPageAccessible` is allowed in POMs |
| Shared mock state between tests | Use per-page-instance `page.route()` inside route classes |
| Missing `await` on assertions | Always `await expect(...)` |
| Mocking in global scope | Mock inside fixture or routes class |
| Importing `test` from `@playwright/test` | Import from `baseTest.ts` to get merged fixtures |
| Putting spec files in `modules/<feature>/` | Spec files belong in `e2e/<feature>/` — modules only holds POMs/fixtures/routes |
| Wrong import path in spec files | Specs are at `src/e2e/<feature>/`, so `baseTest` is always `../../baseTest` |

