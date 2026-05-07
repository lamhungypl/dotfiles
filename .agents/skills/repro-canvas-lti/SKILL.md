---
name: repro-canvas-lti
description: Use when reproducing and recording Playwright videos of errors that occur inside a Canvas LMS iframe embedding MathGPT via LTI, or any production app error that requires navigating through an external OAuth/LTI provider before the target iframe loads.
---

# Canvas LTI Iframe Error Recording

## Overview

Extends `repro-js-lib` for errors in **iframes loaded via LTI/OAuth flows** (e.g., MathGPT embedded in Canvas). The iframe is on a different origin and requires a multi-step login → LTI launch → iframe navigation before you can interact with the target app.

**REQUIRED BACKGROUND:** Read `playwright-record` for HUD helpers, credential safety, and video saving. Read `repro-js-lib` for error interception and code-path driving patterns.

## When to Use

- Sentry error occurs inside a production app embedded as a Canvas LTI iframe
- Error requires real Canvas login + LTI handshake (can't just `goto` the iframe URL directly)
- Need to inject a patch *before* React loads in the iframe (init scripts must run first)
- Error involves `history.replaceState`, navigation loops, or React Router state inside the iframe

## Core Patterns

### 1. Init Script Runs in ALL Frames

`context.addInitScript({ path })` injects into **every frame including iframes**, before any page scripts. This is the only way to patch code that runs at React initialization time.

```js
// Must be called BEFORE page.goto() — patches Canvas page AND all LTI iframes
await context.addInitScript({ path: path.join(__dirname, 'inject-rs-patch.js') });
```

`page.addScriptTag()` runs AFTER DOMContentLoaded — too late for React hooks.

### 2. Finding the Iframe After LTI Redirect

The LTI iframe URL changes during the handshake (`/lms-lti-callback` → `/courses/...`). Poll all frames until one matches:

```js
async function waitForFrame(page, substrings, timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      if (substrings.some(s => frame.url().includes(s))) return frame;
    }
    await new Promise(r => setTimeout(r, 600));
  }
  return null;
}

// After Canvas page loads:
const appFrame = await waitForFrame(page, ['app.mathgpt.ai'], 60000);
```

### 3. Navigating Within the Iframe (React Router)

To simulate `navigate('/home')` from outside React (e.g., to trigger a storm condition without actually crashing the course API):

```js
// pushState + popstate = what React Router v6 navigate() does internally
await appFrame.evaluate(() => {
  window.history.pushState({ idx: 0 }, '', '/home');
  window.dispatchEvent(new PopStateEvent('popstate', { state: window.history.state }));
});
```

### 4. Monitor via Console Events — NOT frame.evaluate() Polling

**Critical WebKit gotcha:** `frame.evaluate()` in a loop hangs after the frame has processed a `replaceState` or navigation event. Use `page.on('console')` instead — it captures ALL frames' console output without blocking.

```js
// ✅ Correct — passive, non-blocking
let rsCount = 0;
page.on('console', msg => {
  if (msg.type() === 'error' && msg.text().includes('[replaceState]')) {
    const m = msg.text().match(/#(\d+)/);
    if (m) rsCount = Math.max(rsCount, parseInt(m[1], 10));
  }
});
page.on('pageerror', err => {
  if (err.message.includes('SecurityError')) console.log('SecurityError!', err.message);
});

// Navigate to /home, then just sleep — no polling:
await appFrame.evaluate(() => { /* pushState + popstate */ });
await new Promise(r => setTimeout(r, 5000)); // observe via console events
```

```js
// ❌ Wrong — hangs indefinitely in WebKit after frame navigation
for (let i = 0; i < 80; i++) {
  const total = await appFrame.evaluate(() => window.__rsTotal ?? 0); // HANGS
  await sleep(150);
}
```

### 5. Forced Demo via Promise (No Polling)

For driving 100+ replaceState calls and capturing the SecurityError, use a **single `frame.evaluate` returning a Promise** — the Promise resolves inside the frame when the error is caught:

```js
const result = await appFrame.evaluate(() => {
  return new Promise(resolve => {
    const dest = window.location.pathname;
    window.__rsTotal = 0; // reset for clean demo
    let count = 0;
    const h = setInterval(() => {
      try {
        window.history.replaceState({}, '', dest + '?t=' + count);
        if (++count >= 110) { clearInterval(h); resolve({ error: null, count }); }
      } catch (e) {
        clearInterval(h);
        resolve({ error: e.message, count });
      }
    }, 60);
  });
});
// result.error = SecurityError message, result.count = call at which it fired
```

This avoids the polling hang entirely — one evaluate, one await, done.

### 6. Confirm LMS Session Before Triggering

Check `lms_view_mode` in sessionStorage to verify the LTI flow completed. Without this key, the storm condition doesn't exist:

```js
const lmsKey = await appFrame.evaluate(() =>
  Object.keys(sessionStorage).find(k => k.includes('lms_view_mode')) ?? null
);
// 'gotit.mathgpt.lms_view_mode' means LMS context active → bug can trigger
```

## Script Skeleton

```js
'use strict';
const { webkit } = require('/Users/harley/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const path = require('path');
const fs   = require('fs');

const VIDEO_DIR  = path.join(__dirname, '.playwright-videos');
const PATCH_PATH = path.join(__dirname, 'inject-rs-patch.js'); // see repro-js-lib

async function main() {
  fs.mkdirSync(VIDEO_DIR, { recursive: true });
  const existingWebms = new Set(fs.readdirSync(VIDEO_DIR).filter(f => f.endsWith('.webm')));

  const browser = await webkit.launch({ headless: false, slowMo: 120 });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 880 },
    recordVideo: { dir: VIDEO_DIR, size: { width: 1440, height: 880 } },
  });

  // MUST be before page.goto() — patches ALL frames including iframe
  await context.addInitScript({ path: PATCH_PATH });

  const page = await context.newPage();

  // 1. Login to Canvas
  await page.goto(process.env.CANVAS_LMS_URL || 'https://mathgpt.instructure.com');
  await page.locator('#pseudonym_session_unique_id').fill(process.env.CANVAS_EMAIL);
  await page.locator('#pseudonym_session_password').fill(process.env.CANVAS_PASSWORD);
  await page.locator('[type=submit]').first().click();
  await page.waitForURL(u => !String(u).includes('/login'));

  // 2. Navigate to module item (Canvas loads LTI iframe automatically)
  await page.goto('https://mathgpt.instructure.com/courses/447/modules/items/2777',
    { waitUntil: 'domcontentloaded' });

  // 3. Find the app iframe
  const appFrame = await waitForFrame(page, ['app.mathgpt.ai']);
  if (!appFrame) throw new Error('Iframe not found');

  // 4. Wait for course content to load
  for (let i = 0; i < 30; i++) {
    if (appFrame.url().includes('courses')) break;
    await new Promise(r => setTimeout(r, 1000));
  }

  // 5. Set up passive monitoring
  page.on('console', msg => { /* track replaceState via [RS] console logs */ });
  page.on('pageerror', err => { /* catch SecurityError */ });

  // 6. Trigger condition (e.g., navigate to /home without clearing lms_view_mode)
  await appFrame.evaluate(() => {
    window.history.pushState({}, '', '/home');
    window.dispatchEvent(new PopStateEvent('popstate', { state: window.history.state }));
  });
  await new Promise(r => setTimeout(r, 5000)); // observe

  // 7. Forced SecurityError demo
  const demo = await appFrame.evaluate(() => new Promise(resolve => {
    const dest = window.location.pathname; window.__rsTotal = 0; let n = 0;
    const h = setInterval(() => {
      try { window.history.replaceState({}, '', dest + '?n=' + n++);
        if (n >= 110) { clearInterval(h); resolve({ error: null, n }); }
      } catch (e) { clearInterval(h); resolve({ error: e.message, n }); }
    }, 60);
  }));

  // 8. Show badge, sleep, close
  await context.close();
  await browser.close();

  // 9. Save named video (snapshot existing webms before run, copy new one)
  await new Promise(r => setTimeout(r, 2000));
  const newWebms = fs.readdirSync(VIDEO_DIR)
    .filter(f => f.endsWith('.webm') && !existingWebms.has(f)).sort();
  if (newWebms.length)
    fs.copyFileSync(path.join(VIDEO_DIR, newWebms.pop()),
      path.join(VIDEO_DIR, 'reproduction-<sentry-or-jira-id>-<error-slug>.webm'));
}
main().catch(e => { console.error(e); process.exit(1); });
```

## Gotchas

| Problem | Solution |
|---|---|
| `frame.evaluate()` hangs after navigation in WebKit | Use `page.on('console')` for observation; single-Promise `evaluate()` for demos |
| `addInitScript` doesn't run in iframe | It does — use `context.addInitScript`, not `page.addInitScript` |
| `waitForURL(fn)` — `u.includes is not a function` | Use `String(u).includes(...)` — Playwright passes URL object in some versions |
| Iframe not found (stays on `lti-callback`) | Increase `waitForFrame` timeout to 60s; LTI handshake can take 20–30s |
| `lms_view_mode` not in sessionStorage | LTI flow didn't complete (check for LMS error screens in iframe) |
| `replaceState` counter not incrementing in demo | Reset `window.__rsTotal = 0` before demo since patch preserves counts across navigations |

## Real-World Example

**Bug:** Sentry MATHGPT-1FH — `SecurityError: history.replaceState() more than 100 times per 10 seconds` in Safari 26.2. Reproducible via Canvas LMS educator LTI flow.

**Script:** `reproduce-canvas-lms-7333453403.cjs` in MathGPT frontend root.

**Result:** Natural LTI launch: 4 replaceState calls. Navigate to `/home` with `lms_view_mode` active: +1 call (batching held in Playwright WebKit). Forced demo: SecurityError at call #100. Video: `.playwright-videos/canvas-lms-sentry-1fh.webm`.
