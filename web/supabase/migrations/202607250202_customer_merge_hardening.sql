create table private.merge_hook_manifests (
  entity_type public.merge_entity_type primary key,
  schema_version integer not null check (schema_version > 0),
  expected_dependencies text[] not null check (cardinality(expected_dependencies) > 0)
);

alter table private.merge_reassignment_hooks
  add column schema_version integer,
  add column covered_dependencies text[];

update private.merge_reassignment_hooks set
  schema_version = 1,
  covered_dependencies = case entity_type
    when 'Customer' then array['contacts','customer_external_references','customer_knowledge_links','merged_customer_tombstones']
    else array['merged_contact_tombstones']
  end;

alter table private.merge_reassignment_hooks
  alter column schema_version set not null,
  alter column covered_dependencies set not null,
  add constraint merge_reassignment_hooks_manifest_identity unique(entity_type,schema_version,hook_name);

insert into private.merge_hook_manifests(entity_type,schema_version,expected_dependencies) values
('Customer',1,array['active_contacts','historical_contacts_preserved','customer_external_references','customer_knowledge_links','merged_customer_tombstones']),
('Contact',1,array['contact_departure_history_preserved','merged_contact_tombstones']);

update private.merge_reassignment_hooks set covered_dependencies=
  case entity_type
    when 'Customer' then array['active_contacts','historical_contacts_preserved','customer_external_references','customer_knowledge_links','merged_customer_tombstones']
    else array['contact_departure_history_preserved','merged_contact_tombstones']
  end;

create function private.assert_merge_manifest_complete(p_entity_type public.merge_entity_type)
returns integer language plpgsql stable security definer set search_path='' as $$
declare manifest private.merge_hook_manifests%rowtype; covered text[];
begin
  select * into manifest from private.merge_hook_manifests where entity_type=p_entity_type;
  if manifest.entity_type is null then
    raise exception using errcode='P0001',message='merge hook manifest is not registered';
  end if;
  select coalesce(array_agg(distinct dependency order by dependency),'{}') into covered
  from private.merge_reassignment_hooks hook
  cross join lateral unnest(hook.covered_dependencies) dependency
  where hook.entity_type=p_entity_type and hook.schema_version=manifest.schema_version;
  if covered is distinct from (select array_agg(distinct value order by value) from unnest(manifest.expected_dependencies) value)
    or exists(select 1 from private.merge_reassignment_hooks where entity_type=p_entity_type and schema_version<>manifest.schema_version) then
    raise exception using errcode='P0001',message='merge reassignment manifest is incomplete';
  end if;
  return manifest.schema_version;
end; $$;

alter table public.customer_knowledge_links drop constraint customer_knowledge_links_unique;
create index customer_knowledge_links_lookup_idx
on public.customer_knowledge_links(owner_id,customer_id,knowledge_id,direction);

