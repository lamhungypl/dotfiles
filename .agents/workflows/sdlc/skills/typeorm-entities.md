---
name: typeorm-entities
description: Use when adding or modifying TypeORM entities, registering new entities in app.module.ts, or working with entity relations (ManyToMany, OneToMany, cascade). Documents the synchronize:true approach and entity barrel pattern.
---

# TypeORM Entities Pattern

## Overview

All entities live in `libs/api/entities/src/lib/`. TypeORM runs with `synchronize: true` — schema changes apply automatically on next API start. No migration files needed during development.

## Existing Entities

| Entity | Key Relations |
|---|---|
| `User` | `ManyToMany assignedTasks`, `OneToMany reportedTasks`, `OneToMany memberships`, `OneToMany ownedTeams` |
| `Task` | `ManyToMany assignees` (join table `task_assignees`), `ManyToOne team`, `ManyToOne reporter`, `OneToMany teamStatuses` |
| `Team` | `ManyToOne owner`, `OneToMany memberships`, `OneToMany todos` |
| `Membership` | `ManyToOne user`, `ManyToOne team` |
| `TaskTeamStatus` | `ManyToOne task`, `ManyToOne team` — unique on `[taskId, teamId]` |
| `Notification` | `ManyToOne user` — `type`, `payload (jsonb)`, `read (bool)` |
| `ExportJob` | `ManyToOne user` — `format`, `status (enum)`, `fileUrl`, `filters (jsonb)` |

## Adding a New Entity

### 1. Create the entity file

```typescript
// libs/api/entities/src/lib/my-thing.entity.ts
import {
  Column, CreateDateColumn, Entity,
  ManyToOne, PrimaryGeneratedColumn, UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity()
export class MyThing {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  user!: User;

  @Column({ type: 'text' })
  userId!: string;

  @Column({ type: 'text' })
  name!: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata?: Record<string, unknown>;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}
```

### 2. Export from barrel

```typescript
// libs/api/entities/src/index.ts
export * from './lib/my-thing.entity';
// keep alphabetical
```

### 3. Register in app.module.ts

```typescript
// apps/teams-gateway-api/src/app/app.module.ts
import { MyThing, /* ...existing... */ } from '@lhypl/entities';

// In TypeOrmModule.forRootAsync:
entities: [User, Team, Membership, Task, TaskTeamStatus, Notification, ExportJob, MyThing],
```

### 4. Add to feature module

```typescript
// libs/api/my-feature/src/lib/my-feature.module.ts
TypeOrmModule.forFeature([MyThing])
```

## ManyToMany Pattern (task_assignees)

```typescript
// On the owning side (Task):
@ManyToMany(() => User, (u) => u.assignedTasks, { eager: true })
@JoinTable({ name: 'task_assignees' })
assignees!: User[];

// On the inverse side (User):
@ManyToMany('Task', 'assignees')
assignedTasks!: Task[];
```

## Unique Constraint Pattern (TaskTeamStatus)

```typescript
@Entity()
@Unique(['taskId', 'teamId'])   // ← composite unique
export class TaskTeamStatus { ... }
```

## Column Type Quick Reference

| TypeScript Type | TypeORM Column |
|---|---|
| `string` | `@Column()` or `@Column({ type: 'text' })` |
| `string[]` | `@Column({ type: 'text', array: true, default: '{}' })` |
| `Record<string, unknown>` | `@Column({ type: 'jsonb', nullable: true })` |
| `Date` | `@Column({ type: 'timestamptz' })` |
| enum | `@Column({ type: 'enum', enum: MyEnum, default: MyEnum.Value })` |
| auto-set date | `@CreateDateColumn({ type: 'timestamptz' })` |
| auto-update date | `@UpdateDateColumn({ type: 'timestamptz' })` |

## Common Mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Forget `!` (definite assignment) | TS strict mode error | All entity columns need `!` or optional `?` |
| Cascade delete not set | Orphaned rows on parent delete | Add `onDelete: 'CASCADE'` to `@ManyToOne` |
| `eager: true` on both sides of ManyToMany | Circular load / stack overflow | Only on owning side |
| Forget to add to `app.module.ts` entities array | Table never created | Always register in TypeORM root config |
| Missing `@JoinTable` on owning side | Join table not created | Required on exactly one side of ManyToMany |
