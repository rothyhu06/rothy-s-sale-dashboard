# CSIG Sales OS Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish Supabase Auth, owner isolation, command/audit infrastructure, private Storage, and the missing shared UI primitives.

**Architecture:** Public and protected route groups share the frozen root theme shell. Server components and commands use request-bound Supabase clients; database functions enforce command receipts, owner-aware relations, and append-only audit behavior.

**Tech Stack:** Next.js 16, `@supabase/ssr`, `@supabase/supabase-js`, Supabase CLI, PostgreSQL RLS, Zod, Vitest, Playwright.

## Global Constraints

- `/login` and `/design-system` are the only anonymous routes.
- `SUPABASE_SERVICE_ROLE_KEY` is server-only and is excluded from normal CRUD.
- Storage bucket `business-attachments` is private with a 100 MiB hard ceiling; application default is 20 MiB.
- Design System examples remain fictional and database-independent.

---

### Task 1: Supabase toolchain and environment contract

**Files:**
- Modify: `web/package.json`
- Modify: `web/.gitignore`
- Create: `web/.env.example`
- Create: `web/supabase/config.toml`
- Create: `web/src/lib/env/server.ts`
- Create: `web/src/lib/env/public.ts`
- Test: `web/src/tests/env/env.test.ts`

**Interfaces:**
- Produces: `serverEnv()` and `publicEnv()` validated environment readers.
- Produces scripts: `db:start`, `db:stop`, `db:reset`, `db:types`, `test:rls`.

- [ ] **Step 1: Write failing environment tests**

```ts
expect(() => serverEnv({})).toThrow("SUPABASE_SERVICE_ROLE_KEY");
expect(publicEnv({ NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321", NEXT_PUBLIC_SUPABASE_ANON_KEY: "anon" }))
  .toEqual({ supabaseUrl: "http://127.0.0.1:54321", supabaseAnonKey: "anon" });
```

- [ ] **Step 2: Run the focused test**

Run: `cd web && pnpm test -- src/tests/env/env.test.ts`

Expected: FAIL because the environment modules do not exist.

- [ ] **Step 3: Add dependencies, scripts, example values, and Zod readers**

Use `z.object({...}).parse(source)`; never read the Service Role key from a client module.

- [ ] **Step 4: Verify**

Run: `cd web && pnpm test -- src/tests/env/env.test.ts && pnpm typecheck`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/package.json web/pnpm-lock.yaml web/.gitignore web/.env.example web/supabase web/src/lib/env web/src/tests/env
git commit -m "chore: configure supabase foundation"
```

### Task 2: Auth route boundary and SSR clients

**Files:**
- Create: `web/src/lib/supabase/client.ts`
- Create: `web/src/lib/supabase/server.ts`
- Create: `web/src/lib/auth/require-user.ts`
- Create: `web/src/proxy.ts`
- Create: `web/src/app/(public)/login/page.tsx`
- Create: `web/src/app/(public)/login/actions.ts`
- Move: `web/src/app/design-system/page.tsx` → `web/src/app/(public)/design-system/page.tsx`
- Create: `web/src/app/(protected)/layout.tsx`
- Move: `web/src/app/page.tsx` → `web/src/app/(protected)/page.tsx`
- Test: `web/src/tests/auth/require-user.test.ts`
- Test: `web/e2e/auth.spec.ts`

**Interfaces:**
- Produces: `createBrowserClient()`, `createServerClient()`, `requireUser()`, `signIn()`, `signOut()`.

- [ ] **Step 1: Write failing unit and browser tests**

```ts
await expect(requireUser(fakeSupabaseWithoutUser)).rejects.toMatchObject({ digest: expect.stringContaining("NEXT_REDIRECT") });
```

Playwright must assert `/customers` redirects to `/login`, `/design-system` remains public, and an authenticated `/login` redirects to `/`.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd web && pnpm test -- src/tests/auth/require-user.test.ts`

Expected: FAIL because auth helpers do not exist.

- [ ] **Step 3: Implement SSR clients and route groups**

`proxy.ts` refreshes cookies and performs only coarse redirects; protected layout and every command call `requireUser()` again. Login exposes email/password only and no signup link.

- [ ] **Step 4: Verify**

