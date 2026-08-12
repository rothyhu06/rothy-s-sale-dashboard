create table private.merge_dependency_ignores (
  entity_type public.merge_entity_type not null,
  dependency_identifier text not null check (
    dependency_identifier ~ '^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$'
  ),
  rationale text not null check (length(btrim(rationale)) > 0),
  primary key(entity_type,dependency_identifier)
);

insert into private.merge_dependency_ignores(entity_type,dependency_identifier,rationale) values
('Customer','public.merge_previews.customer_survivor_id','Immutable preview snapshot; never reassigned during execution'),
('Customer','public.merge_previews.customer_duplicate_id','Immutable preview snapshot; never reassigned during execution'),
('Contact','public.contacts.previous_contact_id','Factual departure-history pointer intentionally survives Contact merge'),
('Contact','public.merge_previews.contact_survivor_id','Immutable preview snapshot; never reassigned during execution'),
('Contact','public.merge_previews.contact_duplicate_id','Immutable preview snapshot; never reassigned during execution');

update private.merge_hook_manifests
set expected_dependencies=case entity_type
  when 'Customer' then array[
    'public.contacts.customer_id',
    'public.customer_external_references.customer_id',
    'public.customer_knowledge_links.customer_id',
    'public.customers.merged_into_id'
  ]
  else array['public.contacts.merged_into_id']
end;

update private.merge_reassignment_hooks
set covered_dependencies=case entity_type
  when 'Customer' then array[
    'public.contacts.customer_id',
    'public.customer_external_references.customer_id',
    'public.customer_knowledge_links.customer_id',
    'public.customers.merged_into_id'
  ]
  else array['public.contacts.merged_into_id']
end
where hook_name in ('customer_builtin_links','contact_builtin_links');

create or replace function private.assert_merge_manifest_complete(
  p_entity_type public.merge_entity_type
) returns integer
language plpgsql stable security definer set search_path='' as $$
declare
  manifest private.merge_hook_manifests%rowtype;
  detected text[];
  registered text[];
  covered text[];
begin
  select * into manifest
  from private.merge_hook_manifests
  where entity_type=p_entity_type;
  if manifest.entity_type is null then
    raise exception using errcode='P0001',message='merge hook manifest is not registered';
  end if;

  with owner_aware_dependencies as (
    select distinct
      child_ns.nspname||'.'||child_table.relname||'.'||child_column.attname as identifier
    from pg_catalog.pg_constraint dependency
    join pg_catalog.pg_class child_table on child_table.oid=dependency.conrelid
    join pg_catalog.pg_namespace child_ns on child_ns.oid=child_table.relnamespace
    cross join lateral pg_catalog.generate_subscripts(dependency.conkey,1) position
    join pg_catalog.pg_attribute child_column
      on child_column.attrelid=dependency.conrelid
     and child_column.attnum=dependency.conkey[position]
    join pg_catalog.pg_attribute parent_column
      on parent_column.attrelid=dependency.confrelid
     and parent_column.attnum=dependency.confkey[position]
    where dependency.contype='f'
      and child_ns.nspname='public'
      and dependency.confrelid=case p_entity_type
        when 'Customer' then 'public.customers'::pg_catalog.regclass
        else 'public.contacts'::pg_catalog.regclass
      end
      and parent_column.attname='id'
      and exists (
        select 1
        from pg_catalog.generate_subscripts(dependency.conkey,1) owner_position
        join pg_catalog.pg_attribute owner_child_column
          on owner_child_column.attrelid=dependency.conrelid
         and owner_child_column.attnum=dependency.conkey[owner_position]
        join pg_catalog.pg_attribute owner_parent_column
          on owner_parent_column.attrelid=dependency.confrelid
         and owner_parent_column.attnum=dependency.confkey[owner_position]
        where owner_child_column.attname='owner_id'
          and owner_parent_column.attname='owner_id'
      )
  )
  select coalesce(array_agg(identifier order by identifier),'{}'::text[])
  into detected
  from owner_aware_dependencies dependency
  where not exists (
    select 1 from private.merge_dependency_ignores ignored
    where ignored.entity_type=p_entity_type
      and ignored.dependency_identifier=dependency.identifier
  );

  select coalesce(array_agg(distinct value order by value),'{}'::text[])
  into registered
  from unnest(manifest.expected_dependencies) value;

  select coalesce(array_agg(distinct dependency order by dependency),'{}'::text[])
  into covered
  from private.merge_reassignment_hooks hook
  cross join lateral unnest(hook.covered_dependencies) dependency
  where hook.entity_type=p_entity_type
    and hook.schema_version=manifest.schema_version;

  if detected is distinct from registered
    or detected is distinct from covered
    or exists (
      select 1 from private.merge_reassignment_hooks
      where entity_type=p_entity_type and schema_version<>manifest.schema_version
    ) then
    raise exception using errcode='P0001',message='merge reassignment manifest is incomplete';
  end if;
  return manifest.schema_version;
