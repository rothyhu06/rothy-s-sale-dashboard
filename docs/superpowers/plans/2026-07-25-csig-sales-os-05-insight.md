# Insight Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn sales facts into independently verifiable cognitive assets and convert validated insights into reusable Knowledge.

**Architecture:** Insight owns the proposition; InsightEvidence links real sources through explicit FKs; append-only ValidationEvents derive maturity. Conversion creates Knowledge but retains the original Insight and evidence chain.

**Tech Stack:** Next.js, Supabase PostgreSQL/RLS, Zod, Vitest, Playwright.

## Global Constraints

- Insight is not a note, meeting record, Task, or Knowledge.
- Evidence uses explicit nullable FKs with an exactly-one CHECK.
- ValidationEvent is append-only.
- Outcome review is an Insight linked to OpportunityOutcome.

---

### Task 1: Insight schema and projection

**Files:**
- Create: `web/supabase/migrations/202607250401_insight.sql`
- Create: `web/supabase/tests/401_insight_rls.sql`
- Create: `web/src/features/insights/schema.ts`
- Create: `web/src/features/insights/projection.ts`
- Test: `web/src/tests/features/insight-projection.test.ts`

- [ ] Write failing tests for exactly-one evidence source, owner-aware FKs, Proposed→Observed→Testing→Validated mapping, rejected/retired behavior, and Level 3 inheritance.
- [ ] Run tests; expect failure.
- [ ] Implement Insight, InsightEvidence, ValidationEvent, CustomerInsightLink, KnowledgeInsightLink, and projection.
- [ ] Run database/unit tests; expect PASS.
- [ ] Commit with `git commit -m "feat: add insight evidence model"`.

### Task 2: Commands and conversion

**Files:**
- Create: `web/src/features/insights/actions.ts`
- Create: `web/src/features/insights/queries.ts`
- Test: `web/src/tests/features/insight-actions.test.ts`

- [ ] Write failing tests for create-from-Interaction without copying notes, idempotent validation, Outcome Review projection, and transactional Knowledge conversion.
- [ ] Run tests; expect failure.
- [ ] Implement receipt-backed create, addEvidence, appendValidationEvent, and convertInsightToKnowledge commands.
- [ ] Run tests and RLS suite; expect PASS.
- [ ] Commit with `git commit -m "feat: add insight validation commands"`.

### Task 3: Insight workspace

**Files:**
- Create: `web/src/app/(protected)/insights/page.tsx`
- Create: `web/src/app/(protected)/insights/new/page.tsx`
- Create: `web/src/app/(protected)/insights/[id]/page.tsx`
- Create: `web/src/features/insights/components/insight-form.tsx`
- Create: `web/src/features/insights/components/evidence-list.tsx`
- Create: `web/src/features/insights/components/validation-actions.tsx`
- Modify: `web/src/app/(protected)/interactions/[id]/page.tsx`
- Modify: `web/src/app/(protected)/opportunities/[id]/page.tsx`
- Test: `web/e2e/insight.spec.ts`

- [ ] Write flow: Interaction → Insight → supporting Task/Learning evidence → Applied → Validated → Knowledge conversion → source trace remains.
- [ ] Run flow; expect missing UI.
- [ ] Implement list/detail/create/validation/conversion UI and Continue Validation section.
- [ ] Run full slice verification and build; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver insight growth loop"`.
