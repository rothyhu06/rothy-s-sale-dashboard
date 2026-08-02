create type public.attachment_storage_status as enum (
  'Pending', 'Available', 'UploadFailed', 'DeletePending', 'DeleteFailed', 'Deleted'
);
create type public.attachment_file_category as enum ('Document', 'Image', 'Text', 'Data', 'Other');

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  original_filename text not null check (length(original_filename) between 1 and 255),
  safe_filename text not null check (
    length(safe_filename) between 1 and 180
    and safe_filename = lower(safe_filename)
    and safe_filename ~ '^[a-z0-9][a-z0-9._-]*$'
    and safe_filename !~ '\.\.'
  ),
  bucket_name text not null default 'business-attachments' check (bucket_name = 'business-attachments'),
  object_path text not null,
  mime_type text not null check (length(mime_type) between 1 and 255),
  file_extension text not null check (file_extension ~ '^[a-z0-9]{1,10}$'),
  size_bytes bigint not null check (size_bytes between 0 and 104857600),
  checksum_sha256 text check (checksum_sha256 is null or checksum_sha256 ~ '^[a-f0-9]{64}$'),
  file_category public.attachment_file_category not null,
  storage_status public.attachment_storage_status not null default 'Pending',
  storage_error_code text check (storage_error_code is null or length(storage_error_code) <= 100),
  data_level public.data_level not null default 'Level2',
  classification_reason text,
  uploaded_at timestamptz,
  storage_deleted_at timestamptz,
  prepared_operation_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  constraint attachments_owner_identity unique (owner_id, id),
  constraint attachments_object_path_unique unique (bucket_name, object_path),
  constraint attachments_prepare_operation_unique unique (owner_id, prepared_operation_id),
  constraint attachments_owner_path check (
    object_path = owner_id::text || '/' || id::text || '/' || safe_filename
  ),
  constraint attachments_lifecycle_consistent check (
    (storage_status = 'Pending' and uploaded_at is null and storage_deleted_at is null and deleted_at is null)
    or (storage_status = 'Available' and uploaded_at is not null and checksum_sha256 is not null and storage_deleted_at is null and deleted_at is null)
    or (storage_status = 'UploadFailed' and uploaded_at is null and storage_deleted_at is null and deleted_at is null)
    or (storage_status in ('DeletePending', 'DeleteFailed') and uploaded_at is not null and storage_deleted_at is null and deleted_at is not null and deleted_by is not null)
    or (storage_status = 'Deleted' and storage_deleted_at is not null and deleted_at is not null and deleted_by is not null)
  )
);

create table public.attachment_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  attachment_id uuid not null,
  created_at timestamptz not null default now(),
  constraint attachment_links_owner_identity unique (owner_id, id),
  constraint attachment_links_owner_attachment_fk foreign key (owner_id, attachment_id)
    references public.attachments(owner_id, id),
  constraint attachment_links_target_not_installed check (false)
);

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  name text not null check (length(btrim(name)) between 1 and 80),
  normalized_name text not null check (
    length(normalized_name) between 1 and 80
    and normalized_name = lower(btrim(normalized_name))
  ),
  description text check (description is null or length(description) <= 500),
  data_level public.data_level not null default 'Level2',
  classification_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  constraint tags_owner_identity unique (owner_id, id)
);

create unique index tags_active_normalized_name_unique
on public.tags(owner_id, normalized_name)
where deleted_at is null;

create table public.tag_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  tag_id uuid not null,
  created_at timestamptz not null default now(),
  constraint tag_links_owner_identity unique (owner_id, id),
  constraint tag_links_owner_tag_fk foreign key (owner_id, tag_id)
    references public.tags(owner_id, id),
  constraint tag_links_target_not_installed check (false)
);

