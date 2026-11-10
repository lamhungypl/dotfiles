# Self-Healing E2E Test System

## Context

Running e2e tests across a multi-service stack (FE, API, WS) is slow and painful when failures require manually diagnosing which service broke. This system automates the fix loop: run tests → classify failures → dispatch specialized Claude agents per service → re-run tests. Each agent is a standalone, resumable Claude CLI process that can also be launched independently for ad-hoc fixing.

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  e2e-heal CLI (bash script)                     │
│                                                 │
│  e2e-heal start    → infra + services           │
│  e2e-heal test     → run playwright             │
│  e2e-heal fix-api  → launch API fixer agent     │
│  e2e-heal fix-fe   → launch FE fixer agent      │
│  e2e-heal fix-ws   → launch WS fixer agent      │
│  e2e-heal fix-test → launch test fixer agent    │
│  e2e-heal run      → automated loop             │
│  e2e-heal stop     → teardown                   │
│  e2e-heal status   → show running services       │
└─────────────────────────────────────────────────┘
```

## Components

### 1. `docker-compose.e2e.yml` — Infrastructure only

Minimal compose file for e2e testing:
- **PostgreSQL 16** with health check (port 5432)
- **Redis 7** with health check (port 6379)
- **Seeder** service (runs once after db is healthy)

No app services — those run natively on host for hot reload + direct file access by agents.

**File:** `docker-compose.e2e.yml` (new, at repo root)

### 2. `tools/e2e-heal` — CLI Entry Point

A bash script providing subcommands:

#### `e2e-heal start`
1. `docker-compose -f docker-compose.e2e.yml up -d`
2. Wait for db + redis health checks
3. Start services in background (via `nx`):
   - `pnpm exec nx run teams-gateway-api:start:dev` (port 3000)
   - `pnpm exec nx run teams-gateway-ws:serve` (port 3001)
   - `pnpm exec nx run @lhypl/teams-board-web-fe:dev` (port 4200)
4. Poll health endpoints until ready (`/api/health`, `localhost:4200`)
5. Write PIDs to `.e2e-heal.pid` for cleanup

#### `e2e-heal test`
- Run: `pnpm exec nx run teams-board-web-fe-e2e:e2e -- --reporter=json --reporter=list`
- Save JSON results to `.e2e-heal-results.json`
- Print summary: passed / failed / skipped

#### `e2e-heal fix-api [error-context]`
Launch a Claude CLI agent specialized for the API service:
```bash
claude -p \
  --name "e2e-fix-api-$(date +%s)" \
  --system-prompt "$(cat tools/e2e-heal-prompts/api.md)" \
  --allowed-tools "Read Edit Grep Glob Bash" \
  --output-format stream-json \
  "$error_context"
```
- Resumable via `claude --resume "e2e-fix-api"`
- System prompt contains: NestJS patterns, relevant file paths (`apps/teams-gateway-api/`, `libs/api/`), TypeORM entity locations, common error patterns
- When called with error context: agent reads the error, finds the root cause, fixes it
- When called without: agent reads `.e2e-heal-results.json` for API-related failures

#### `e2e-heal fix-fe [error-context]`
Same pattern, specialized for FE:
- System prompt: React/RTK Query patterns, `apps/teams-board-web-fe/`, `libs/fe/`, MUI/Tailwind context
- Knows about component structure, routing, data binding

#### `e2e-heal fix-ws [error-context]`
Same pattern, specialized for WS:
- System prompt: Socket.io, Redis pub/sub, `apps/teams-gateway-ws/`, `libs/api/ws-gateway/`

#### `e2e-heal fix-test [error-context]`
Launch a Claude CLI agent specialized for fixing **the test cases themselves**:
```bash
claude -p \
  --name "e2e-fix-test-$(date +%s)" \
  --system-prompt "$(cat tools/e2e-heal-prompts/test.md)" \
  --allowed-tools "Read Edit Grep Glob Bash" \
  --output-format stream-json \
  "$error_context"
```
- System prompt: Playwright test patterns, page objects, fixtures, selectors
- Key directories: `apps/teams-board-web-fe-e2e/src/`
- Knows about: test structure (`e2e/`, `setups/`, `modules/`), baseTest.ts fixture composition, page object pattern
- Common fixes: wrong selectors, outdated assertions, stale test data expectations, missing waits, incorrect page object methods, flaky timing issues

**When to dispatch this agent vs app agents:**
The test agent is dispatched when the failure is likely caused by the test being wrong/outdated rather than the app being broken. This is determined by the classification logic (see below).

#### `e2e-heal run` — The Automated Loop
```
loop (max 5 iterations):
  1. Run e2e tests → parse JSON results
  2. If all pass → print success, exit
  3. Classify failures by service (see classification logic below)
  4. For each implicated service:
     - Check retry count for this service (max 3 per service)
     - If under limit: launch `e2e-heal fix-<service>` with error context
     - If over limit AND not yet tried fix-test: escalate to fix-test
       (the test itself may be wrong, not the app)
     - If both app-fix and test-fix exhausted: mark as skipped
  5. Wait for all agents to complete
  6. If all remaining failures are skipped → print report, exit
  7. Continue loop
