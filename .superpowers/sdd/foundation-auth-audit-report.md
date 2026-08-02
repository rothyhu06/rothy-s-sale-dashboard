# Foundation Auth Audit Integration Report

Date: 2026-08-03

## Scope

Closed the Foundation integration gap between Supabase SSR authentication and the existing append-only `AuditLog` infrastructure. No domain tables or page-level visual rules were added.

## Delivered behavior

- Successful password sign-in is followed by `getClaims()` verification before any business redirect.
- A verified sign-in appends `SignedIn / AuthSession` through the existing server-only `writeAuditLog` boundary.
- Claims or sign-in audit failure is **fail-closed**: remote rollback is attempted and local Supabase session cookies are always expired, even when remote rollback returns an error or throws.
- Sign-out captures verified claims when available, attempts remote invalidation, unconditionally expires local session cookies, and only then appends `SignedOut / AuthSession`.
- A successful remote invalidation is audited as `Success`; a returned error or exception is audited as `Failed / RemoteSignOutFailed` without copying provider error text.
- Sign-out audit failure is **fail-open for logout availability**: audit failure is contained after local invalidation has completed.
- Local cleanup delegates to the official `@supabase/ssr` cookie clearer using the exact project storage key. Only the auth cookie and its chunks at `/` are expired; unrelated cookies are preserved.
- Audit entries contain only the verified subject UUID, action, entity type, empty changed fields, and empty metadata. Email, password, tokens, and request bodies are not forwarded.
- The existing `/login` redirects, public `/design-system` boundary, and no-signup behavior remain unchanged.

## TDD evidence

1. `session-audit.test.ts` initially failed because the orchestration module did not exist.
2. After the minimal sign-in implementation, failure-path and sign-out tests failed because audit errors were not handled and `signOutWithAudit` did not exist.
3. `login-actions.test.ts` then failed because the server actions still called Supabase Auth directly.
4. Independent review tests reproduced eight failure cases: thrown claims verification, failed/thrown remote rollback, missing local cleanup, pre-invalidation logout audit, and untruthful remote failure results.
5. The cookie cleanup test first failed because no narrow cleanup boundary existed; the deterministic local-user test first failed because no reusable lifecycle helper existed.
6. Minimal implementations were added after each observed failure; focused tests then passed.

## Tests added or updated

- Unit tests for:
  - verified and sanitized `SignedIn` audit;
  - rejected credentials producing no audit;
  - failed/thrown claims verification and audit failure performing remote rollback plus local cookie cleanup;
  - local cleanup removing the current Supabase auth cookie chunks while preserving unrelated cookies;
  - `SignedOut` audit ordering after remote and local invalidation;
  - returned and thrown remote sign-out errors producing a sanitized non-success audit;
  - logout completing when claims lookup or audit writing fails;
  - login/logout Server Actions routing through the audited orchestration.
- Local authenticated Playwright test now:
  - find-or-creates one deterministic isolated local-only Supabase user and resets its password;
  - signs in through the real page;
  - signs out through the real page;
  - reads `audit_logs` through the isolated user's authenticated RLS context;
  - scopes assertions to that deterministic user and the current run;
  - asserts ordered `SignedIn` and `SignedOut` rows exist;
  - asserts serialized rows contain neither test email, test password, nor token fields.

Because `AuditLog` is intentionally immutable and references the authenticated owner, the local E2E user is reused rather than deleted or recreated on every run. The E2E suite refuses non-loopback Supabase URLs.

## Fresh verification

- `pnpm lint` — passed.
- `pnpm typecheck` — passed.
- `pnpm test` — 34 files, 124 tests passed.
- `pnpm build` — production build passed.
- `pnpm test:e2e` with local Supabase credentials — 11 tests passed.
- `pnpm test:rls` after E2E — 2 pgTAP files, 111 assertions passed.

## Files

- `web/src/lib/auth/session-audit.ts`
- `web/src/lib/auth/session-cookies.ts`
- `web/src/app/(public)/login/actions.ts`
- `web/src/tests/auth/session-audit.test.ts`
- `web/src/tests/auth/session-cookies.test.ts`
- `web/src/tests/auth/local-test-user.test.ts`
- `web/src/tests/auth/login-actions.test.ts`
- `web/e2e/support/local-test-user.ts`
- `web/e2e/auth.spec.ts`
