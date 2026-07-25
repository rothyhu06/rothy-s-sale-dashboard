# Customer, Contact & Opportunity Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver institution and contact records plus an append-only Opportunity pipeline.

**Architecture:** Customer and Contact retain stable facts; Opportunity owns sales process; current stage and next action are projections. Merge uses preview/version/hash/token and preserves Tombstones.

**Tech Stack:** Next.js, Supabase PostgreSQL/RLS, Zod, Vitest, Playwright, Design System V2.0.

## Global Constraints

- Customer never stores pipeline stage, last activity, next action, health score, or subjective size.
- Contact position and Opportunity role remain separate.
- Opportunity stage changes only through `OpportunityStageHistory`.
- Currency uses ISO 4217 and stage never implies probability.

---

### Task 1: Customer and Contact schema, commands, and merge

**Files:**
- Create: `web/supabase/migrations/202607250201_customer_contact.sql`
- Create: `web/supabase/tests/201_customer_contact_rls.sql`
- Create: `web/src/features/customers/schema.ts`
- Create: `web/src/features/customers/actions.ts`
- Create: `web/src/features/customers/queries.ts`
- Create: `web/src/features/customers/merge.ts`
- Create: `web/src/features/contacts/schema.ts`
- Create: `web/src/features/contacts/actions.ts`
- Create: `web/src/features/contacts/queries.ts`
- Test: `web/src/tests/features/customer-merge.test.ts`

**Interfaces:**
- Produces Customer, CustomerExternalReference, Contact, CustomerKnowledgeLink and merge commands.

- [ ] Write failing tests for normalized-name duplicate warnings, owner-aware references, Contact departure history, applicability requirements, stale preview rejection, and Survivor Tombstone routing.
- [ ] Run database and unit tests; expect failure.
- [ ] Implement schema and commands with Preview Token + Plan Hash + entity versions.
- [ ] Run `pnpm db:reset && pnpm test:rls && pnpm test -- src/tests/features/customer-merge.test.ts`; expect PASS.
- [ ] Commit with `git commit -m "feat: add customer and contact domain"`.

### Task 2: Opportunity process and projections

**Files:**
- Create: `web/supabase/migrations/202607250202_opportunity.sql`
- Create: `web/supabase/tests/202_opportunity_rls.sql`
- Create: `web/src/features/opportunities/schema.ts`
- Create: `web/src/features/opportunities/actions.ts`
- Create: `web/src/features/opportunities/queries.ts`
- Create: `web/src/features/opportunities/projection.ts`
- Test: `web/src/tests/features/opportunity-transition.test.ts`

**Interfaces:**
- Produces `createOpportunity()`, `transitionOpportunity()`, `recordOutcome()`, `reopenOpportunity()`, `getOpportunityProjection()`.

- [ ] Write failing tests for Initial/Forward/Backward/Skip/Reopen, immutable history, separate estimated/final amount, voided outcome, one owner, and deterministic stalled projection.
- [ ] Run tests and verify failure.
- [ ] Implement Opportunity, StageHistory, Outcome, ContactRole, receipt-backed transitions, and query projection.
- [ ] Run database/unit tests; expect PASS.
- [ ] Commit with `git commit -m "feat: add opportunity process"`.

### Task 3: Customer, Contact, and Pipeline UI

**Files:**
- Create: `web/src/app/(protected)/customers/page.tsx`
- Create: `web/src/app/(protected)/customers/new/page.tsx`
- Create: `web/src/app/(protected)/customers/[id]/page.tsx`
- Create: `web/src/app/(protected)/contacts/page.tsx`
- Create: `web/src/app/(protected)/contacts/[id]/page.tsx`
- Create: `web/src/app/(protected)/opportunities/page.tsx`
- Create: `web/src/app/(protected)/opportunities/new/page.tsx`
- Create: `web/src/app/(protected)/opportunities/[id]/page.tsx`
- Create: `web/src/features/customers/components/customer-form.tsx`
- Create: `web/src/features/customers/components/merge-preview-dialog.tsx`
- Create: `web/src/features/opportunities/components/opportunity-form.tsx`
- Create: `web/src/features/opportunities/components/pipeline-board.tsx`
- Test: `web/e2e/customer-opportunity.spec.ts`

**Interfaces:**
- Produces Customer list/detail, Contact list/detail, Opportunity board/detail, merge preview, and stage transition dialogs.

- [ ] Write Playwright flow: Customer → Contact → Opportunity → role → stage forward/back → Closed Lost → review-required projection → reopen.
- [ ] Run the flow; expect missing routes.
- [ ] Implement pages with direct Customer actions for Contact, Opportunity, Interaction placeholder, and Task placeholder; placeholders are disabled navigation only until Slice 4 and contain no mock data.
- [ ] Run full slice tests, axe checks, responsive projects, and `pnpm build`; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver customer opportunity workflow"`.