```

#### `e2e-heal stop`
- Kill service PIDs from `.e2e-heal.pid`
- `docker-compose -f docker-compose.e2e.yml down`
- Clean up temp files

#### `e2e-heal status`
- Show which services are running (check PIDs + ports)
- Show infra status (docker-compose ps)

### 3. Agent System Prompts — `tools/e2e-heal-prompts/`

Four markdown files providing deep service context:

#### `tools/e2e-heal-prompts/api.md`
- Role: NestJS API specialist for teams-board
- Key directories: `apps/teams-gateway-api/src/`, `libs/api/*/src/`
- Entity files: `libs/api/entities/src/lib/`
- Module pattern: NestJS modules in `libs/api/<feature>/`
- Common fixes: controller logic, service methods, TypeORM queries, DTO validation, auth guards
- Instructions: read the error, find the relevant file, fix it, verify with a quick check

#### `tools/e2e-heal-prompts/fe.md`
- Role: React FE specialist for teams-board
- Key directories: `apps/teams-board-web-fe/app/`, `libs/fe/*/src/`
- Stack: React 19, React Router 7, Redux Toolkit, RTK Query, MUI v7, Tailwind v4
- State pattern: RTK Query endpoints in `*-data-access` libs, store in `libs/fe/store/`
- Common fixes: component rendering, routing, form validation, API data binding, selectors

#### `tools/e2e-heal-prompts/ws.md`
- Role: WebSocket specialist for teams-board
- Key directories: `apps/teams-gateway-ws/src/`, `libs/api/ws-gateway/src/`, `libs/api/redis/src/`
- Stack: NestJS, Socket.io, Redis pub/sub, ioredis
- Common fixes: event handlers, pub/sub relay, JWT auth in WS context, Redis channel patterns

#### `tools/e2e-heal-prompts/test.md`
- Role: Playwright E2E test specialist for teams-board
- Key directories: `apps/teams-board-web-fe-e2e/src/`
- Test structure: `e2e/` (specs), `setups/` (auth setup), `modules/` (page objects + fixtures)
- Base test: `src/baseTest.ts` (fixture composition from all modules)
- Stack: Playwright 1.50, custom page object pattern, modular fixtures
- Common fixes: wrong/outdated selectors (element IDs, test-ids, roles), stale assertions (text changed, element moved), missing `await`/`waitFor`, incorrect page object methods, flaky timing (need `toBeVisible()` before interaction), test data expectations out of sync with seed data
- Key principle: **The app behavior is the source of truth** — if the app works correctly but the test expects something different, fix the test

### 4. Failure Classification Logic

Built into the `e2e-heal run` orchestrator. Reads Playwright JSON output + service logs:

| Signal in test output | Service | Reasoning |
|---|---|---|
| HTTP status 4xx/5xx, "api" in error URL, server error in logs | API | App-side: API returned an error |
| "socket", "ws", "disconnect", "real-time" in error | WS | App-side: WebSocket connection issue |
| Element not found, timeout waiting for selector (but API returns correct data) | FE | App-side: component rendering issue |
| Assertion mismatch (expected text ≠ actual text, but app looks correct) | TEST | Test-side: assertion is outdated |
| Selector not found (but element exists with different selector) | TEST | Test-side: selector is stale |
| Multiple signals | Dispatch agents for each implicated service | |

**Classification priority order:**
1. First, check service logs — if a service is crashing/erroring, it's an app-side issue
2. If all services are healthy, it's likely a test-side issue (wrong selector, outdated assertion)
3. If an app-fix agent fails after max retries, escalate to fix-test (maybe the test is wrong, not the app)

This two-pass approach prevents the system from endlessly trying to change app code to match a broken test.

### 5. File Structure (new files)

```
docker-compose.e2e.yml                    # Infra-only compose
tools/
  e2e-heal                                # Main CLI script (bash, executable)
  e2e-heal-prompts/
    api.md                                # API agent system prompt
    fe.md                                 # FE agent system prompt
    ws.md                                 # WS agent system prompt
    test.md                               # Playwright test fixer system prompt
    classify.sh                           # Failure classification helper
```

## Implementation Steps

### Step 1: Create `docker-compose.e2e.yml`
- Extract db + redis + seeder from existing `docker-compose.yml`
- Remove all app services
- Ensure seeder uses same seed data as existing setup

### Step 2: Create agent system prompts
- Write `tools/e2e-heal-prompts/api.md`, `fe.md`, `ws.md`, `test.md`
- Include service-specific file paths, patterns, and fixing instructions
- Reference actual code patterns found in the codebase

### Step 3: Create `tools/e2e-heal` CLI script
- Implement subcommands: `start`, `stop`, `status`, `test`
- Implement `fix-api`, `fix-fe`, `fix-ws`, `fix-test` — each spawns a named Claude CLI process
- Implement `run` — the automated test→classify→fix loop
- Make executable (`chmod +x`)

### Step 4: Create classification helper
- `tools/e2e-heal-prompts/classify.sh` — parses Playwright JSON output
- Groups failures by probable service
- Outputs structured list for the orchestrator

## Verification

1. **Manual agent test:**
   - `./tools/e2e-heal start` — verify infra + services come up
   - `./tools/e2e-heal fix-fe "Button 'Submit' not found on login page"` — verify agent launches, is named, can be resumed
   - `claude --resume "e2e-fix-fe"` — verify session is resumable

2. **Automated loop test:**
   - `./tools/e2e-heal run` — verify full loop executes
   - Introduce a deliberate bug (e.g., typo in a component) and verify the loop detects and fixes it

3. **Cleanup test:**
   - `./tools/e2e-heal stop` — verify all services and infra are torn down
