# E2E Test Generation for Feature Roadmap + Self-Healing Integration

## Context

The feature roadmap (`agents/plans/feature-roadmap-implementation.md`) adds 15 features across 5 phases. Each feature needs e2e test coverage. This plan defines:
1. What e2e tests to create per feature (page objects, fixtures, specs)
2. How to integrate with the self-healing e2e system (`agents/plans/self-healing-e2e.md`)
3. The workflow: implement feature → generate tests → run self-healing loop → ship

## Workflow Per Feature

```
1. Implement feature (app code)
2. Create page objects + fixtures for the feature
3. Write e2e spec files
4. Run `e2e-heal run` → self-healing loop:
   - Tests fail → fix-fe/fix-api/fix-ws agents fix app code
   - Tests still fail → fix-test agent fixes test selectors/assertions
   - All green → done
5. Commit feature + tests together
```

This means the **fix-test agent** is critical — AI-generated tests will have wrong selectors, stale assertions, or timing issues on the first pass. The self-healing loop polishes both app and test code.

---

## Existing Test ID Scheme

Current tests use `[C00001]` through `[C00128]`. New tests start at `[C00200]` per phase:
- Phase 1: `[C00200]` – `[C00249]`
- Phase 2: `[C00250]` – `[C00299]`
- Phase 3: `[C00300]` – `[C00399]`
- Phase 4: `[C00400]` – `[C00449]`
- Phase 5: `[C00450]` – `[C00499]`

---

## Phase 1: Quick Wins

### 1.1 Swagger API Docs Cleanup
**No e2e tests needed** — this is backend documentation only. Verify manually at `/docs`.

### 1.2 Async Export Fix
**Modify existing tests** — export tests already exist in `e2e/tasks/task-export.spec.ts` (6 tests).

**Changes to existing page object** (`modules/tasks/task-export.page.ts`):
- Add `verifyDownloadContent(download)` method — check file size > 0, correct MIME type

**New specs** in `e2e/tasks/task-export.spec.ts`:
- `[C00200]` - Export as PDF produces a valid file (non-empty, correct content-type)
- `[C00201]` - Export as DOCX produces a valid file
- `[C00202]` - Export progress indicator shows during async export

### 1.3 Password Reset Flow
**New page object**: `modules/auth/reset-password.page.ts`
- Locators: `newPasswordInput`, `confirmPasswordInput`, `submitBtn`, `successMessage`
- Methods: `fillNewPassword()`, `submit()`, `verifySuccess()`
- Implements `AppPage` (has `goto()` with `?token=...` param)

**Modify fixture**: `modules/auth/auth.fixtures.ts` — add `resetPasswordPage`

**New spec**: `e2e/auth/reset-password.spec.ts`
- `[C00210]` - Reset password page renders with token param
- `[C00211]` - Submit new password → success message
- `[C00212]` - Login with new password succeeds
- `[C00213]` - Invalid/expired token shows error
- `[C00214]` - Password mismatch shows validation error

**Update** `baseTest.ts` — merge `authFixtures` (already done, just need new fixture)

---

## Phase 2: Dashboard & Email

### 2.1 Dashboard Widgets
**New page object**: `modules/dashboard/dashboard.page.ts`
- Locators: `statsCards`, `myTasksList`, `overdueAlert`, `activityFeed`
- Methods: `getStatValue(cardName)`, `getMyTaskCount()`, `isOverdueAlertVisible()`
- Implements `AppPage` with `goto('/')`

**Modify fixture**: `modules/dashboard/dashboard.fixtures.ts` — add `dashboardPage`

**New spec**: `e2e/dashboard/dashboard-widgets.spec.ts`
- `[C00250]` - Dashboard shows summary cards (total tasks, in progress, completed, overdue)
- `[C00251]` - Summary card counts match actual task data
- `[C00252]` - My tasks list shows tasks assigned to current user
- `[C00253]` - Overdue alert visible when overdue tasks exist
- `[C00254]` - Dashboard loads without errors after login redirect

### 2.2 Email Delivery Service
**No e2e tests** — email delivery is backend infrastructure. Tested via integration/unit tests. The password reset flow (1.3) already covers the user-facing trigger.

---

## Phase 3: Major Features

### 3.1 Activity/Audit Log
**New page object**: `modules/activity-log/activity-log.page.ts`
- Locators: `activityList`, `activityItems`, `filterDropdown`
- Methods: `getActivityCount()`, `getLatestActivity()`, `filterByEntity(type)`
- Can be a panel/widget on dashboard or standalone page

