# Global Search & Unified Timeline Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find any owned business object and understand its chronological sales history without creating new business state.

**Architecture:** SearchDocument is a disposable persisted projection; Timeline is a dynamic owner-filtered UNION mapped into non-persisted envelopes. Search locates objects; Timeline explains process.

**Tech Stack:** PostgreSQL `pg_trgm` and FTS, Next.js Server Actions, HMAC exact lookup, keyset pagination, Vitest, Playwright.

## Global Constraints

- Search never scans business tables at query time.
- SearchDocument cannot be a business lookup or FK target.
- TimelineEventEnvelope never persists.
- Search terms are not logged or stored in URLs/localStorage.

---

### Task 1: Search indexing and secure query

**Files:**
- Create: `web/supabase/migrations/202607250601_search.sql`
- Create: `web/supabase/tests/601_search_rls.sql`
- Create: `web/src/features/search/normalize.ts`
- Create: `web/src/features/search/index-document.ts`
- Create: `web/src/features/search/query.ts`
- Create: `web/src/features/search/actions.ts`
- Test: `web/src/tests/features/search.test.ts`

- [ ] Write failing tests for Chinese trigram, English FTS, exact title ordering, tag text, masked Contact result, HMAC email/phone lookup, owner isolation, and projection-version filtering.
- [ ] Run tests; expect failure.
- [ ] Implement `pg_trgm`, SearchDocument indexes, transactional source refresh, rebuild command, and POST Server Action.
- [ ] Run database/unit tests; expect PASS.
- [ ] Commit with `git commit -m "feat: add secure global search"`.

### Task 2: Timeline event projection

**Files:**
- Create: `web/src/features/timeline/envelope.ts`
- Create: `web/src/features/timeline/query.ts`
- Create: `web/src/features/timeline/cursor.ts`
- Test: `web/src/tests/features/timeline.test.ts`

- [ ] Write failing tests for stable event_key, event_time vs recorded_at, Backfilled, operation grouping, soft-delete Tombstone, Merge mapping, maximum data level, and cursor invalidation.
- [ ] Run tests; expect failure.
- [ ] Implement owner-filtered UNION branches and keyset cursor `(event_time, recorded_at, event_key)`.
- [ ] Run tests and RLS suite; expect PASS.
- [ ] Commit with `git commit -m "feat: project unified sales timeline"`.

### Task 3: Search and Timeline presentation

**Files:**
- Create: `web/src/app/(protected)/search/page.tsx`
- Create: `web/src/app/(protected)/timeline/page.tsx`
- Create: `web/src/features/search/components/global-search-dialog.tsx`
- Create: `web/src/features/search/components/search-result-group.tsx`
- Create: `web/src/features/timeline/components/timeline-filter-bar.tsx`
- Create: `web/src/features/timeline/components/timeline-event-group.tsx`
- Modify: `web/src/components/workspace/workspace-shell.tsx`
- Test: `web/e2e/search-timeline.spec.ts`

- [ ] Write flow: search Chinese/English/contact exact value → open object → view filtered activity → verify grouped operation →补录 Interaction → verify Backfilled and stable pagination.
- [ ] Run flow; expect missing routes.
- [ ] Implement Command Dialog, grouped results, timeline filters, event groups, context panel, and mobile sheets.
- [ ] Run full slice verification and build; expect PASS.
- [ ] Commit with `git commit -m "feat: deliver search and timeline workspace"`.
