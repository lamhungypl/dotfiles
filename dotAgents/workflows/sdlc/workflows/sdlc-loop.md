# SDLC Loop — Full Pipeline Architecture

## Philosophy

Every software change is a state transition: **S1 → S2**.

- S1 = current behavior (what the app does today)
- S2 = target behavior (what it should do after the sprint)
- A **test** is a machine-readable description of S2
- A **failing test** proves the spec is correct (it cannot pass until S2 is real)
- A **passing test** proves the implementation is complete

A bug is an unwanted feature — the same S1 → S2 framing applies. There is no special pipeline for bugs.

---

## Agent Roles

### Metadata Agent
- **Input**: `inputs/figma/`, `inputs/qa/`, `inputs/docs/`
- **Output**: `metadata/features.json`, `metadata/requirements.json`, `metadata/open-questions.md`
- **Role**: Extract structured intent from unstructured human artifacts; surface ambiguities and conflicts as open questions
- **SSoT for**: product intent
- **Skill**: `agents/skills/metadata-agent/SKILL.md`

### Design Agent
- **Input**: `metadata/features.json`, `metadata/requirements.json`, `metadata/open-questions.md`, design files, frontend codebase (via `workspaces.json`)
- **Output**: `metadata/tech-design.md`, `metadata/detailed-design.md`, `metadata/qna-resolved.md`
- **Role**: Resolve ambiguities via draft Q&A, then produce technical design (API/UI/UX decisions with rationale) and detailed design (engineering implementation spec per feature)
- **SSoT for**: design decisions and implementation approach
- **Skill**: `agents/skills/design-agent/SKILL.md`

### PO Agent (Product Owner Agent)
- **Input**: `metadata/features.json`, `metadata/detailed-design.md` (optional), `metadata/qna-resolved.md` (optional)
- **Output**: `backlog.json`, `backlog.carryover.json`
- **Role**: Convert requirements into discrete, ordered, testable backlog items; record deferred/skipped items in carryover file
- **SSoT for**: requirements (what must be built this sprint)
- **Skill**: `agents/skills/po-agent/SKILL.md`

### CSV Import Agent
- **Input**: `inputs/bugs/*.csv` (Linear, Jira, GitHub Issues, or custom export)
- **Output**: `backlog.json` (same schema as PO Agent)
- **Role**: Structured shortcut — bypasses Metadata Agent + PO Agent when requirements already exist as a bug/issue list
- **Use when**: you have a CSV export from a bug tracker instead of designs + docs
- **Skill**: `agents/skills/csv-import-agent/SKILL.md`

### QA Agent
- **Input**: `backlog.json` (pending items)
- **Output**: `*.spec.ts` (failing tests), updated `backlog.json` (qa_done items)
- **Role**: Write a failing Playwright test for each backlog item
- **SSoT for**: software behavior (the test is the spec)
- **Skill**: `agents/skills/qa-agent/SKILL.md`

### Dev Agent
- **Input**: `backlog.json` (qa_done items), `*.spec.ts` files
- **Output**: code changes in `apps/teams-board-web-fe/` and `libs/fe/`, updated `backlog.json` (done items)
- **Role**: Implement code changes until all tests pass
- **SSoT for**: implementation
- **Skill**: `agents/skills/dev-agent/SKILL.md`

---

## Data Flow

```
── Method A: Figma + docs ──────────────────────────────────────────
inputs/
  figma/*.png, *.json        (human-authored)
  qa/*.md                    (human-authored)
  docs/*.md                  (human-authored)
        │
        ▼
[Metadata Agent]
        │
        ▼
metadata/
  features.json              (generated)
  requirements.json          (generated)
  open-questions.md          (generated — ambiguities flagged for team review)
        │
        ▼ [Human gate: answer/defer open questions]
        │
        ▼
[Design Agent]
        │
        ▼
metadata/
  tech-design.md             (generated — API/UI/UX decisions + rationale)
  detailed-design.md         (generated — engineering implementation spec)
  qna-resolved.md            (generated — closed Q&A log)
        │
        ▼ [Human gate: review design artifacts]
        │
        ▼
[PO Agent]
        │
        ▼
backlog.carryover.json       (generated — deferred/skipped items for opt-in carry-over)
        │
        ▼

── Method B: CSV / bug export ───────────────────────────────────────
inputs/
  bugs/*.csv                 (Linear / Jira / GitHub / Coda export)
        │
        ▼
[CSV Import Agent]           ← skips Metadata + PO Agent entirely
        │
        ▼

── Method C: both (mixed cycle) ─────────────────────────────────────
Run both Method A and Method B — whichever runs second detects the
existing backlog.json and appends its items. Order does not matter.
Single global sequence per project (e.g. TB-007 follows TB-006). No per-type sequences — type is a separate field.

── All methods converge here ────────────────────────────────────────
backlog.json                 ← SSoT for requirements (IMMUTABLE after human sign-off)
  items[].status: "pending"
        │
        ▼ [QA Agent copies to backlog.agent.json on first run]
        │
backlog.agent.json           ← agent working copy (QA + Dev agents write here)
        │
        ▼
[QA Agent]
  writes apps/teams-board-web-fe-e2e/src/e2e/**/*.spec.ts  (failing tests)
  updates items[].status: "qa_done"
  updates items[].testFile
        │
        ▼
src/e2e/**/*.spec.ts         ← SSoT for software behavior (cross-release, accumulates)
  (all tests are RED)
        │
        ▼
[Dev Agent]
  implements changes in apps/teams-board-web-fe/ and libs/fe/
  updates items[].status: "done"
        │
        ▼
tests are GREEN              ← sprint complete
backlog.agent.json queue is empty
        │
        ▼
[Report Agent]  (auto-invoked by Dev Agent)
  writes releases/<path>/report.md   (this sprint)
  updates releases/REPORT.md         (cross-sprint trend)
```

