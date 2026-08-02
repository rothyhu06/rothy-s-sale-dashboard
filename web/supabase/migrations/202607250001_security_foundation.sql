create type public.data_level as enum ('Level1', 'Level2', 'Level3');
create type public.command_status as enum ('Processing', 'Completed', 'Failed');

create table public.command_receipts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  client_request_id uuid not null,
  command_type text not null check (command_type ~ '^[A-Z][A-Za-z0-9]{0,99}$'),
  operation_id uuid not null default gen_random_uuid(),
  result_entity_type text,
  result_entity_id uuid,
  result_reference jsonb,
  status public.command_status not null default 'Processing',
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint command_receipts_owner_identity unique (owner_id, id),
  constraint command_receipts_idempotency unique (owner_id, command_type, client_request_id),
  constraint command_receipts_result_reference_is_object
    check (result_reference is null or jsonb_typeof(result_reference) = 'object'),
  constraint command_receipts_completion_consistent check (
    (status = 'Processing' and completed_at is null)
    or (status in ('Completed', 'Failed') and completed_at is not null)
  )
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  actor_id uuid not null default auth.uid() references auth.users(id),
  action text not null check (length(action) between 1 and 100),
  entity_type text not null check (length(entity_type) between 1 and 100),
  entity_id uuid,
  request_id uuid,
  client_request_id uuid,
  operation_id uuid,
  occurred_at timestamptz not null default now(),
  changed_fields jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  request_ip_hash text,
  user_agent text,
  result text not null check (length(result) between 1 and 50),
  error_code text,
  constraint audit_logs_owner_identity unique (owner_id, id),
  constraint audit_logs_changed_fields_is_array
    check (jsonb_typeof(changed_fields) = 'array'),
  constraint audit_logs_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint audit_logs_request_ip_hash_length
    check (request_ip_hash is null or length(request_ip_hash) <= 256),
  constraint audit_logs_user_agent_length
    check (user_agent is null or length(user_agent) <= 1024)
);

alter table public.command_receipts enable row level security;
alter table public.command_receipts force row level security;
alter table public.audit_logs enable row level security;
alter table public.audit_logs force row level security;

create policy command_receipts_select_owner
on public.command_receipts for select
to authenticated
using (auth.uid() = owner_id);

create policy command_receipts_insert_owner
on public.command_receipts for insert
to authenticated
with check (false);

create policy command_receipts_update_owner
on public.command_receipts for update
to authenticated
using (false)
with check (false);

create policy command_receipts_delete_denied
on public.command_receipts for delete
to authenticated
using (false);

create policy audit_logs_select_owner
on public.audit_logs for select
to authenticated
using (auth.uid() = owner_id);

create policy audit_logs_insert_denied
on public.audit_logs for insert
to authenticated
with check (false);

create policy audit_logs_update_denied
on public.audit_logs for update
to authenticated
using (false)
with check (false);

create policy audit_logs_delete_denied
on public.audit_logs for delete
to authenticated
using (false);

create function public.reject_audit_log_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'audit logs are append-only';
end;
$$;

create trigger audit_logs_reject_update_or_delete
before update or delete on public.audit_logs
for each row execute function public.reject_audit_log_mutation();

create function public.protect_command_receipt_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.owner_id is distinct from old.owner_id
    or new.client_request_id is distinct from old.client_request_id
    or new.command_type is distinct from old.command_type
    or new.operation_id is distinct from old.operation_id
    or new.started_at is distinct from old.started_at
    or new.created_at is distinct from old.created_at then
    raise exception using
      errcode = 'P0001',
      message = 'command receipt identity is immutable';
  end if;

  if old.status = 'Completed' and new is distinct from old then
    raise exception using
      errcode = 'P0001',
      message = 'completed command receipts are immutable';
  end if;

  return new;
end;
$$;

create trigger command_receipts_protect_identity
before update on public.command_receipts
for each row execute function public.protect_command_receipt_identity();

create function public.reject_command_receipt_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'command receipts cannot be deleted';
end;
$$;

create trigger command_receipts_reject_delete
before delete on public.command_receipts
for each row execute function public.reject_command_receipt_delete();

create function public.write_audit_log(
  p_action text,
  p_entity_type text,
  p_entity_id uuid default null,
  p_request_id uuid default null,
  p_client_request_id uuid default null,
  p_operation_id uuid default null,
  p_changed_fields jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb,
  p_request_ip_hash text default null,
  p_user_agent text default null,
  p_result text default 'Success',
  p_error_code text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_owner uuid := auth.uid();
  audit_id uuid;
begin
  if current_owner is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  insert into public.audit_logs (
    owner_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    request_id,
    client_request_id,
    operation_id,
    changed_fields,
    metadata,
    request_ip_hash,
    user_agent,
    result,
    error_code
  ) values (
    current_owner,
    current_owner,
    p_action,
    p_entity_type,
    p_entity_id,
    p_request_id,
    p_client_request_id,
    p_operation_id,
    coalesce(p_changed_fields, '[]'::jsonb),
    coalesce(p_metadata, '{}'::jsonb),
    p_request_ip_hash,
    p_user_agent,
    p_result,
    p_error_code
  )
  returning id into audit_id;

  return audit_id;
end;
$$;

revoke all on table public.command_receipts from anon, authenticated;
revoke all on table public.audit_logs from anon, authenticated;
grant select on table public.command_receipts to authenticated;
grant select on table public.audit_logs to authenticated;
grant select on table public.command_receipts to anon;
grant select on table public.audit_logs to anon;

revoke all on function public.write_audit_log(
  text, text, uuid, uuid, uuid, uuid, jsonb, jsonb, text, text, text, text
) from public, anon;
grant execute on function public.write_audit_log(
  text, text, uuid, uuid, uuid, uuid, jsonb, jsonb, text, text, text, text
) to authenticated;
revoke all on function public.reject_audit_log_mutation() from public, anon, authenticated;
revoke all on function public.protect_command_receipt_identity() from public, anon, authenticated;
revoke all on function public.reject_command_receipt_delete() from public, anon, authenticated;

comment on table public.command_receipts is
  'Infrastructure idempotency anchor; not a business event and not a projection replay source.';
comment on table public.audit_logs is
  'Append-only authenticated security and operation audit; never a Timeline source.';
