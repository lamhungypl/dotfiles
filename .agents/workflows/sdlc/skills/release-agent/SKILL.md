# Release Agent Skill (Dispatcher)

**Trigger:** `/release [release-name]`

**Purpose:** Start a full release from zero. Creates the release folder, validates inputs are in place, then orchestrates the entire agent chain (Metadata → Design → PO → CSV Import → QA → Dev → Report) in the correct order. Asks for confirmation at every stage where human input is required.

---

## Step 1 — Resolve release name

If `release-name` was given as an argument, use it verbatim.

If no name was given, ask:

```
[Release Agent] What should this release be called?

Enter a short kebab-case name (e.g. "kanban-polish", "task-dependencies", "auth-reset"):
```

Wait for the user's answer before continuing.

---

## Step 2 — Resolve release folder path

Compute the folder path using the current year and month:

```
agents/releases/<yyyy>/<mm>/<release-name>/
```

**If the folder already exists:** Skip creation, go to Step 3.

**If it does not exist:** Create the full directory tree:

```
agents/releases/<yyyy>/<mm>/<release-name>/
  inputs/
    figma/
    qa/
    docs/
    bugs/
```

Report:

```
[Release Agent] Created release folder:
  agents/releases/<yyyy>/<mm>/<release-name>/

Input directories ready:
  inputs/figma/   ← PNG/JPG screenshots + design token exports
  inputs/qa/      ← Markdown Q&A transcripts, user stories
  inputs/docs/    ← Markdown Coda/Confluence/Notion exports, acceptance criteria
  inputs/bugs/    ← CSV exports from Linear, Jira, GitHub Issues (optional)
```

---

## Step 3 — Verify workspaces.json

Check that `workspaces.json` exists at the workspace root.

**If missing**, stop and report:

```
[Release Agent] ⛔ workspaces.json not found.

Create it from the template before continuing:
  cp agents/workspaces.example.json workspaces.json

Then edit it to set your local absolute paths:
  {
    "project": "TB",
    "workspace": "<absolute path to this monorepo root>",
    "e2e": "<absolute path to teams-board/apps/teams-board-web-fe-e2e>",
    "frontend": "<absolute path to teams-board/apps/teams-board-web-fe>"
  }

Once created, run /release <release-name> again.
```

**If present:** Read it silently and continue.

---

## Step 4 — Detect input method and validate inputs

Scan the `inputs/` directories to determine which release method applies:

| Condition | Method |
|-----------|--------|
| `inputs/bugs/*.csv` files exist, design inputs empty | **B** — CSV only |
| Design inputs exist (`figma/`, `qa/`, or `docs/`), no CSV | **A** — Figma + docs |
| Both design inputs and CSV files exist | **C** — Mixed |
| All inputs empty | **⛔ No inputs** |

**If no inputs found:**

```
[Release Agent] ⚠️  No inputs found in:
  inputs/figma/   (empty)
  inputs/qa/      (empty)
  inputs/docs/    (empty)
  inputs/bugs/    (empty)

Drop your input files and reply "ready" to continue.

Method A (designs + docs):   figma/, qa/, docs/
Method B (CSV tracker):      bugs/*.csv
Method C (mixed sprint):     both of the above
```

Wait for the user to reply "ready" (or any confirmation), then re-scan. Repeat if still empty.

**If inputs found**, report a summary and ask for confirmation:

```
[Release Agent] Inputs found — please confirm before running agents:

Release:  <release-name>
Folder:   agents/releases/<yyyy>/<mm>/<release-name>/
Method:   <A | B | C>
Project:  TB (from workspaces.json)

Input files detected:
  inputs/figma/   — N file(s): <list filenames>
  inputs/qa/      — N file(s): <list filenames>
  inputs/docs/    — N file(s): <list filenames>
  inputs/bugs/    — N file(s): <list filenames>

Agent chain that will run:
  <Method A: Metadata Agent → Design Agent → PO Agent → QA Agent → Dev Agent → Report Agent>
  <Method B: CSV Import Agent → QA Agent → Dev Agent → Report Agent>
  <Method C: Metadata Agent → Design Agent → PO Agent + CSV Import Agent → QA Agent → Dev Agent → Report Agent>

All agents use HITL mode (human gates enabled) by default.

Confirm? (yes / no — or list any missing files before proceeding)
```

