# Knowledge & Learning Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a real Knowledge Hub and Learning chain that can create, edit, search locally, attach sources, track mastery, and continue learning.

**Architecture:** Knowledge is the reusable asset; Learning is the activity fact. Server commands write both domains, owner-aware links, tags, attachments, derived plaintext, search documents, receipts, and audit records transactionally.

**Tech Stack:** Next.js Server Components/Actions, Supabase PostgreSQL/RLS, Zod, Design System V2.0, Vitest, Playwright.

## Global Constraints

- `content_blocks` is authoritative; `content_plaintext` is server-derived.
- Knowledge status and confidence are independent.
- Mastery is fixed to 1 Aware, 2 Understand, 3 Explain, 4 Apply, 5 Teach.
- Review creates a child Learning through `parent_learning_id`; it never overwrites the original.

---

### Task 1: Knowledge and Learning schema with RLS

**Files:**
- Create: `web/supabase/migrations/202607250101_knowledge_learning.sql`
- Create: `web/supabase/tests/101_knowledge_learning_rls.sql`
- Create: `web/src/features/knowledge/schema.ts`
- Create: `web/src/features/learning/schema.ts`
- Test: `web/src/tests/features/knowledge-learning-schema.test.ts`

**Interfaces:**
- Produces tables `knowledge`, `learning`, `learning_knowledge_links`, `knowledge_relations`.
- Extends `attachment_links` and `tag_links` with Knowledge/Learning FKs and partial unique indexes.

- [ ] Write failing enum, CHECK, composite-FK, soft-delete uniqueness, and cross-owner pgTAP tests.
- [ ] Run `cd web && pnpm db:reset && pnpm test:rls`; expect missing-table failures.
- [ ] Implement migration and matching Zod enums exactly as specified.
- [ ] Run `cd web && pnpm db:reset && pnpm test:rls && pnpm test -- src/tests/features/knowledge-learning-schema.test.ts`; expect PASS.
- [ ] Commit with `git commit -m "feat: add knowledge and learning data model"`.

### Task 2: Transactional domain commands and queries

**Files:**
- Create: `web/src/features/knowledge/actions.ts`
- Create: `web/src/features/knowledge/queries.ts`
- Create: `web/src/features/learning/actions.ts`
- Create: `web/src/features/learning/queries.ts`
- Test: `web/src/tests/features/knowledge-actions.test.ts`
- Test: `web/src/tests/features/learning-actions.test.ts`

**Interfaces:**
- Produces: `createKnowledge(input, clientRequestId)`, `updateKnowledge(input, expectedVersion)`, `createLearning()`, `completeLearning()`, `createReviewLearning()`, `getContinueLearning()`.

- [ ] Write failing tests proving owner injection, plaintext derivation, idempotent create, 409 version conflict, mastery bounds, and Learning parent ownership.
- [ ] Run targeted tests and verify failure.
- [ ] Implement commands through `CommandReceipt`; write SearchDocument and AuditLog in the same database transaction.
- [ ] Run targeted tests and `pnpm test:rls`; expect PASS.
- [ ] Commit with `git commit -m "feat: add knowledge learning commands"`.

### Task 3: Knowledge and Learning pages

**Files:**
- Create: `web/src/app/(protected)/knowledge/page.tsx`
- Create: `web/src/app/(protected)/knowledge/new/page.tsx`
- Create: `web/src/app/(protected)/knowledge/[id]/page.tsx`
- Create: `web/src/app/(protected)/learning/page.tsx`
- Create: `web/src/app/(protected)/learning/new/page.tsx`
- Create: `web/src/app/(protected)/learning/[id]/page.tsx`
- Create: `web/src/features/knowledge/components/knowledge-form.tsx`
- Create: `web/src/features/learning/components/learning-form.tsx`
- Test: `web/e2e/knowledge-learning.spec.ts`

**Interfaces:**
- Consumes all Task 2 commands.
- Produces working routes and Continue Learning.

- [ ] Write Playwright flow: create Knowledge → attach Tag → create Learning → complete as Applied → create Review → verify chain and search.
- [ ] Run `pnpm test:e2e -- e2e/knowledge-learning.spec.ts`; expect route failure.
- [ ] Implement list/create/edit/detail forms using only Design System public components.
- [ ] Run `pnpm lint && pnpm typecheck && pnpm test && pnpm build && pnpm test:e2e -- e2e/knowledge-learning.spec.ts`; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver knowledge learning workflow"`.