create function public.guard_mutable_entity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.owner_id is distinct from old.owner_id or new.created_at is distinct from old.created_at then
    raise exception using errcode = 'P0001', message = 'entity identity is immutable';
  end if;
  if new.data_level::text < old.data_level::text then
    raise exception using errcode = 'P0001', message = 'data level cannot be downgraded';
  end if;
  new.updated_at := now();
  new.version := old.version + 1;
  return new;
end;
$$;

create trigger attachments_guard_mutation
before update on public.attachments
for each row execute function public.guard_mutable_entity();
create trigger tags_guard_mutation
before update on public.tags
for each row execute function public.guard_mutable_entity();

create function public.reject_mutable_entity_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = 'business entities use soft delete';
end;
$$;

create trigger attachments_reject_physical_delete
before delete on public.attachments
for each row execute function public.reject_mutable_entity_delete();
create trigger tags_reject_physical_delete
before delete on public.tags
for each row execute function public.reject_mutable_entity_delete();

create function public.guard_attachment_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.storage_status = 'Pending' and new.storage_status not in ('Available', 'UploadFailed')
    or old.storage_status = 'Available' and new.storage_status <> 'DeletePending'
    or old.storage_status = 'UploadFailed'
    or old.storage_status = 'DeletePending' and new.storage_status not in ('Deleted', 'DeleteFailed')
    or old.storage_status = 'DeleteFailed' and new.storage_status <> 'DeletePending'
    or old.storage_status = 'Deleted' then
    raise exception using errcode = 'P0001', message = 'invalid attachment lifecycle transition';
  end if;
  return new;
end;
$$;

create trigger attachments_guard_lifecycle
before update of storage_status on public.attachments
for each row when (old.storage_status is distinct from new.storage_status)
execute function public.guard_attachment_lifecycle();

alter table public.attachments enable row level security;
alter table public.attachments force row level security;
alter table public.attachment_links enable row level security;
alter table public.attachment_links force row level security;
alter table public.tags enable row level security;
alter table public.tags force row level security;
alter table public.tag_links enable row level security;
alter table public.tag_links force row level security;

create policy attachments_select_owner on public.attachments for select to authenticated using (auth.uid() = owner_id);
create policy attachments_insert_denied on public.attachments for insert to authenticated with check (false);
create policy attachments_update_denied on public.attachments for update to authenticated using (false) with check (false);
create policy attachments_delete_denied on public.attachments for delete to authenticated using (false);
create policy attachment_links_select_owner on public.attachment_links for select to authenticated using (auth.uid() = owner_id);
create policy attachment_links_insert_denied on public.attachment_links for insert to authenticated with check (false);
create policy attachment_links_update_denied on public.attachment_links for update to authenticated using (false) with check (false);
create policy attachment_links_delete_denied on public.attachment_links for delete to authenticated using (false);
create policy tags_select_owner on public.tags for select to authenticated using (auth.uid() = owner_id);
create policy tags_insert_denied on public.tags for insert to authenticated with check (false);
create policy tags_update_denied on public.tags for update to authenticated using (false) with check (false);
create policy tags_delete_denied on public.tags for delete to authenticated using (false);
create policy tag_links_select_owner on public.tag_links for select to authenticated using (auth.uid() = owner_id);
create policy tag_links_insert_denied on public.tag_links for insert to authenticated with check (false);
create policy tag_links_update_denied on public.tag_links for update to authenticated using (false) with check (false);
create policy tag_links_delete_denied on public.tag_links for delete to authenticated using (false);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-attachments', 'business-attachments', false, 104857600,
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'image/png', 'image/jpeg', 'image/webp', 'text/plain', 'text/markdown', 'text/csv'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy business_attachments_upload_pending_owner
on storage.objects for insert to authenticated
with check (
  bucket_id = 'business-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.attachments
    where attachments.owner_id = auth.uid()
      and attachments.object_path = name
      and attachments.storage_status = 'Pending'
      and attachments.deleted_at is null
  )
);

