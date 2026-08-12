# Customer / Contact Task 1 Report

## Scope

Implemented the Customer and Contact facts, safe reads, atomic create commands, and
Customer/Contact merge protocol. No Customer UI, Opportunity, pipeline stage, last
activity, next action, health, or subjective organization-size state was added.

## TDD evidence

### RED

Before production files existed, `pnpm test -- src/tests/features/customer-merge.test.ts`
failed on the missing `@/features/customers/schema` module. A fresh
`pnpm db:reset && pnpm test:rls` left the existing seven database suites green while
the new 201 suite failed its missing tables, functions, and composite-FK assertions.

### GREEN

- Fresh database reset applied `202607250201_customer_contact.sql`.
- pgTAP passed 8 files / 339 assertions.
- Database lint reported no schema errors.
- Focused and full Vitest passed 43 files / 171 tests.
- ESLint, TypeScript, and the production Next.js build exited successfully.
- Auth, cross-cutting, Knowledge/Learning, and Design System Playwright regressions
  passed 15 tests using local Supabase credentials injected only into the test process.

## Delivered boundaries

- Customer stores stable institution facts, an advisory `normalized_name` index,
  factual student/faculty/campus estimates with as-of/source provenance, and no
  manually persisted lifecycle or sales-process state. Lifecycle is exposed only as
  an explicit projection contract.
- CustomerExternalReference is a separate Level 3, owner-aware fact with
  `(owner_id, source_system, external_reference)` uniqueness.
- Contact is a Level 3 employment record. Stable position remains separate from a
  future Opportunity role; channel and contact-time preferences remain distinct;
  non-Unknown influence requires evidence; `previous_contact_id` requires a departed
  employment at another Customer.
- CustomerKnowledgeLink uses real owner-aware Customer and Knowledge FKs. `Applicable
  To` requires applicability, Low/Not Applicable require a reason, and `Sourced From`
  carries no applicability and remains Level 3.
- Customer and Contact create commands are service-only, atomic, audited,
  receipt-backed, and replay-safe. SearchDocument refresh happens in the transaction;
  Contact email/mobile/WeChat and external-reference values do not enter broad search.
- Merge preview persists only entity IDs, versions, deterministic child-ID/count
  instructions, hook names, plan hash, token hash, expiry, and consumption time. It
  never persists the raw one-time token or entity payload.
- Execute validates expiry, one-time token, plan hash, both entity versions, active
  same-owner survivor/duplicate state, and unchanged child identity sets. It locks
  deterministically, runs explicitly registered reassignment hooks, refreshes affected
  search documents, appends audit/receipt facts, and creates merged tombstones without
  physical deletion. Historical detail resolvers return survivor routing context.

## Future merge extensions

Later migrations adding child relationships must register a concrete tested function
in `private.merge_reassignment_hooks`. Execution fails closed if an entity type has no
registered hook; there is no table-existence probe or silently skipped dynamic child.

## Concerns

- Exact email/mobile lookup hashes remain empty here because the frozen MVP requires
  a server-held HMAC secret and forbids raw values in broad search; no safe SQL secret
  contract exists in this slice. Exact contact lookup belongs in the later global
  search service boundary.
- `preferred_channel`, customer type/segment/region, and current provider fields are
  bounded text because the frozen Customer/Contact section does not define enums for
  them. Frozen enums were used only where exact value sets are specified.

---

## Review follow-up: merge safety and evidence preservation

### RED

A new `202_customer_merge_hardening.sql` pgTAP suite reproduced the review findings:
NULL token and NULL plan hash reached merge execution without an exception because
SQL three-valued comparisons did not enter the validation branch, and no explicit
expected hook manifest existed. Subsequent test-first cycles demonstrated absent
inbound-tombstone planning/flattening, factual Contact history reassignment, and
same-key CustomerKnowledgeLink evidence loss.

### Corrected behavior

- Execute rejects NULL/blank token and plan hash before hashing/comparison, uses
  null-safe `IS DISTINCT FROM` checks, and retains wrong/expired/used-token rejection
  plus completed-receipt replay behavior.
- Customer and Contact repeat merges include inbound tombstone IDs/counts in the
  hashed plan, flatten every same-owner inbound redirect to the final survivor, and
  refresh each affected SearchDocument. Detail resolvers independently follow up to
  100 same-owner redirects with visited-ID cycle detection and broken-chain failure.
- `merge_hook_manifests` declares an entity-type schema version and exact expected
  dependency names. Hooks declare the same version and coverage. Preview and execute
  fail closed unless the sets match exactly; pgTAP creates a real future FK-bearing
  table and proves that declaring it without a concrete hook blocks preview.
- Contact merge leaves `previous_contact_id` untouched, so immutable departure history
  continues pointing at its Left tombstone. Customer merge reparents only active
  employment records; departed records retain their factual Customer reference.
- CustomerKnowledgeLink no longer collapses by Customer/Knowledge/direction. Preview
  exposes each collision with both link-ID sets and deterministic `PreserveBoth`
  resolution; execution reparents every link so applicability and reason evidence are
  retained without a `DO NOTHING` path.
- Expanded RLS behavior covers cross-owner read, insert, update, and delete attempts
  for Customer, Contact, CustomerExternalReference, and CustomerKnowledgeLink.

### Fresh verification

- Database reset passed; pgTAP passed 9 files / 377 assertions.
- Database lint reported no schema errors.
- Focused and full Vitest passed 43 files / 171 tests.
- ESLint, TypeScript, and the production build passed.
- Auth, cross-cutting, Knowledge/Learning, and Design System Playwright regressions
  passed 15 tests with local credentials injected only into the test process.
