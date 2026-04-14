# QA Agent Skill

**Trigger:** `/qa-agent [release-name]` or invoked by dispatcher

**Purpose:** For each `pending` item in `backlog.json`, write a failing Playwright test that asserts `targetState` behavior.

A failing test is a correct spec — it proves the test is testing what it should.

---

## Pre-flight

1. Read `workspaces.json` at the workspace root — resolve `e2e` path for test commands
   - If missing: ask the user to copy `agents/workspaces.example.json` → `workspaces.json` and fill in their paths
2. Read `agents/releases/LEARNINGS.md` if it exists — apply accumulated selector patterns and blocker signals before writing any locators or specs
3. Read `agents/agent.md` — understand the project structure before writing any code
4. Find the release folder: `agents/releases/<yyyy>/<mm>/<dd-release-name>/`
   - If `release-name` is given, search `releases/` for a folder matching that name
   - If ambiguous, list candidates and ask the user to confirm
5. Resolve the working backlog:
   - If `backlog.agent.json` **already exists** in the release folder → resume from it (crashed or partial sprint)
   - If it does **not** exist → copy `backlog.json` → `backlog.agent.json` to create the working copy
   - Never modify `backlog.json` — it is the immutable human-signed plan
6. Filter items in `backlog.agent.json` where `status === "pending"`

---

## Per Item Loop

For each `pending` item:

### Step 1 — Understand the delta

Read `item.currentState` (S1) and `item.targetState` (S2).

The test should assert S2 behavior — specifically the part that does NOT pass today.

### Step 2 — Identify or create the module

Check if `apps/teams-board-web-fe-e2e/src/modules/{item.feature}/` exists.

**If it exists:**
- Read `{feature}.page.ts` and `{feature}.fixtures.ts`
- Identify which locators or methods need to be added for S2

**If it does not exist:**
- Create `apps/teams-board-web-fe-e2e/src/modules/{item.feature}/{item.feature}.page.ts`:
  ```typescript
  import { Page } from '@playwright/test';
  import { AppPage } from 'app.page';

  export class FeaturePage implements AppPage {
    constructor(public readonly page: Page) {}

    async goto() {
      await this.page.goto('/feature-url');
    }

    async verifyPageAccessible() {
      await this.page.getByRole('heading', { name: /Feature Name/i }).waitFor();
    }

    async getStarted() {
      await this.goto();
      await this.verifyPageAccessible();
    }
  }
  ```
- Create `apps/teams-board-web-fe-e2e/src/modules/{item.feature}/{item.feature}.fixtures.ts`:
  ```typescript
  import { permissionsFixtures } from 'modules/permissions/permissions.fixtures';
  import { FeaturePage } from './{feature}.page';

  export const featureFixtures = permissionsFixtures.extend<{
    featurePage: FeaturePage;
  }>({
    featurePage: async ({ authenticatedPage }, use) => {
      await use(new FeaturePage(authenticatedPage.page));
    },
  });
  ```

### Step 3 — Discover selectors from the live app

If the dev server is running at `http://localhost:4200`, browse it to verify real selectors before writing locators.

Use the Chrome DevTools MCP or Playwright's `--headed` mode to inspect the live DOM:

```bash
# Run with visible browser to inspect selectors
pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e --headed --grep "[TB-XXX]"
```

From the DOM:
- Identify the element that S2 asserts (a button, heading, status message, etc.)
- Confirm it is **absent or wrong today** (validates S1 — the item is real, unfixed work)
- Extract the best Playwright locator for it

Use selectors in this order:
1. `getByRole()` — preferred; use the role + name from the ARIA tree
2. `getByLabel()` — for form elements
3. `getByText()` — for visible text content
4. `locator('[data-testid="..."]')` — when ARIA role is ambiguous

Write the verified selector into `{feature}.page.ts`.

> If the dev server is not running, note this in `item.notes`, set `status: "blocked"` with `blockedReason: "dev server not running"`, and skip to the next item.

### Step 4 — Write the failing test

Create (or append to) `apps/teams-board-web-fe-e2e/src/e2e/{item.feature}/{item.feature}.spec.ts`:

```typescript
import { expect } from '@playwright/test';
import { featureFixtures } from '../../modules/{feature}/{feature}.fixtures';

const test = featureFixtures;

test.describe('{Feature Area}', () => {
  test('[{item.id}] {description of targetState behavior}', async ({ featurePage }) => {
    await featurePage.getStarted();

    // Assert targetState (S2)
    // This assertion MUST fail against the current codebase
    await expect(featurePage.page.getByRole('...', { name: /.../ })).toBeVisible();
  });
});
```

Rules for the test body:
- Name matches `[{item.id}] present-tense description`
- Asserts exactly the S2 behavior described in `item.targetState`
- Must fail against the current codebase (confirms it is testing something real)
- Must pass after the Dev Agent implements the fix

### Step 5 — Verify it fails

Run from workspace root:
```bash
pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e --grep "\[{item.id}\]"
```

Expected outcome: **test fails**

If the test passes (green), the assertion is wrong — it is not testing S2 behavior. Revise the assertion.

If the test errors on import or setup (not on the assertion), fix the structural error first.

### Step 6 — Update backlog.agent.json

After verifying the test fails, update the item in `backlog.agent.json`:

```json
{
  "id": "{item.id}",
  "status": "qa_done",
  "testFile": "apps/teams-board-web-fe-e2e/src/e2e/{feature}/{feature}.spec.ts"
}
```

### Step 7 — HITL gate

If `autonomy.mode === "hitl"` and `autonomy.gates.after_qa_write === true`:

Pause and report to the user:
```
[QA Agent] {item.id} — spec written
  Test file: apps/teams-board-web-fe-e2e/src/e2e/{feature}/{feature}.spec.ts
  Run: pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e --grep "[{item.id}]"
  Status: FAILING (expected)

  Ready to continue to next item? (y/n)
```

Wait for approval before processing the next item.

---

## Output Summary

After processing all pending items, report:

```
[QA Agent] Done
  Release: {release-name}
  Items processed: N
  Specs written: N

  Files created/modified:
    apps/teams-board-web-fe-e2e/src/modules/{feature}/{feature}.page.ts
    apps/teams-board-web-fe-e2e/src/e2e/{feature}/{feature}.spec.ts
    agents/releases/.../backlog.agent.json (status updated)

  All tests are FAILING — ready for Dev Agent.
  Run: pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e (to see all failures)
```

---

## Edge Cases

**Item has no matching module area:**
Create a new module. Use the feature name from `item.feature` as the directory name. Kebab-case.

**Spec file already exists for the feature:**
Append the new test to the existing `describe` block. Do not create a duplicate file.

**Test cannot be written without backend data:**
Note this in `item.notes` and set `status: "blocked"` with a `blockedReason`. Skip to next item.

**Locator is ambiguous between user roles:**
Default to the primary user (alice/`authenticatedPage` fixture). Note the ambiguity in `item.notes`. Use `role-permissions.fixtures.ts` for multi-user tests.
