---
name: fix-a11y-bugs
description: >
  Accessibility (a11y) bug fix workflow. Filters bugs.csv by PIC name and optional Eng Status,
  lists matching accessibility issues for confirmation, then investigates and plans fixes before
  implementing. Only handles WCAG/a11y bugs — delegates all fix strategy and execution to the a11y skill.
  Triggers on: "fix my bugs", "fix bugs assigned to", "fix <name>'s bugs", "my bugs in bugs.csv".
  Only use for accessibility/WCAG bug fixes, not general bug fixing.
---

# Fix My Bugs Skill

End-to-end workflow for fixing **accessibility (a11y) bugs** assigned to a specific person in `bugs.csv`.

> **Scope**: This skill is exclusively for WCAG/accessibility bugs tracked in `bugs.csv`.
> For general bug fixing, use a different workflow.

## Quick Start

```
fix-a11y-bugs                      → fix bugs where PIC = current user (asks who)
fix-a11y-bugs Harley               → fix all bugs assigned to Harley (status ignored)
fix-a11y-bugs Harley --dry-run     → list + plan only, no code changes
```

---

## Workflow (5 Phases)

### Phase 1 — SELECT

Read `.playwright-mcp/data/bugs.csv` and filter rows where:

- `PIC` column (col 28) matches the person name (case-insensitive, partial match OK)

**Do NOT filter by `Eng Status`** — the status column is unreliable/stale in this project.
Work all bugs assigned to the PIC regardless of recorded status.
The `Got It / Eng Status` column (col 27) will be updated to `Fixed` only after the verify loop passes.

**CSV structure** (multi-row header — row 0 + row 1 combined):

| Column name        | Notes                                              |
| ------------------ | -------------------------------------------------- |
| `S.NO`             | Row number                                         |
| `Defect Title`     | Bug title                                          |
| `WCAG information` | e.g. `1.3.1 Info and Relationships`                |
| `Severity`         | Low / Medium / High / Critical                     |
| `Eng Status`       | `Todo`, `Review`, `Fixed`, `Out of Scope`          |
| `Source`           | PIC name (e.g. `Harley`)                           |
| `Feature Name`     | e.g. `Assignment Question`                         |
| `Page Title`       | e.g. `Assignment 1 \| MathGPT.AI`                  |
| `Sub Section Name` | e.g. `Radio Button`                                |
| `Recommendations`  | Auditor's suggested fix                            |
| `Suggested code`   | Auditor's code snippet (may be empty)              |
| `Affected Code`    | Existing broken code snippet                       |
| `Method`           | Screen reader testing / Keyboard / Automated (Axe) |

Parse the CSV by combining the two header rows (row 0 provides group names,
row 1 provides sub-column names). Data starts at row 2.

**If 0 bugs found** → tell the user and stop.
**If bugs found** → proceed to Phase 2.

---

### Phase 2 — LIST & CONFIRM

Present all selected bugs in a compact table:

```
Found N bug(s) assigned to <PIC>:

 # | S.NO | Sev    | WCAG    | Title
---|------|--------|---------|------
 1 |  42  | Medium | 1.4.13  | BUTTON | Missing tooltip on "Open graph layers" button
 2 |  67  | Medium | 1.3.1   | CHECKBOX | Question text is not grouped with the checkbox

Proceed with investigation and planning? (y/n)
```

**Wait for user confirmation before Phase 3.**
If `--dry-run` flag: stop after planning (Phase 3), no implementation.

---

### Phase 3 — INVESTIGATE & PLAN

For each bug, perform root cause analysis:

1. **Read Recommendations + Suggested code** from the CSV row first
2. **Search the codebase** for affected components (use Grep/Glob or Serena tools)
3. **Read relevant source** — understand current implementation
4. **Identify fix approach** using the a11y skill's `known-patterns.yml`:
   - Path: `.claude/skills/a11y/references/known-patterns.yml`
   - Match by WCAG criterion or pattern `id`
5. **Identify the spec file** to update:
   - Look for `.playwright-mcp/src/modules/<feature>/<feature>.spec.ts`
   - If none exists yet, note it needs to be created