end; $$;

create table private.customer_merge_reparent_capabilities (
  transaction_id xid8 not null,
  backend_pid integer not null,
  owner_id uuid not null,
  survivor_id uuid not null,
  duplicate_id uuid not null,
  primary key(transaction_id,backend_pid,owner_id,survivor_id,duplicate_id)
);
revoke all on private.customer_merge_reparent_capabilities from public,anon,authenticated,service_role;

create or replace function private.validate_contact_history()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  previous public.contacts%rowtype;
  merge_reparent_allowed boolean:=false;
begin
  if new.previous_contact_id is null then return new; end if;
  select * into previous
  from public.contacts
  where owner_id=new.owner_id and id=new.previous_contact_id;

  if previous.id is not null
    and previous.employment_status='Left'
    and previous.customer_id=new.customer_id
    and tg_op='UPDATE' then
    select exists(
      select 1
      from private.customer_merge_reparent_capabilities capability
      where capability.transaction_id=pg_catalog.pg_current_xact_id()
        and capability.backend_pid=pg_catalog.pg_backend_pid()
        and capability.owner_id=new.owner_id
        and capability.survivor_id=new.customer_id
        and capability.duplicate_id=old.customer_id
    ) into merge_reparent_allowed;
  end if;

  if previous.id is null
    or previous.employment_status<>'Left'
    or (previous.customer_id=new.customer_id and not merge_reparent_allowed) then
    raise exception using errcode='P0001',message='previous contact must be a departed employment at another customer';
  end if;
  return new;
end; $$;

