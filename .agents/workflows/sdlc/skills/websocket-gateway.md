---
name: websocket-gateway
description: Use when working with the real-time WebSocket layer, adding new event types, or debugging real-time notification delivery between the API and connected browser clients.
---

# WebSocket Gateway Architecture

## Overview

Real-time delivery uses a two-hop architecture: the REST API publishes to Redis channels; the separate WebSocket server (`teams-gateway-ws` on port 3001) subscribes and relays to connected socket clients.

```
REST API (port 3000)
  → Redis PUBLISH ws:broadcast:<userId>
      → teams-gateway-ws (port 3001)
          → Socket.IO emit('notification', payload) to client room <userId>
```

## Key Files

| File | Purpose |
|---|---|
| `libs/api/ws-gateway/src/lib/events.gateway.ts` | Socket.IO gateway — JWT auth on connect, user rooms |
| `libs/api/ws-gateway/src/lib/pubsub-relay.service.ts` | Subscribes to Redis `ws:broadcast:*`, relays to rooms |
| `libs/api/notifications/src/lib/notification.worker.ts` | Publishes to Redis after persisting notification |
| `apps/teams-gateway-ws/src/app/app.module.ts` | WS app module (imports `WsGatewayModule`, `RedisModule`) |

## Adding a New Real-Time Event

1. **Enqueue notification job** from the feature service (tasks, exports, etc.):
   ```typescript
   await this.notificationsQueue.add('task_event', {
     type: 'my_new_event',       // ← new event type
     taskId: task.id,
     actorId: userId,
     assigneeIds: [targetUserId],
   });
   ```

2. **Notification worker persists + publishes** (no changes needed in `notification.worker.ts` for standard `task_event` jobs — it already publishes to `ws:broadcast:<userId>` for each assignee).

3. **Frontend subscribes** via `useWsClient().on('notification', handler)`.

## Redis Channel Convention

```
ws:broadcast:<userId>    ← per-user channel
```

The pub/sub relay uses `psubscribe('ws:broadcast:*')` to catch all user channels.

## JWT Auth on Connect

`events.gateway.ts` extracts the JWT from:
1. `socket.handshake.auth.token` (explicit auth object)
2. `access_token` cookie in `socket.handshake.headers.cookie`

The user's id (`payload.sub`) is stored on the socket and used to `socket.join(userId)`.

## Frontend Connection

```typescript
// libs/fe/ws-client/src/lib/ws-client.provider.tsx
const socket = io(url, {
  withCredentials: true,  // sends access_token cookie
  autoConnect: true,
  reconnection: true,
});
```

Use `VITE_WS_URL` env var (default `http://localhost:3001`).

## Debugging

```bash
# Check Redis pub/sub activity
redis-cli PSUBSCRIBE 'ws:broadcast:*'

# In another terminal, trigger a task update → should see published message

# Check WS server logs (Docker)
docker logs <ws-container-id> -f
```

## Common Mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Sharing the pub Redis client for subscribe | `ERR not allowed` after SUBSCRIBE | Always `redisClient.duplicate()` for subscriber |
| Missing `socket.join(userId)` on connect | Emit to room drops silently | Join in `handleConnection` |
| Publishing without per-user channel (`ws:broadcast:*`) | All users receive all events | Include `userId` in channel name |
| WS app not in `depends_on: redis` in docker-compose | Race condition on startup | Already set — keep `redis: condition: service_healthy` |
