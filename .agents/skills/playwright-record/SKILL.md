---
name: playwright-record
description: Use when adding visible step labels, status HUD, or result badges to a Playwright recording — including credential safety rules for shareable videos.
---

# Recording with Steps

## Overview

Patterns for adding a visible HUD overlay to Playwright `.webm` recordings: a top status banner, a top-right step panel, and a center result badge. All helpers are **self-healing** — they create their element if absent, so they work correctly after full-page navigations without `setInterval` or `addInitScript`.

## Credential Safety (ALWAYS apply)

**Never show raw credentials in HUD text, step panels, or badge messages.** Recordings are shareable.

| What | Rule | Example |
|---|---|---|
| Email/username | Show role only | `"Logging in as educator"` not the address |
| Password | Always omit | never include |
| API keys / tokens | `"[redacted]"` | |
| Session IDs / launch IDs | Omit or truncate | show first 8 chars + `...` |

```js
// ❌ exposes credentials
await stepPanel(page, 'Step 2 — Login\nkatie@example.com\nMyP@ssword');

// ✅ role only
await stepPanel(page, 'Step 2 — Educator login');
await hud(page, 'Logging in as educator...');
```

## Self-Healing HUD Helpers

Copy these three helpers into any recording script. Each creates its element on demand — safe across `page.goto()` navigations.

```js
async function hud(page, msg) {
  try {
    await page.evaluate((t) => {
      let el = document.getElementById('__pw_hud');
      if (!el) {
        el = document.createElement('div');
        el.id = '__pw_hud';
        el.style.cssText =
          'position:fixed;top:0;left:0;right:0;' +
          'background:rgba(8,8,8,.95);color:#eee;' +
          'padding:9px 18px;font:13px/1.4 monospace;' +
          'z-index:2147483647;pointer-events:none;text-align:center;' +
          'border-bottom:2px solid #444;box-shadow:0 2px 12px rgba(0,0,0,.7);';
        document.body?.appendChild(el);
      }
      el.textContent = t;
    }, msg);
  } catch (_) {}
}

async function stepPanel(page, msg) {
  try {
    await page.evaluate((t) => {
      let el = document.getElementById('__pw_step');
      if (!el) {
        el = document.createElement('div');
        el.id = '__pw_step';
        el.style.cssText =
          'position:fixed;top:46px;right:8px;' +
          'background:rgba(8,8,8,.95);color:#3f3;' +
          'padding:10px 14px;border-radius:6px;font:11px/1.5 monospace;' +
          'z-index:2147483647;pointer-events:none;white-space:pre;max-width:330px;' +
          'border:1px solid #2a2;box-shadow:0 2px 10px rgba(0,0,0,.7);';
        document.body?.appendChild(el);
      }
      el.textContent = t;
    }, msg);
  } catch (_) {}
}

async function badge(page, msg, ok) {
  try {
    await page.evaluate(([t, o]) => {
      let el = document.getElementById('__pw_badge');
      if (!el) {
        el = document.createElement('div');
        el.id = '__pw_badge';
        el.style.cssText =
          'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);' +
          'padding:28px 44px;border-radius:14px;font:bold 14px/1.9 monospace;' +
          'z-index:2147483647;text-align:center;max-width:720px;' +
          'box-shadow:0 4px 28px rgba(0,0,0,.8);';
        document.body?.appendChild(el);
      }
      el.style.background = o ? '#082008' : '#200808';
      el.style.color      = '#fff';
      el.style.border     = '2px solid ' + (o ? '#3d3' : '#f44');
      el.textContent      = t;
    }, [msg, ok]);
  } catch (_) {}
}
```

## Mouse Tracking

Inject a visible cursor dot + click-ripple into recordings so reviewers can follow mouse movement without needing the real OS cursor.

Use **`context.addInitScript`** (not `page.addInitScript`) so it fires on every page and every popup tab automatically. The listener attaches to `document` immediately; DOM element creation is deferred until `document.body` is ready.

```js
async function installMouseTracker(context) {
  await context.addInitScript(() => {
    let cursorEl = null, ringEl = null;

    function ensureElements() {
      if (!document.body) return;
      if (!document.getElementById('__pw_cursor')) {
        cursorEl = document.createElement('div');
        cursorEl.id = '__pw_cursor';
        cursorEl.style.cssText =
          'position:fixed;width:18px;height:18px;border-radius:50%;' +
          'background:rgba(255,220,0,0.9);border:2.5px solid #fff;' +
          'pointer-events:none;z-index:2147483646;' +
          'left:-100px;top:-100px;transform:translate(-50%,-50%);' +
          'box-shadow:0 2px 8px rgba(0,0,0,0.5);';
        document.body.appendChild(cursorEl);
      } else {
        cursorEl = document.getElementById('__pw_cursor');
      }
      if (!document.getElementById('__pw_ring')) {
        ringEl = document.createElement('div');
        ringEl.id = '__pw_ring';
        ringEl.style.cssText =
          'position:fixed;width:36px;height:36px;border-radius:50%;' +
          'border:3px solid rgba(255,80,0,0.85);' +
          'pointer-events:none;z-index:2147483645;' +
          'left:-100px;top:-100px;transform:translate(-50%,-50%);opacity:0;';
        document.body.appendChild(ringEl);
      } else {
        ringEl = document.getElementById('__pw_ring');
      }
    }

    document.addEventListener('mousemove', (e) => {
      ensureElements();
      if (cursorEl) { cursorEl.style.left = e.clientX + 'px'; cursorEl.style.top = e.clientY + 'px'; }
      if (ringEl)   { ringEl.style.left   = e.clientX + 'px'; ringEl.style.top   = e.clientY + 'px'; }
    }, { passive: true });

    document.addEventListener('mousedown', (e) => {
      ensureElements();
      if (!ringEl) return;
      ringEl.style.left = e.clientX + 'px';
      ringEl.style.top  = e.clientY + 'px';
      ringEl.style.transition = 'none';
      ringEl.style.opacity    = '0.9';
      ringEl.style.transform  = 'translate(-50%,-50%) scale(0.4)';
      ringEl.getBoundingClientRect(); // force reflow
      ringEl.style.transition = 'transform 0.35s ease-out, opacity 0.35s ease-out';
      ringEl.style.transform  = 'translate(-50%,-50%) scale(2.2)';
      ringEl.style.opacity    = '0';
    });

    if (document.body) ensureElements();
    else document.addEventListener('DOMContentLoaded', ensureElements);
  });
}
```

