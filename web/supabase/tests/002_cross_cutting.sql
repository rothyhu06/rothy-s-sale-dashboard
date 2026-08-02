begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

select has_type('public', 'attachment_storage_status', 'attachment storage status enum exists');
select has_table('public', 'attachments', 'attachments table exists');
select has_table('public', 'attachment_links', 'attachment link scaffold exists');
select has_table('public', 'tags', 'tags table exists');
select has_table('public', 'tag_links', 'tag link scaffold exists');

select col_not_null('public', 'attachments', 'owner_id', 'attachment owner is required');
select col_not_null('public', 'attachment_links', 'owner_id', 'attachment link owner is required');
select col_not_null('public', 'tags', 'owner_id', 'tag owner is required');
select col_not_null('public', 'tag_links', 'owner_id', 'tag link owner is required');
select col_not_null('public', 'attachments', 'version', 'attachments use optimistic versions');
select col_not_null('public', 'tags', 'version', 'tags use optimistic versions');

select policies_are(
  'public', 'attachments',
  array['attachments_delete_denied', 'attachments_insert_denied', 'attachments_select_owner', 'attachments_update_denied'],
  'attachment metadata defines an explicit policy for every CRUD operation'
);
select policies_are(
  'public', 'attachment_links',
  array['attachment_links_delete_denied', 'attachment_links_insert_denied', 'attachment_links_select_owner', 'attachment_links_update_denied'],
  'attachment links define an explicit policy for every CRUD operation'
);
select policies_are(
  'public', 'tags',
  array['tags_delete_denied', 'tags_insert_denied', 'tags_select_owner', 'tags_update_denied'],
  'tags define an explicit policy for every CRUD operation'
);
select policies_are(
  'public', 'tag_links',
  array['tag_links_delete_denied', 'tag_links_insert_denied', 'tag_links_select_owner', 'tag_links_update_denied'],
  'tag links define an explicit policy for every CRUD operation'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.attachment_links'::regclass
      and contype = 'f'
      and conname = 'attachment_links_owner_attachment_fk'
  ),
  'attachment link has an owner-aware composite source FK'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.tag_links'::regclass
      and contype = 'f'
      and conname = 'tag_links_owner_tag_fk'
  ),
  'tag link has an owner-aware composite source FK'
);

select is(
  (select public from storage.buckets where id = 'business-attachments'),
  false,
  'business attachment bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'business-attachments'),
  104857600::bigint,
  'bucket has a 100 MiB hard ceiling'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'business_attachments_upload_pending_owner'
  ),
  'storage upload policy requires an owner Pending attachment path'
);
select ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'business_attachments%'
      and cmd = 'SELECT'
  ),
  'authenticated users receive files through signed URLs, not direct SELECT policy'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, created_at, updated_at
) values
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cross-owner@example.test', '', now(), now()),
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-0000-8000-000000000000', 'authenticated', 'authenticated', 'cross-other@example.test', '', now(), now());

set local role postgres;
insert into public.attachments (
  id, owner_id, original_filename, safe_filename, bucket_name, object_path,
  mime_type, file_extension, size_bytes, file_category, storage_status, data_level,
  prepared_operation_id
) values (
  '41000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  'proposal.pdf', 'proposal.pdf', 'business-attachments',
  '40000000-0000-4000-8000-000000000001/41000000-0000-4000-8000-000000000001/proposal.pdf',
  'application/pdf', 'pdf', 1024, 'Document', 'Pending', 'Level3',
  '43000000-0000-4000-8000-000000000001'
);
insert into public.tags (id, owner_id, name, normalized_name, data_level)
values (
  '42000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  'AI', 'ai', 'Level2'
);

