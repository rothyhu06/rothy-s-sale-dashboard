# CSIG Sales OS Operations Runbook

## Provision the private account

Create the only user in Supabase Authentication → Users. Public sign-up is disabled and the application has no registration route.

## Environment variables

Browser-safe: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

Server-only: `SUPABASE_SERVICE_ROLE_KEY`. Never prefix it with `NEXT_PUBLIC_` and never paste it into Vercel client settings, screenshots, logs, or repository files.

## Deploy

1. Apply migrations in filename order with the Supabase CLI.
2. Configure the three environment variables in Vercel.
3. Deploy the `web` directory as the Next.js root.
4. Verify `/login` and the public sample-only `/design-system` route.
5. Sign in and verify Today, Knowledge, Customers, Pipeline, Interactions, Tasks, Insights, Reports, Search, Timeline, Files & Tags.

## Backup and restore

Enable scheduled Supabase backups. Before a risky migration, create an on-demand database backup and separately inventory the private `business-attachments` bucket. Restore into staging first, run migrations and `pnpm verify`, then promote.

## Projection rebuild

An authenticated owner can POST `/api/admin/projections/rebuild` with an optional UUID `Idempotency-Key`. The command deletes and recreates only that owner’s disposable SearchDocument rows. It does not modify business facts, append-only histories, reports, attachments, or AuditLog.

## Attachment recovery

Inspect `Pending`, `UploadFailed`, `DeletePending`, and `DeleteFailed` records. Retry through the application command; do not edit lifecycle columns manually. Only mark `Deleted` after Storage confirms the object is absent.

## Key rotation and rollback

Rotate the Supabase service key in Supabase, update the Vercel server-only secret, redeploy, then revoke the old key. Roll back application code before database migrations; database rollback requires a reviewed forward migration or a verified backup restore.
