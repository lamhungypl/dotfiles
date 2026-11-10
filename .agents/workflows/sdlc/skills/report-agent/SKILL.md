# Report Agent Skill

**Trigger:** `/report-agent [release-name]`
**Also called by:** Dev Agent automatically when all items reach `done` or `blocked`

**Purpose:** Two jobs — human reporting and agent learning.

| Output | Audience | Purpose |
|--------|----------|---------|
| `releases/<path>/report.md` | Humans | Sprint summary, blocked items, test coverage |
| `releases/<path>/learnings.md` | Agents | Patterns from this sprint — read by agents next sprint |
| `releases/REPORT.md` | Humans | Cross-sprint trend tables (velocity, type breakdown, growth) |
| `releases/LEARNINGS.md` | Agents | Accumulated cross-sprint memory — read at every sprint start |

---

## Pre-flight

1. Find the release folder: `agents/releases/<yyyy>/<mm>/<dd-release-name>/`
2. Read `backlog.json` — the original plan
3. Read `backlog.agent.json` — the execution record
   - If missing: cannot generate — run `/qa-agent` and `/dev-agent` first
4. Read `workspaces.json` → `project` key

---

## Step 1 — Collect sprint metrics

From `backlog.json` vs `backlog.agent.json`:

| Metric | How to compute |
|--------|---------------|
| Planned | total items in `backlog.json` |
| Done | `status: "done"` in `backlog.agent.json` |
| Blocked | `status: "blocked"` |
| Carry-over | `status: "pending"` or `"qa_done"` |
| By type | count done/blocked per `type` |
| Block reasons | group and count `blockedReason` values |

From `apps/teams-board-web-fe-e2e/src/e2e/`:

| Metric | How to compute |
|--------|---------------|
| Specs added | `.spec.ts` files referenced in done items' `testFile` |
| Test count | count `test(` in those files |
| Features touched | unique `item.feature` across done items |

From git log:
```bash
git log --oneline --since="<backlog.json generated_at>" -- apps/ libs/
```

---

## Step 2 — Write `report.md` (human)

Write to `releases/<yyyy>/<mm>/<dd-release-name>/report.md`:

```markdown
# Sprint Report: {release-name}
**Project:** TB | **Date:** {date} | **Branch:** {git branch}

## Summary

| | Count |
|--|-------|
| Planned | N |
| ✅ Done | N |
| 🚫 Blocked | N |
| ↩ Carry-over | N |
| Completion rate | N% |

## Done Items

| ID | Type | Feature | Title |
|----|------|---------|-------|
| TB-001 | feature | kanban | Task can be moved between columns by dragging |

## Blocked Items

| ID | Type | Title | Reason |
|----|------|-------|--------|
| TB-005 | feature | export | Requires new backend export endpoint |

## Test Coverage Added

| Spec file | Tests added | Feature area |
|-----------|-------------|--------------|
| apps/teams-board-web-fe-e2e/src/e2e/kanban/kanban.spec.ts | 3 | kanban |

**Total new tests:** N | **Cumulative suite size:** N specs across N feature areas

## Retrospective Notes

> _Fill in as a team — agents do not write this section._

### What went well
-

### What was harder than expected
-

### Process changes for next sprint
-
```

---

## Step 3 — Write `learnings.md` (agents)

Write to `releases/<yyyy>/<mm>/<dd-release-name>/learnings.md`.

This file is **written for agents, not humans**. Future agents read it in pre-flight to adjust their behavior. Be specific and actionable — not descriptive prose.