**New fixture**: `modules/activity-log/activity-log.fixtures.ts`

**New spec**: `e2e/activity-log/activity-log.spec.ts`
- `[C00300]` - Activity log shows entries after task creation
- `[C00301]` - Activity log shows entries after task update
- `[C00302]` - Activity log shows entries after task deletion
- `[C00303]` - Activity log shows team membership changes
- `[C00304]` - Activity entries show correct actor name and timestamp

### 3.2 Role-Based Access Control (RBAC)
**Requires multi-user auth setup.**

**Modify setup**: `setups/auth.setup.ts` — add second user auth state
- `alice` → `.auth/user.json` (owner of Alpha Squad)
- `bob` → `.auth/user-bob.json` (member of Alpha Squad)

**New fixture**: `modules/permissions/role-permissions.fixtures.ts`
- `memberPage` — authenticated as bob (member role)
- `ownerPage` — authenticated as alice (owner role)

**Modify page object**: `modules/teams/team-detail.page.ts`
- Add: `memberRoleBadge(index)`, `changeRoleDropdown(index)`, `getRoleName(index)`

**New spec**: `e2e/permissions/rbac.spec.ts`
- `[C00310]` - Owner sees role management dropdown on team members
- `[C00311]` - Member does NOT see role management dropdown
- `[C00312]` - Owner can change member role to admin
- `[C00313]` - Viewer cannot create/edit/delete tasks (buttons disabled or hidden)
- `[C00314]` - Member can create tasks but cannot delete others' tasks
- `[C00315]` - Role badges display correctly on team member list

### 3.3 Task Comments
**New page objects**:
- `modules/comments/comments-list.page.ts` — `commentItems`, `commentCount`, `getCommentText(index)`, `getCommentAuthor(index)`
- `modules/comments/comment-form.page.ts` — `bodyInput`, `submitBtn`, `fillBody()`, `submit()`

**New fixture**: `modules/comments/comments.fixtures.ts`

**New spec**: `e2e/comments/task-comments.spec.ts`
- `[C00320]` - Comment form visible on task detail
- `[C00321]` - Submit comment → appears in comment list
- `[C00322]` - Comment shows author name and timestamp
- `[C00323]` - Edit own comment
- `[C00324]` - Delete own comment
- `[C00325]` - Comments persist after page reload

### 3.4 Full-Text Search
**New page object**: `modules/search/search.page.ts`
- Locators: `searchInput`, `searchResults`, `resultItems`, `noResultsMessage`
- Methods: `search(query)`, `getResultCount()`, `clickResult(index)`, `clearSearch()`

**New fixture**: `modules/search/search.fixtures.ts`

**New spec**: `e2e/search/task-search.spec.ts`
- `[C00330]` - Search input visible in toolbar
- `[C00331]` - Typing query shows matching results (debounced)
- `[C00332]` - Search by task title returns correct results
- `[C00333]` - Search with no matches shows empty state
- `[C00334]` - Clicking search result navigates to task
- `[C00335]` - Search is case-insensitive

### 3.5 Drag-and-Drop Kanban Board
**New page object**: `modules/kanban/kanban.page.ts`
- Locators: `columns` (by status name), `cards`, `viewToggle`
- Methods: `getColumnCardCount(status)`, `dragCard(fromCol, cardIndex, toCol)`, `switchToKanbanView()`, `switchToTableView()`
- Drag uses Playwright's `dragTo()` API

**New fixture**: `modules/kanban/kanban.fixtures.ts`

**New spec**: `e2e/kanban/kanban-board.spec.ts`
- `[C00340]` - Kanban view toggle visible on task list page
- `[C00341]` - Kanban board renders columns for each status
- `[C00342]` - Cards show title, assignee, due date
- `[C00343]` - Drag card from one column to another updates task status
- `[C00344]` - After drag, switching to table view shows updated status
- `[C00345]` - Kanban board reflects real-time data

### 3.6 User Profile & Avatar
**New page object**: `modules/profile/profile-dialog.page.ts`
- Locators: `dialog`, `avatarUpload`, `nameInput`, `saveBtn`, `currentAvatar`
- Methods: `uploadAvatar(filePath)`, `fillName()`, `submit()`, `verifyVisible()`

**New fixture**: `modules/profile/profile.fixtures.ts`

**New spec**: `e2e/profile/user-profile.spec.ts`
- `[C00350]` - Profile dialog opens from header/sidebar
- `[C00351]` - Current name pre-populated in form
- `[C00352]` - Update display name → reflected in sidebar
- `[C00353]` - Upload avatar → image preview shown
- `[C00354]` - Avatar displayed in header after upload

