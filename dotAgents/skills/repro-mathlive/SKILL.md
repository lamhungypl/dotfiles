---
name: repro-mathlive
description: Use when a Sentry/production error originates inside the gotit MathLive fork (@gotitinc/mathlive) and you need to reproduce it locally, find the source location, fix it, build, and publish the new hotfix version. For the Playwright scaffold use repro-js-lib.
---

# Reproducing MathLive Errors (gotit fork)

## Overview

Unlike MathQuill, MathLive errors are **standard TypeErrors/RangeErrors** — no custom internal handler. They surface via normal `window.onerror` / Sentry instrumentation. The challenge is mapping minified names to source, fixing in the fork, and publishing a hotfix version.

**REQUIRED:** Use `playwright-record` for HUD overlays, step labels, credential safety, and video saving.
**REQUIRED:** Use `repro-js-lib` for the Playwright scaffold.

## Fork Location

```
/Users/harley/workspaces/gotit/gotit_mathlive
```

- Package: `@gotitinc/mathlive`
- Current version pattern: `0.98.6-hfN` (hotfix series)
- Main source entry: `src/mathlive.ts`
- Build output: `dist/mathlive.min.mjs` (consumed by frontend)

## Finding Source from Minified Stack

1. Look at the **code snippet** in Sentry around the crash frame — minified code often contains readable identifiers (`smartFence`, `lastSibling`, `onKeystroke`)
2. Search the fork source for those identifiers:
   ```bash
   grep -r "smartFence\|lastSibling" src/
   ```
3. The crash location maps to the source file via those readable strings

## Error Interception (no custom handler needed)

Standard try/catch around the triggering call:

```js
let capturedError = null;
try {
  // simulate the keystroke or action that crashes
  mathfield.executeCommand('insertSmartFence'); // or direct key dispatch
} catch (e) {
  capturedError = e?.message ?? String(e);
}
return { error: capturedError };
```

Or intercept at the component event listener level:

```js
// Patch onKeystroke before driving
const orig = mathfield._mathfield?.onKeystroke?.bind(mathfield._mathfield);
if (orig) {
  mathfield._mathfield.onKeystroke = (e) => {
    try { return orig(e); }
    catch (err) { capturedError = err?.message ?? String(err); }
  };
}
```

## Fixing, Building, Publishing

After identifying and fixing the source file:

```bash
cd /Users/harley/workspaces/gotit/gotit_mathlive

# 1. Bump version in package.json: 0.98.6-hf3 → 0.98.6-hf4
#    (increment hfN by 1)

# 2. Build
bash scripts/build.sh

# 3. Publish
npm publish --access public
```

## Updating the Frontend

In `mathgpt_frontend/package.json`, update the dependency:
```json
"@gotitinc/mathlive": "0.98.6-hf4"
```
Then `pnpm install`.

## Real-World Example

**Bug:** `TypeError: Cannot read properties of undefined (reading 'type')` — Sentry MATHGPT-R2, 220 occurrences, Chrome 146

**Stack:** `keydown → onKeystroke → Rl (keystroke handler) → Il (insertSmartFence)`

**Root cause:** `insertSmartFence()` captures `atom = model.at(model.position)` before calling `ModeEditor.insert()`. After insert mutates the tree, `atom.parent` is `undefined` → `atom.siblings` returns `[]` → `atom.lastSibling` is `undefined`. Line then crashes: `atom.lastSibling.type !== 'first'`.

**Fix** (`src/editor-mathfield/keyboard-input.ts`):
```typescript
// Before:
if (atom.lastSibling.type !== 'first') {

// After (optional chaining guards stale reference):
if (atom.lastSibling?.type !== 'first') {
```

**Version:** `0.98.6-hf3` → `0.98.6-hf4`
