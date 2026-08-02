# Foundation Auth Audit Integration Report

Date: 2026-08-03

## Scope

Closed the Foundation integration gap between Supabase SSR authentication and the existing append-only `AuditLog` infrastructure. No domain tables or page-level visual rules were added.

## Delivered behavior

- Successful password sign-in is followed by `getClaims()` verification before any business redirect.
- A verified sign-in appends `SignedIn / AuthSession` through the existing server-only `writeAuditLog` boundary.
- Sign-in audit failure is **fail-closed**: the newly established session is revoked and the action returns the existing safe login error route.
- Sign-out verifies the current claims and attempts `SignedOut / AuthSession` before session invalidation.
- Sign-out audit failure is **fail-open for logout availability**: audit failure is contained and session invalidation still runs.
- Audit entries contain only the verified subject UUID, action, entity type, empty changed fields, and empty metadata. Email, password, tokens, and request bodies are not forwarded.
- The existing `/login` redirects, public `/design-system` boundary, and no-signup behavior remain unchanged.

## TDD evidence

1. `session-audit.test.ts` initially failed because the orchestration module did not exist.
2. After the minimal sign-in implementation, failure-path and sign-out tests failed because audit errors were not handled and `signOutWithAudit` did not exist.
3. `login-actions.test.ts` then failed because the server actions still called Supabase Auth directly.
4. Minimal implementations were added after each observed failure; focused tests then passed.

## Tests added or updated

- Unit tests for:
  - verified and sanitized `SignedIn` audit;
  - rejected credentials producing no audit;
  - invalid claims revoking the new session and producing no audit;
  - sign-in audit failure revoking the new session;
  - `SignedOut` audit ordering before invalidation;
  - logout completing when audit writing fails;
  - login/logout Server Actions routing through the audited orchestration.
- Local authenticated Playwright test now:
  - creates an isolated local-only Supabase user;
  - signs in through the real page;
  - signs out through the real page;
  - reads `audit_logs` through the isolated user's authenticated RLS context;
  - asserts ordered `SignedIn` and `SignedOut` rows exist;
  - asserts serialized rows contain neither test email, test password, nor token fields.

Because `AuditLog` is intentionally immutable and references the authenticated owner, the local E2E user is not deleted independently. It is removed by the next local database reset. The E2E suite refuses non-loopback Supabase URLs.

## Fresh verification

- `pnpm lint` — passed.
- `pnpm typecheck` — passed.
- `pnpm test` — 32 files, 118 tests passed.
- `pnpm build` — production build passed.
- `pnpm test:e2e` with local Supabase credentials — 11 tests passed.
- `pnpm test:rls` after E2E — 2 pgTAP files, 111 assertions passed.

## Files

- `web/src/lib/auth/session-audit.ts`
- `web/src/app/(public)/login/actions.ts`
- `web/src/tests/auth/session-audit.test.ts`
- `web/src/tests/auth/login-actions.test.ts`
- `web/e2e/auth.spec.ts`