create or replace function private.reassign_customer_builtin_links(
  p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  contact_count integer;
  external_count integer;
  knowledge_count integer;
  tombstone_count integer;
  record_id uuid;
begin
  insert into private.customer_merge_reparent_capabilities(
    transaction_id,backend_pid,owner_id,survivor_id,duplicate_id
  ) values(
    pg_catalog.pg_current_xact_id(),pg_catalog.pg_backend_pid(),
    p_owner_id,p_survivor_id,p_duplicate_id
  );
  begin
    update public.contacts
    set customer_id=p_survivor_id
    where owner_id=p_owner_id
      and customer_id=p_duplicate_id
      and employment_status<>'Left';
    get diagnostics contact_count=row_count;
    delete from private.customer_merge_reparent_capabilities
    where transaction_id=pg_catalog.pg_current_xact_id()
      and backend_pid=pg_catalog.pg_backend_pid()
      and owner_id=p_owner_id
      and survivor_id=p_survivor_id
      and duplicate_id=p_duplicate_id;
  exception when others then
    delete from private.customer_merge_reparent_capabilities
    where transaction_id=pg_catalog.pg_current_xact_id()
      and backend_pid=pg_catalog.pg_backend_pid()
      and owner_id=p_owner_id
      and survivor_id=p_survivor_id
      and duplicate_id=p_duplicate_id;
    raise;
  end;

  for record_id in
    select id from public.contacts
    where owner_id=p_owner_id
      and customer_id=p_survivor_id
      and employment_status<>'Left'
  loop
    perform private.refresh_contact_search(p_owner_id,record_id);
  end loop;

  insert into public.customer_external_references(
    owner_id,customer_id,source_system,external_reference,created_at
  )
  select owner_id,p_survivor_id,source_system,external_reference,created_at
  from public.customer_external_references
  where owner_id=p_owner_id and customer_id=p_duplicate_id
  on conflict(owner_id,source_system,external_reference) do nothing;
  delete from public.customer_external_references
  where owner_id=p_owner_id and customer_id=p_duplicate_id;
  get diagnostics external_count=row_count;

  update public.customer_knowledge_links set customer_id=p_survivor_id
  where owner_id=p_owner_id and customer_id=p_duplicate_id;
  get diagnostics knowledge_count=row_count;

  update public.customers set merged_into_id=p_survivor_id
  where owner_id=p_owner_id and merged_into_id=p_duplicate_id and id<>p_survivor_id;
  get diagnostics tombstone_count=row_count;
  for record_id in
    select id from public.customers
    where owner_id=p_owner_id and merged_into_id=p_survivor_id and id<>p_duplicate_id
  loop
    perform private.refresh_customer_search(p_owner_id,record_id);
  end loop;
  return jsonb_build_object(
    'nonLeftContactsReassigned',contact_count,
    'historicalContactsPreserved',true,
    'externalReferencesProcessed',external_count,
    'knowledgeLinksPreserved',knowledge_count,
    'tombstonesFlattened',tombstone_count
  );
end; $$;

create or replace function private.merge_plan(
  p_owner_id uuid,p_entity_type public.merge_entity_type,
  p_survivor_id uuid,p_duplicate_id uuid
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare plan jsonb;manifest_version integer;
begin
  manifest_version:=private.assert_merge_manifest_complete(p_entity_type);
  if p_entity_type='Customer' then
    select jsonb_build_object(
      'contactCount',(select count(*) from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null),
      'contactIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null),
      'reparentedContactCount',(select count(*) from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and employment_status<>'Left'),
      'reparentedContactIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and employment_status<>'Left'),
      'preservedHistoricalContactCount',(select count(*) from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and employment_status='Left'),
      'preservedHistoricalContactIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and employment_status='Left'),
      'externalReferenceCount',(select count(*) from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id),
      'externalReferenceIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customer_external_references where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)),
      'knowledgeLinkCount',(select count(*) from public.customer_knowledge_links where owner_id=p_owner_id and customer_id=p_duplicate_id),
      'knowledgeLinkIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customer_knowledge_links where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)),
      'knowledgeLinkCollisions',(select coalesce(jsonb_agg(jsonb_build_object(
        'knowledgeId',collision.knowledge_id,'direction',collision.direction,
        'survivorLinkIds',collision.survivor_ids,'duplicateLinkIds',collision.duplicate_ids,
        'resolution','PreserveBoth') order by collision.knowledge_id,collision.direction),'[]')
        from (select knowledge_id,direction,
          array_agg(id order by id) filter(where customer_id=p_survivor_id) survivor_ids,
          array_agg(id order by id) filter(where customer_id=p_duplicate_id) duplicate_ids
          from public.customer_knowledge_links
          where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)
          group by knowledge_id,direction
          having count(*) filter(where customer_id=p_survivor_id)>0
             and count(*) filter(where customer_id=p_duplicate_id)>0) collision),
      'inboundTombstoneCount',(select count(*) from public.customers where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
      'inboundTombstoneIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customers where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
      'fieldChoice','Survivor','hookManifestVersion',manifest_version,
      'reassignmentHooks',(select jsonb_agg(hook_name order by execution_order) from private.merge_reassignment_hooks where entity_type='Customer' and schema_version=manifest_version)
    ) into plan;
  else
    select jsonb_build_object(
      'historyReferenceCount',(select count(*) from public.contacts where owner_id=p_owner_id and previous_contact_id=p_duplicate_id),
      'historyReferenceIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and previous_contact_id=p_duplicate_id),
      'inboundTombstoneCount',(select count(*) from public.contacts where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
      'inboundTombstoneIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
      'fieldChoice','Survivor','hookManifestVersion',manifest_version,
      'reassignmentHooks',(select jsonb_agg(hook_name order by execution_order) from private.merge_reassignment_hooks where entity_type='Contact' and schema_version=manifest_version)
    ) into plan;
  end if;
  return plan;
end; $$;

create or replace function public.execute_entity_merge(
  p_verified_user_id uuid,p_client_request_id uuid,p_preview_id uuid,
  p_preview_token text,p_plan_hash text,p_survivor_version integer,p_duplicate_version integer
) returns table(
  entity_type public.merge_entity_type,survivor_id uuid,duplicate_id uuid,
  survivor_version integer,operation_id uuid,receipt jsonb
) language plpgsql security definer set search_path='' as $$
declare
  command record;
  preview public.merge_previews%rowtype;
  current_survivor integer;
  current_duplicate integer;
  hook_results jsonb;
  new_version integer;
begin
  if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required'; end if;
  select * into command from private.claim_command_receipt(p_verified_user_id,'ExecuteEntityMerge',p_client_request_id);
  if command.status='Completed' then
    return query select
      (command.result_reference->>'entityType')::public.merge_entity_type,
      (command.result_reference->>'survivorId')::uuid,
      (command.result_reference->>'duplicateId')::uuid,
      (command.result_reference->>'survivorVersion')::integer,
      command.operation_id,command.result_reference;
    return;
  end if;
  if p_preview_token is null or length(btrim(p_preview_token))=0 then
    raise exception using errcode='P0001',message='merge preview token is required';
  end if;
  if p_plan_hash is null or length(btrim(p_plan_hash))=0 then
    raise exception using errcode='P0001',message='merge plan hash is required';
  end if;
  if p_survivor_version is null or p_duplicate_version is null then
    raise exception using errcode='P0001',message='merge entity versions are required';
  end if;
  select * into preview
  from public.merge_previews
  where owner_id=p_verified_user_id and id=p_preview_id
  for update;
  if preview.id is null then raise exception using errcode='P0001',message='merge preview not found'; end if;
  if preview.used_at is not null then raise exception using errcode='P0001',message='merge preview already used'; end if;
  if preview.expires_at<=now() then raise exception using errcode='P0001',message='merge preview expired'; end if;
  if preview.token_hash is distinct from encode(extensions.digest(p_preview_token,'sha256'),'hex')
    or preview.plan_hash is distinct from p_plan_hash
    or preview.plan_hash is distinct from encode(extensions.digest(preview.plan::text,'sha256'),'hex') then
    raise exception using errcode='P0001',message='merge preview validation failed';
  end if;
  if preview.survivor_version is distinct from p_survivor_version
    or preview.duplicate_version is distinct from p_duplicate_version then
    raise exception using errcode='40001',message='merge preview is stale';
  end if;
  if preview.entity_type='Customer' then
    perform 1 from public.customers where owner_id=p_verified_user_id and id in(preview.survivor_id,preview.duplicate_id) order by id for update;
    select version into current_survivor from public.customers where owner_id=p_verified_user_id and id=preview.survivor_id and deleted_at is null and merged_into_id is null;
    select version into current_duplicate from public.customers where owner_id=p_verified_user_id and id=preview.duplicate_id and deleted_at is null and merged_into_id is null;
  else
    perform 1 from public.contacts where owner_id=p_verified_user_id and id in(preview.survivor_id,preview.duplicate_id) order by id for update;
    select version into current_survivor from public.contacts where owner_id=p_verified_user_id and id=preview.survivor_id and deleted_at is null and merged_into_id is null;
    select version into current_duplicate from public.contacts where owner_id=p_verified_user_id and id=preview.duplicate_id and deleted_at is null and merged_into_id is null;
  end if;
  if current_survivor is distinct from preview.survivor_version
    or current_duplicate is distinct from preview.duplicate_version
    or private.merge_plan(p_verified_user_id,preview.entity_type,preview.survivor_id,preview.duplicate_id) is distinct from preview.plan then
    raise exception using errcode='40001',message='merge preview is stale';
  end if;
  hook_results:=private.run_merge_hooks(preview.entity_type,p_verified_user_id,preview.survivor_id,preview.duplicate_id);
  if preview.entity_type='Customer' then
    update public.customers set updated_at=now() where owner_id=p_verified_user_id and id=preview.survivor_id returning version into new_version;
    update public.customers set merged_into_id=preview.survivor_id,deleted_at=now(),deleted_by=p_verified_user_id where owner_id=p_verified_user_id and id=preview.duplicate_id;
    perform private.refresh_customer_search(p_verified_user_id,preview.survivor_id);
    perform private.refresh_customer_search(p_verified_user_id,preview.duplicate_id);
  else
    update public.contacts set updated_at=now() where owner_id=p_verified_user_id and id=preview.survivor_id returning version into new_version;
    update public.contacts set merged_into_id=preview.survivor_id,deleted_at=now(),deleted_by=p_verified_user_id where owner_id=p_verified_user_id and id=preview.duplicate_id;
    perform private.refresh_contact_search(p_verified_user_id,preview.survivor_id);
    perform private.refresh_contact_search(p_verified_user_id,preview.duplicate_id);
  end if;
  update public.merge_previews set used_at=now() where id=preview.id;
  perform private.append_audit_log(
    p_verified_user_id,preview.entity_type::text||'Merged',preview.entity_type::text,
    preview.survivor_id,null,p_client_request_id,command.operation_id,
    array_to_json(array['merged_into_id','deleted_at','child_reassignment'])::jsonb,
    jsonb_build_object('duplicateId',preview.duplicate_id,'previewId',preview.id,
      'planHash',preview.plan_hash,'hookResults',hook_results),
    null,null,'Success',null
  );
  perform private.complete_command_receipt(
    p_verified_user_id,command.id,command.operation_id,'Completed',preview.entity_type::text,
    preview.survivor_id,jsonb_build_object('entityType',preview.entity_type,
      'survivorId',preview.survivor_id,'duplicateId',preview.duplicate_id,
      'survivorVersion',new_version)
  );
  return query select preview.entity_type,preview.survivor_id,preview.duplicate_id,
    new_version,command.operation_id,jsonb_build_object('hookResults',hook_results);
end; $$;

revoke all on function private.assert_merge_manifest_complete(public.merge_entity_type)
from public,anon,authenticated,service_role;
