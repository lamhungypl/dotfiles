# Design Agent Skill

**Trigger:** `/design-agent [release-name]`

**Purpose:** Translate structured metadata and answered Q&A into three engineering artifacts: a technical design document (decisions + rationale), a detailed design document (implementation spec), and a resolved Q&A log. These feed directly into the PO Agent and Dev Agent.

---

## Pre-flight

1. Find the release folder: `agents/releases/<yyyy>/<mm>/<release-name>/`
   - If `release-name` is given, search `releases/` for a matching folder
   - If ambiguous, list candidates and ask the user to confirm
2. Verify `metadata/features.json` and `metadata/requirements.json` exist
   - If missing: stop — run `/metadata-agent` first
3. Check for `metadata/open-questions.md`:
   - If missing: generate it now (same rules as Metadata Agent's open-questions step), then pause for human answers before continuing
   - If present: read it and check for any `PENDING` questions with no `**Answer:**` line
     - If unresolved questions remain: list them and pause — do not proceed until all are resolved or explicitly deferred
4. Read `workspaces.json` at the workspace root for the `frontend` path
5. Scan the frontend codebase to build a component inventory

---

## Component Inventory (Pre-step)

Before writing any artifacts, scan the frontend codebase to understand what already exists:

- List component files matching `libs/fe/**/*.tsx` and `apps/teams-board-web-fe/app/**/*.tsx`
- List hooks matching `libs/fe/hooks/**/*.ts`
- Note existing API route patterns in `libs/api/*/`
- Check existing RTK Query endpoints in `libs/fe/*-data-access/`

This inventory is used in `detailed-design.md` to annotate every component decision with "reuse existing" or "create new".

---

## Output 1: `metadata/tech-design.md`

Technical design document — architectural decisions with rationale. Written for tech leads and reviewers, not implementers (implementers use `detailed-design.md`).

### Sections

#### API Schema

For each new or modified API endpoint needed by this release:

```markdown
### POST /api/tasks/:id/status

**Decision:** Add a PATCH endpoint to update task status (not reusing task update endpoint).
**Reason:** Status updates happen frequently from the Kanban board and should be a focused, fast operation separate from full task edits.
**Request:**
  { "status": TaskStatus }
**Response:**
  { "id": string, "status": TaskStatus, "updatedAt": ISO8601 }
**Error states:** 400 if status invalid, 403 if not team member, 404 if task not found
**Affects requirements:** R-001, R-003
```

If no new API is needed, write: `No new API endpoints required for this release.`

#### UI/UX Decisions

For each feature where a UI/UX decision was made:

```markdown
### [F-001] Kanban — Drag-and-Drop Library

**Decision:** Use existing `@dnd-kit/core` if already in the bundle; otherwise evaluate `react-beautiful-dnd`.
**Reason:** Teams Board already uses MUI components — adding a heavy DnD library adds bundle cost. Prefer the lighter option.
**Affects requirements:** R-001, R-002
**Figma ref:** inputs/figma/kanban-board.png
```

#### Conflicts Resolved

List every conflict found across inputs and how it was resolved:

```markdown
| Conflict | Source A | Source B | Resolution |
|----------|----------|----------|------------|
| Task status options | Design: 4 statuses | Backend: 3 statuses | Use backend enum as source of truth |
```

---

## Output 2: `metadata/detailed-design.md`

Engineering implementation spec — detailed enough for the Dev Agent or an engineer to implement each feature without ambiguity. Written per feature.

### Structure per feature

```markdown
## [F-001] Kanban — Drag-and-Drop Task Status

### Components

| Component | Action | Location |
|-----------|--------|----------|
| `KanbanBoard` | Reuse | `libs/fe/kanban/src/KanbanBoard.tsx` |
| `KanbanColumn` | Reuse | `libs/fe/kanban/src/KanbanColumn.tsx` |
| `KanbanCard` | Reuse | `libs/fe/kanban/src/KanbanCard.tsx` |
| `useDragDrop` | Create new | `libs/fe/kanban/src/hooks/useDragDrop.ts` |

### Function / Method Signatures

```typescript
// New hook for drag-drop state
function useDragDrop(tasks: Task[]): {
  onDragEnd: (result: DragResult) => void;
  groupedTasks: Record<TaskStatus, Task[]>;
}

// RTK Query mutation (add to tasks-data-access)
updateTaskStatus: builder.mutation<Task, { id: string; status: TaskStatus }>({
  query: ({ id, status }) => ({ url: `/tasks/${id}/status`, method: 'PATCH', body: { status } }),
  invalidatesTags: ['Task'],
})
```

### State Shape

```typescript
// No new global state — task status updates via RTK Query mutation + cache invalidation
// Local drag state managed in useDragDrop hook
```

### Data Flow

1. User drags a `KanbanCard` to a new column
2. `onDragEnd` fires with source/destination column (= TaskStatus)
3. `updateTaskStatus` RTK Query mutation dispatched
4. On success: RTK cache invalidated, board re-renders with new position
5. On failure: optimistic update rolled back, error snackbar shown

### API Integration

- `PATCH /api/tasks/:id/status` — new endpoint (see tech-design.md)
- Update `libs/api/tasks/` to handle the new route

### Edge Cases

- Dropping in same column: no-op
- Dropping while mutation in-flight: disable drag cursor
- Network error: roll back optimistic update, show notification

### Implementation Order

1. Add `PATCH /api/tasks/:id/status` to NestJS tasks module
2. Add `updateTaskStatus` mutation to `libs/fe/tasks-data-access`
3. Create `useDragDrop` hook in `libs/fe/kanban`
4. Wire hook into `KanbanBoard` component
5. Verify Playwright test passes
```

---

## Output 3: `metadata/qna-resolved.md`

Final Q&A log — all questions from `open-questions.md` with answers, decisions traced, and status closed.

### Format

```markdown
# Q&A — Resolved

Release: kanban-polish
Closed: <date>

---

## [Q-001] Team: UX — Status columns

**Question:** Should the Kanban board show all task statuses or only active ones?
**Affects requirements:** R-001
**Draft answer (Design Agent):** Show all statuses defined in the TaskStatus enum. DRAFT — AWAITING CONFIRMATION.
**Final answer:** Confirmed — show all statuses.
**Design decision:** See tech-design.md → UI/UX Decisions → Kanban columns
**Status:** RESOLVED ✓
```

---

## Draft Answers

For each open question in `open-questions.md` that has no `**Answer:**` line, the Design Agent proposes a best-guess answer based on available inputs. Each draft is clearly marked:

```
**Draft answer (Design Agent):** <proposed answer>. DRAFT — AWAITING CONFIRMATION.
```

Write draft answers directly into `open-questions.md`, then pause for human review.

**Deferred questions:** If a question is marked `DEFERRED — <reason>`, the affected requirements are marked `status: "deferred"` in the backlog with `skipReason` set to the deferral reason.

---

## Human Review Gate

After writing all three artifacts, pause and report:

```
[Design Agent] Done — review required before PO Agent runs

Release: kanban-polish
Artifacts written:
  metadata/tech-design.md       — N API decisions, N UI/UX decisions, N conflicts resolved
  metadata/detailed-design.md   — N features documented
  metadata/qna-resolved.md      — N questions resolved, N deferred

Deferred requirements (will become deferred backlog items):
  R-031 — <title> (deferred: <reason>)

Review the artifacts above, then run: /po-agent kanban-polish
```

Do not run the PO Agent automatically.

---

## Edge Cases

**No open-questions.md:** Generate it in the same pass (Metadata Agent rules apply), add draft answers, then pause before proceeding to design artifacts.

**All questions are already resolved:** Skip the Q&A phase, proceed directly to design artifact generation.

**Frontend codebase not available** (workspaces.json frontend path doesn't exist): Note "component scan unavailable — workspaces.json frontend path not accessible" in `detailed-design.md`. List proposed component names without file path annotations. Continue.

**Requirement has no clear implementation path:** Flag it with `[DESIGN BLOCKER]` in `detailed-design.md`. Mark the corresponding backlog item `status: "blocked"` with `blockedReason` explaining the design gap.

**New feature area not in existing codebase:** Note in `detailed-design.md` that a new module must be scaffolded. QA Agent will create the E2E module; Dev Agent will create the feature lib.
