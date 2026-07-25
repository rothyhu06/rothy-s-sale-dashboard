# Interaction & Task Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the operating loop in which completed customer interactions create explicit future commitments.

**Architecture:** Interaction is a fact and Task is a commitment. One receipt-backed transaction creates Interaction, participant snapshots, Opportunity links, Tasks, initial Task histories, search updates, and audit rows.

**Tech Stack:** Next.js, Supabase PostgreSQL/RLS, Zod, Vitest, Playwright.

## Global Constraints

- Interaction never automatically advances Opportunity.
- Task current status is derived from append-only TaskStatusHistory.
- Customer Next Action is derived from open TaskProjection.
- Participants retain historical name/department/position snapshots.

---

### Task 1: Interaction/Task schema and projections

**Files:**
- Create: `web/supabase/migrations/202607250301_interaction_task.sql`
- Create: `web/supabase/tests/301_interaction_task_rls.sql`
- Create: `web/src/features/interactions/schema.ts`
- Create: `web/src/features/interactions/projection.ts`
- Create: `web/src/features/tasks/schema.ts`
- Create: `web/src/features/tasks/projection.ts`
- Test: `web/src/tests/features/task-projection.test.ts`

- [ ] Write failing tests for required Customer + Contact, one Primary Opportunity link, participant snapshots, immutable task history, overdue/next-action sorting, and cross-owner rejection.
- [ ] Run database/unit tests; expect failure.
- [ ] Implement tables, enums, CHECKs, partial unique indexes, and projections.
- [ ] Run database/unit tests; expect PASS.
- [ ] Commit with `git commit -m "feat: add interaction task model"`.

### Task 2: Atomic commands

**Files:**
- Create: `web/src/features/interactions/actions.ts`
- Create: `web/src/features/interactions/queries.ts`
- Create: `web/src/features/tasks/actions.ts`
- Create: `web/src/features/tasks/queries.ts`
- Test: `web/src/tests/features/interaction-command.test.ts`

- [ ] Write failing tests proving one Interaction can create two Tasks with one operation_id, retries create neither duplicate Interaction nor Tasks, and Task completion does not change Opportunity stage.
- [ ] Run tests; expect failure.
- [ ] Implement receipt-backed RPC commands and same-transaction Search/Audit updates.
- [ ] Run targeted, RLS, and concurrency tests; expect PASS.
- [ ] Commit with `git commit -m "feat: add interaction task commands"`.

### Task 3: Daily operating pages

**Files:**
- Create: `web/src/app/(protected)/interactions/page.tsx`
- Create: `web/src/app/(protected)/interactions/new/page.tsx`
- Create: `web/src/app/(protected)/interactions/[id]/page.tsx`
- Create: `web/src/app/(protected)/tasks/page.tsx`
- Create: `web/src/app/(protected)/tasks/[id]/page.tsx`
- Create: `web/src/features/interactions/components/interaction-form.tsx`
- Create: `web/src/features/interactions/components/participant-fields.tsx`
- Create: `web/src/features/tasks/components/task-form.tsx`
- Create: `web/src/features/tasks/components/task-status-actions.tsx`
- Modify: `web/src/app/(protected)/customers/[id]/page.tsx`
- Modify: `web/src/app/(protected)/opportunities/[id]/page.tsx`
- Test: `web/e2e/interaction-task.spec.ts`

- [ ] Write browser flow: record meeting with two participants → create two follow-ups → start/complete/reopen Task → verify Customer next action.
- [ ] Run flow; expect missing pages.
- [ ] Implement list/detail/forms and explicit “suggest stage transition” action without automatic transition.
- [ ] Run slice tests, accessibility, responsive checks, and build; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver interaction task loop"`.
