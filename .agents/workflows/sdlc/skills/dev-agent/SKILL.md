# Dev Agent Skill

**Trigger:** `/dev-agent [release-name]` or invoked by dispatcher

**Purpose:** For each `qa_done` item in `backlog.agent.json`, implement code changes in the frontend (`apps/teams-board-web-fe/` and `libs/fe/`) until the corresponding Playwright test passes.

The test is the contract. The Dev Agent never modifies test files.

---

## Pre-flight

1. Read `workspaces.json` at the workspace root — resolve `e2e`, `frontend`, and `workspace` paths
   - If missing: ask the user to copy `agents/workspaces.example.json` → `workspaces.json` and fill in their paths
2. Read `agents/releases/LEARNINGS.md` if it exists — note fragile components, prior healer invocations, and scope signals before implementing
3. Read `agents/agent.md` — onboard on the E2E project structure and frontend code locations
4. Find the release folder: `agents/releases/<yyyy>/<mm>/<dd-release-name>/`
5. Read `backlog.agent.json` — the agent working copy created by the QA Agent
   - If missing: report "`backlog.agent.json` not found — run /qa-agent first" and stop
   - Never read or modify `backlog.json` — it is the immutable human-signed plan
6. Filter items where `status === "qa_done"`
   - If none: report "No qa_done items — run /qa-agent first" and stop
7. Confirm the frontend dev server is running at `http://localhost:4200`
   - If not: remind the user to run `pnpm exec nx run @lhypl/teams-board-web-fe:dev` and wait

---

## Per Item Loop

For each `qa_done` item (in backlog order):

### Step 1 — Read the spec

Open `item.testFile` and read the failing test.

Identify:
- What selector is being asserted (`getByRole`, `getByLabel`, etc.)
- What state is being asserted (`toBeVisible`, `toHaveAttribute`, `toHaveFocus`, etc.)
- What user action precedes the assertion (if any)

### Step 2 — Confirm the test is still failing

Run:
```bash
pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e --grep "\[{item.id}\]"
```

If it passes: the behavior was already implemented. Set `status: "done"`, add `notes: "Already passing before dev work"`. Continue to next item.

If it fails on a structural error (import, config): fix the structural error first. This is a QA Agent artifact, not a feature gap.

### Step 3 — Locate the frontend code

Read `AGENTS.md` at the workspace root for architecture conventions.

Use the E2E selector as a guide to find the right component:
- `getByRole('button', { name: /Create Task/i })` → find `<Button>` with that label in `libs/fe/tasks-ui-loadable/`
- `getByLabel('Email')` → find the form field with that label in `libs/fe/auth-ui/`
- `getByRole('heading', { name: /Teams/i })` → find the heading in `libs/fe/teams/`

Frontend code locations:
- React SPA entry: `apps/teams-board-web-fe/app/`
- Feature UI: `libs/fe/{feature}/`
- Data access (RTK Query): `libs/fe/{feature}-data-access/`
- Shared UI components: `libs/fe/ui/`
- Backend API: `libs/api/{feature}/` (NestJS modules)

### Step 4 — Implement the fix

Make the minimal change needed to satisfy the test assertion.

Rules:
- Change only what the test requires — no refactoring, no bonus improvements
- Follow the architecture in `AGENTS.md` — respect the `data-access` → `ui` layer separation
- If the fix requires touching more than 3 files, pause and explain the scope to the user before proceeding
- Run `pnpm exec nx run @lhypl/teams-board-web-fe:type-check` after each change to catch type errors early
- Run `pnpm exec nx run-many --target=lint --projects=@lhypl/teams-board-web-fe` after changes

If the fix requires a **backend change** (new API endpoint, entity update):
- Note it in `item.notes`
- Make the backend change in `libs/api/{feature}/` and/or `libs/api/entities/`
- Start both frontend and backend dev servers to test end-to-end

### Step 5 — Verify the test passes

Run:
```bash
pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e --grep "\[{item.id}\]"
```

Expected: **test passes (green)**

If still failing after two iterations: review the selector from `agent.md`, inspect the live DOM with `--headed` mode, and auto-fix any stale selectors or assertion mismatches before trying again.

If a different test broke (regression): investigate the regression before continuing. Do not proceed with a broken baseline.

### Step 6 — Update backlog.agent.json

```json
{
  "id": "{item.id}",
  "status": "done"
}
```

### Step 7 — HITL gate

If `autonomy.mode === "hitl"` and `autonomy.gates.after_dev_pass === true`:

Pause and report:
```
[Dev Agent] {item.id} — PASSING

  Test: {item.testFile}
  Run: pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e --grep "[{item.id}]"

  Files changed:
    libs/fe/kanban/src/KanbanBoard.tsx
    libs/fe/tasks-data-access/src/queries.ts

  Ready to continue to next item? (y/n)
```

Wait for approval before processing the next item.

---

## Output Summary

After all items are processed, invoke the `report-agent` skill automatically:

```
[Dev Agent] Done — invoking Report Agent

Release: {release-name}
Items completed: N
Items already passing: N
Items blocked: N

Files changed:
  libs/fe/kanban/...
  libs/api/tasks/...

Run pnpm exec nx run @lhypl/teams-board-web-fe-e2e:e2e to verify all tests are green.
Sprint complete when all backlog items are "done".
```

---

## Constraints

- **Never modify test files** — the spec is the contract
- **Never modify `.auth/` files** or auth state
- **Never modify `playwright.config.ts`** unless explicitly instructed
- **Never modify `nx.json`, `tsconfig.base.json`, or `pnpm-lock.yaml`** unless required for a dependency change
- **Scope = one item = one focused change** — no combining multiple items in one edit pass
- **ESLint module boundaries**: `data-access` libs may only depend on other `data-access` or `util` libs — not UI libs. Enforce this strictly.

---

## Frontend Architecture Quick Reference

- **State management**: Redux Toolkit + RTK Query. Base query in `libs/fe/store-data-access`. Feature endpoints injected via `injectEndpoints`.
- **Routing**: React Router v7, lazy-loaded route modules
- **Forms**: React Hook Form + Zod, MUI field components from `libs/fe/ui`
- **Dialogs**: Centralized registry in `libs/fe/dialog-registry`, state in `libs/fe/store-dialog`
- **Styling**: Tailwind CSS v4 + Material-UI v7
- **TypeScript check**: `pnpm exec nx run @lhypl/teams-board-web-fe:type-check`

---

## Edge Cases

**Fix requires a new TypeORM entity or migration:** Note that `synchronize: true` is used in dev — TypeORM will auto-sync. Note in `item.notes` and proceed.

**Component is in a loadable/lazy-loaded chunk:** Find the source in `libs/fe/{feature}-ui-loadable/` or `libs/fe/{feature}/`.

**Multiple items affect the same component:** Process them sequentially. Each must be verified passing before moving to the next. If a later item breaks an earlier passing test, resolve the conflict before continuing.

**Fix requires a backend endpoint that doesn't exist:** Implement the NestJS route in `libs/api/{feature}/` and the controller in `apps/teams-gateway-api/src/`. Note both changes in the HITL gate report.
