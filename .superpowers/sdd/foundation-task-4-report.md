# Foundation Task 4 — Content blocks, private attachments, tags, and shared controls

## Status and commit

Task 4 implementation and the independent-review hardening are complete across:

- `3d5c9d9 feat: complete secure cross-cutting foundation`
- the follow-up security-hardening commit reported at handoff

No Knowledge, Learning, Customer, Opportunity, or other business-domain table/page was added.

## Schema and RLS

Migration `202607250002_cross_cutting.sql` adds:

- `attachment_storage_status`: Pending, Available, UploadFailed, DeletePending,
  DeleteFailed, Deleted;
- `attachment_file_category`: Document, Image, Text, Data, Other;
- mutable `attachments` and `tags` with explicit `owner_id`, `data_level`, timestamps,
  optimistic `version`, and soft-delete fields;
- `attachment_links` and `tag_links` as owner-aware relation scaffolds;
- the private `business-attachments` Storage bucket with a 100 MiB hard ceiling.

All four public tables force RLS and define explicit SELECT/INSERT/UPDATE/DELETE
policies. Authenticated users may read only their own rows. Browser mutations are denied;
controlled server commands are the only write path. Physical DELETE is rejected for
Attachment and Tag metadata even when normal RLS is bypassed.

Level 3 cannot be downgraded by an update. Storage metadata enforces an exact
`{owner_id}/{attachment_id}/{safe_filename}` path. The only authenticated Storage INSERT
policy requires an owner-matching Pending Attachment at that exact path. There is no
authenticated Storage SELECT policy: downloads use short-lived signed URLs.

## Link strategy

Foundation intentionally does not create a polymorphic `entity_type/entity_id` target.
The link scaffolds contain explicit `owner_id` and owner-aware composite source FKs:

```text
(owner_id, attachment_id) -> Attachment(owner_id, id)
(owner_id, tag_id)        -> Tag(owner_id, id)
```

Until a business slice exists, a database CHECK prevents either scaffold from receiving
rows. Each later slice adds its own nullable real owner-aware target FK, an exactly-one-
target CHECK, and a target-specific partial unique index before enabling inserts. Thus
Foundation Finalize makes an Attachment Available but cannot create a fake business Link.

## Attachment Saga

`prepareUpload()` performs server validation, claims a Saga receipt, atomically creates
Pending metadata plus AuditLog and receipt result, and then creates a signed upload token.
Every token issue or replay first calls a service-only authorization RPC that verifies the
Attachment is still Pending and records the conservative credential expiry. A completed
Prepare receipt therefore cannot mint another token after finalization or deletion starts.
The allowlist covers PDF, OOXML DOCX/XLSX/PPTX, PNG/JPEG/WebP, TXT/Markdown/CSV. Active
HTML/SVG, executables, macros, disguised double extensions, MIME mismatches, and files
above the 20 MiB application default are rejected.

`finalizeUpload()` uses a separate idempotent receipt. The server reads the Owner row and
downloads the private object. It identifies PDF and images from magic bytes, parses OOXML
ZIP containers with entry-count, size, compression-ratio, traversal, macro, and content-
type safeguards, and applies strict UTF-8/active-content checks to text. It then compares
the identified extension/category and actual size against Pending metadata, calculates
SHA-256, and atomically writes Available, AuditLog, and the completed receipt. Browser
`Blob.type`, filename, and Pending MIME are never accepted as proof of content type.
Missing, malformed, spoofed, or mismatched objects become UploadFailed rather than
Available.

Deletion is explicitly compensating, not a cross-system transaction:

```text
Available / DeleteFailed
-> database DeletePending + tombstone + stable delete operation identity + audit
-> Storage remove
-> Storage list confirms absence
-> database Deleted + storage_deleted_at + audit + completed receipt
```

Deletion is state-aware and idempotently recoverable. Replaying the original command from
DeletePending or DeleteFailed retains the original operation identity and does not fail on
the now-stale client version. If Storage is already absent, the command completes the
database receipt without another physical mutation. Active upload credentials block
physical deletion until their recorded conservative expiry, and the command returns a
retry time. Failure after the database step becomes DeleteFailed with the original Receipt
and operation identity available for an explicit retry. `deleted_at` and
`storage_deleted_at` retain distinct semantics. Tombstoned metadata is excluded from
normal owner RLS reads while service commands retain the access required for recovery.

