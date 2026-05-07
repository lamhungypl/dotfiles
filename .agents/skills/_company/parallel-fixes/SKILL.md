---
name: parallel-fixes
description: >
  Parallel bug fix workflow using git worktrees and background sub-agents. Creates isolated
  worktrees per issue, launches sub-agents in parallel, reviews results, pushes branches.
  Triggers on: "fix these bugs in parallel", "worktree fix", "parallel fixes",
  "fix N issues at once". Works with any bug list — a11y, general, or ad-hoc.
---

# Parallel Worktree Fixes

Fix multiple independent bugs in parallel using git worktrees + background sub-agents.

## Quick Start

```
parallel-fixes                  → prompted for base branch + issue list
parallel-fixes <base-branch>    → use given base, prompted for issues
```

---

## Workflow

### Phase 1 — Gather Inputs

Determine (ask user if not provided):

| Input | Example |
|-------|---------|
| **Base branch** | `release/vpat-2026/main`, `main`, `hotfix/v1.3.1.hf/main` |
| **Branch prefix** | derived from base (e.g. `release/vpat-2026/fix-`) |
| **Issue list** | list of bugs with: slug, summary, location hint, fix approach |
| **PR tag** | e.g. `[VPAT]`, `[CHOCO]` — derived from branch convention |

### Phase 2 — Create Worktrees

One worktree per issue, branching from the base:

```bash
git worktree add .worktrees/<slug> -b <prefix><slug> <base-branch>
```

Example for two issues:
```bash
git worktree add .worktrees/fix-aria-menubar  -b release/vpat-2026/fix-aria-menubar  release/vpat-2026/main
git worktree add .worktrees/fix-hidden-list   -b release/vpat-2026/fix-hidden-list   release/vpat-2026/main
```

### Phase 3 — Launch Sub-Agents (in parallel)

Send a **single message** with multiple `Agent` tool calls. Each agent prompt must include:

```
Working directory: /absolute/path/to/repo/.worktrees/<slug>
Branch: <prefix><slug>

Issue summary:
  - What's broken: <symptom>
  - Location: <page/section/file hint>
  - Element clue: <HTML snippet or search term>

Fix approach:
  <specific technical guidance>

Steps:
1. Search in <worktree>/src/ for the component. Use grep for the element clue or known text.
2. Read the file to understand full context.
3. Apply minimal fix.
4. Run: pnpm check:ts  (in worktree dir)
5. Run: pnpm exec prettier --write <changed-files>
6. Commit: git add <files> && git commit -m "<type>: <subject>"
7. Push: git push -u origin <prefix><slug>

Constraint: Only edit files under .worktrees/<slug>/. Keep changes minimal.
```

Set `run_in_background: true` for all agents so they run concurrently.

### Phase 4 — Review Results

When agents complete, check each:
- Did TypeScript / lint pass cleanly?
- Was `--no-verify` used? Acceptable only for pre-existing env issues (e.g. missing gitignored dirs).
- Is the fix targeted and minimal?
- Was the branch pushed?

### Phase 5 — Push (if missed) and Create PRs

Push any branches agents didn't push:
```bash
git -C .worktrees/<slug> push -u origin <prefix><slug>
```

Create PRs:
```bash
gh pr create --head <prefix><slug> --base <base-branch> \
  --title "[TAG] fix: <Subject>" --body "..."
```

---

## Searching for Components

```bash
# Find by ARIA attribute
grep -r 'role="menubar"' src/

# Find by visible text
grep -r 'Satisfaction' src/components/Authenticated/

# Find by class pattern
grep -r 'u-srOnly' src/components/

# Find by element hint from bug report
grep -r 'aria-label="Secondary menu"' src/
```

Use Serena MCP tools (`find_symbol`, `find_referencing_symbols`) for semantic searches when available.

---

## Common A11y Fix Patterns

### sr-only list announced during navigation (WCAG 1.3.1, 1.3.2)
`<ul class="u-srOnly">` in DOM reading flow gets announced by screen readers.
- Add `aria-hidden="true"` to the `<ul>`
- Add an `id` and wire `aria-describedby={id}` to the associated trigger

### ARIA role missing required children (WCAG 4.1.2)
`role="menubar"` / `role="menu"` without `role="menuitem"` children.
- If children are links: remove the parent role or change to `role="navigation"` / `role="group"`
- If menubar semantics are correct: add `role="menuitem"` to each interactive child

### Incorrect reading / focus order (WCAG 1.3.2)
DOM order doesn't match visual order.
- Move the element in JSX to match visual order
- Never use CSS `order` to reorder semantic content
- Use `aria-flowto` only as a last resort

### Missing accessible name (WCAG 4.1.2)
Icon buttons with no label.
- Add `aria-label` to the button
- Or use `<span class="u-srOnly">Label</span>` inside the button
