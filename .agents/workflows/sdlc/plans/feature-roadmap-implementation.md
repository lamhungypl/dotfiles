# Teams Board — 16 Feature Implementation Plan

## Context

The Teams Board app has a solid foundation (auth, tasks CRUD, teams, real-time WS, async job queue) but several features are stubbed or missing. This plan implements all 16 non-AI features from `docs/missing-features.md` to make the app a complete portfolio showcase. Features are ordered by dependency — each phase is independently shippable.

**Key finding:** Dark/Light theme toggle (feature #12) is already implemented — `ThemeSwitcher` component exists in the header. Removing from scope.

**Scope:** 15 features across 5 phases. Plan also goes into `agents/plans/` for agent execution.

---

## Phase 1: Quick Wins (no new entities, no new libs)

### 1.1 Swagger API Docs Cleanup

**Modify:**
- `apps/teams-gateway-api/src/main.ts` — title → "Teams Board API", description, version "1.0.0", remove `.addTag('cats')`
- All controllers in `libs/api/*/` — add `@ApiTags('Auth')`, `@ApiTags('Tasks')`, etc.

**Verify:** `pnpm nx serve teams-gateway-api` → open `http://localhost:3000/docs`

### 1.2 Async Export Fix

**Problem:** `libs/api/exports/src/lib/export.worker.ts` line 41 writes placeholder text instead of real files.

**Fix:**
- `libs/api/exports/src/lib/exports.module.ts` — import `TypeOrmModule.forFeature([Task])` and provide `ExportService` from `@lhypl/tasks`
- `libs/api/exports/src/lib/export.worker.ts` — inject `ExportService` + `Repository<Task>`, fetch tasks by filters from `ExportJob`, call `exportService.generate(format, tasks)`, write real buffer to disk

**Verify:** Trigger async export from FE → poll status → download file → confirm real DOCX/PDF content

### 1.3 Password Reset Flow

**Backend:**
- `libs/api/auth/src/lib/dtos/reset-password.dto.ts` — **new**, DTO: `token: string`, `newPassword: string`
- `libs/api/auth/src/lib/auth.service.ts` — add `resetPassword(token, newPassword)`: verify JWT with `FORGOT_PASSWORD_SECRET`, extract `sub`, hash + update
- `libs/api/auth/src/lib/auth.controller.ts` — add `@Post('reset-password')`

**Frontend:**
- `apps/teams-board-web-fe/app/routes.tsx` — add `route('reset-password', ...)`
- `apps/teams-board-web-fe/app/routes/auth/reset-password-page.tsx` — **new**, reads `?token=` from URL, new password form
- `libs/fe/routes-utils/` — add `resetPassword` to `pathMap`

**Verify:** Call forgot-password → copy token from server console → navigate to `/reset-password?token=...` → submit → login with new password

---

## Phase 2: Dashboard & Email

### 2.1 Dashboard Widgets

**Backend:**
- `libs/api/tasks/src/lib/tasks.controller.ts` — add `@Get('dashboard/stats')` (before `:id` route)
- `libs/api/tasks/src/lib/tasks.service.ts` — add `getDashboardStats(userId)`: counts by status, overdue, due today

**Frontend:**
- `libs/fe/tasks-data-access/` — add `getDashboardStats` query + service + types
- `apps/teams-board-web-fe/app/routes/dashboard/dashboard-page.tsx` — replace empty `<div>` with: summary cards (MUI Grid + Card), my tasks list, overdue alert

**Verify:** Login → navigate to `/` → see populated dashboard

### 2.2 Email Delivery Service

**New lib:** `libs/api/email/` (generate via `pnpm nx g @nx/nest:library email --directory=libs/api/email`)
- `email.module.ts` — exports `EmailService`, ConfigModule for SMTP env vars
- `email.service.ts` — Nodemailer transport, methods: `sendPasswordReset()`, `sendDailySummary()`, `sendOverdueAlert()`
- `templates/` — HTML strings per email type

**New dep:** `nodemailer`, `@types/nodemailer`

**Modify:**
- `apps/teams-gateway-api/src/app/app.module.ts` — import `EmailModule`
- `libs/api/auth/src/lib/auth.service.ts` — replace `console.log` with `emailService.sendPasswordReset()`
- `libs/api/scheduler/src/lib/scheduler.service.ts` — send emails in cron jobs

**Env vars:** `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`

**Verify:** Trigger forgot-password → check Mailtrap/Mailcatcher for received email

---

## Phase 3: Major Features

### 3.1 Activity/Audit Log

**New entity** in `libs/api/entities/src/lib/activity-log.entity.ts`:
- Fields: `id`, `action` (string: 'task.created', etc.), `actorId`, `entityType`, `entityId`, `diff` (jsonb), `createdAt`

**New lib:** `libs/api/activity-log/` — module, service (`log()`, `findByEntity()`, `findAll()`), controller (`GET /activity-log`)
**New lib:** `libs/fe/activity-log-data-access/` — RTK Query endpoints

**Modify:**
- `libs/api/entities/src/index.ts` — export `ActivityLog`
- `apps/teams-gateway-api/src/app/app.module.ts` — register entity + module
- `libs/api/tasks/src/lib/tasks.service.ts` — inject `ActivityLogService`, call `log()` on create/update/delete
- `libs/api/teams/src/lib/teams.service.ts` — same for team/member operations
- Dashboard page — add activity feed widget

### 3.2 Role-Based Access Control (RBAC)

**Modify entity:** `libs/api/entities/src/lib/membership.entity.ts` — add `role` column (enum: owner, admin, member, viewer, default: member)

**New in `libs/api/core/`:**
- `guards/roles.guard.ts` — reads `@Roles()` metadata, queries Membership for user's role in team
- `decorators/roles.decorator.ts` — `@Roles('admin', 'owner')` SetMetadata

**New in `libs/common/types/`:** `MemberRole` enum (shared FE/BE)

**Modify:**
- `libs/api/teams/src/lib/teams.service.ts` — set creator role to `owner`, default `member` on add
- `libs/api/teams/src/lib/teams.controller.ts` — add `PATCH :teamId/members/:userId/role`, apply `@Roles()` guards
- `libs/api/tasks/src/lib/tasks.controller.ts` — apply `@Roles()` on write endpoints
- `libs/fe/teams/` — role badges, role management dropdown for owners
- `libs/fe/teams-data-access/` — add `updateMemberRole` mutation

### 3.3 Task Comments

**New entity** in `libs/api/entities/src/lib/comment.entity.ts`:
- Fields: `id`, `body`, `authorId` (ManyToOne User), `taskId` (ManyToOne Task, CASCADE), `createdAt`, `updatedAt`

**New lib:** `libs/api/comments/` — module, service (CRUD), controller (`POST /tasks/:taskId/comments`, `GET /tasks/:taskId/comments`, `PATCH /comments/:id`, `DELETE /comments/:id`)
**New lib:** `libs/fe/comments-data-access/` — RTK Query endpoints
**New lib:** `libs/fe/comments/` — `CommentsList`, `CommentItem`, `CommentForm`

**Modify:**
- `libs/api/entities/src/lib/task.entity.ts` — add `@OneToMany(() => Comment)`
- `apps/teams-gateway-api/src/app/app.module.ts` — register entity + module
- Task detail UI (UpdateTaskDialog or new detail view) — render `<CommentsList>`
- WS: on comment create, push `comment_added` notification via existing pipeline

### 3.4 Full-Text Search

**Backend:**
- `libs/api/tasks/src/lib/tasks.controller.ts` — add `@Get('search')` (before `:id`)
- `libs/api/tasks/src/lib/tasks.service.ts` — add `search(q, page, limit)` using `to_tsvector/plainto_tsquery` in QueryBuilder

**Frontend:**
- `libs/fe/tasks-data-access/` — add `searchTasks` query
- `libs/fe/dashboard/src/lib/components/dashboard-header.tsx` — add search TextField in toolbar, debounced
- New route or reuse task list with search filter for results

### 3.5 Drag-and-Drop Kanban Board

**New dep:** `@dnd-kit/core`, `@dnd-kit/sortable`, `@dnd-kit/utilities`

**New lib:** `libs/fe/kanban/` — `KanbanBoard`, `KanbanColumn`, `KanbanCard`
- Columns from `TaskStatus` enum values
- On drag end: call existing `updateTask` mutation with optimistic update
- Card: title, assignee chips, due date badge, type icon

**Modify:**
- Task list page — add Table/Kanban view toggle
- `libs/fe/tasks-data-access/` — add optimistic update config for drag mutations

### 3.6 User Profile & Avatar

**Modify entity:** `libs/api/entities/src/lib/user.entity.ts` — add `avatarUrl` column (nullable)

**Backend:**
- `libs/api/users/src/lib/users.controller.ts` — add `POST /users/me/avatar` (FileInterceptor), `PATCH /users/me`
- `libs/api/users/src/lib/users.service.ts` — `updateAvatar()`, `updateProfile()`
- Configure static file serving for `/uploads/avatars/`

**Frontend:**
- `libs/fe/me-data-access/` — add `updateAvatar`, `updateProfile` mutations
- New `ProfileDialog` — avatar upload, name edit
- `libs/fe/dialog-registry/` — register `ProfileDialog`
- Task list + team member components — render `<Avatar src={avatarUrl} />`

---

## Phase 4: Nice to Have

### 4.1 Notification Preferences

**New entity:** `NotificationPreference` — `userId`, `type`, `inApp` (bool), `email` (bool)

**Backend:** endpoints in `libs/api/notifications/` — `GET/PUT /notifications/preferences`
**Modify:** `notification.worker.ts` — check preferences before creating notification / sending email

**Frontend:** settings dialog with toggles per notification type

### 4.2 Task Dependencies & Subtasks

**Modify entity:** `libs/api/entities/src/lib/task.entity.ts` — add `parentTaskId` (self-ref ManyToOne), `subtasks` (OneToMany)
**New entity:** `TaskDependency` junction — `dependentTaskId`, `prerequisiteTaskId`

**Backend:** subtask CRUD (`POST /tasks/:id/subtasks`), dependency CRUD, circular dependency validation
**Frontend:** subtask list + dependency links in task detail

### 4.3 Keyboard Shortcuts

**New:** `libs/fe/hooks/src/lib/use-hotkeys.ts` — keydown listener hook
**New:** `KeyboardShortcutsDialog` — help modal

**Shortcuts:** `?` help, `c` create task, `Cmd+K` focus search, `j/k` list navigation
**Register** in `dialog-registry`, wire in `dashboard-layout.tsx`

---

## Phase 5: Stretch Goals

### 5.1 Sprint/Milestone Grouping

**New entity:** `Sprint` — `name`, `startDate`, `endDate`, `teamId`
**Modify:** Task entity — add `sprintId` (nullable ManyToOne)

**New libs:** `libs/api/sprints/`, `libs/fe/sprints/`, `libs/fe/sprints-data-access/`
**Features:** Sprint CRUD, assign tasks, sprint board (filtered kanban), burndown chart

### 5.2 CSV Import

**Backend:** `POST /tasks/import/csv` with FileInterceptor, parse + validate + bulk insert
**Frontend:** upload dialog with preview table, validation errors, confirm button
**New dep:** `csv-parse`

---

## Summary

| Phase | Features | New Entities | New Libs |
|-------|---------|-------------|----------|
| 1 | Swagger, Export Fix, Password Reset | 0 | 0 |
| 2 | Dashboard, Email | 0 | 1 (api/email) |
| 3 | Activity Log, RBAC, Comments, Search, Kanban, Profile | 2 (ActivityLog, Comment) | 5 (api + fe) |
| 4 | Notif Prefs, Task Deps, Keyboard Shortcuts | 2 (NotifPref, TaskDep) | 0 |
| 5 | Sprints, CSV Import | 1 (Sprint) | 3 (api + fe) |

## Verification Strategy

After each phase:
1. `pnpm nx run-many -t lint typecheck` — ensure no type errors
2. `pnpm nx serve teams-gateway-api` + `pnpm nx dev teams-board-web-fe` — manual smoke test
3. `pnpm nx e2e teams-board-web-fe-e2e` — existing E2E tests still pass
4. Phase-specific checks listed under each feature above