create or replace function private.reassign_customer_builtin_links(p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare contact_count integer;external_count integer;knowledge_count integer;tombstone_count integer;record_id uuid;
begin
 update public.contacts set customer_id=p_survivor_id
 where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null and employment_status='Active';
 get diagnostics contact_count=row_count;
 for record_id in select id from public.contacts where owner_id=p_owner_id and customer_id=p_survivor_id and deleted_at is null and employment_status='Active' loop
   perform private.refresh_contact_search(p_owner_id,record_id);
 end loop;
 insert into public.customer_external_references(owner_id,customer_id,source_system,external_reference,created_at)
 select owner_id,p_survivor_id,source_system,external_reference,created_at from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id
 on conflict(owner_id,source_system,external_reference) do nothing;
 delete from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id;
 get diagnostics external_count=row_count;
 update public.customer_knowledge_links set customer_id=p_survivor_id
 where owner_id=p_owner_id and customer_id=p_duplicate_id;
 get diagnostics knowledge_count=row_count;
 update public.customers set merged_into_id=p_survivor_id
 where owner_id=p_owner_id and merged_into_id=p_duplicate_id and id<>p_survivor_id;
 get diagnostics tombstone_count=row_count;
 for record_id in select id from public.customers where owner_id=p_owner_id and merged_into_id=p_survivor_id and id<>p_duplicate_id loop
   perform private.refresh_customer_search(p_owner_id,record_id);
 end loop;
 return jsonb_build_object('activeContactsReassigned',contact_count,'historicalContactsPreserved',true,'externalReferencesProcessed',external_count,'knowledgeLinksPreserved',knowledge_count,'tombstonesFlattened',tombstone_count);
end; $$;

create or replace function private.reassign_contact_builtin_links(p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tombstone_count integer;record_id uuid;
begin
 update public.contacts set merged_into_id=p_survivor_id
 where owner_id=p_owner_id and merged_into_id=p_duplicate_id and id<>p_survivor_id;
 get diagnostics tombstone_count=row_count;
 for record_id in select id from public.contacts where owner_id=p_owner_id and merged_into_id=p_survivor_id and id<>p_duplicate_id loop
   perform private.refresh_contact_search(p_owner_id,record_id);
 end loop;
 return jsonb_build_object('departureHistoryPreserved',true,'tombstonesFlattened',tombstone_count);
end; $$;

create or replace function private.merge_plan(p_owner_id uuid,p_entity_type public.merge_entity_type,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare plan jsonb;manifest_version integer;
begin
 manifest_version:=private.assert_merge_manifest_complete(p_entity_type);
 if p_entity_type='Customer' then
   select jsonb_build_object(
     'contactCount',(select count(*) from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null),
     'contactIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null),
     'externalReferenceCount',(select count(*) from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id),
     'externalReferenceIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customer_external_references where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)),
     'knowledgeLinkCount',(select count(*) from public.customer_knowledge_links where owner_id=p_owner_id and customer_id=p_duplicate_id),
     'knowledgeLinkIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customer_knowledge_links where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)),
     'knowledgeLinkCollisions',(select coalesce(jsonb_agg(jsonb_build_object(
       'knowledgeId',collision.knowledge_id,'direction',collision.direction,'survivorLinkIds',collision.survivor_ids,
       'duplicateLinkIds',collision.duplicate_ids,'resolution','PreserveBoth') order by collision.knowledge_id,collision.direction),'[]')
       from (select knowledge_id,direction,
         array_agg(id order by id) filter(where customer_id=p_survivor_id) survivor_ids,
         array_agg(id order by id) filter(where customer_id=p_duplicate_id) duplicate_ids
         from public.customer_knowledge_links where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)
         group by knowledge_id,direction
         having count(*) filter(where customer_id=p_survivor_id)>0 and count(*) filter(where customer_id=p_duplicate_id)>0) collision),
     'inboundTombstoneCount',(select count(*) from public.customers where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
     'inboundTombstoneIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customers where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
     'fieldChoice','Survivor','hookManifestVersion',manifest_version,
     'reassignmentHooks',(select jsonb_agg(hook_name order by execution_order) from private.merge_reassignment_hooks where entity_type='Customer' and schema_version=manifest_version)) into plan;
 else
   select jsonb_build_object(
     'historyReferenceCount',(select count(*) from public.contacts where owner_id=p_owner_id and previous_contact_id=p_duplicate_id),
     'historyReferenceIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and previous_contact_id=p_duplicate_id),
     'inboundTombstoneCount',(select count(*) from public.contacts where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
     'inboundTombstoneIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and merged_into_id=p_duplicate_id),
     'fieldChoice','Survivor','hookManifestVersion',manifest_version,
     'reassignmentHooks',(select jsonb_agg(hook_name order by execution_order) from private.merge_reassignment_hooks where entity_type='Contact' and schema_version=manifest_version)) into plan;
 end if; return plan;
end; $$;

create or replace function private.run_merge_hooks(p_entity_type public.merge_entity_type,p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare hook record;result jsonb:='{}'::jsonb;piece jsonb;manifest_version integer;
begin
 manifest_version:=private.assert_merge_manifest_complete(p_entity_type);
 for hook in select hook_name,function_name from private.merge_reassignment_hooks where entity_type=p_entity_type and schema_version=manifest_version order by execution_order loop
   execute format('select %s($1,$2,$3)',split_part(hook.function_name::text,'(',1)) into piece using p_owner_id,p_survivor_id,p_duplicate_id;
   result:=result||jsonb_build_object(hook.hook_name,piece);
 end loop; return result;
end; $$;

create or replace function public.resolve_customer_detail(p_customer_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare origin public.customers%rowtype;current public.customers%rowtype;visited uuid[]:='{}'::uuid[];depth integer:=0;
begin
 select * into origin from public.customers where owner_id=auth.uid() and id=p_customer_id;
 if origin.id is null then raise exception using errcode='P0002',message='Customer not found'; end if;
 current:=origin;
 while current.merged_into_id is not null loop
   if current.id=any(visited) or depth>=100 then raise exception using errcode='P0001',message='Customer merge redirect cycle'; end if;
   visited:=array_append(visited,current.id); depth:=depth+1;
   select * into current from public.customers where owner_id=auth.uid() and id=current.merged_into_id;
   if current.id is null then raise exception using errcode='P0001',message='Customer merge redirect is broken'; end if;
 end loop;
 if origin.merged_into_id is not null then return jsonb_build_object('state','Merged','tombstoneId',origin.id,'mergedIntoId',current.id,'survivorName',current.name,'route','/customers/'||current.id); end if;
 if origin.deleted_at is not null then raise exception using errcode='P0002',message='Customer not found'; end if;
 return to_jsonb(origin)-array['owner_id','deleted_by'];
end; $$;

create or replace function public.resolve_contact_detail(p_contact_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare origin public.contacts%rowtype;current public.contacts%rowtype;visited uuid[]:='{}'::uuid[];depth integer:=0;
begin
 select * into origin from public.contacts where owner_id=auth.uid() and id=p_contact_id;
 if origin.id is null then raise exception using errcode='P0002',message='Contact not found'; end if;
 current:=origin;
 while current.merged_into_id is not null loop
   if current.id=any(visited) or depth>=100 then raise exception using errcode='P0001',message='Contact merge redirect cycle'; end if;
   visited:=array_append(visited,current.id); depth:=depth+1;
   select * into current from public.contacts where owner_id=auth.uid() and id=current.merged_into_id;
   if current.id is null then raise exception using errcode='P0001',message='Contact merge redirect is broken'; end if;
 end loop;
 if origin.merged_into_id is not null then return jsonb_build_object('state','Merged','tombstoneId',origin.id,'mergedIntoId',current.id,'survivorName',current.full_name,'route','/contacts/'||current.id); end if;
 if origin.deleted_at is not null then raise exception using errcode='P0002',message='Contact not found'; end if;
 return to_jsonb(origin)-array['owner_id','deleted_by'];
end; $$;

create or replace function public.execute_entity_merge(p_verified_user_id uuid,p_client_request_id uuid,p_preview_id uuid,p_preview_token text,p_plan_hash text,p_survivor_version integer,p_duplicate_version integer)
returns table(entity_type public.merge_entity_type,survivor_id uuid,duplicate_id uuid,survivor_version integer,operation_id uuid,receipt jsonb)
language plpgsql security definer set search_path='' as $$
declare command record;preview public.merge_previews%rowtype;current_survivor integer;current_duplicate integer;hook_results jsonb;new_version integer;
begin
 if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required'; end if;
 select * into command from private.claim_command_receipt(p_verified_user_id,'ExecuteEntityMerge',p_client_request_id);
 if command.status='Completed' then return query select (command.result_reference->>'entityType')::public.merge_entity_type,(command.result_reference->>'survivorId')::uuid,(command.result_reference->>'duplicateId')::uuid,(command.result_reference->>'survivorVersion')::integer,command.operation_id,command.result_reference; return; end if;
 if p_preview_token is null or length(btrim(p_preview_token))=0 then raise exception using errcode='P0001',message='merge preview token is required'; end if;
 if p_plan_hash is null or length(btrim(p_plan_hash))=0 then raise exception using errcode='P0001',message='merge plan hash is required'; end if;
 select * into preview from public.merge_previews where owner_id=p_verified_user_id and id=p_preview_id for update;
 if preview.id is null then raise exception using errcode='P0001',message='merge preview not found'; end if;
 if preview.used_at is not null then raise exception using errcode='P0001',message='merge preview already used'; end if;
 if preview.expires_at<=now() then raise exception using errcode='P0001',message='merge preview expired'; end if;
 if preview.token_hash is distinct from encode(extensions.digest(p_preview_token,'sha256'),'hex') or preview.plan_hash is distinct from p_plan_hash or preview.plan_hash is distinct from encode(extensions.digest(preview.plan::text,'sha256'),'hex') then raise exception using errcode='P0001',message='merge preview validation failed'; end if;
 if preview.survivor_version<>p_survivor_version or preview.duplicate_version<>p_duplicate_version then raise exception using errcode='40001',message='merge preview is stale'; end if;
 if preview.entity_type='Customer' then
   perform 1 from public.customers where owner_id=p_verified_user_id and id in(preview.survivor_id,preview.duplicate_id) order by id for update;
   select version into current_survivor from public.customers where owner_id=p_verified_user_id and id=preview.survivor_id and deleted_at is null and merged_into_id is null;
   select version into current_duplicate from public.customers where owner_id=p_verified_user_id and id=preview.duplicate_id and deleted_at is null and merged_into_id is null;
 else
   perform 1 from public.contacts where owner_id=p_verified_user_id and id in(preview.survivor_id,preview.duplicate_id) order by id for update;
   select version into current_survivor from public.contacts where owner_id=p_verified_user_id and id=preview.survivor_id and deleted_at is null and merged_into_id is null;
   select version into current_duplicate from public.contacts where owner_id=p_verified_user_id and id=preview.duplicate_id and deleted_at is null and merged_into_id is null;
 end if;
 if current_survivor is distinct from preview.survivor_version or current_duplicate is distinct from preview.duplicate_version or private.merge_plan(p_verified_user_id,preview.entity_type,preview.survivor_id,preview.duplicate_id) is distinct from preview.plan then raise exception using errcode='40001',message='merge preview is stale'; end if;
 hook_results:=private.run_merge_hooks(preview.entity_type,p_verified_user_id,preview.survivor_id,preview.duplicate_id);
 if preview.entity_type='Customer' then
   update public.customers set updated_at=now() where owner_id=p_verified_user_id and id=preview.survivor_id returning version into new_version;
   update public.customers set merged_into_id=preview.survivor_id,deleted_at=now(),deleted_by=p_verified_user_id where owner_id=p_verified_user_id and id=preview.duplicate_id;
   perform private.refresh_customer_search(p_verified_user_id,preview.survivor_id); perform private.refresh_customer_search(p_verified_user_id,preview.duplicate_id);
 else
   update public.contacts set updated_at=now() where owner_id=p_verified_user_id and id=preview.survivor_id returning version into new_version;
   update public.contacts set merged_into_id=preview.survivor_id,deleted_at=now(),deleted_by=p_verified_user_id where owner_id=p_verified_user_id and id=preview.duplicate_id;
   perform private.refresh_contact_search(p_verified_user_id,preview.survivor_id); perform private.refresh_contact_search(p_verified_user_id,preview.duplicate_id);
 end if;
 update public.merge_previews set used_at=now() where id=preview.id;
 perform private.append_audit_log(p_verified_user_id,preview.entity_type::text||'Merged',preview.entity_type::text,preview.survivor_id,null,p_client_request_id,command.operation_id,array_to_json(array['merged_into_id','deleted_at','child_reassignment'])::jsonb,jsonb_build_object('duplicateId',preview.duplicate_id,'previewId',preview.id,'planHash',preview.plan_hash,'hookResults',hook_results),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,command.id,command.operation_id,'Completed',preview.entity_type::text,preview.survivor_id,jsonb_build_object('entityType',preview.entity_type,'survivorId',preview.survivor_id,'duplicateId',preview.duplicate_id,'survivorVersion',new_version));
 return query select preview.entity_type,preview.survivor_id,preview.duplicate_id,new_version,command.operation_id,jsonb_build_object('hookResults',hook_results);
end; $$;

revoke all on function private.assert_merge_manifest_complete(public.merge_entity_type) from public,anon,authenticated,service_role;