---

## What Carries Forward Between Releases

Release folders (`agents/releases/`) are immutable snapshots — they store the plan, inputs, and progress for one sprint. They are never modified after completion.

The following live **outside** release folders and accumulate across every sprint:

| Asset | Location | What it is |
|-------|----------|------------|
| Regression suite | `apps/teams-board-web-fe-e2e/src/e2e/**/*.spec.ts` | Every test ever written — grows with each release, never deleted |
| Page objects | `apps/teams-board-web-fe-e2e/src/modules/**/*.page.ts` | DOM locators and actions — extended per sprint, shared across releases |
| Fixtures | `apps/teams-board-web-fe-e2e/src/modules/**/*.fixtures.ts` | Auth + page setup — extended as new features are tested |
| Frontend code | `apps/teams-board-web-fe/` and `libs/fe/` | The app itself — where Dev Agent makes changes |

Each sprint adds new `.spec.ts` files (and new page object methods) that stay forever. By the time a feature has gone through two or three sprints, its spec file contains a full regression suite for that area — built incrementally, at zero extra cost.

---

## Item Lifecycle

```
pending → qa_done → in_progress → done
                               ↘ blocked
```

| Status | Set by | Meaning |
|--------|--------|---------|
| `pending` | PO Agent | Item is ready for QA Agent |
| `qa_done` | QA Agent | Failing test written and verified |
| `in_progress` | Dev Agent | Dev Agent is implementing |
| `done` | Dev Agent | Test passes, implementation complete |
| `blocked` | Any agent | Cannot proceed — reason in `blockedReason` |
| `deferred` | Design/PO Agent | Held for a future sprint — reason in `skipReason`; also in `backlog.carryover.json` |
| `skipped` | Design/PO Agent | Explicitly out of scope this sprint — reason in `skipReason`; also in `backlog.carryover.json` |

---

## Autonomy Gates

Controlled by `backlog.json` → `autonomy`:

```json
{
  "autonomy": {
    "mode": "hitl",
    "gates": {
      "after_qa_write": true,
      "after_dev_pass": true
    }
  }
}
```

### HITL Mode (default)

Agent pauses at each enabled gate and waits for human confirmation before continuing.

Gates:
- `after_qa_write` — pause after each failing test is written (human reviews spec)
- `after_dev_pass` — pause after each test passes (human reviews implementation)

### Auto Mode (future)

All agents run sequentially without interruption. Suitable for CI pipelines and fully trusted backlogs.

---

## Release Folder Convention

```
agents/releases/<yyyy>/<mm>/<dd-release-name>/
  inputs/
    figma/          ← PNG screenshots, design token exports
    qa/             ← Markdown Q&A transcripts, user stories
    docs/           ← Markdown Coda/Confluence/Notion exports
    bugs/           ← CSV exports from Linear, Jira, GitHub Issues (optional)
  metadata/         ← GENERATED — do not edit manually
    features.json
    requirements.json
    open-questions.md       ← Metadata Agent + human answers + Design Agent drafts
    tech-design.md          ← Design Agent — API/UI/UX decisions
    detailed-design.md      ← Design Agent — engineering implementation spec
    qna-resolved.md         ← Design Agent — closed Q&A log
  backlog.json              ← GENERATED by PO Agent — IMMUTABLE after human sign-off
  backlog.carryover.json    ← GENERATED by PO Agent — deferred/skipped items
  backlog.agent.json        ← GENERATED by QA Agent at sprint start — agent working copy
```

Naming: `<dd-release-name>` where `dd` is the zero-padded day of the sprint start.

Examples:
- `releases/2026/04/07-kanban-polish/`
- `releases/2026/05/15-task-dependencies/`

---

## Reusability

The pipeline is **data-driven** — all agent skills are generic. To start a new sprint:

```bash
# Create new release folder
mkdir -p agents/releases/2026/05/15-task-dependencies/inputs/{figma,qa,docs}
# Drop new inputs, run agents — same skills work unchanged
```

No changes to skills, schemas, or agent code are needed for a new release.

---

## Extending the Pipeline

To add a new agent:

1. Create `agents/skills/<agent-name>/SKILL.md`
2. Define: trigger, input, output, behavior, edge cases
3. Wire it into this document under Agent Roles
4. Update `agents/README.md` status table

Agents communicate only through files — no shared state, no direct calls. This makes each agent independently testable and replaceable.
