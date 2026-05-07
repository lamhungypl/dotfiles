---
name: repro-js-lib
description: Use when a Sentry/production error originates inside a vendored or minified third-party JS library (MathQuill, CodeMirror, Monaco, ProseMirror, etc.) and you need to reproduce it locally or verify a fix. For MathQuill-specific errors use repro-mathquill. For MathLive-specific errors use repro-mathlive.
---

# Reproducing Vendor JS Library Errors

## Overview

Errors in minified vendor code need an interception strategy. The approach depends on whether the library has a custom internal error handler.

This skill handles the **vendor JS library** branch of `repro`. For standard app errors use `repro` directly.

**REQUIRED:** Use `playwright-record` for HUD overlays, step labels, credential safety, and video saving.

## Approach Selection

| Library has custom errorHandler?                                   | Approach                                                |
| ------------------------------------------------------------------ | ------------------------------------------------------- |
| Yes (MathQuill `prayer failed:`, ProseMirror `Invariant violated`) | Intercept internal handler — see library-specific skill |
| No (standard TypeError/ReferenceError)                             | `window.onerror` or wrap suspect call in `try/catch`    |

**Library-specific skills:**

- MathQuill: `repro-mathquill`
- MathLive (gotit fork): `repro-mathlive`

| Library      | Handler location                                                 |
| ------------ | ---------------------------------------------------------------- |
| MathQuill    | `ctrl.options.errorHandler` — see `repro-mathquill` |
| CodeMirror 6 | `EditorView` config `dispatchTransactions` + try/catch           |
| Monaco       | `editor.onDidAttemptReadOnlyEdit` / internal diagnostics         |
| ProseMirror  | wrap `dispatchTransaction`                                       |

## Identifying the Code Path

From the Sentry stack trace:

1. Find the **last frame inside the library** — this is the crashing call
2. Find the **frame that called it** — this tells you which user action triggered it
3. Search the library's source repo for the minified function name pattern in the surrounding code snippet
4. Drive that path programmatically (don't rely on browser event timing)

## Playwright Script Scaffold (CJS)

```js
// Use .cjs extension if package.json has "type": "module"
const {
  chromium,
} = require("/Users/harley/.npm/_npx/e41f203b7505f1fb/node_modules/playwright");
const path = require("path");
const fs = require("fs");

// Script lives in .playwright-mcp/<sentry-or-jira-id>/ — __dirname is already the right folder
const VIDEO_DIR = path.join(__dirname);

async function main() {
  fs.mkdirSync(VIDEO_DIR, { recursive: true });
  const existingWebms = new Set(
    fs.readdirSync(VIDEO_DIR).filter((f) => f.endsWith(".webm")),
  );

  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({
    viewport: null,
    recordVideo: { dir: VIDEO_DIR, size: { width: 1440, height: 800 } },
  });

  // login, navigate, open target page...

  const result = await page.evaluate(async () => {
    // intercept / drive steps / return { error }
  });

  console.log(
    result.error ? "❌ BUG:" : "✅ FIXED:",
    result.error ?? "no error",
  );

  await context.close();
  await browser.close();

  await new Promise((r) => setTimeout(r, 2000));
  const newWebms = fs
    .readdirSync(VIDEO_DIR)
    .filter((f) => f.endsWith(".webm") && !existingWebms.has(f));
  if (newWebms.length) {
    fs.copyFileSync(
      path.join(VIDEO_DIR, newWebms[newWebms.length - 1]),
      path.join(VIDEO_DIR, "reproduction-<sentry-or-jira-id>-<error-slug>.webm"), // same folder as this .cjs
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

## Verify the Fix

Re-run the exact same script. Only acceptable pass:

```
{ error: null }   ← fix confirmed
```

## Gotchas

| Problem                           | Solution                                                                            |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| `require is not defined`          | Rename script to `.cjs`                                                             |
| `playwright` not found            | Global npx cache: `/Users/harley/.npm/_npx/e41f203b7505f1fb/node_modules/playwright` |
| Login redirects before form loads | `waitForURL(/login\|home/)` then check `page.url()`                                 |
| Preview opens new tab             | `context.waitForEvent('page')` before clicking                                      |
| Video records wrong tab           | Snapshot existing `.webm` files before run; pick new files after                    |
| `await` inside `page.evaluate`    | Use `async () => {}` directly, don't pass as string                                 |
