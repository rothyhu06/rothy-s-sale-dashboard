# Daily & Weekly Report Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate traceable daily and weekly work views from real facts while preserving editable human reflection.

**Architecture:** Report is a mutable presentation container; ReportSnapshot and ReportSourceLink are immutable. A single transaction fixes timezone, half-open period, `as_of`, metrics, links, audit, and receipt.

**Tech Stack:** Next.js, Supabase PostgreSQL/RLS, PostgreSQL JSONB projections, Vitest, Playwright.

## Global Constraints

- Daily and Weekly share one Report table.
- Periods are `[period_start, period_end)`.
- Metrics cannot be edited.
- Re-generation appends a Snapshot and SourceLinks; it never overwrites history.

---

### Task 1: Report schema and immutable source chain

**Files:**
- Create: `web/supabase/migrations/202607250501_report.sql`
- Create: `web/supabase/tests/501_report_rls.sql`
- Create: `web/src/features/reports/schema.ts`
- Test: `web/src/tests/features/report-period.test.ts`

- [ ] Write failing tests for Daily/Weekly CHECKs, partial unique indexes, owner-aware source FKs, and UPDATE/DELETE denial on Snapshot/SourceLink.
- [ ] Run database/unit tests; expect failure.
- [ ] Implement Report, Snapshot, SourceLink and every explicit source FK.
- [ ] Run tests; expect PASS.
- [ ] Commit with `git commit -m "feat: add immutable report model"`.

### Task 2: Projection and snapshot transaction

**Files:**
- Create: `web/src/features/reports/projection.ts`
- Create: `web/src/features/reports/actions.ts`
- Create: `web/src/features/reports/queries.ts`
- Test: `web/src/tests/features/report-projection.test.ts`

- [ ] Write failing tests for Shanghai day/week boundaries, one `as_of`, TaskStatusHistory event-date counting, no duplicate source, late fact regeneration, and maximum data-level inheritance.
- [ ] Run tests; expect failure.
- [ ] Implement live preview and `generateReportSnapshot()` RPC with pre-generated SourceLink UUIDs and `period_start <= event_time < min(period_end, as_of)`.
- [ ] Run tests and RLS suite; expect PASS.
- [ ] Commit with `git commit -m "feat: generate traceable reports"`.

### Task 3: Report UI and export

**Files:**
- Create: `web/src/app/(protected)/reports/page.tsx`
- Create: `web/src/app/(protected)/reports/daily/page.tsx`
- Create: `web/src/app/(protected)/reports/daily/[date]/page.tsx`
- Create: `web/src/app/(protected)/reports/weekly/page.tsx`
- Create: `web/src/app/(protected)/reports/weekly/[yearWeek]/page.tsx`
- Create: `web/src/features/reports/components/report-narrative-editor.tsx`
- Create: `web/src/features/reports/components/report-source-list.tsx`
- Create: `web/src/features/reports/components/snapshot-selector.tsx`
- Create: `web/src/app/api/reports/[id]/export/route.ts`
- Test: `web/e2e/reports.spec.ts`

- [ ] Write flow: create facts → generate Daily → edit reflection → create tomorrow Task → regenerate after late Interaction → generate Weekly → export → verify audit.
- [ ] Run flow; expect missing routes.
- [ ] Implement source drill-down, immutable snapshot selector, narrative editor, Task/Insight conversion, and authenticated export.
- [ ] Run slice tests, accessibility, responsive checks, and build; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver daily weekly reporting"`.