```markdown
# Agent Learnings: {release-name}
_Source: backlog.agent.json + git log. Read by all agents at next sprint start._

## Selector Patterns

Observations from QA Agent selector discovery this sprint:
- List each feature area and whether `getByRole` was reliable or required fallback
- Note any components where ARIA roles were dynamic or unreliable
- Note any features where `data-testid` was the only reliable selector

Example entries (generate from actual sprint data):
- `kanban`: `getByRole` reliable — all 3 locators stable
- `tasks`: Dialog selectors need scoping to the dialog container (multiple dialogs can be open)
- `notifications`: Toast selectors time-sensitive — use `waitFor` with timeout

## Blocker Patterns

Recurring block reasons this sprint:
- List `blockedReason` values grouped by feature and type
- Flag feature areas that blocked more than once

Example:
- `export` + `feature` type: 2/2 items blocked on backend dependency
  → **Next sprint:** flag `export` feature items for backend check before QA writes specs

## QA Agent Notes

Observations specific to spec writing:
- Which features had unclear S1/S2 that required inference
- Which backlog items needed the most iteration before the test was correctly failing
- Any selector that was written wrong and had to be corrected

## Dev Agent Notes

Observations specific to implementation:
- Which features required multiple fix iterations
- Which components are fragile (small change broke multiple tests)
- Any fix that touched more than 3 files (scope creep signal)
- RTK Query cache invalidation gotchas encountered

## Estimation Signal

- Planned: N | Done: N | Accuracy: N%
- Carry-overs: N — note whether these were low priority (expected) or misjudged scope
- If accuracy < 70%: flag for PO Agent — scope items more conservatively next sprint
```

Generate each section from the actual sprint data. If a section has nothing to report (e.g. no blocked items), write `- None this sprint.`

---

## Step 4 — Update `releases/LEARNINGS.md` (agents, cross-sprint)

This is the **accumulated agent memory**. Every agent reads it at sprint start. Append new entries — never overwrite old ones.

```markdown
# Agent Learnings — TB (Teams Board)
_Accumulated across all sprints. Read in pre-flight by all agents._
_Most recent sprint at the top._

---

## {release-name} ({date})

### Selector Memory
- `tasks` dialogs: scope selectors to dialog container — multiple dialogs can stack
- `kanban`: `getByRole` stable across board columns

### Recurring Blockers
- `export` features frequently blocked on backend — flag early in QA planning

### Process Notes
- RTK Query `invalidatesTags` must be run after mutations or tests see stale data

---

## {previous-release} ({date})

...prior entries preserved here...
```

Rules:
- Prepend new sprint entry at the top (most recent first)
- If a pattern appears for the second consecutive sprint, mark it `(confirmed N sprints running)`
- If a prior entry is contradicted by new data (e.g. a fixed component is now stable), add a `~~strikethrough~~` note rather than deleting

---

## Step 5 — Update `releases/REPORT.md` (humans, cross-sprint)

Append a new row to each trend table. Never rewrite historical rows.

```markdown
# Project Report — TB (Teams Board)

## Sprint Velocity
| Sprint | Date | Planned | Done | Blocked | Carry-over | Completion % |
|--------|------|---------|------|---------|------------|--------------|
| kanban-polish | 2026-04-07 | 8 | 7 | 1 | 0 | 88% |

## Type Breakdown
| Sprint | Features | Bugs | Enhancements |
|--------|----------|------|--------------|
| kanban-polish | 5 | 2 | 1 |

## Test Suite Growth
| Sprint | Tests Added | Cumulative | Feature Areas |
|--------|-------------|------------|---------------|
| kanban-polish | 8 | 8 | 3 |

## Block Rate Trend
| Sprint | Blocked | Block Rate | Top Blocker |
|--------|---------|------------|-------------|
| kanban-polish | 1 | 12% | Backend dependency (1×) |
```

---

## Step 6 — Output summary

```
[Report Agent] Done

  Sprint:     {release-name}
  Project:    TB
  Completion: N/N items (N%)

  ✅ Done:      N  (feature: N  bug: N  enhancement: N)
  🚫 Blocked:   N
  ↩  Carry-over: N

  New tests: N | Cumulative suite: N specs

  Written:
    releases/<path>/report.md       ← human sprint summary
    releases/<path>/learnings.md    ← agent learnings this sprint
    releases/REPORT.md              ← human trend log updated
    releases/LEARNINGS.md           ← agent memory updated

  Next steps:
    1. Fill in Retrospective Notes in report.md
    2. Agents will read LEARNINGS.md automatically next sprint
```

---

## Edge Cases

**First sprint:** Create `LEARNINGS.md` and `REPORT.md` fresh with headers and first entry.

**Zero done items:** Still generate all four files. A 0% sprint is a meaningful signal.

**Carry-over items:** List in report. Do not copy to next sprint — human decides at retro.

**Re-run:** Overwrite per-sprint files safely. Do not add duplicate rows to cross-sprint files — check release name first.
