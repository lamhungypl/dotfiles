---
name: rtk-query-data-access
description: Use when creating a new frontend data-access lib or adding RTK Query endpoints. Documents the injectEndpoints pattern, service/query/types file split, and tag invalidation conventions.
---

# RTK Query Data-Access Pattern

## Overview

All frontend API calls use RTK Query via the `injectEndpoints` pattern on a shared `queryApi` base. Each feature has a `*-data-access` lib with three files: services (raw axios), queries (RTK endpoints), types (payload/response shapes).

## Existing Data-Access Libs

| Lib | Import | Purpose |
|---|---|---|
| `@lhypl/tasks-data-access` | `useGetTasksQuery`, `useCreateTaskMutation`, ... | Task CRUD + export |
| `@lhypl/teams-data-access` | `useGetTeamsQuery`, `useAddMemberMutation`, ... | Team management |
| `@lhypl/notifications-data-access` | `useGetNotificationsQuery`, `useMarkAllReadMutation` | Notification list/read |
| `@lhypl/team-status-data-access` | `useGetTaskTeamStatusesQuery`, `useUpsertTaskTeamStatusMutation` | Per-team task statuses |
| `@lhypl/me-data-access` | `useGetMeQuery` | Current user |
| `@lhypl/users-data-access` | `useGetUsersListQuery` | User list (for assignee picker) |

## File Structure

```
libs/fe/<name>-data-access/src/
  index.ts
  lib/
    <name>.services.ts   ← axios calls, plain async functions
    <name>.queries.ts    ← RTK Query injectEndpoints
    <name>.types.ts      ← payload/response interfaces
```

## Services Pattern

```typescript
// <name>.services.ts
import { http } from '@lhypl/ui-data-access';

export const getThings = async (): Promise<Thing[]> => {
  const response = await http.get<Thing[]>('/things');
  return response.data;
};

export const createThing = async (data: CreateThingPayload): Promise<Thing> => {
  const response = await http.post<Thing>('/things', data);
  return response.data;
};
```

## Queries Pattern

```typescript
// <name>.queries.ts
import { queryApi } from '@lhypl/store-data-access';
import { getThings, createThing } from './<name>.services';
import type { Thing, CreateThingPayload } from './<name>.types';

export const thingsQueryApi = queryApi
  .enhanceEndpoints({ addTagTypes: ['Things'] })
  .injectEndpoints({
    endpoints: (builder) => ({
      getThings: builder.query<Thing[], void>({
        queryFn: async () => ({ data: await getThings() }),
        providesTags: ['Things'],
      }),
      createThing: builder.mutation<Thing, CreateThingPayload>({
        queryFn: async (payload) => ({ data: await createThing(payload) }),
        invalidatesTags: ['Things'],
      }),
    }),
  });

export const { useGetThingsQuery, useCreateThingMutation } = thingsQueryApi;
```

## Tag Invalidation Conventions

| Pattern | When to use |
|---|---|
| `invalidatesTags: ['Things']` | Mutation affects list |
| `invalidatesTags: [{ type: 'Things', id: payload.id }]` | Mutation affects specific item |
| `providesTags: (result) => result?.map(t => ({ type: 'Things', id: t.id }))` | List query, enables item-level invalidation |

## Manual Invalidation (from WS events)

```typescript
import { useAppDispatch } from '@lhypl/store';
import { tasksQueryApi } from '@lhypl/tasks-data-access';

const dispatch = useAppDispatch();
dispatch(tasksQueryApi.util.invalidateTags(['Tasks']));
```

## Polling Query

```typescript
getExportStatus: builder.query<ExportStatus, string>({
  queryFn: async (jobId) => ({ data: await getExportStatus(jobId) }),
}),

// Usage — poll every 3s, stop when done:
const { data } = useGetExportStatusQuery(jobId, {
  pollingInterval: 3000,
  skip: !jobId || status === 'done',
});
```

## Required: package.json for new data-access lib

```json
{
  "name": "@lhypl/<name>-data-access",
  "version": "0.0.1",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "dependencies": {
    "@lhypl/store-data-access": "workspace:*",
    "@lhypl/ui-data-access": "workspace:*"
  }
}
```

## Common Mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Using `baseQuery` instead of `fakeBaseQuery` | Type errors | All queries use `queryFn`, not `query` |
| Importing directly from axios | Skips auth interceptor | Always use `http` from `@lhypl/ui-data-access` |
| Missing `addTagTypes` | TS error on `providesTags` | Add all tag types to `enhanceEndpoints` |
| Not exporting hooks from `index.ts` | Hook not discoverable | Export from `src/index.ts` |