Available attachments receive signed download URLs for 60 seconds by default and never
more than five minutes. Level 3 signed access appends a minimal AuditLog without filename,
token, URL, or file正文.

## Tag and ContentBlockDocument

`createTag()` is a pure database command: claim, normalized owner-scoped insert, audit,
and completion occur in one RPC transaction. Replaying the same command returns the
original Tag without duplication. Active normalized names are unique per Owner.

`ContentBlockDocumentSchema` is the V1 authoritative protocol for Paragraph, Heading,
List, Quote, Callout, Checklist, Code, Attachment Reference, and Image Reference blocks.
It rejects unknown/HTML blocks, malformed UUID references, unknown schema versions, extra
fields, and duplicate block IDs. `extractPlaintext()` validates first and deterministically
derives search text; browsers do not submit authoritative plaintext.

`validateAttachmentReferences()` is the shared server-only guard for future domain writes.
It validates every Attachment/Image Reference against the real Owner row, Available and
non-deleted lifecycle state, Image category where required, and returns the maximum
effective Data Level so a containing document cannot under-classify referenced files.

## Design System additions

The public Design System now exports and demonstrates:

- Checkbox;
- CommandDialog;
- Badge;
- Skeleton.

They only use Design System V2.0 semantic tokens and existing typography/motion/radius
rules. `/design-system` visibly labels all content `Demo / Sample Data`, remains database-
independent, supports Day/Night and all target viewports, respects reduced motion, and has
no serious or critical axe violations.

## TDD evidence

RED was observed before implementation:

- ContentBlock imports failed because the protocol modules did not exist;
- the four public Design System exports were undefined;
- pgTAP failed on all missing types, tables, owner fields, RLS policies, FKs, and bucket;
- Attachment/Tag action tests failed because their modules did not exist;
- object mismatch validation failed because `validateStoredObject()` did not exist.

The GREEN cycle found and corrected real defects before the final gate: missing
`service_role` metadata SELECT privilege, an ambiguous deletion RPC column, a missing
physical-delete guard, unchecked Storage metadata mismatch, an ARIA-label misuse, and an
insufficient Success Badge contrast. Independent review then added failing regression
tests for stale-version delete recovery, signed-upload replay, active-credential deletion,
tombstone visibility, binary/container identification, server-only ContentBlock attachment
validation, deterministic post-E2E pgTAP, and CommandDialog semantics before the fixes.

## Fresh verification

Local Supabase CLI values were mapped only inside command processes; no key was printed,
written to a local env file, or committed.

```text
pnpm db:reset                                      PASS
pnpm test:rls                                     PASS — 2 files / 111 tests
pnpm exec supabase db lint --local                PASS — no schema errors
pnpm lint                                         PASS — 0 errors / 0 warnings
pnpm typecheck                                    PASS
pnpm test                                         PASS — 30 files / 110 tests
pnpm build                                        PASS
pnpm exec playwright test auth/design/cross      PASS — 11/11
pnpm test:rls (again, without reset after E2E)    PASS — 2 files / 111 tests
```

The real local Storage Playwright flow proves signed upload, server-side rejection of a
spoofed PDF, denial of authenticated direct download, denial of public URL access, server
byte identification/finalization of a valid PDF, working 60-second signed download,
credential-safe DeletePending behavior, and tombstone invisibility. The second pgTAP run
proves the suite remains deterministic after E2E-created users, audit rows, receipts, and
Storage metadata exist.

## Known limits and next dependencies

- Relation targets and link creation are deliberately deferred to each real domain
  migration; empty scaffolds cannot be populated today.
- Supabase controls the signed-upload token lifetime. The application conservatively
  records 125 minutes of credential validity and postpones physical deletion until expiry;
  signed downloads remain 60 seconds by default and five minutes maximum.
- Foundation exposes Tag creation but no Tag management page. Domain pages will compose
  Tag links after installing their real FKs.
- Cleanup/retry scheduling for orphaned Pending/UploadFailed/DeleteFailed Storage objects
  is a Production Hardening concern; the lifecycle and retry primitives are already
  explicit.
- ContentBlock rendering/editor migrations remain slice concerns; this task freezes the
  protocol and server derivation helpers without adding a rich editor.
