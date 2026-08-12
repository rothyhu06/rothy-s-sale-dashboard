### Task 1: Customer and Contact schema, commands, and merge

**Files:**
- Create: `web/supabase/migrations/202607250201_customer_contact.sql`
- Create: `web/supabase/tests/201_customer_contact_rls.sql`
- Create: `web/src/features/customers/schema.ts`
- Create: `web/src/features/customers/actions.ts`
- Create: `web/src/features/customers/queries.ts`
- Create: `web/src/features/customers/merge.ts`
- Create: `web/src/features/contacts/schema.ts`
- Create: `web/src/features/contacts/actions.ts`
- Create: `web/src/features/contacts/queries.ts`
- Test: `web/src/tests/features/customer-merge.test.ts`

**Interfaces:**
- Produces Customer, CustomerExternalReference, Contact, CustomerKnowledgeLink and merge commands.

- [ ] Write failing tests for normalized-name duplicate warnings, owner-aware references, Contact departure history, applicability requirements, stale preview rejection, and Survivor Tombstone routing.
- [ ] Run database and unit tests; expect failure.
- [ ] Implement schema and commands with Preview Token + Plan Hash + entity versions.
- [ ] Run `pnpm db:reset && pnpm test:rls && pnpm test -- src/tests/features/customer-merge.test.ts`; expect PASS.
- [ ] Commit with `git commit -m "feat: add customer and contact domain"`.