create function private.require_processing_receipt(
  p_owner_id uuid, p_receipt_id uuid, p_operation_id uuid, p_command_type text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.command_receipts
    where owner_id = p_owner_id and id = p_receipt_id and operation_id = p_operation_id
      and command_type = p_command_type and status = 'Processing'
  ) then
    raise exception using errcode = 'P0001', message = 'processing command receipt not found';
  end if;
end;
$$;

create function public.prepare_attachment_upload(
  p_verified_user_id uuid, p_receipt_id uuid, p_operation_id uuid,
  p_original_filename text, p_safe_filename text, p_mime_type text,
  p_file_extension text, p_size_bytes bigint, p_file_category public.attachment_file_category,
  p_data_level public.data_level, p_classification_reason text default null
)
returns table (id uuid, object_path text, storage_status public.attachment_storage_status, data_level public.data_level)
language plpgsql
security definer
set search_path = ''
as $$
declare attachment public.attachments%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  perform private.require_processing_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'PrepareAttachmentUpload');
  attachment.id := gen_random_uuid();
  insert into public.attachments (
    id, owner_id, original_filename, safe_filename, object_path, mime_type,
    file_extension, size_bytes, file_category, data_level, classification_reason, prepared_operation_id
  ) values (
    attachment.id, p_verified_user_id, p_original_filename, p_safe_filename,
    p_verified_user_id::text || '/' || attachment.id::text || '/' || p_safe_filename,
    p_mime_type, p_file_extension, p_size_bytes, p_file_category, p_data_level,
    p_classification_reason, p_operation_id
  ) returning * into attachment;
  perform private.append_audit_log(
    p_verified_user_id, 'AttachmentUploadPrepared', 'Attachment', attachment.id,
    null, null, p_operation_id, '[]'::jsonb,
    jsonb_build_object('dataLevel', attachment.data_level, 'sizeBytes', attachment.size_bytes),
    null, null, 'Success', null
  );
  perform private.complete_command_receipt(
    p_verified_user_id, p_receipt_id, p_operation_id, 'Completed', 'Attachment', attachment.id,
    jsonb_build_object('attachmentId', attachment.id, 'objectPath', attachment.object_path)
  );
  return query select attachment.id, attachment.object_path, attachment.storage_status, attachment.data_level;
end;
$$;

create function public.finalize_attachment_upload(
  p_verified_user_id uuid, p_receipt_id uuid, p_operation_id uuid,
  p_attachment_id uuid, p_size_bytes bigint, p_mime_type text, p_checksum_sha256 text
)
returns table (id uuid, storage_status public.attachment_storage_status, uploaded_at timestamptz, version integer)
language plpgsql
security definer
set search_path = ''
as $$
declare attachment public.attachments%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  perform private.require_processing_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'FinalizeAttachmentUpload');
  select * into attachment from public.attachments
  where owner_id = p_verified_user_id and attachments.id = p_attachment_id for update;
  if attachment.id is null or attachment.storage_status <> 'Pending' then
    raise exception using errcode = 'P0001', message = 'pending attachment not found';
  end if;
  if attachment.size_bytes <> p_size_bytes or attachment.mime_type <> p_mime_type then
    raise exception using errcode = 'P0001', message = 'uploaded object metadata mismatch';
  end if;
  update public.attachments set storage_status = 'Available', checksum_sha256 = p_checksum_sha256,
    uploaded_at = now(), storage_error_code = null
  where owner_id = p_verified_user_id and attachments.id = p_attachment_id returning * into attachment;
  perform private.append_audit_log(
    p_verified_user_id, 'AttachmentUploadFinalized', 'Attachment', attachment.id,
    null, null, p_operation_id, array_to_json(array['storage_status'])::jsonb,
    jsonb_build_object('dataLevel', attachment.data_level), null, null, 'Success', null
  );
  perform private.complete_command_receipt(
    p_verified_user_id, p_receipt_id, p_operation_id, 'Completed', 'Attachment', attachment.id,
    jsonb_build_object('attachmentId', attachment.id, 'storageStatus', attachment.storage_status)
  );
  return query select attachment.id, attachment.storage_status, attachment.uploaded_at, attachment.version;