---

## Phase 4: Nice to Have

### 4.1 Notification Preferences
**New page object**: `modules/notifications/notification-prefs.page.ts`
- Locators: `prefsDialog`, `toggles` (per notification type), `saveBtn`
- Methods: `toggleInApp(type)`, `toggleEmail(type)`, `submit()`

**New fixture**: `modules/notifications/notifications.fixtures.ts`

**New spec**: `e2e/notifications/notification-preferences.spec.ts`
- `[C00400]` - Notification preferences dialog opens
- `[C00401]` - Toggle in-app notification for a type
- `[C00402]` - Toggle email notification for a type
- `[C00403]` - Preferences persist after save and reload

### 4.2 Task Dependencies & Subtasks
**Modify page object**: `modules/tasks/task-update-dialog.page.ts`
- Add: `subtasksList`, `addSubtaskBtn`, `dependencySelect`
- Methods: `addSubtask(title)`, `getSubtaskCount()`, `addDependency(taskName)`

**New spec**: `e2e/tasks/task-subtasks.spec.ts`
- `[C00410]` - Add subtask to a task
- `[C00411]` - Subtask appears in task detail
- `[C00412]` - Complete subtask updates parent progress
- `[C00413]` - Add dependency between tasks
- `[C00414]` - Circular dependency shows error

### 4.3 Keyboard Shortcuts
**No new page objects** — test directly via `page.keyboard.press()`.

**New spec**: `e2e/common/keyboard-shortcuts.spec.ts`
- `[C00420]` - Press `?` opens keyboard shortcuts help dialog
- `[C00421]` - Press `c` opens create task dialog
- `[C00422]` - Press `j`/`k` navigates task list
- `[C00423]` - Shortcuts disabled when input is focused

---

## Phase 5: Stretch Goals

### 5.1 Sprint/Milestone Grouping
**New page objects**:
- `modules/sprints/sprint-list.page.ts` — `createBtn`, `sprintItems`, `getSprintCount()`
- `modules/sprints/sprint-detail.page.ts` — `taskList`, `burndownChart`, `addTaskBtn`
- `modules/sprints/create-sprint-dialog.page.ts` — `nameInput`, `startDateInput`, `endDateInput`

**New fixture**: `modules/sprints/sprints.fixtures.ts`

**New spec**: `e2e/sprints/sprint-management.spec.ts`
- `[C00450]` - Create sprint with name and dates
- `[C00451]` - Assign task to sprint
- `[C00452]` - Sprint board shows only sprint tasks
- `[C00453]` - Burndown chart renders

### 5.2 CSV Import
**New page object**: `modules/import/csv-import-dialog.page.ts`
- Locators: `dialog`, `fileUpload`, `previewTable`, `confirmBtn`, `errorMessages`
- Methods: `uploadFile(path)`, `getPreviewRowCount()`, `confirm()`

**New fixture**: `modules/import/import.fixtures.ts`

**New spec**: `e2e/import/csv-import.spec.ts`
- `[C00460]` - Upload valid CSV shows preview table
- `[C00461]` - Confirm import creates tasks
- `[C00462]` - Invalid CSV shows validation errors
- `[C00463]` - Imported tasks appear in task list

---

## File Structure Summary (new e2e files)

