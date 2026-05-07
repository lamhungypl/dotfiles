# Metadata Agent Skill

**Trigger:** `/metadata-agent [release-name]`

**Purpose:** Read raw product inputs (design screenshots, Q&A transcripts, Coda/Confluence docs) and extract structured feature metadata. Output feeds directly into the PO Agent.

---

## Pre-flight

1. Find the release folder: `agents/releases/<yyyy>/<mm>/<dd-release-name>/`
   - If `release-name` is given, search `releases/` for a matching folder
   - If ambiguous, list candidates and ask the user to confirm
2. Verify `inputs/` has at least one file across `figma/`, `qa/`, or `docs/`
   - If all are empty, stop and report: no inputs found
3. Read `agents/schemas/metadata.schema.json` — this defines the required output shape

---

## Input Reading

### `inputs/figma/`

For each `.png` or `.jpg` file:
- View the screenshot and identify the UI area (feature module)
- Note visible UI elements: buttons, headings, form fields, error states, empty states
- Record what behavior the design implies (S2 intent)

For each `.json` file (token exports):
- Extract color tokens, spacing values, typography — attach to the relevant feature

### `inputs/qa/`

For each `.md` file (Q&A transcripts, user stories):
- Extract discrete requirements stated or implied
- Identify the feature area each requirement belongs to
- Extract S1 (current behavior described or implied) and S2 (desired behavior)
- Flag any ambiguous or contradictory requirements for human review

### `inputs/docs/`

For each `.md` file (Coda/Confluence/Notion exports):
- Extract acceptance criteria and feature descriptions
- Cross-reference with figma and qa inputs to resolve ambiguity
- Note any out-of-scope items or deferred work

---

## Extraction Rules

**One requirement = one S1 → S2 pair.** If a sentence describes two changes, split it into two requirements.

**S1 must be verifiable today.** If you cannot describe what the app currently does, write `"S1: not yet implemented"` — this is valid.

**S2 must be testable.** Write S2 as observable UI behavior: "The user sees X", "The button is disabled when Y", "Navigating to Z shows W". Not: "The system processes…".

**Feature area maps to a module.** The `area` field in `features.json` must match (or be a new candidate for) a directory under `apps/teams-board-web-fe-e2e/src/modules/` in the E2E project. Use kebab-case.

---

## Output

### `metadata/open-questions.md`

Written **before** `features.json` — surface ambiguities first so they can be resolved before downstream work begins.

Raise a question for each of:
- Contradiction between two input sources (design vs docs, or doc vs Q&A)
- Missing information that prevents writing a testable `targetState`
- Design pattern or component that conflicts with an existing pattern
- Requirement that seems out of scope for this release

Format:
```markdown
## Open Questions

### [Q-001] Team: UX
**Question:** The design shows a blue primary button but the current codebase uses `--color-primary`. Which applies here?
**Affects requirements:** R-003, R-007
**Status:** PENDING

### [Q-002] Team: Backend
**Question:** Does the new flow require a new API endpoint or reuse an existing one?
**Affects requirements:** R-012
**Status:** PENDING
```

If no questions exist, write the file with `## Open Questions\n\n_No open questions._`

The Design Agent will propose draft answers to these questions. Team adds or edits answers before the Design Agent produces design artifacts.

### `metadata/features.json`

Validated against `agents/schemas/metadata.schema.json`.

Example:
```json
{
  "schema_version": "1.0",
  "release": "kanban-polish",
  "generated_at": "2026-04-07T10:00:00Z",
  "features": [
    {
      "id": "F-001",
      "name": "Kanban drag-and-drop task status",
      "area": "kanban",
      "description": "Tasks can be dragged between status columns on the Kanban board",
      "source": ["inputs/qa/kanban-requirements.md", "inputs/figma/kanban-board.png"],
      "requirements": [
        {
          "id": "R-001",
          "description": "Task can be moved from 'To Do' to 'In Progress' by dragging",
          "currentState": "Tasks cannot be dragged — status is only changeable via the edit dialog",
          "targetState": "User can drag a task card from one column to another and the task status updates immediately",
          "priority": "high",
          "figmaRef": "inputs/figma/kanban-board.png"
        }
      ]
    }
  ]
}
```

### `metadata/requirements.json`

Flat list of all requirements across all features — for quick scanning and cross-referencing.

```json
{
  "schema_version": "1.0",
  "release": "kanban-polish",
  "generated_at": "2026-04-07T10:00:00Z",
  "requirements": [
    {
      "id": "R-001",
      "featureId": "F-001",
      "feature": "kanban",
      "description": "Task can be moved by dragging",
      "currentState": "...",
      "targetState": "...",
      "priority": "high"
    }
  ]
}
```

---

## Human Review Gate

After writing all three output files, always pause and report:

```
[Metadata Agent] Done — review required before Design Agent runs

Release: kanban-polish
Features found: N
Requirements extracted: N
Open questions: N  (metadata/open-questions.md)

Sources used:
  inputs/figma/  — N files
  inputs/qa/     — N files
  inputs/docs/   — N files

Review:
  metadata/open-questions.md  ← answer or defer each question
  metadata/features.json

Then run: /design-agent kanban-polish
```

Do not run the Design Agent automatically. Metadata extraction requires human sign-off because downstream work depends on it.

---

## Edge Cases

**No Figma inputs:** Proceed with qa/ and docs/ only. Note in the report that visual specs are missing.

**Requirement is out of scope for this release:** Add to `features.json` with `priority: "low"` and a note in `description`. PO Agent will skip low-priority items unless queue is empty.

**Two input files contradict each other:** Flag both in the ambiguities section. Do not guess. Wait for human resolution before writing that requirement.

**No clear S1 exists (new feature):** Write `"currentState": "Feature does not exist"`. This is a valid S1.
