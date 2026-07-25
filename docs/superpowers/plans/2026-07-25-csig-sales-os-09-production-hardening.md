# CSIG Sales OS Production Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the entire MVP can be rebuilt, secured, deployed, and used daily without mock data or hidden cross-owner leaks.

**Architecture:** Fresh-database verification, projection rebuild commands, security regression, performance budgets, production environment checks, and one full browser journey gate release readiness.

**Tech Stack:** Supabase CLI, PostgreSQL EXPLAIN, Vitest, pgTAP, Playwright, Next.js production build, Vercel.

## Global Constraints

- No new business features.
- No Account Plan, AI Assistant, team model, or external CRM integration.
- Production verification must use the same migrations and RLS policies as local verification.
- No secrets, production data, or test credentials enter Git.

---

### Task 1: Projection rebuild and operational commands

**Files:**
- Create: `web/src/app/api/admin/projections/rebuild/route.ts`
- Create: `web/src/lib/projections/rebuild.ts`
- Create: `web/scripts/verify-projections.ts`
- Test: `web/src/tests/projections/rebuild.test.ts`

- [ ] Write failing tests proving SearchDocument can be deleted/rebuilt, dynamic projections need no persisted cache, snapshots/history/audit are untouched, and rebuild writes one sanitized AuditLog.
- [ ] Run tests; expect failure.
- [ ] Implement owner-scoped, authenticated rebuild with projection schema version.
- [ ] Run tests and compare before/after projection counts and stable keys; expect equality.
- [ ] Commit with `git commit -m "feat: add safe projection rebuild"`.

### Task 2: Security and performance regression

**Files:**
- Create: `web/supabase/tests/901_cross_owner_regression.sql`
- Create: `web/e2e/security.spec.ts`
- Create: `web/scripts/check-query-plans.ts`
- Modify: `web/package.json`

- [ ] Write regression tests for direct URL auth, cross-owner CRUD/linking, RLS parameter tampering, signed URL expiry, Service Role bundle absence, soft delete, concurrency 409, idempotent retries, and append-only denial.
- [ ] Add query-plan assertions for Dashboard, Search, Timeline, Customer detail, Opportunity projection, and Report generation using seeded scale data.
- [ ] Run the new gate and observe any failures before optimization.
- [ ] Add only indexes proven necessary by EXPLAIN; rerun until the documented budgets pass.
- [ ] Commit with `git commit -m "test: harden security and query performance"`.

### Task 3: Full production journey and deployment documentation

**Files:**
- Create: `web/e2e/mvp-closed-loop.spec.ts`
- Create: `web/docs/operations/runbook.md`
- Create: `web/docs/operations/security-checklist.md`
- Modify: `web/README.md`
- Modify: `web/package.json`

- [ ] Implement the 21-step acceptance journey from the frozen specification using isolated test-user data and private test attachments.
- [ ] Run `cd web && pnpm db:reset && pnpm verify`; expect every lint, type, unit, build, RLS, and browser suite to pass.
- [ ] Document account provisioning, environment variables, migration deployment, backup/restore, projection rebuild, Attachment cleanup, key rotation, and rollback.
- [ ] Verify a production build against staging Supabase without exposing Service Role or sample credentials.
- [ ] Commit with `git commit -m "docs: complete mvp production readiness"`.

### Task 4: Release gate

**Files:**
- Modify only files required by failures discovered in this task.

- [ ] Run `git status --short` and confirm no generated artifacts or secrets.
- [ ] Run `cd web && pnpm db:reset && pnpm verify` from a clean checkout.
- [ ] Run the security checklist manually against the deployed preview.
- [ ] Record known limitations from the frozen non-goals; do not add scope.
- [ ] Commit any verified corrections separately, then use the finishing-a-development-branch skill for merge/PR options.
