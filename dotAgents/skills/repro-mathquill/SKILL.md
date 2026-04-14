---
name: repro-mathquill
description: Use when a Sentry/production error originates inside MathQuill (prayer failed:, cursor/sibling pointer corruption) and you need to reproduce it locally, verify a fix, or add a Sentry safety net. For the Playwright scaffold use repro-js-lib.
---

# Reproducing MathQuill Errors

## Overview

MathQuill errors (like `prayer failed:`) are caught internally and **never reach `window.onerror`**. You must intercept MathQuill's own `errorHandler`. Once intercepted, drive the crash by calling internal controller methods directly — don't simulate real clicks.

**REQUIRED:** Use `playwright-record` for HUD overlays, step labels, credential safety, and video saving.
**REQUIRED:** Use `repro-js-lib` for the Playwright script scaffold.

## 1. Intercept the Error Handler

```js
const ctrl = MathQuill.getInterface(2)(mathField).__controller;
let capturedError = null;
const origEH = ctrl.options.errorHandler;
ctrl.options.errorHandler = (err) => {
  capturedError = err?.message ?? String(err);
};
// ... drive the code path ...
ctrl.options.errorHandler = origEH; // always restore
return { error: capturedError };
```

## 2. Drive the Code Path Programmatically

Don't fight browser event timing — call internal methods directly:

```js
// Simulates: user clicks elsewhere → focusout fires
ctrl.blurWithoutResettingCursor();
// Simulates: mousedown repositions cursor
ctrl.cursor.insAtRightEnd(ctrl.root);
```

Identify the exact methods from the Sentry stack trace frames.

## 3. Multiple Error Variants from One Bug

MathQuill `prayer failed:` errors often have many variants (`leftward is properly set up`, `following direction siblings`, etc.) that share a single root cause but fire at different code points.

- Fix the **root cause**, not individual assertions
- Test the most common variant — if the root cause is fixed, all variants disappear
- Add a single Sentry safety net while the fix deploys:

```typescript
sentryIgnoreErrors: [
  /prayer failed:/,  // covers all MathQuill assertion variants
]
```

## Reproduction Report Template

When writing the `.md` output file for a MathQuill bug, use this structure exactly:

````markdown
# <ISSUE-ID> — `<error message>`

## Summary
One paragraph TL;DR. Affected version + fix commit ref.

## Context
Issue ID, error string, source location, trigger condition.
(Generic — not Sentry-specific. Works for internal bug reports too.)

## Root Cause
Tree state / state diagram + numbered event sequence + version-specific note.

## Fix
File + location. Before/after diff. One paragraph explaining why it works.

## General Reproduction

| Step | Type |
|---|---|
| <user action description> | Human |
| <internal event or triggered consequence> | Mocked |

Types:
- **Human** — an action a user can perform directly (navigate, click, type, drag)
- **Mocked** — a step that cannot be reliably triggered by a real user action (internal event timing, API error injection, programmatic state mutation)

Every step description must be human-readable plain English. The Mocked type applies when a human *cannot* easily reproduce that step (e.g. "API throws 500", "focusout fires mid-drag"), not merely because the script happens to drive it programmatically.

## Implementation Reproduction
Detailed engineering walkthrough:
- Which internal APIs are called and why
- What state is set up before the crash path
- Which specific method calls trigger each stage
- Reference to the .cjs script function that drives the steps

## Related
Cross-references to source files.
````

---

## Real-World Example

**Bug:** `prayer failed: leftward is properly set up` — Chrome 145+

**Root cause:** Chrome 145 changed `focusout`/`mousedown` event order → `TextBlock.blur()` called twice on the same empty TextBlock → `disown()` corrupts sibling pointers on the second call.

**Fix:** Guard in `TextBlock.blur()`:
```typescript
const isStillInTree =
  this.parent &&
  (!this[L] ? this.parent.getEnd(L) === this : this[L][R] === this);
if (isStillInTree) {
  this.remove();
  if (cursor[L] === this) cursor[L] = this[L];
  else if (cursor[R] === this) cursor[R] = this[R];
}
```
