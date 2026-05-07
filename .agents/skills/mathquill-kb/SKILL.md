# MathQuill Input Knowledge — MathGPT

Reference for working with MathQuill math inputs in MathGPT. Covers architecture,
key files, internal state lifecycle, error patterns, and reproduction strategies.

---

## Architecture Overview

MathGPT uses a **vendored MathQuill** library with a custom equation-editor palette
built on top. Three layers work together:

| File | Role |
|------|------|
| `public/mathquill/mathquill.js` | Vendored MathQuill core |
| `public/mathquill/mqeditor.js` | Custom keyboard editor (global `MQeditor`) |
| `public/mathquill/mqedlayout.js` | Layout definitions + `myMQeditor.getLayout()` |
| `public/mathquill/mqeditor.css` | Palette styling |

### How it works end-to-end

1. A `<input type="text">` with `data-mq` attribute lives in the HTML.
2. `MQeditor.toggleMQ(el, true)` hides the input and inserts a `<span class="mathquill-math-field">` with id `mqinput-{originalId}`.
3. `MQeditor.attachEditor(span)` wires focus/blur listeners. On focus, `showEditor()` builds and appends a `<div id="mqeditor">` keyboard palette inside the nearest `[data-keyboard-container]` element.
4. On blur, a 100 ms `blurTimer` calls `hideEditor()` which removes the palette.

---

## Key Global State in `mqeditor.js`

| Variable | Set by | Cleared by |
|----------|--------|------------|
| `curMQfield` | `showEditor()` (after building palette) | `hideEditor()`, `resetEditor()` |
| `blurTimer` | `attachEditor` blur handler, `showEditor` focusout handler | `clearTimeout` in `showEditor()` |
| `keyRepeatInterval` | `handleMQbtn` when `cmdval === 'Backspace'` | `touchend`/`mouseup` handler on button |

**Public API** (returned from the IIFE):
```js
MQeditor.setConfig(cfg)    // configure layout, callbacks, toMQ/fromMQ converters
MQeditor.toggleMQ(el, state, nofocus)
MQeditor.toggleMQAll(selector, state)
MQeditor.attachEditor(mqel)
MQeditor.getLayoutstyle()
MQeditor.resetEditor()     // clears palette + sets curMQfield = null
```

---

## Layout System (`mqedlayout.js`)

`myMQeditor.getLayout(mqEl, layoutstyle)` returns a layout tree based on:
- `layoutstyle`: `'under'` (desktop floating) or `'OSK'` (mobile fixed-bottom)
- `data-mq` attribute on the original input: controls which tabs are enabled
  (e.g. `fraction`, `decimal`, `logic`, `setexp`, `chemeqn`, `interval`, `matrix`)
- `data-mq-vars`: comma-separated variable names that get extra palette buttons

Layout trees are tab-based (`layout.tabs[]`) for both styles.

---

## `curMQfield` Lifecycle — Critical for Bugs

```
focus on MQ textarea
    → showEditor()
        → clearTimeout(blurTimer)          ← blurTimer cancelled
        → builds #mqeditor palette
        → curMQfield = MQ.MathField(mqEl)  ← set here

blur from MQ textarea
    → blurTimer = setTimeout(hideEditor, 100)

focus to palette button
    → focusout on editor → blurTimer set again (100ms)
    → handleMQbtn()
        // NOTE: clearTimeout(blurTimer) was removed (now commented out)
        → curMQfield.focus()               ← CRASHES if curMQfield is null

hideEditor()
    → curMQfield = null                    ← cleared here
```

**Race window**: between a scheduled repeat-Backspace `setTimeout` (600 ms) and
`hideEditor` setting `curMQfield = null`.

---

## Known Error Pattern — `TypeError: Cannot read properties of null (reading 'focus')`

**Sentry ID**: MATHGPT-1F5
**Location**: `mqeditor.js:777` — `curMQfield.focus()`
**Mechanism**: `auto.browser.browserapierrors.setTimeout`

### Root Cause

`handleMQbtn` schedules a 600 ms repeat `setTimeout` when Backspace is held:

