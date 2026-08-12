# Knowledge & Learning Task 3 Report

## Status and commits

Implemented and independently re-reviewed the protected Knowledge and Learning product slice.
The delivery sequence is:

- `4d88a3958a73d4d3d12b97d9152148a2144ba335` — `feat: deliver knowledge learning workflow`
- `718473daff6a69828c59f292c6f4401abf7f560d` — `docs: finalize knowledge learning task report`
- `69c03ceffcbfe423bf57390b1d24fd7b161782eb` — `fix: harden knowledge learning workflows`
- Final governance commit — `fix: align knowledge conversion warning with design system`

## Routes and operations

- `/knowledge`: owner-RLS library read, client-local text search and status filtering, empty/loading/error states.
- `/knowledge/new`: status/confidence/source/classification fields, Textarea to ContentBlockDocument V1, tags, available attachments, and related Knowledge.
- `/knowledge/[id]` and `/knowledge/[id]/edit`: complete source/body/business fields, tags/attachments/relations, mastery direction, real edit and Create Learning actions.
- `/learning`: real Continue Learning projection plus fact history.
- `/learning/new`: Knowledge link and fixed mastery-before creation.
- `/learning/[id]`: Knowledge/mastery relation, parent/children chain, Applied outcome, mastery-after and practice-result completion.
- `/learning/[id]/review`: creates a child Review fact and carries the parent's resulting mastery forward as the next mastery-before.

All mutations call the reviewed Task 2 server-only receipt-backed commands after the
protected layout session gate. No localStorage, mock repository, global Search route, AI
operation, or public-gallery business connection was added. Conflict errors return an
in-place message and preserve uncontrolled form values.

## Minimal Task 2 query composition

Task 2 exposed only Knowledge projection search and Continue Learning. The page slice adds
owner-RLS reads in the existing query modules for Knowledge list/detail/form support and
Learning list/detail/parent-child/mastery composition. These use the authenticated server
client and existing SELECT policies; no service role, mutation, RPC privilege, transaction,
or RLS rule was changed.

## TDD and verification

RED evidence:

- The Playwright journey failed at the missing `/knowledge` route heading after the 11
  existing E2Es passed.
- Focused page-query tests failed because `listKnowledge`, `getKnowledgeSupport`,
  `listLearning`, and `getLearning` did not exist.
- The Textarea adapter test failed on the missing form adapter.
- Design System component tests failed before page-level heading semantics and the primary
  foreground contrast fix were implemented.

Fresh GREEN evidence:

- Local reset applied migrations 001 through 104.
- pgTAP passed 6 files / 278 assertions before and after E2E; database lint found no issues.
- ESLint and TypeScript passed.
- Vitest passed 40 files / 152 tests, including query composition, exact structured ContentBlock preservation, stable form command identities, multi-link mastery composition,
  conflict safety, and Design System primitive regressions.
- Next.js production build passed and emitted every required route.
- Playwright passed 15/15: auth/audit, private Storage, sample-only public gallery, full
  Knowledge → edit → Learning → Applied completion → Review → relation/search workflow,
  axe, keyboard focus, and mobile/tablet/desktop responsive assertions/screenshots.

## Responsive and accessibility evidence

The shared protected shell uses the Design System navigation pattern: fixed bottom
navigation and 20px page padding on mobile, 72px navigation on tablet, and 224px navigation
on desktop. Screenshots were captured under `web/test-results/` during the final run.
The journey runs axe after the library and mobile flows; no violations remained.

## Limitations and concerns

- Attachment selection is limited to already finalized, owner-visible `Available` files;
  uploading new bytes remains the existing Attachment workflow and is not duplicated here.
- The personal-library local filter loads the complete owner-visible Knowledge collection;
  pagination or virtualization can be added when real usage demonstrates that it is needed.
- Textarea editing preserves the exact original structured ContentBlock V1 document, IDs,
  image/attachment reference types and captions when its body is untouched. A changed
  structured body is rejected unless the user explicitly confirms conversion after a warning
  that Heading/List/Code/Callout textual semantics will flatten into Paragraph blocks;
  selected attachment/image reference blocks and their existing captions are preserved.

## Independent-review follow-up (2026-08-12)

All independent-review findings were addressed under strict RED/GREEN TDD:

- Page actions now use one allowlisted error mapper. Zod validation, known user-safe
  validation, and optimistic conflicts receive fixed copy; auth/database/runtime details are
  never reflected. Generic failures log only operation, error type, and error code—never form
  bodies, tokens, SQL, or raw database messages.
- Learning create and Review forms select active owner tags and `Available` attachments, and
  details resolve all linked targets. Parent tag, attachment, and Knowledge links are shown
  unchecked on Review and are inherited only after explicit user selection.
- The authoritative completion entry point is now `complete_learning_exact`. The legacy
  implementation is private and not executable by `service_role`; the public wrapper requires
  submitted mastery IDs to be exactly the stored LearningKnowledgeLink set and rejects subsets,
  extras, and duplicates before mutation. Receipt replay remains stable.
- Review uses a dedicated server action bound to the route-resolved parent. Ordinary create
  ignores tampered Review/parent fields. PostgreSQL independently requires the active,
  same-owner parent to be `Completed`.
- Detail queries convert only PostgREST's explicit no-row/RLS-hidden result into
  `EntityNotFoundError`; operational failures reach the route error boundary. Mastery is shown
  as accessible named levels 1–5 without a fabricated percentage progressbar, and the filter
  reset uses a 44px Design System button.

The real-browser lifecycle resets the local database once in Playwright global setup, before
parallel workers start, and refuses a non-local Supabase URL. Fixed user/tag names are then
created on that clean database. The verified attachment follows the production prepare receipt
→ authorize credential → signed private Storage upload → finalize receipt flow. Tests never
physically delete immutable Knowledge/Learning facts and no cleanup RPC was added. Repeated
runs therefore do not accumulate users, tags, attachments, Knowledge, or Learning records.

Fresh follow-up evidence:

- `pnpm db:reset`: migrations 001–105 applied successfully.
- `pnpm test:rls`: 7 files / 283 assertions passed before and after browser execution.
- `supabase db lint --local --level warning`: zero findings.
- `pnpm lint`, `pnpm typecheck`: passed.
- `pnpm test`: 41 files / 161 tests passed.
- `pnpm build`: passed with all Knowledge/Learning routes emitted.
- Focused Knowledge/Learning Playwright: 4/4 passed.
- Full normal parallel Playwright: 15/15 passed using five workers; the expanded journey
  creates a valid attachment and two Knowledge facts, asserts relation/tag/attachment details,
  completes the exact two-link mastery set with `Applied` and practice evidence, and creates an
  explicitly linked Review child/chain. Axe and mobile/tablet/desktop assertions also pass.

The final governance pass replaces page-local warning radius/color utilities with frozen
Design System classes (`radius-card`, `border-border`, and `bg-paper`) and corrects the copy:
conversion replaces structured textual blocks with paragraphs while preserving selected
attachment/image reference blocks and their captions. The final governance commit is identified
above by its unique subject; its resulting hash is reported with the delivered verification
evidence because a commit cannot contain its own stable hash.