**Call immediately after `browser.newContext()`**, before any page is opened:

```js
const context = await browser.newContext({ recordVideo: { ... } });
await installMouseTracker(context);  // ← before newPage()
const page = await context.newPage();
```

**Why `context.addInitScript` not `page.addInitScript`:** Popup tabs (`context.waitForEvent('page')`) get the script automatically — no need to re-install on the preview page.

**Why not `addInitScript` for HUD helpers:** HUD text changes per-step; it must be called imperatively. Mouse tracking is fire-and-forget — `addInitScript` is the right fit.

## Positioning

| Element | Position | Purpose |
|---|---|---|
| `hud` | `top:0` full-width banner | Current action / status |
| `stepPanel` | `top:46px;right:8px` | Step number + technical detail |
| `badge` | Center overlay | Final pass/fail result |

**Why top banner for HUD:** Canvas and other apps embed iframes that cover the lower portion of the viewport. `top:0` is always visible above any iframe content.

## Video Saving

Snapshot existing `.webm` files before the run; copy the new one to a named output after close.

**Naming convention:** All three output files go inside `.playwright-mcp/<sentry-or-jira-id>/` and share the same base name.

```
.playwright-mcp/<sentry-or-jira-id>/reproduction-<sentry-or-jira-id>-<error-slug>.webm
.playwright-mcp/<sentry-or-jira-id>/reproduce-<sentry-or-jira-id>-<error-slug>.cjs
.playwright-mcp/<sentry-or-jira-id>/reproduction-<sentry-or-jira-id>-<error-slug>.md
```

Examples:
- `.playwright-mcp/MATHGPT-1D2/reproduction-MATHGPT-1D2-codePointAt.webm`
- `.playwright-mcp/MATHGPT-R2/reproduction-MATHGPT-R2-smartfence-crash.webm`
- `.playwright-mcp/PROJ-42/reproduction-PROJ-42-canvas-lti-blank-screen.webm`

```js
const OUTPUT_NAME = 'reproduction-<sentry-or-jira-id>-<error-slug>.webm'; // ← set this per script

const existingWebms = new Set(fs.readdirSync(VIDEO_DIR).filter(f => f.endsWith('.webm')));

// ... run ...

await context.close();
await browser.close();
await new Promise(r => setTimeout(r, 2000)); // Playwright flushes video async

const newWebms = fs.readdirSync(VIDEO_DIR)
  .filter(f => f.endsWith('.webm') && !existingWebms.has(f))
  .sort();
if (newWebms.length)
  fs.copyFileSync(path.join(VIDEO_DIR, newWebms.pop()),
    path.join(VIDEO_DIR, OUTPUT_NAME));
console.log('Video saved:', path.join(VIDEO_DIR, OUTPUT_NAME));
```

## Recording a Popup / New Tab

When `window.open(..., '_blank')` opens a new tab, Playwright records **each tab as a separate `.webm`**. The file-scan approach (`readdirSync` diff) may copy the wrong tab's video. Use `page.video()` to target the exact tab you want.

```js
// 1. Open popup and capture the page reference
const [popupPage] = await Promise.all([
  context.waitForEvent('page'),
  page.locator('button:has-text("Preview")').click(),
]);
await popupPage.waitForLoadState('networkidle');

// 2. Attach HUD helpers to the popup (self-healing, re-call after navigation)
await hud(popupPage, 'Step 3 — Popup tab loaded');

// 3. Grab the video reference BEFORE closing context
//    (popupPage.video() becomes unavailable after context.close())
const popupVideo = popupPage.video();

await context.close();
await browser.close();
await new Promise(r => setTimeout(r, 2000)); // Playwright flushes video async

// 4. Save the popup tab's video specifically
if (popupVideo) {
  const src = await popupVideo.path();
  if (src && fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(VIDEO_DIR, OUTPUT_NAME));
    console.log('Video saved (popup tab):', OUTPUT_NAME);
  }
}
```

**Why `page.video()` not `readdirSync` diff:** Multiple tabs produce multiple new `.webm` files. `readdirSync` gives you the last-modified one, which may be the background tab. `page.video().path()` is always the correct file for that specific page.

## Gotchas

| Problem | Solution |
|---|---|
| Elements disappear after Canvas SPA navigation | `hud()`/`stepPanel()` already re-create — just call them again after `page.goto()` |
| HUD hidden behind iframe | Use `top:0` banner (not `bottom`) — always above iframe content |
| `addInitScript` for HUD causes race with `document.body` | Don't use `addInitScript` for HUD; use self-healing helpers after `goto()` resolves |
| Credentials visible in recording | See Credential Safety table above |
| Multi-tab recording copies wrong `.webm` | Use `page.video().path()` not `readdirSync` diff — see Popup section above |