Wait for explicit confirmation. If the user lists missing files, re-scan after they respond "ready".

---

## Step 5 — Run the agent chain

### Method A — Figma + docs

#### 5A-1: Metadata Agent

Invoke `/metadata-agent <release-name>`.

The Metadata Agent has its own human gate — it will pause and display its review summary. Wait for the user to review `metadata/features.json` and reply to continue.

#### 5A-2: Design Agent

Invoke `/design-agent <release-name>`.

The Design Agent reads `metadata/open-questions.md`, proposes draft answers, then pauses for human review. Once questions are resolved, it produces `tech-design.md`, `detailed-design.md`, and `qna-resolved.md`. Wait for the user to review and reply to continue.

#### 5A-3: PO Agent

Invoke `/po-agent <release-name>`.

The PO Agent reads `metadata/detailed-design.md` and has its own human gate — it will pause and display its backlog summary. Wait for the user to sign off on `backlog.json` before continuing.

#### 5A-4: QA Agent

Invoke `/qa-agent <release-name>`.

The QA Agent processes items one at a time (skips any `deferred` or `skipped` items). Each item may have its own HITL gate (`after_qa_write`). Let the QA Agent manage its own gates. Wait until the QA Agent reports all pending items are `qa_done`.

#### 5A-5: Dev Agent

Invoke `/dev-agent <release-name>`.

The Dev Agent processes items one at a time. Each item may have its own HITL gate (`after_dev_pass`). Let the Dev Agent manage its own gates. Wait until all items are `done`.

#### 5A-6: Report Agent

The Dev Agent auto-invokes the Report Agent on completion. If it does not, invoke `/report-agent <release-name>` manually.

---

### Method B — CSV only

#### 5B-1: CSV Import Agent

Invoke `/csv-import-agent <release-name>`.

The CSV Import Agent has its own human gate — it will display a preview of the imported backlog items and ask for confirmation. Wait for sign-off.

#### 5B-2: QA Agent → Dev Agent → Report Agent

Continue as steps 5A-4 through 5A-6 above.

---

### Method C — Mixed cycle

#### 5C-1: Metadata Agent → Design Agent → PO Agent

Run as steps 5A-1 through 5A-3 above. Wait for all human gates.

#### 5C-2: CSV Import Agent

Invoke `/csv-import-agent <release-name>`.

The CSV Import Agent detects the existing `backlog.json` from the PO Agent and appends bug items. It will report how many items were appended and show the merged total. Wait for confirmation.

#### 5C-3: QA Agent → Dev Agent → Report Agent

Continue as steps 5A-4 through 5A-6 above.

---

## Step 6 — Sprint complete

When all items in `backlog.agent.json` are `done` and the Report Agent has run:

```
[Release Agent] ✅ Sprint complete

Release:  <release-name>
Folder:   agents/releases/<yyyy>/<mm>/<release-name>/

Items completed:  N
Tests added:      N  (cumulative suite: N tests)
Blocked:          N  (see backlog.agent.json for blockedReason)

Reports written:
  releases/<path>/report.md         ← this sprint
  releases/<path>/learnings.md      ← agent learnings for next sprint
  releases/REPORT.md                ← cross-sprint trend table (updated)
  releases/LEARNINGS.md             ← accumulated agent memory (updated)

Next sprint: /release <next-release-name>
```

---

## Edge Cases

**Release folder already exists with a partial backlog:** Re-scan inputs and resume from the first incomplete agent stage. Determine resume point by reading `backlog.agent.json`:
- No `backlog.agent.json` → resume from QA Agent
- Items have `qa_done` or `in_progress` → resume from Dev Agent
- All items `done` → resume from Report Agent

**User provides a full path (e.g. `releases/2026/04/kanban-polish`):** Strip the `agents/` prefix if needed and use the provided path as the release folder.

**workspaces.json has no `project` key:** Stop and ask the user to add it. Do not generate IDs without a project key.

---

## Notes

- This agent is a coordinator. It does not implement agent logic itself — it invokes each specialist agent in order and manages the handoff between them.
- Each specialist agent manages its own output files, schemas, and HITL gates. Do not duplicate that logic here.
- Do not skip any human gate, even if the user requests speed. Gates exist to prevent downstream waste.
