# CSV Import Agent Skill

**Trigger:** `/csv-import-agent [release-name]`

**Purpose:** Convert a bug/issue CSV export (Linear, Jira, Coda, GitHub Issues) directly into `backlog.json`, bypassing the Metadata Agent. Use this when requirements already exist as a structured bug/issue list rather than as designs + docs.

This agent is a drop-in replacement for `/metadata-agent` + `/po-agent` when the input is a CSV.

---

## Pre-flight

1. Read `agents/releases/LEARNINGS.md` if it exists — use blocker patterns to pre-flag items likely to block (e.g. known backend-dependent features)
2. Find the release folder: `agents/releases/<yyyy>/<mm>/<dd-release-name>/`
3. Look for CSV files in `inputs/bugs/`
   - If none found: stop and report — drop the CSV export into `inputs/bugs/` first
   - If multiple: list them and ask the user which to import
4. Check if `backlog.json` already exists in the release folder:
   - If it has items with `status !== "pending"`: warn before overwriting — a sprint may be in progress

---

## Step 1 — Detect the source tool

Sniff the CSV headers to identify the export tool:

| Tool | Distinctive headers |
|------|---------------------|
| **Linear** | `ID`, `Title`, `Description`, `Priority`, `Label` |
| **Jira** | `Issue key`, `Summary`, `Issue Type`, `Priority`, `Description` |
| **GitHub Issues** | `number`, `title`, `body`, `labels`, `milestone` |
| **Coda** | varies — fall back to manual mapping |

If headers are unrecognised: look for `column-map.json` in `inputs/bugs/` (see below).
If no `column-map.json` either: output a template and ask the user to fill it in.

---

## Step 2 — Map columns to backlog fields

### Standard mappings by tool

**Linear:**
| Backlog field | CSV column |
|--------------|------------|
| `title` | `Title` (truncate to 80 chars) |
| `feature` | `Label` (first label, kebab-case) |
| `priority` | `Priority` → map: Urgent→critical, High→high, Medium→medium, Low→low |
| `type` | `Label` → contains "bug"→bug, "feat"/"feature"→feature, "enhancement"→enhancement |
| raw description | `Description` |

**Jira:**
| Backlog field | CSV column |
|--------------|------------|
| `title` | `Summary` |
| `feature` | `Component/s` or `Epic Name` |
| `priority` | `Priority` → map: Blocker/Critical→critical, Major/High→high, Minor/Medium→medium, Trivial/Low→low |
| `type` | `Issue Type` → Bug→bug, Story/Task→feature, Enhancement→enhancement |
| raw description | `Description` |

**GitHub Issues:**
| Backlog field | CSV column |
|--------------|------------|
| `title` | `title` |
| `feature` | first label (kebab-case) |
| `priority` | label containing "priority:" |
| `type` | label containing "bug"→bug, "enhancement"→enhancement, "feature"→feature |
| raw description | `body` |

### Custom mapping (`column-map.json`)

If the tool is unrecognised, create `inputs/bugs/column-map.json` from this template:

```json
{
  "title": "column name for title",
  "description": "column name for full description",
  "feature": "column name for area/component/label",
  "priority": "column name for priority",
  "type": "column name for issue type",
  "priority_map": {
    "your-tool-value": "critical|high|medium|low"
  },
  "type_map": {
    "your-tool-value": "bug|feature|enhancement"
  }
}
```

---

## Step 3 — Extract `currentState` and `targetState`

This is the critical step. The description field contains both S1 and S2 mixed together. Extract them as follows:

### Pattern matching (in order of preference)

1. **Explicit sections** — look for these headers in the description:
   - S1: `Current behavior:`, `Actual behavior:`, `Steps to reproduce:`, `What happens:`
   - S2: `Expected behavior:`, `Acceptance criteria:`, `What should happen:`, `Definition of done:`

2. **Bug title inference** — if no explicit sections, derive from the title:
   - Title: `"Create task dialog does not close after submit"`
   - S1: `"Create task dialog remains open after the form is submitted"`
   - S2: `"Create task dialog closes automatically after successful form submission"`

3. **Description as S1, title-derived as S2** — if the description only describes the broken state:
   - S1: full description (trimmed)
   - S2: inferred from title (negate the broken state)

4. **Flag for review** — if S2 cannot be confidently inferred:
   - Set `status: "blocked"`, `blockedReason: "targetState unclear — needs product clarification"`
   - Include the raw description in `notes` for human review

---

## Step 4 — Assign IDs

IDs follow the same format as the PO Agent: `{PROJECT}-{NNN}` — a single global sequence.

Read the `project` key from `workspaces.json` at the workspace root (e.g. `"project": "TB"`).

When appending to an existing backlog: find the highest `{PROJECT}-NNN` number already used and continue the sequence from there. IDs never reset per type — `TB-007` follows `TB-006` regardless of type.

If the source CSV has its own IDs (e.g. `LIN-123`): preserve them in the `sourceId` field. Assign a new pipeline ID as the primary `id`.

---

## Step 5 — Write `backlog.json`

### If `backlog.json` does not exist — create fresh

Output follows the same schema as PO Agent output (`agents/schemas/backlog.schema.json`).

### If `backlog.json` already exists (mixed cycle — features + bugs)

The PO Agent already ran and wrote feature items. **Append** the imported items — do not overwrite.

1. Read existing `backlog.json`
2. Find the highest sequence number already used (e.g. `TB-003` → next is `TB-004`)
3. Assign new IDs continuing from those sequences
4. Append imported items to `items[]`
5. Re-sort the full combined list: `critical` → `high` → `medium` → `low`, then by `feature`

### Both cases — always set `autonomy` if missing

```json
"autonomy": {
  "mode": "hitl",
  "gates": {
    "after_qa_write": true,
    "after_dev_pass": true
  }
}
```

---

## Step 6 — Human review gate

Always pause after writing `backlog.json`:

```
[CSV Import Agent] Done — review required before QA Agent runs

Source: inputs/bugs/<filename>.csv
Tool detected: Linear | Jira | GitHub | custom

Items imported: N
  bug:         N
  feature:     N
  enhancement: N
  blocked (targetState unclear): N

Items needing review (check notes.sourceId → targetState):
  TB-003  "Create task dialog doesn't close after submit"    ← targetState inferred
  TB-007  "Table row flickering on sort"                    ← targetState unclear, status: blocked

Review: agents/releases/<yyyy>/<mm>/<dd>/backlog.json
Then run: /qa-agent <release-name>
```

Do not run the QA Agent automatically. Human sign-off on the backlog is required.

---

## Edge Cases

**Row has no description, only a title:**
Use the title as both the basis for S1 and S2 inference. Note in `notes`: `"No description in source — S1/S2 inferred from title only"`.

**Multiple CSVs in `inputs/bugs/`:**
Import all of them, deduplicate by title similarity (>80% match = same issue). Note merged source IDs.

**CSV contains closed/resolved issues:**
Skip rows where status column is `Done`, `Resolved`, `Closed`, `Won't Fix`. Report skipped count in the summary.

**Priority column missing:**
Default to `medium`. Note: `"Priority not set in source"`.

**Feature area from CSV doesn't match any existing E2E module:**
Use the label/component value as-is (kebab-case). QA Agent will create the module if needed.
