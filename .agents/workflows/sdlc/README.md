# AI Workflow — Usage Guide

## The Idea

This pipeline converts product intent (designs + docs + Q&A) into verified, running software through a chain of AI agents. Each layer is the SSoT for its concern:

```
inputs/ (human-authored per release)
  figma/ + qa/ + docs/
       ↓  Metadata Agent
metadata/features.json + requirements.json + open-questions.md
       ↓  [Human: answer open questions]
       ↓  Design Agent
metadata/tech-design.md + detailed-design.md + qna-resolved.md
       ↓  [Human: review designs]
       ↓  PO Agent
backlog.json        ← SSoT for requirements
backlog.carryover.json  ← deferred/skipped items
       ↓  QA Agent  ← FIRST MILESTONE
*.spec.ts           ← SSoT for software (failing tests)
       ↓  Dev Agent
code passes tests   ← sprint complete
```

## For a New Release

### One command (recommended)

```bash
/release <release-name>
```

The Release Agent handles everything: creates the folder, validates inputs, detects which method applies, and runs the full agent chain with confirmation at every human gate.

If no inputs exist yet, it will tell you exactly what to drop where and wait for you to confirm before starting.

---

### Manual (step-by-step)

### Method A — Figma + docs (design-driven)
1. Create folder: `agents/releases/<yyyy>/<mm>/<release-name>/inputs/`
2. Drop files into `inputs/figma/`, `inputs/qa/`, `inputs/docs/`
3. Run: `/metadata-agent`  → generates `metadata/features.json` + `open-questions.md`
4. Answer/defer questions in `metadata/open-questions.md`
5. Run: `/design-agent`    → generates `tech-design.md`, `detailed-design.md`, `qna-resolved.md`
6. Run: `/po-agent`        → generates `backlog.json` + `backlog.carryover.json`
7. Run: `/qa-agent`        → writes failing Playwright tests per backlog item
8. Run: `/dev-agent`       → implements code until all tests pass

### Method B — CSV / bug export (issue-tracker-driven)
1. Create folder: `agents/releases/<yyyy>/<mm>/<dd-release-name>/inputs/bugs/`
2. Drop CSV export into `inputs/bugs/` (Linear, Jira, GitHub Issues, Coda)
3. Run: `/csv-import-agent` → maps CSV rows → `backlog.json` (skips steps 3-4 above)
4. Run: `/qa-agent`         → writes failing Playwright tests per backlog item
5. Run: `/dev-agent`        → implements code until all tests pass

### Method C — Mixed cycle (features + bugs in the same sprint)
1. Set up `inputs/figma/`, `inputs/qa/`, `inputs/docs/` **and** `inputs/bugs/`
2. Run: `/metadata-agent`   → `metadata/features.json` + `open-questions.md`
3. Answer questions, then run: `/design-agent` → design artifacts
4. Run: `/po-agent`         → writes FEAT items to `backlog.json`
5. Run: `/csv-import-agent` → **appends** BUG items to existing `backlog.json`, re-sorts
5. Run: `/qa-agent`         → writes failing tests for all items
6. Run: `/dev-agent`        → implements code until all tests pass

Sprint complete when `backlog.agent.json` queue is empty and all tests are green.

### Example

```bash
# New release — one command
/release kanban-polish

# Manual folder setup (if needed)
mkdir -p agents/releases/2026/05/15-kanban-polish/inputs/{figma,qa,docs}
# Drop inputs, then run agents — same skills, new data
```

## Folder Naming Convention

`releases/<yyyy>/<mm>/<dd-release-name>`

- Nested year → month → release
- Browse `releases/2026/` to see all releases this year
- Existing sprints are never modified — each release folder is immutable after completion

## Autonomy Config (in `backlog.json`)

```json
"autonomy": {
  "mode": "hitl",
  "gates": {
    "after_qa_write": true,
    "after_dev_pass": true
  }
}
```

| Mode | Behavior |
|------|----------|
| `"hitl"` | Agent pauses for human approval at each gate (default, safe) |
| `"auto"` | Runs all phases without interruption (future) |

## Current Status

| Milestone | Agent | Status | Description |
|-----------|-------|--------|-------------|
| — | `agent.md` | ✅ | E2E architecture doc — agents read this to onboard |
| M1 | `/qa-agent` | ✅ | backlog item → failing Playwright test |
| M2 | `/metadata-agent` | ✅ | inputs → structured metadata + open-questions.md |
| M2 | `/design-agent` | ✅ | open-questions + metadata → tech-design.md, detailed-design.md, qna-resolved.md |
| M2 | `/po-agent` | ✅ | metadata + design → backlog.json + backlog.carryover.json |
| M2 | `/csv-import-agent` | ✅ | CSV bug export → backlog.json (alternative to M2) |
| M3 | `/dev-agent` | ✅ | failing test → code fix |
| M3 | `/report-agent` | ✅ | sprint complete → report.md + trend log |
| M4 | `/release` | ✅ | orchestrates all agents from one command |

## Key Files

| File | Purpose |
|------|---------|
| `agents/README.md` | This file — human guide |
| `agents/agent.md` | E2E project onboarding doc for agents |
| `agents/workflows/sdlc-loop.md` | Full pipeline architecture reference |
| `agents/skills/release-agent/SKILL.md` | Release Agent: single command to start a full sprint |
| `agents/skills/metadata-agent/SKILL.md` | Metadata Agent: inputs → features.json + open-questions.md |
| `agents/skills/design-agent/SKILL.md` | Design Agent: open-questions + metadata → tech/detailed design |
| `agents/skills/po-agent/SKILL.md` | PO Agent: features.json + design → backlog.json |
| `agents/skills/qa-agent/SKILL.md` | QA Agent: item → failing test |
| `agents/skills/csv-import-agent/SKILL.md` | CSV Import Agent: bug export → backlog.json |
| `agents/skills/dev-agent/SKILL.md` | Dev Agent: failing test → code fix |
| `agents/skills/report-agent/SKILL.md` | Report Agent: sprint complete → report.md + trend log |
| `agents/releases/REPORT.md` | Cross-sprint trend log (auto-updated each sprint) |
| `agents/schemas/backlog.schema.json` | Backlog validation schema |
| `agents/schemas/metadata.schema.json` | Metadata validation schema |
| `agents/releases/<yyyy>/<mm>/<dd-name>/backlog.json` | Release backlog (SSoT for work) |
| `workspaces.json` | Local developer paths (gitignored) — copy from `agents/workspaces.example.json` |