6. **Classify fix risk** (mirrors a11y skill's fix-planner categories):
   - `safe` — aria attributes, labels, roles, tooltip wrappers (no logic change)
   - `medium` — structural HTML changes, grouping, refactor of a shared component
   - `risky` — behavior changes, keyboard flow, focus management
7. **Plan the spec test** — describe what the `[S.NO-X]` test will assert
   (DOM state, aria attributes, focus behavior, etc.)

Present the full plan per bug:

```
## Bug 1 — <Title>
- File: src/components/...
- Root cause: <1-2 sentences>
- Fix: <diff sketch or description>
- Risk: safe / medium / risky
- Spec file: .playwright-mcp/src/modules/<feature>/<feature>.spec.ts
- Test: [S.NO-X] <what the test asserts>
```

**Wait for user confirmation before Phase 4.**
If `--dry-run`: stop here.

---

### Phase 4 — IMPLEMENT

For each confirmed bug, in order:

#### 4a. Branch

Create a branch following the project convention if not already on one:

```
release/vpat-2026/<short-slug>
```

If multiple bugs touch different components and are truly independent, you may
fix them all on the same branch (one commit per bug or one combined commit).

#### 4b. Fix (delegate to a11y skill strategy)

Follow the **a11y skill's FIX strategy** exactly:

- Read `Recommendations` / `Suggested code` from the bug row first
- If none → apply WCAG rules by issue type
- **Trace root cause** (not symptom) — read the actual source file
- **Impact analysis** — check if the component is shared; find all call sites
- Apply the fix
- Run `pnpm check:ts` after each fix

**Fix risk escalation rules** (from a11y skill):

- `safe` → apply directly
- `medium` → show diff to user before applying
- `risky` → show diff + explicit user approval required

#### 4c. Spec update

Locate `.playwright-mcp/src/modules/<feature>/<feature>.spec.ts` and add or update
the test for this bug using the tag `[S.NO-X]` where X is the `S.NO` from bugs.csv.

The test must:

1. Login as student using env vars from `.playwright-mcp/.env`:
   - Base URL: `BASE_URL` (fallback: `http://localhost:3000`)
   - Email: `STUDENT_EMAIL`
   - Password: `STUDENT_PASSWORD`
2. Navigate to the relevant page
3. Assert the specific a11y fix (aria attribute, label, role, focus, etc.)
4. Be tagged with the S.NO so it can be run individually

#### 4d. Investigation report

Write `.playwright-mcp/results/reproduce-<slug>.md` with:

- Bug details (S.NO, title, WCAG criterion, severity)
- Root cause analysis
- Fix diff (before/after code)
- DOM evidence (relevant HTML before/after)
- WCAG compliance table

This file is gitignored (in `results/`) — it is evidence only, not committed.

#### 4e. Record BEFORE evidence (best-effort)

If it is possible to capture the failing state (e.g. via `git stash` of the fix),
run the spec test on unfixed code and save the video:

```bash
cd .playwright-mcp
git stash   # stash the fix temporarily
pnpm exec playwright test --video=on src/modules/<feature>/<feature>.spec.ts
# copy test-results/**/video.webm → results/reproduce-<slug>-failed.webm
git stash pop
```

If stashing is not practical, capture the DOM state in the `.md` instead
(screenshot via Playwright or DOM dump). Skip the `-failed.webm` gracefully.

#### 4f. Format & lint

```bash
pnpm exec prettier --write <changed files>
pnpm check:ts
```

#### 4g. Commit

One commit per logical fix group, following the project commit convention:

```
fix: <subject in 50 chars>

<body explaining why — WCAG criterion, root cause, approach>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

### Phase 5 — VERIFY LOOP

After committing, run the spec test with video recording:

```bash
cd .playwright-mcp && pnpm exec playwright test --video=on src/modules/<feature>/
```

**If PASS**:

1. Find the video in `test-results/<test-title>/video.webm`
2. Copy it to `results/reproduce-<slug>-success.webm`
3. Mark `Eng Status = Fixed` in `.playwright-mcp/data/bugs.csv` for the fixed row
4. Proceed to summary

**If FAIL**:

1. Diagnose the failure (read test output + video)
2. Fix the issue (spec test or source code)
3. Re-run (max 3 iterations)
4. After 3 failures: escalate to user with full diagnosis before retrying

**Final summary**:

```
## Fix My Bugs — Summary

**PIC**: Harley
**Fixed**: 2  |  **Skipped**: 0  |  **Manual**: 0
**Branch**: release/vpat-2026/fix-close-graph-tooltip-checkbox-group
**Commits**: 1

### Fixed
- [Medium] BUTTON | Missing tooltip on "Open graph layers" button
  → GraphLayers.tsx: aria-label + <Tooltip> on close button
  → Spec: .playwright-mcp/src/modules/graph/graph.spec.ts [S.NO-42]
  → Video: .playwright-mcp/results/reproduce-close-graph-layers-button-success.webm
- [Medium] CHECKBOX | Question text not grouped with checkboxes
  → InputCheck/index.tsx: role="group" for checkbox type
  → Spec: .playwright-mcp/src/modules/assignment/assignment.spec.ts [S.NO-67]
  → Video: .playwright-mcp/results/reproduce-checkbox-not-grouped-success.webm

### Remaining
- (none)
```

Update `.playwright-mcp/data/bugs.csv` for any bugs marked Fixed.

---

## Results Folder Structure

```
.playwright-mcp/
  results/                                  ← gitignored
    reproduce-<slug>.md                     ← investigation + fix approach
    reproduce-<slug>-failed.webm            ← before fix (DOM evidence, best-effort)
    reproduce-<slug>-success.webm           ← after fix (test passes)
  src/modules/<feature>/<feature>.spec.ts   ← test code (committed with fix)
  data/bugs.csv                             ← canonical bug input
```

---

## Guardrails

- MUST read `.playwright-mcp/data/bugs.csv` before starting — never work from memory
- MUST list bugs and get confirmation before Phase 4
- MUST read `known-patterns.yml` during investigation
- MUST follow a11y skill FIX strategy (Recommendations first, WCAG second)
- MUST NOT implement without user confirmation after the plan
- MUST NOT mark bugs Fixed without running the verify loop and getting a PASS
- MUST run `pnpm check:ts` after every fix
- MUST update the `.spec.ts` file — it is part of the deliverable and IS committed
- `results/` is gitignored — investigation artifacts live there but are not committed
- Source code changes and `.spec.ts` updates are committed; `results/` artifacts are not

---

## A11y Skill Reference

This skill delegates fix **strategy** to the a11y skill. Key references:

| Resource                             | Path                                                |
| ------------------------------------ | --------------------------------------------------- |
| Fix strategies & risk classification | `.claude/skills/a11y/skill.md` → FIX section        |
| Known patterns (root cause hints)    | `.claude/skills/a11y/references/known-patterns.yml` |
| Project config (auth, routes)        | `.claude/skills/a11y/references/project-config.yml` |
| Route map                            | `.claude/skills/a11y/references/route-map.md`       |
| bugs.csv (canonical)                 | `.playwright-mcp/data/bugs.csv`                     |
