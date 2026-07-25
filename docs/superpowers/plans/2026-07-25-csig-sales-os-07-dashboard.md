# Adaptive Sales Command Center Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the gallery redirect with an action-first personal workspace that identifies today’s next move from existing projections.

**Architecture:** DashboardRequestContext fixes viewer, timezone, day boundaries, `as_of`, and projection version. Stateless presentation components compose deterministic action candidates, timeline preview, evidence-based growth, and weekly reflection.

**Tech Stack:** Next.js Server Components, Supabase query projections, Design System V2.0, Vitest, Playwright.

## Global Constraints

- No Dashboard table or widget state.
- No AI call in MVP.
- No amount-based customer importance.
- Five-second first viewport shows Brief, first Focus action, customer/opportunity context, and growth next practice.

---

### Task 1: Dashboard projection composer

**Files:**
- Create: `web/src/features/dashboard/request-context.ts`
- Create: `web/src/features/dashboard/action-candidates.ts`
- Create: `web/src/features/dashboard/today-brief.ts`
- Create: `web/src/features/dashboard/growth-evidence.ts`
- Create: `web/src/features/dashboard/weekly-reflection.ts`
- Create: `web/src/features/dashboard/query.ts`
- Test: `web/src/tests/features/dashboard-projection.test.ts`

- [ ] Write failing tests for shared context, deterministic priority, category diversity, no amount ranking, follow-up gaps, stalled Opportunity, Learning continuity, and Insight validation.
- [ ] Run tests; expect failure.
- [ ] Implement pure projection functions plus one server composer receiving a frozen DashboardRequestContext.
- [ ] Run tests; expect PASS.
- [ ] Commit with `git commit -m "feat: compose dashboard actions"`.

### Task 2: Responsive command center

**Files:**
- Replace: `web/src/app/(protected)/page.tsx`
- Create: `web/src/features/dashboard/components/today-brief.tsx`
- Create: `web/src/features/dashboard/components/today-focus.tsx`
- Create: `web/src/features/dashboard/components/memory-preview.tsx`
- Create: `web/src/features/dashboard/components/sales-journey.tsx`
- Create: `web/src/features/dashboard/components/weekly-reflection.tsx`
- Create: `web/src/components/workspace/workspace-shell.tsx`
- Test: `web/e2e/dashboard.spec.ts`

- [ ] Write Playwright assertions for Desktop, Tablet, Mobile, keyboard operation, empty state, first viewport, and Context Panel.
- [ ] Run flow; expect the existing redirect or missing content.
- [ ] Implement Header, rule-based Today Brief, up-to-four Focus cards, Memory preview, Sales Journey evidence, Weekly Reflection, and Quick Capture.
- [ ] Run `pnpm lint && pnpm typecheck && pnpm test && pnpm build && pnpm test:e2e -- e2e/dashboard.spec.ts`; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver adaptive sales command center"`.
