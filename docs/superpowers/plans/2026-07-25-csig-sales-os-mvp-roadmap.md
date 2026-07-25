# CSIG Sales OS MVP Vertical-Slice Implementation Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the private CSIG Sales OS MVP as nine independently demonstrable vertical slices.

**Architecture:** The Next.js application uses server-authenticated domain modules backed by Supabase PostgreSQL and private Storage. Mutable business objects, append-only events, disposable projections, and presentation composers remain separate; every slice includes schema, RLS, server commands, UI, audit, unit/integration tests, Playwright acceptance, and a production build.

**Tech Stack:** Next.js 16, React 19, TypeScript 5, Tailwind CSS 4, Design System V2.0, Supabase PostgreSQL/Auth/Storage, Zod, Vitest, Playwright.

## Global Constraints

- No public registration; anonymous access is limited to `/login` and `/design-system`.
- Every persisted business, relation, event, audit, receipt, and search table contains immutable `owner_id`.
- All CRUD uses RLS; ordinary business requests never use the Service Role client.
- Durable business entities use soft delete and optimistic concurrency.
- Append-only events, immutable snapshots, source links, and audit logs cannot be updated or deleted.
- Commands use `CommandReceipt`; `client_request_id` provides idempotency and server-generated `operation_id` correlates writes.
- Business data is never persisted in localStorage; the existing theme preference and wallpaper repository remain non-business UI preferences.
- Every page imports visual primitives from `@/components/design-system`.
- Each slice ends with `pnpm lint`, `pnpm typecheck`, targeted tests, Playwright acceptance, `pnpm build`, and an independent commit.

---

## Slice order

1. [Foundation](2026-07-25-csig-sales-os-01-foundation.md)
2. [Knowledge & Learning](2026-07-25-csig-sales-os-02-knowledge-learning.md)
3. [Customer / Contact / Opportunity](2026-07-25-csig-sales-os-03-customer-opportunity.md)
4. [Interaction & Task](2026-07-25-csig-sales-os-04-interaction-task.md)
5. [Insight](2026-07-25-csig-sales-os-05-insight.md)
6. [Daily & Weekly Report](2026-07-25-csig-sales-os-06-report.md)
7. [Adaptive Sales Command Center](2026-07-25-csig-sales-os-07-dashboard.md)
8. [Global Search & Unified Timeline](2026-07-25-csig-sales-os-08-search-timeline.md)
9. [Production Hardening](2026-07-25-csig-sales-os-09-production-hardening.md)

## Delivery gate

Do not start a later slice until the preceding slice has:

- applied cleanly to a fresh local Supabase database;
- passed owner-isolation integration tests;
- completed its real browser workflow without mock repositories;
- passed responsive and axe checks;
- passed a production build;
- been committed independently.

## Final acceptance

The ninth slice runs the complete scenario from login → learning → customer → opportunity → interaction → task → stage transition → insight → knowledge conversion → reports → dashboard → search/timeline → secure attachment deletion.