select throws_ok(
  $$
    insert into public.attachment_links (owner_id, attachment_id)
    values (
      '40000000-0000-4000-8000-000000000002',
      '41000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514', null,
  'attachment links remain empty until a domain installs a real target FK'
);
select throws_ok(
  $$
    insert into public.tag_links (owner_id, tag_id)
    values (
      '40000000-0000-4000-8000-000000000002',
      '42000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514', null,
  'tag links remain empty until a domain installs a real target FK'
);
select throws_ok(
  $$
    update public.attachments
    set storage_status = 'Available', data_level = 'Level1'
    where id = '41000000-0000-4000-8000-000000000001'
  $$,
  'P0001', 'data level cannot be downgraded',
  'Level 3 metadata cannot be downgraded'
);
select throws_ok(
  $$ delete from public.attachments where id = '41000000-0000-4000-8000-000000000001' $$,
  'P0001', 'business entities use soft delete',
  'attachment metadata rejects physical deletion even when RLS is bypassed'
);
select throws_ok(
  $$ delete from public.tags where id = '42000000-0000-4000-8000-000000000001' $$,
  'P0001', 'business entities use soft delete',
  'tags reject physical deletion even when RLS is bypassed'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select is((select count(*) from public.attachments), 1::bigint, 'owner can read own attachment metadata');
select is((select count(*) from public.tags), 1::bigint, 'owner can read own tags');
select throws_ok(
  $$ insert into public.tags (name, normalized_name) values ('Bypass', 'bypass') $$,
  '42501', null,
  'browser cannot bypass service-only tag commands'
);
select throws_ok(
  $$ update public.attachments set original_filename = 'tampered.pdf' $$,
  '42501', null,
  'browser cannot bypass the attachment Saga'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select is((select count(*) from public.attachments), 0::bigint, 'other owner cannot read attachment metadata');
select is((select count(*) from public.tags), 0::bigint, 'other owner cannot read tags');
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

select is(
  (
    select normalized_name from public.create_tag(
      '40000000-0000-4000-8000-000000000001',
      '44000000-0000-4000-8000-000000000001',
      'Secure Tag', 'secure tag', null, 'Level2'
    )
  ),
  'secure tag',
  'service-only tag command writes owner-derived normalized data'
);
select lives_ok(
  $$
    select * from public.create_tag(
      '40000000-0000-4000-8000-000000000001',
      '44000000-0000-4000-8000-000000000001',
      'Ignored Replay', 'ignored replay', null, 'Level2'
    )
  $$,
  'tag command safely replays a completed receipt'
);
select is(
  (select count(*) from public.tags where owner_id = '40000000-0000-4000-8000-000000000001' and normalized_name = 'secure tag'),
  1::bigint,
  'tag replay does not duplicate the entity'
);

create temporary table prepare_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '40000000-0000-4000-8000-000000000001',
  'PrepareAttachmentUpload',
  '44000000-0000-4000-8000-000000000002'
);
create temporary table prepared_attachment on commit drop as
select * from public.prepare_attachment_upload(
  '40000000-0000-4000-8000-000000000001',
  (select id from prepare_claim),
  (select operation_id from prepare_claim),
  'secure.pdf', 'secure.pdf', 'application/pdf', 'pdf', 6, 'Document', 'Level3', 'Customer material'
);
select is((select storage_status::text from prepared_attachment), 'Pending', 'prepare command creates Pending metadata');
select matches(
  (select object_path from prepared_attachment),
  '^40000000-0000-4000-8000-000000000001/[0-9a-f-]+/secure\.pdf$',
  'prepare command generates an owner-partitioned object path'
);

create temporary table finalize_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '40000000-0000-4000-8000-000000000001',
  'FinalizeAttachmentUpload',
  '44000000-0000-4000-8000-000000000003'
);
select is(
  (
    select storage_status::text from public.finalize_attachment_upload(
      '40000000-0000-4000-8000-000000000001',
      (select id from finalize_claim),
      (select operation_id from finalize_claim),
      (select id from prepared_attachment),
      6, 'application/pdf', repeat('a', 64)
    )
  ),
  'Available',
  'finalize command records verified object metadata as Available'
);

create temporary table delete_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '40000000-0000-4000-8000-000000000001',
  'DeleteAttachment',
  '44000000-0000-4000-8000-000000000004'
);
select is(
  (
    select storage_status::text from public.request_attachment_deletion(
      '40000000-0000-4000-8000-000000000001',
      (select id from delete_claim),
      (select operation_id from delete_claim),
      (select id from prepared_attachment),
      (select version from public.attachments where id = (select id from prepared_attachment))
    )
  ),
  'DeletePending',
  'delete request tombstones metadata before Storage removal'
);
select lives_ok(
  format(
    'select public.complete_attachment_deletion(%L, %L, %L, %L)',
    '40000000-0000-4000-8000-000000000001',
    (select id from delete_claim),
    (select operation_id from delete_claim),
    (select id from prepared_attachment)
  ),
  'delete completion is accepted only after the resource step'
);
select is(
  (select storage_status::text from public.attachments where id = (select id from prepared_attachment)),
  'Deleted',
  'confirmed deletion has a distinct terminal storage status'
);
select isnt(
  (select storage_deleted_at from public.attachments where id = (select id from prepared_attachment)),
  null::timestamptz,
  'physical deletion completion receives its own timestamp'
);
reset role;

select * from finish();
rollback;
