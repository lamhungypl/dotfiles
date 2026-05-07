---
name: mathgpt-educator
description: Use when working with educator-side course features in MathGPT — especially the two distinct student-view modes (Preview vs View as Student), their flags, URL shapes, and Playwright capture patterns. Also covers common UI blockers like the walkthrough overlay and MathQuill input selectors.
---

# MathGPT Educator Course Features

## The Two Student-View Modes

There are **two completely different ways** an educator can view the student assignment experience. Confusing them causes navigation failures, wrong URL formats, and broken Playwright scripts.

| | "View as Student" | "Preview" |
|---|---|---|
| **Button location** | Course sidebar (all pages) | Educator assignment detail footer |
| **Navigation** | Same tab (`react-router navigate()`) | **New tab** (`window.open(..., '_blank')`) |
| **Flag set** | `isStudentViewMode = true` | `isPreviewAssignmentMode = true` |
| **URL path** | `/courses/:courseId/assignments/:studentAssignmentId` | `/courses/:courseId/assignments/:educatorAssignmentId?preview_assignment_data=<hex>` |
| **ID in URL path** | Student assignment ID | Educator assignment ID |
| **API call** | `requestResetStudentView` → returns `studentAssignmentId` | Same — encodes result in URL param |
| **Availability guard** | `moduleItem.status === PUBLISHED` | Same |
| **Playwright capture** | `page.waitForURL(...)` — same page | `context.waitForEvent('page')` — new page |

### "View as Student" — Playwright

```js
await page.locator('button:has-text("View as Student")').click();
await page.waitForURL(url => url.href.includes('/assignments/') && !url.href.includes('/assignments/21823'), {
  timeout: 20000
});
// continues on the same `page`
```

### "Preview" — Playwright (new tab)

```js
const [previewPage] = await Promise.all([
  context.waitForEvent('page', { timeout: 20000 }),
  page.locator('button:has-text("Preview")').click(),
]);
await previewPage.waitForLoadState('networkidle');
// work in `previewPage`, NOT `page`
```

> **For video recording:** the preview tab needs its own video saved via `previewPage.video().path()` — see `playwright-record` skill, Popup section.

---

## URL Encoding: `preview_assignment_data`

The `?preview_assignment_data=` param is a hex-encoded JSON array:

```
JSON.stringify([previewCourseId, educatorAssignmentId, studentAssignmentId])
→ utf8ToHex(...)
→ URLSearchParams({ preview_assignment_data: hexString })
```

Source: `src/utils/previewAssignment.ts` — `encodeAssignmentPreviewModeData`.

You **cannot** construct this URL manually without first making the `requestResetStudentView` API call to obtain `studentAssignmentId`. Always go through the Preview button click.

---

## Direct URL Navigation — What Works and What Doesn't

| URL | Logged in as | Result |
|---|---|---|
| `/courses/:id/assignments/:educatorId` | Educator | ✅ Educator assignment detail |
| `/courses/:id/assignments/:studentId` | Educator | ❌ Redirects to course home — educator routing ignores student IDs |
| `/courses/:id/assignments/:educatorId?preview_assignment_data=<hex>` | Educator | ✅ Preview mode (only if hex was generated server-side first) |
| `/courses/:id/assignments/:studentId?question=N` | Educator in `isStudentViewMode` session | ✅ Works because session state is set |

---

## MathQuill Input Selectors

| Selector | What it is | `isVisible()` |
|---|---|---|
| `.mq-editable-field` | Visible math display area — click this to focus | ✅ visible |
| `.mq-textarea textarea` | Hidden native textarea for keyboard input | ❌ CSS-hidden, always false |

**Correct interaction pattern:**

```js
// Click the visible field to focus
await page.locator('.mq-editable-field').first().click();
await page.keyboard.type('2x');
```

Do **not** use `isVisible()` on `.mq-textarea textarea` to detect MathQuill presence — use `.count() > 0` or check `.mq-editable-field` visibility instead.

---

## Common UI Blockers

### Walkthrough overlay

A full-page `div#walkthrough_overlay_container` (tooltip feature announcement) intercepts pointer events on assignment list rows. Dismiss it before clicking:

```js
// Dismiss button
const okBtn = page.locator('button:has-text("OK, got it")').first();
if (await okBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
  await okBtn.click();
  await page.waitForTimeout(500);
}
// Force-remove as fallback
await page.evaluate(() => {
  document.getElementById('walkthrough_overlay_container')?.remove();
});
```

### Login button text

The login button is not a generic `type=submit`. The text depends on role:

```js
// Educator
await page.click('button:has-text("Log in as an Instructor")');
// Student
await page.click('button:has-text("Log in as a Student")');
```

### Sidebar "View as Student" hidden when sidebar is collapsed

The button exists in the DOM but is not visible. Scroll it into view:

```js
const btn = page.locator('button:has-text("View as Student")').first();
await btn.scrollIntoViewIfNeeded();
await btn.click();
```