```
apps/teams-board-web-fe-e2e/src/
├── modules/
│   ├── auth/
│   │   └── reset-password.page.ts           # NEW
│   ├── dashboard/
│   │   └── dashboard.page.ts                # NEW
│   ├── activity-log/                        # NEW module
│   │   ├── activity-log.page.ts
│   │   └── activity-log.fixtures.ts
│   ├── comments/                            # NEW module
│   │   ├── comments-list.page.ts
│   │   ├── comment-form.page.ts
│   │   └── comments.fixtures.ts
│   ├── search/                              # NEW module
│   │   ├── search.page.ts
│   │   └── search.fixtures.ts
│   ├── kanban/                              # NEW module
│   │   ├── kanban.page.ts
│   │   └── kanban.fixtures.ts
│   ├── profile/                             # NEW module
│   │   ├── profile-dialog.page.ts
│   │   └── profile.fixtures.ts
│   ├── notifications/                       # NEW module
│   │   ├── notification-prefs.page.ts
│   │   └── notifications.fixtures.ts
│   ├── sprints/                             # NEW module
│   │   ├── sprint-list.page.ts
│   │   ├── sprint-detail.page.ts
│   │   ├── create-sprint-dialog.page.ts
│   │   └── sprints.fixtures.ts
│   ├── import/                              # NEW module
│   │   ├── csv-import-dialog.page.ts
│   │   └── import.fixtures.ts
│   └── permissions/
│       └── role-permissions.fixtures.ts     # NEW
├── e2e/
│   ├── auth/
│   │   └── reset-password.spec.ts           # NEW
│   ├── dashboard/
│   │   └── dashboard-widgets.spec.ts        # NEW
│   ├── activity-log/
│   │   └── activity-log.spec.ts             # NEW
│   ├── permissions/
│   │   └── rbac.spec.ts                     # NEW
│   ├── comments/
│   │   └── task-comments.spec.ts            # NEW
│   ├── search/
│   │   └── task-search.spec.ts              # NEW
│   ├── kanban/
│   │   └── kanban-board.spec.ts             # NEW
│   ├── profile/
│   │   └── user-profile.spec.ts             # NEW
│   ├── notifications/
│   │   └── notification-preferences.spec.ts # NEW
│   ├── tasks/
│   │   └── task-subtasks.spec.ts            # NEW
│   ├── common/
│   │   └── keyboard-shortcuts.spec.ts       # NEW
│   ├── sprints/
│   │   └── sprint-management.spec.ts        # NEW
│   └── import/
│       └── csv-import.spec.ts               # NEW
└── setups/
    └── auth.setup.ts                        # MODIFIED (add bob auth)
```

**Totals:** 13 new spec files, ~70 new test cases, 10 new page objects, 9 new fixture files

---

## Integration with Self-Healing System

### Per-Phase Workflow

```
For each phase:
  1. Implement all features in the phase (app code)
  2. Generate all e2e test files for the phase (page objects + fixtures + specs)
  3. Update baseTest.ts to merge new fixtures
  4. Run: e2e-heal start
  5. Run: e2e-heal run
     └── Self-healing loop:
         ├── fix-api  → fixes NestJS endpoints, DTOs, services
         ├── fix-fe   → fixes React components, selectors, routing
         ├── fix-ws   → fixes WebSocket handlers
         └── fix-test → fixes wrong selectors, assertions, timing
  6. All green → commit phase
```

### What fix-test Needs to Know About New Tests

The `fix-test` agent system prompt (`tools/e2e-heal-prompts/test.md`) must include:
- The page object pattern (AppPage interface, dialog pattern)
- Fixture composition via `mergeTests` in `baseTest.ts`
- Selector priority: `getByRole()` > `getByLabel()` > `getByText()` > `getByTestId()`
- Dialog scoping pattern (all locators relative to `this.dialog`)
- Auth setup pattern (`.auth/user.json` storageState)
- Test ID scheme (`[C00XXX]`)

### Agent Dispatch Optimization

When running the self-healing loop after generating tests for a new feature:
- **First iteration**: Most failures will be test-side (wrong selectors). Dispatch `fix-test` alongside `fix-fe`.
- **Subsequent iterations**: If app code has issues, `fix-api`/`fix-fe` will be dispatched.
- **Key insight**: After generating AI tests, expect ~60% test-side issues, ~40% app-side issues.

The classification logic in `self-healing-e2e.md` should be tuned:
- For the **first run** after test generation: bias toward `fix-test` (selectors are likely wrong)
- For **subsequent runs**: normal classification (check service logs first)

---

## Implementation Steps

### Step 1: Build the self-healing e2e system first
Follow `agents/plans/self-healing-e2e.md` to create:
- `docker-compose.e2e.yml`
- `tools/e2e-heal` CLI
- Agent system prompts (including `test.md`)

### Step 2: Per phase — implement features, then generate tests
For each feature in the roadmap:
1. Implement the feature (follow `agents/plans/feature-roadmap-implementation.md`)
2. Create the page objects, fixtures, and spec files listed above
3. Update `baseTest.ts` to include new fixtures
4. Run `e2e-heal run` to polish both app and tests

### Step 3: Multi-user auth setup (needed for Phase 3 RBAC)
Before Phase 3, update `auth.setup.ts` to create a second authenticated state for bob.

## Verification

After all phases:
1. `pnpm exec nx run teams-board-web-fe-e2e:e2e` — all ~70 new tests + existing tests pass
2. Each feature has at least 3-5 e2e tests covering happy path + key edge cases
3. All page objects follow existing patterns (AppPage interface, dialog scoping)
4. `baseTest.ts` merges all fixtures without conflicts