```js
keyRepeatInterval = setTimeout(function () {
  handleMQbtn(event, cmdtype, cmdval); // ← fires after curMQfield may be null
}, keyRepeatInterval === null ? 600 : 70);
```

If `hideEditor()` fires in between (via `blurTimer` or navigation), `curMQfield`
is set to `null` before the 600 ms timer fires, causing the crash.

### Trigger scenario

1. User holds Backspace on the palette — repeat timer is armed (600 ms)
2. User/browser triggers editor hide (blur, tab switch, navigation)
   → `hideEditor()` runs → `curMQfield = null`
3. 600 ms timer fires → `handleMQbtn` → `curMQfield.focus()` → **TypeError**

### Fix direction (analysis only — do not implement without ticket)

Add a null guard before `curMQfield.focus()`:
```js
if (!isUiCommand) {
  if (!curMQfield) return;
  curMQfield.focus();
}
```

---

## Reproduction Script Format

Reproduction scripts for MathQuill issues are **CJS node scripts** (`.cjs` extension),
not Playwright spec files. The project does not have `@playwright/test` installed and
`pnpm dlx playwright` cannot resolve the import from the project directory at runtime.

**Pattern** (matches existing `.playwright-mcp/reproduce-*.cjs` files):
```js
'use strict';
const { chromium } = require('/path/to/global/playwright');
// ... HUD helpers, login, test logic
```
Run with: `node .playwright-mcp/reproduce-ISSUE.cjs`

The global playwright binary is at:
`/Users/harley/.npm/_npx/e41f203b7505f1fb/node_modules/playwright`

---

## Intercepting MathQuill Errors in Playwright

MathQuill `prayer failed:` errors use an internal handler — not `window.onerror`.
Null-reference errors from `handleMQbtn` DO reach `window.onerror` via the
setTimeout boundary.

```js
// In page.evaluate — capture null-focus error
window.__mqError = null;
window.addEventListener('error', (e) => {
  if (e.message?.includes('focus')) window.__mqError = e.message;
});

// Drive the race:
const mqField = document.querySelector('.mathquill-math-field:not(.disabled)');
const textarea = mqField?.querySelector('[tabindex="0"]');
textarea.focus();
await new Promise(r => setTimeout(r, 300)); // editor shows

// Mousedown Backspace to arm 600ms repeat timer
const bsBtn = [...document.querySelectorAll('#mqeditor .mqed-btn')]
  .find(b => b.getAttribute('aria-label')?.toLowerCase() === 'backspace');
bsBtn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));

// Immediately clear curMQfield via public API
await new Promise(r => setTimeout(r, 50));
MQeditor.resetEditor();            // curMQfield → null

// Wait for the 600ms timer to fire
await new Promise(r => setTimeout(r, 700));
return { error: window.__mqError };
```

---

## Common `data-mq` Values

| Value | Enables |
|-------|---------|
| `fraction` / `mixednumber` / `fracordec` | Fraction-specific OSK layout |
| `decimal` | Decimal-only number pad |
| `logic` | Logic operators (∨ ∧ ⊕ ¬ ⇒ ⇔) |
| `setexp` | Set expression operators (∪ ∩ ⊖ complement) |
| `chemeqn` / `chemeqn,reaction` | Chemistry subscript/superscript, arrows |
| `interval` | Interval notation brackets |
| `matrix` | Matrix insert/edit panel |
| `inequality` | Inequality signs panel |
| `notrig` | Suppresses Trig tab |
| `nodecimal` | Hides decimal point key |
| `allowplusminus` | ± button in `=<%` tab |
| `allowdegrees` | Degree symbol in Trig tab |

---

## Useful Selectors

```css
.mathquill-math-field            /* MQ wrapper span */
.mathquill-math-field [tabindex="0"]   /* focusable textarea/span */
#mqeditor                        /* active keyboard palette */
#mqeditor .mqed-btn              /* all palette buttons */
#mqeditor .mqed-tab              /* tab strip buttons */
#mqeditor .mqed-tabpanel         /* tab content panels (visible = active) */
[data-keyboard-container]        /* palette mount point in each question */
```