end;
$$;

create function public.fail_attachment_upload(
  p_verified_user_id uuid, p_receipt_id uuid, p_operation_id uuid,
  p_attachment_id uuid, p_error_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  perform private.require_processing_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'FinalizeAttachmentUpload');
  update public.attachments set storage_status = 'UploadFailed', storage_error_code = left(p_error_code, 100)
  where owner_id = p_verified_user_id and id = p_attachment_id and storage_status = 'Pending';
  perform private.append_audit_log(p_verified_user_id, 'AttachmentUploadFailed', 'Attachment', p_attachment_id,
    null, null, p_operation_id, '[]'::jsonb, '{}'::jsonb, null, null, 'Failed', left(p_error_code, 100));
  perform private.complete_command_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'Failed', 'Attachment', p_attachment_id, null);
end;
$$;

create function public.request_attachment_deletion(
  p_verified_user_id uuid, p_receipt_id uuid, p_operation_id uuid,
  p_attachment_id uuid, p_expected_version integer
)
returns table (id uuid, object_path text, storage_status public.attachment_storage_status, version integer)
language plpgsql
security definer
set search_path = ''
as $$
declare attachment public.attachments%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  perform private.require_processing_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'DeleteAttachment');
  update public.attachments as target set storage_status = 'DeletePending', deleted_at = now(), deleted_by = p_verified_user_id,
    storage_error_code = null
  where target.owner_id = p_verified_user_id and target.id = p_attachment_id
    and target.storage_status in ('Available', 'DeleteFailed') and target.version = p_expected_version
  returning target.* into attachment;
  if attachment.id is null then raise exception using errcode = 'P0001', message = 'attachment version conflict'; end if;
  perform private.append_audit_log(p_verified_user_id, 'AttachmentDeleteRequested', 'Attachment', attachment.id,
    null, null, p_operation_id, array_to_json(array['deleted_at','storage_status'])::jsonb,
    jsonb_build_object('dataLevel', attachment.data_level), null, null, 'Success', null);
  return query select attachment.id, attachment.object_path, attachment.storage_status, attachment.version;
end;
$$;

create function public.complete_attachment_deletion(
  p_verified_user_id uuid, p_receipt_id uuid, p_operation_id uuid, p_attachment_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  perform private.require_processing_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'DeleteAttachment');
  update public.attachments set storage_status = 'Deleted', storage_deleted_at = now(), storage_error_code = null
  where owner_id = p_verified_user_id and id = p_attachment_id and storage_status = 'DeletePending';
  if not found then raise exception using errcode = 'P0001', message = 'delete-pending attachment not found'; end if;
  perform private.append_audit_log(p_verified_user_id, 'AttachmentDeleted', 'Attachment', p_attachment_id,
    null, null, p_operation_id, array_to_json(array['storage_status','storage_deleted_at'])::jsonb,
    '{}'::jsonb, null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'Completed', 'Attachment', p_attachment_id,
    jsonb_build_object('attachmentId', p_attachment_id, 'storageStatus', 'Deleted'));
end;
$$;

create function public.fail_attachment_deletion(
  p_verified_user_id uuid, p_receipt_id uuid, p_operation_id uuid,
  p_attachment_id uuid, p_error_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  perform private.require_processing_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'DeleteAttachment');
  update public.attachments set storage_status = 'DeleteFailed', storage_error_code = left(p_error_code, 100)
  where owner_id = p_verified_user_id and id = p_attachment_id and storage_status = 'DeletePending';
  if not found then raise exception using errcode = 'P0001', message = 'delete-pending attachment not found'; end if;
  perform private.append_audit_log(p_verified_user_id, 'AttachmentDeleteFailed', 'Attachment', p_attachment_id,
    null, null, p_operation_id, '[]'::jsonb, '{}'::jsonb, null, null, 'Failed', left(p_error_code, 100));
  perform private.complete_command_receipt(p_verified_user_id, p_receipt_id, p_operation_id, 'Failed', 'Attachment', p_attachment_id, null);
