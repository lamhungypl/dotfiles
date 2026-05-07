# PO Agent Skill (Product Owner Agent)

**Trigger:** `/po-agent [release-name]`

**Purpose:** Convert structured metadata into an ordered, prioritized backlog of testable work items. Output is `backlog.json` — the SSoT for the sprint.

---

## Pre-flight

1. Read `agents/releases/LEARNINGS.md` if it exists — use blocker patterns and estimation signals to improve item scoping and flag risky features early
2. Find the release folder: `agents/releases/<yyyy>/<mm>/<release-name>/`
3. Verify `metadata/features.json` exists and is non-empty
   - If missing: stop and report — run `/metadata-agent` then `/design-agent` first
4. Check for `metadata/detailed-design.md` — if present, read it to populate `techDesignRef` on each item and use implementation notes to improve `notes` fields
5. Check for `metadata/qna-resolved.md` — if present, read it to identify any deferred requirements and record them as `status: "deferred"` items
6. Read `agents/schemas/backlog.schema.json` — this defines the required output shape
7. Check if `backlog.json` already exists in the release folder:
   - If items have `status !== "pending"`: warn the user before overwriting — work may be in progress
   - If items are all `"pending"` (CSV Import Agent already ran): **append** FEAT items rather than overwrite — find the highest sequence, continue from there, re-sort combined list

---

## Transformation Rules

Each requirement in `metadata/features.json` becomes one backlog item.

### Project Key

Read `project` from `workspaces.json` at the workspace root (e.g. `"project": "TB"`).
Write it into the `backlog.json` header — all item IDs use this as their prefix.

### ID Assignment

IDs follow Jira-style format: `{PROJECT}-{NNN}` — a **single global sequence** across all item types.

- `TB-001`, `TB-002`, `TB-003` … regardless of whether the item is a bug, feature, or enhancement
- `NNN` starts at `001`, zero-padded to 3 digits minimum
- When appending to an existing backlog: read the highest existing number and continue from there

### Field Mapping

| Backlog field | Source |
|--------------|--------|
| `id` | Assigned by PO Agent (project key + sequence) |
| `type` | Derived from requirement type |
| `feature` | `requirement.feature` (= `features[].area`) |
| `title` | Concise restatement of `requirement.description` (max 80 chars) |
| `currentState` | `requirement.currentState` |
| `targetState` | `requirement.targetState` |
| `status` | Always `"pending"` |
| `priority` | `requirement.priority` |
| `figmaRef` | `requirement.figmaRef` if present |

### Ordering

Sort items in the output array by:
1. `priority` descending: `critical` → `high` → `medium` → `low`
2. Within same priority: `feature` alphabetically (groups related items for the Dev Agent)

### Splitting

If a requirement's `targetState` describes more than one independently testable behavior, split it into multiple backlog items. Each item must be testable with a single Playwright assertion focus.

Rule: if you could write the test two different ways and both would correctly validate the requirement independently → split.

### Merging

If two requirements from different features describe the same observable behavior, merge them into one item. Note both source requirement IDs in `notes`.

---

## Output

### `backlog.json`

Write `backlog.json` validated against `agents/schemas/backlog.schema.json`.

Preserve the `autonomy` block from the seed file if it exists, or write the default:
```json
"autonomy": {
  "mode": "hitl",
  "gates": {
    "after_qa_write": true,
    "after_dev_pass": true
  }
}
```

Example item:
```json
{
  "id": "TB-001",
  "type": "feature",
  "feature": "kanban",
  "title": "Task can be moved between columns by dragging",
  "currentState": "Task status can only be changed via the edit dialog",
  "targetState": "User drags a task card to a new column and its status updates immediately",
  "status": "pending",
  "priority": "high",
  "figmaRef": "inputs/figma/kanban-board.png",
  "techDesignRef": ["TD-001"]
}
```

Deferred item example:
```json
{
  "id": "TB-012",
  "type": "feature",
  "feature": "kanban",
  "title": "Custom column ordering on Kanban board",
  "currentState": "Columns are always in fixed order",
  "targetState": "User can reorder columns by dragging",
  "status": "deferred",
  "priority": "low",
  "skipReason": "Out of scope for this sprint — revisit when drag-and-drop is stable"
}
```

### `backlog.carryover.json`

Written alongside `backlog.json`. Contains all items with `status: "deferred"` or `status: "skipped"`. Provides an opt-in handoff to future sprints.

```json
{
  "schema_version": "1.0",
  "release": "kanban-polish",
  "generated_at": "...",
  "note": "Deferred and skipped items from this sprint. Import into the next sprint by copying desired items into the new release's metadata inputs.",
  "items": [
    {
      "id": "TB-012",
      "title": "Custom column ordering on Kanban board",
      "skipReason": "Out of scope — revisit when drag-and-drop is stable",
      "deferredFrom": "kanban-polish",
      "originalRequirement": "R-009",
      "priority": "low",
      "feature": "kanban"
    }
  ]
}
```

---

## Human Review Gate

Always pause after writing `backlog.json`:

```
[PO Agent] Done — review required before QA Agent runs

Release: kanban-polish
Items created: N
  critical: N
  high:     N
  medium:   N
  low:      N

Items by feature:
  kanban     — N items
  tasks      — N items
  ...

Splits performed: N  (see notes fields)
Merges performed: N  (see notes fields)

Review: agents/releases/2026/04/07-kanban-polish/backlog.json
Then run: /qa-agent kanban-polish
```

Do not run the QA Agent automatically, regardless of `autonomy.mode`. The backlog is the contract for the sprint — human sign-off is required.

---

## Edge Cases

**Requirement has no clear targetState:** Flag it, set `status: "blocked"`, `blockedReason: "targetState undefined — needs product clarification"`.

**Requirement references a feature area that has no existing E2E module:** Create the item anyway. QA Agent will create the module. Note: `"QA Agent will scaffold apps/teams-board-web-fe-e2e/src/modules/{feature}/"` in `notes`.

**Duplicate requirements across features:** Merge and note both source IDs. Do not create duplicate tests.

**Low-priority items when backlog is large (>20 items):** Move low-priority items to a separate section at the bottom of the array and add a note: `"Deferred — add to next sprint if queue empties early"`.