Run: `cd web && pnpm test -- src/tests/auth/require-user.test.ts && pnpm test:e2e -- e2e/auth.spec.ts`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src web/e2e/auth.spec.ts
git commit -m "feat: enforce private supabase authentication"
```

### Task 3: Security migration, CommandReceipt, and AuditLog

**Files:**
- Create: `web/supabase/migrations/202607250001_security_foundation.sql`
- Create: `web/supabase/tests/001_security_foundation.sql`
- Create: `web/src/lib/commands/command-context.ts`
- Create: `web/src/lib/audit/audit.ts`
- Test: `web/src/tests/commands/command-context.test.ts`

**Interfaces:**
- Produces database types `data_level`, `command_status`, tables `command_receipts`, `audit_logs`.
- Produces: `createCommandContext(commandType, clientRequestId)` returning `{ user, operationId }`.

- [ ] **Step 1: Write pgTAP tests first**

Tests must prove owner columns are NOT NULL, audit rows reject UPDATE/DELETE, receipts enforce `UNIQUE(owner_id, command_type, client_request_id)`, and anon cannot read either table.

- [ ] **Step 2: Reset database to observe failure**

Run: `cd web && pnpm db:reset && pnpm test:rls`

Expected: FAIL because the migration objects do not exist.

- [ ] **Step 3: Implement migration and command wrapper**

Add separate RLS policies for SELECT/INSERT/UPDATE/DELETE. `operation_id` is generated server-side; completed receipts return `result_reference`.

- [ ] **Step 4: Verify migration and unit tests**

Run: `cd web && pnpm db:reset && pnpm test:rls && pnpm test -- src/tests/commands/command-context.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/supabase web/src/lib/commands web/src/lib/audit web/src/tests/commands
git commit -m "feat: add command and audit security base"
```

### Task 4: Content blocks, private attachments, tags, and shared controls

**Files:**
- Create: `web/supabase/migrations/202607250002_cross_cutting.sql`
- Create: `web/src/lib/content-blocks/schema.ts`
- Create: `web/src/lib/content-blocks/plaintext.ts`
- Create: `web/src/features/attachments/actions.ts`
- Create: `web/src/features/tags/actions.ts`
- Create: `web/src/components/design-system/checkbox.tsx`
- Create: `web/src/components/design-system/command-dialog.tsx`
- Create: `web/src/components/design-system/badge.tsx`
- Create: `web/src/components/design-system/skeleton.tsx`
- Modify: `web/src/components/design-system/index.ts`
- Modify: `web/src/components/gallery/design-system-gallery.tsx`
- Test: `web/src/tests/content-blocks/content-blocks.test.ts`
- Test: `web/src/tests/components/public-api.test.ts`
- Test: `web/e2e/design-system.spec.ts`

**Interfaces:**
- Produces: `ContentBlockDocumentSchema`, `extractPlaintext()`, `prepareUpload()`, `finalizeUpload()`, `requestAttachmentDeletion()`.
- Produces tables `attachments`, `attachment_links`, `tags`, `tag_links`; target FKs are added slice-by-slice.

- [ ] **Step 1: Write failing schema, component, and storage-policy tests**

```ts
expect(extractPlaintext({ schemaVersion: 1, blocks: [{ id: "b1", type: "paragraph", text: "AI 教学助手" }] }))
  .toBe("AI 教学助手");
expect(() => ContentBlockDocumentSchema.parse({ schemaVersion: 1, blocks: [{ type: "html", html: "<script/>" }] })).toThrow();
```

- [ ] **Step 2: Run focused tests**

Run: `cd web && pnpm test -- src/tests/content-blocks/content-blocks.test.ts src/tests/components/public-api.test.ts`

Expected: FAIL.

- [ ] **Step 3: Implement migration, upload Saga boundaries, and components**

Create private bucket policies for `{auth.uid()}/{attachment_id}/{safe_filename}`. Use statuses Pending, Available, UploadFailed, DeletePending, DeleteFailed, Deleted. Never claim database/Storage atomicity.

- [ ] **Step 4: Verify the complete foundation**

Run: `cd web && pnpm db:reset && pnpm test:rls && pnpm lint && pnpm typecheck && pnpm test && pnpm build && pnpm test:e2e -- e2e/auth.spec.ts e2e/design-system.spec.ts`

Expected: all commands PASS.

- [ ] **Step 5: Commit**

```bash
git add web
git commit -m "feat: complete secure cross-cutting foundation"
```