end;
$$;

create function public.create_tag(
  p_verified_user_id uuid, p_client_request_id uuid, p_name text,
  p_normalized_name text, p_description text, p_data_level public.data_level
)
returns table (id uuid, name text, normalized_name text, version integer)
language plpgsql
security definer
set search_path = ''
as $$
declare receipt record; tag public.tags%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'CreateTag', p_client_request_id);
  if receipt.status = 'Completed' then
    select * into tag from public.tags
    where owner_id = p_verified_user_id
      and tags.id = (receipt.result_reference ->> 'tagId')::uuid;
    return query select tag.id, tag.name, tag.normalized_name, tag.version; return;
  end if;
  insert into public.tags(owner_id, name, normalized_name, description, data_level)
  values (p_verified_user_id, p_name, p_normalized_name, p_description, p_data_level) returning * into tag;
  perform private.append_audit_log(p_verified_user_id, 'Created', 'Tag', tag.id, null, p_client_request_id,
    receipt.operation_id, array_to_json(array['name','description','data_level'])::jsonb, '{}'::jsonb, null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed', 'Tag', tag.id,
    jsonb_build_object('tagId', tag.id));
  return query select tag.id, tag.name, tag.normalized_name, tag.version;
end;
$$;

revoke all on table public.attachments, public.attachment_links, public.tags, public.tag_links from anon, authenticated, service_role;
grant select on table public.attachments, public.attachment_links, public.tags, public.tag_links to anon, authenticated;
grant select on table public.attachments, public.attachment_links, public.tags, public.tag_links to service_role;

revoke all on function public.prepare_attachment_upload(uuid,uuid,uuid,text,text,text,text,bigint,public.attachment_file_category,public.data_level,text) from public, anon, authenticated;
revoke all on function public.finalize_attachment_upload(uuid,uuid,uuid,uuid,bigint,text,text) from public, anon, authenticated;
revoke all on function public.fail_attachment_upload(uuid,uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.request_attachment_deletion(uuid,uuid,uuid,uuid,integer) from public, anon, authenticated;
revoke all on function public.complete_attachment_deletion(uuid,uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function public.fail_attachment_deletion(uuid,uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.create_tag(uuid,uuid,text,text,text,public.data_level) from public, anon, authenticated;
grant execute on function public.prepare_attachment_upload(uuid,uuid,uuid,text,text,text,text,bigint,public.attachment_file_category,public.data_level,text) to service_role;
grant execute on function public.finalize_attachment_upload(uuid,uuid,uuid,uuid,bigint,text,text) to service_role;
grant execute on function public.fail_attachment_upload(uuid,uuid,uuid,uuid,text) to service_role;
grant execute on function public.request_attachment_deletion(uuid,uuid,uuid,uuid,integer) to service_role;
grant execute on function public.complete_attachment_deletion(uuid,uuid,uuid,uuid) to service_role;
grant execute on function public.fail_attachment_deletion(uuid,uuid,uuid,uuid,text) to service_role;
grant execute on function public.create_tag(uuid,uuid,text,text,text,public.data_level) to service_role;

revoke all on function private.require_processing_receipt(uuid,uuid,uuid,text) from public, anon, authenticated, service_role;
revoke all on function public.guard_mutable_entity() from public, anon, authenticated, service_role;
revoke all on function public.guard_attachment_lifecycle() from public, anon, authenticated, service_role;
revoke all on function public.reject_mutable_entity_delete() from public, anon, authenticated, service_role;

comment on table public.attachment_links is 'Owner-aware relation scaffold. Domain migrations add real target FKs, exactly-one-target checks, and partial unique indexes before inserts are enabled.';
comment on table public.tag_links is 'Owner-aware relation scaffold. Domain migrations add real target FKs, exactly-one-target checks, and partial unique indexes before inserts are enabled.';
