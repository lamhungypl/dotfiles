---
name: nestjs-bullmq
description: Use when adding a new BullMQ queue, worker, or producer in the NestJS API. Covers module wiring, worker class, and queue injection patterns.
---

# NestJS BullMQ Pattern

## Overview

This monorepo uses `@nestjs/bullmq` for background job processing. Three queues exist: `notifications`, `exports`, and implicit scheduler enqueues. Redis connection is configured globally via `BullModule.forRootAsync` in `app.module.ts`.

## Registered Queues

| Queue | Worker | Purpose |
|---|---|---|
| `notifications` | `NotificationWorker` in `libs/api/notifications/` | Persist notification + Redis pub/sub |
| `exports` | `ExportWorker` in `libs/api/exports/` | Async file generation |

## Worker Pattern

```typescript
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';

@Processor('queue-name')
export class MyWorker extends WorkerHost {
  constructor(private readonly myService: MyService) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (job.name === 'my-job') {
      const { fieldA, fieldB } = job.data as { fieldA: string; fieldB: string };
      await this.myService.doWork(fieldA, fieldB);
    }
  }
}
```

## Enqueuing from a Service

```typescript
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class MyService {
  constructor(
    @InjectQueue('notifications') private readonly notificationsQueue: Queue
  ) {}

  async doSomething() {
    await this.notificationsQueue.add('task_event', {
      type: 'task_updated',
      taskId: task.id,
      assigneeIds: task.assignees.map(a => a.id),
    });
  }
}
```

## Module Registration

Every module that **produces or consumes** a queue must register it:

```typescript
@Module({
  imports: [
    BullModule.registerQueue({ name: 'notifications' }),
    BullModule.registerQueue({ name: 'exports' }), // if also producing exports
  ],
  providers: [MyService, MyWorker],
})
export class MyModule {}
```

`BullModule.forRootAsync` is wired once in `app.module.ts` — do NOT add it to feature modules.

## Adding a New Queue

1. Add `BullModule.registerQueue({ name: 'new-queue' })` to the feature module's `imports`
2. Create worker class extending `WorkerHost` with `@Processor('new-queue')`
3. Inject `@InjectQueue('new-queue')` in producing services
4. Add worker to module `providers` array

## Common Mistakes

| Mistake | Effect | Fix |
|---|---|---|
| `BullModule.forRootAsync` in feature module | Duplicate connection setup | Only in `app.module.ts` |
| Missing `BullModule.registerQueue` in module | `@InjectQueue` fails at startup | Add to both producer and consumer modules |
| Returning value from `process()` | Worker treats as result, may log warnings | Use `void` or `Promise<void>` |
| Not extending `WorkerHost` | Worker not registered as Bull processor | Always extend `WorkerHost` |
