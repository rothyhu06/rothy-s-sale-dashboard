# Security release checklist

- Public registration and invitations remain disabled.
- Anonymous access is limited to `/login` and `/design-system`.
- Every business table has non-null `owner_id`, forced RLS, and owner-only reads.
- Browser roles cannot execute service-only business commands or mutate append-only history.
- Service Role exists only in the server runtime and is absent from browser bundles.
- Level 3 customer, contact, opportunity, meeting and attachment data is not sent to external AI.
- Contact channels are excluded from broad SearchDocument text.
- Private attachments have no permanent public URL; downloads use short-lived signed URLs.
- Login, logout, sensitive attachment access, deletion, export, and projection rebuild are audited without credentials or full sensitive text.
- Soft deletion is used for business authorities; append-only histories and AuditLog are retained.
- `pnpm db:reset`, `pnpm test:rls`, lint, typecheck, unit tests, build and Playwright pass against local Supabase.
