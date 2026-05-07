---
name: mathgpt-auth
description: Use when you need to log into MathGPT locally (localhost:3003) as educator or student, or navigate to an assignment in either view. Covers credentials, role-specific login URLs, and reaching assignment preview via the educator course flow.
---

# MathGPT Local Authentication & Assignment Flow

## Environment

| Setting | Value |
|---------|-------|
| Base URL | `http://localhost:3003` |
| Dev server command | `pnpm start` (port 3003) |

## Credentials

| Role | Login URL | Email | Password |
|------|-----------|-------|----------|
| Educator | `http://localhost:3003/login?role=educator` | env `MATHGPT_EDUCATOR_EMAIL` | env `MATHGPT_EDUCATOR_PASSWORD` |
| Student | `http://localhost:3003/login` | env `MATHGPT_STUDENT_EMAIL` | env `MATHGPT_STUDENT_PASSWORD` |

## Login Rule: Always Prefer Educator

**Always log in as educator first.** Direct student login should only be used for bugs
that are strictly in non-assignment student flows (e.g. student dashboard, profile pages).

For **any bug in a student assignment view**, use the educator login + "Preview" button path.
Never use direct student login to reach an assignment — enrolled course data is often missing
for the test student account.

## Educator Login Flow

```js
await page.goto(`${BASE}/login?role=educator`);
// Wait in case already authenticated (SPA redirects immediately)
await page.waitForTimeout(1500);
if (!page.url().includes('/login')) return; // already logged in
await page.fill('input[placeholder*="email"], [type=email]', process.env.MATHGPT_EDUCATOR_EMAIL);
await page.fill('input[placeholder*="password"], [type=password]', process.env.MATHGPT_EDUCATOR_PASSWORD);
await page.click('button:has-text("Log in as an Instructor")');
await page.waitForURL(url => !url.toString().includes('/login'), { timeout: 15000 });
```

## Student Assignment View — Via Educator "Preview" Button

The "Preview" button is in the **footer of the educator assignment detail page**.
It opens a **new tab** with the student-facing assignment view.

```js
// 1. Log in as educator (see above)
// 2. Navigate to course assignments list
await page.goto(`${BASE}/courses`);
// ... click course → click assignment row ...

// 3. Dismiss walkthrough overlay if present
const okBtn = page.locator('button:has-text("OK, got it")').first();
if (await okBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
  await okBtn.click();
  await page.waitForTimeout(500);
}
await page.evaluate(() => {
  document.getElementById('walkthrough_overlay_container')?.remove();
});

// 4. Click Preview — opens student view in a new tab
const [previewPage] = await Promise.all([
  context.waitForEvent('page', { timeout: 20000 }),
  page.locator('button:has-text("Preview")').click(),
]);
await previewPage.waitForLoadState('networkidle');

// 5. Work in previewPage (NOT page)
// HUD, crash tests, screenshots all go on previewPage
```

> **Video recording:** save `previewPage.video().path()` — NOT the `readdirSync` diff approach,
> which may pick up the wrong tab. See `playwright-record` skill → Popup section.

## Decision Tree

```
Bug to reproduce
  └─ Educator-side feature? → log in as educator, work in page
  └─ Student assignment view?
       └─ Always → educator login + "Preview" button → previewPage
  └─ Student non-assignment page (dashboard, profile)?
       └─ Only then → direct student login
```

## Playwright Script Bootstrap (CJS)

```js
// reproduce-<sentry-or-jira-id>-<error-slug>.cjs
// All three output files share the same base name:
//   reproduce-<id>-<slug>.cjs        ← this script
//   reproduction-<id>-<slug>.md      ← investigation report
//   reproduction-<id>-<slug>.webm    ← recorded video
const { chromium } = require('/Users/harley/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const path = require('path');
const fs = require('fs');

const BASE = 'http://localhost:3003';
const VIDEO_DIR = path.join(__dirname); // Script lives in .playwright-mcp/<sentry-or-jira-id>/ — __dirname is already the right folder
const OUTPUT_NAME = 'reproduction-<sentry-or-jira-id>-<error-slug>.webm';

async function loginAsEducator(page) {
  await page.goto(`${BASE}/login?role=educator`);
  await page.waitForTimeout(1500);
  if (!page.url().includes('/login')) return;
  await page.fill('input[placeholder*="email"], [type=email]', process.env.MATHGPT_EDUCATOR_EMAIL);
  await page.fill('input[placeholder*="password"], [type=password]', process.env.MATHGPT_EDUCATOR_PASSWORD);
  await page.click('button:has-text("Log in as an Instructor")');
  await page.waitForURL(url => !url.toString().includes('/login'), { timeout: 15000 });
}

async function dismissWalkthrough(page) {
  const okBtn = page.locator('button:has-text("OK, got it")').first();
  if (await okBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
    await okBtn.click();
    await page.waitForTimeout(500);
  }
  await page.evaluate(() => {
    document.getElementById('walkthrough_overlay_container')?.remove();
  });
}

async function openPreviewTab(context, page) {
  const [previewPage] = await Promise.all([
    context.waitForEvent('page', { timeout: 20000 }),
    page.locator('button:has-text("Preview")').click(),
  ]);
  await previewPage.waitForLoadState('networkidle');
  return previewPage;
}

async function main() {
  // VIDEO_DIR is __dirname — the .playwright-mcp/<issue-id>/ folder the script lives in

  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 800 },
    recordVideo: { dir: VIDEO_DIR, size: { width: 1440, height: 800 } },
  });
  // installMouseTracker(context) here if using playwright-record
  const page = await context.newPage();

  await loginAsEducator(page);

  // Navigate to course → assignment detail
  // await page.goto(`${BASE}/courses/<courseId>/assignments/<assignmentId>`);
  await dismissWalkthrough(page);

  // Open student preview tab
  const previewPage = await openPreviewTab(context, page);
  const previewVideo = previewPage.video(); // capture BEFORE context.close()

  // --- reproduce steps in previewPage here ---

  await context.close();
  await browser.close();

  await new Promise(r => setTimeout(r, 2000));
  if (previewVideo) {
    const src = await previewVideo.path();
    if (src && fs.existsSync(src)) {
      fs.copyFileSync(src, path.join(VIDEO_DIR, OUTPUT_NAME));
      console.log('Video saved (preview tab):', OUTPUT_NAME);
    }
  }
}

main().catch(e => { console.error(e); process.exit(1); });
```

## Gotchas

| Problem | Fix |
|---------|-----|
| Login button selector | `button:has-text("Log in as an Instructor")` or `button:has-text("Log in as a Student")` — NOT `type=submit` |
| Already authenticated | `waitForTimeout(1500)` then check `page.url().includes('/login')` before filling |
| Walkthrough overlay blocks assignment clicks | Call `dismissWalkthrough(page)` before any row clicks |
| Preview opens new tab | `context.waitForEvent('page')` before clicking Preview |
| Multi-tab recording saves wrong video | Use `previewPage.video().path()` — not `readdirSync` diff |
| `require is not defined` | Rename script to `.cjs` |
| `playwright` not found | Global npx cache: `/Users/harley/.npm/_npx/e41f203b7505f1fb/node_modules/playwright` |
