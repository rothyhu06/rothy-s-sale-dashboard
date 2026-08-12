# Knowledge & Learning Task 3 Report

## Status and commit

Implemented the protected Knowledge and Learning product slice. Planned commit message:

`feat: deliver knowledge learning workflow`

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
  image/attachment reference types and captions when its body
  is untouched. Editing the body intentionally converts textual content to Paragraph blocks;
  the MVP Textarea cannot author Heading/List/Code/Callout structure.

## Commit hash

Task commit: `e5269bb5546d35e8d314abe8d4771fc2b031e830 feat: deliver knowledge learning workflow`.
