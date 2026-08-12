begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
('91000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','merge-contract@example.test','',now(),now());

set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Dependency Survivor','ignored','University'),
('92000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','Dependency Duplicate','ignored','University'),
('92000000-0000-4000-8000-000000000011','91000000-0000-4000-8000-000000000001','History Survivor','ignored','University'),
('92000000-0000-4000-8000-000000000012','91000000-0000-4000-8000-000000000001','History Duplicate','ignored','University'),
('92000000-0000-4000-8000-000000000021','91000000-0000-4000-8000-000000000001','Version Survivor','ignored','University'),
('92000000-0000-4000-8000-000000000022','91000000-0000-4000-8000-000000000001','Version Duplicate','ignored','University');

select has_table('private','merge_dependency_ignores','intentional historical and preview references have an explicit ignore registry');
select ok(exists(
  select 1 from private.merge_dependency_ignores
  where entity_type='Contact'
    and dependency_identifier='public.contacts.previous_contact_id'
    and length(btrim(rationale))>0
),'historical Contact pointer ignore has a rationale');

create table public.test_future_customer_dependents(
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  customer_id uuid not null,
  unique(owner_id,id),
  foreign key(owner_id,customer_id) references public.customers(owner_id,id)
);
insert into public.test_future_customer_dependents(owner_id,customer_id)
values('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002');

reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select throws_ok($$select * from public.preview_entity_merge(
  '91000000-0000-4000-8000-000000000001','Customer',
  '92000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002')$$,
  'P0001','merge reassignment manifest is incomplete',
  'a real owner-aware FK automatically fails closed without manual manifest edits');

reset role;
set local role postgres;
create function private.reassign_test_future_customer_dependents(
  p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare moved integer;
begin
  update public.test_future_customer_dependents
  set customer_id=p_survivor_id
  where owner_id=p_owner_id and customer_id=p_duplicate_id;
  get diagnostics moved=row_count;
  return jsonb_build_object('rowsReassigned',moved);
end; $$;
update private.merge_hook_manifests
set expected_dependencies=array_append(expected_dependencies,'public.test_future_customer_dependents.customer_id')
where entity_type='Customer';
insert into private.merge_reassignment_hooks(
  entity_type,hook_name,function_name,execution_order,schema_version,covered_dependencies
) values(
  'Customer','test_future_customer_dependents',
  'private.reassign_test_future_customer_dependents(uuid,uuid,uuid)'::regprocedure,
  50,1,array['public.test_future_customer_dependents.customer_id']
);

reset role;
set local role service_role;
create temporary table dependency_preview as select * from public.preview_entity_merge(
  '91000000-0000-4000-8000-000000000001','Customer',
  '92000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002');
select pass('registering the stable FK identifier and a concrete hook restores preview');
create temporary table dependency_merge as select * from public.execute_entity_merge(
  '91000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',
  (select preview_id from dependency_preview),(select preview_token from dependency_preview),
  (select plan_hash from dependency_preview),(select survivor_version from dependency_preview),
  (select duplicate_version from dependency_preview));
reset role;
set local role postgres;
select is(
  (select customer_id from public.test_future_customer_dependents limit 1),
  '92000000-0000-4000-8000-000000000001'::uuid,
  'registered future dependency hook performs the reassignment'
);

insert into public.contacts(
  id,owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence
) values
('94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000011','Prior Left at Survivor','Left','Dormant','Unknown'),
('94000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000012','Unknown at Duplicate','Unknown','Unknown','Unknown'),
('94000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000012','Active at Duplicate','Active','Developing','Unknown'),
('94000000-0000-4000-8000-000000000004','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000012','Left at Duplicate','Left','Dormant','Unknown');
update public.contacts
set previous_contact_id='94000000-0000-4000-8000-000000000001'
where id='94000000-0000-4000-8000-000000000002';
select throws_ok($$update public.contacts
  set customer_id='92000000-0000-4000-8000-000000000011'
  where id='94000000-0000-4000-8000-000000000002'$$,
  'P0001','previous contact must be a departed employment at another customer',
  'ordinary edits cannot collapse employment history onto one Customer');

reset role;
set local role service_role;
create temporary table history_preview as select * from public.preview_entity_merge(
  '91000000-0000-4000-8000-000000000001','Customer',
  '92000000-0000-4000-8000-000000000011','92000000-0000-4000-8000-000000000012');
select is((select (plan->>'reparentedContactCount')::integer from history_preview),2,
  'preview counts Active and Unknown Contacts as reparented');
select set_eq(
  $$select jsonb_array_elements_text(plan->'reparentedContactIds') from history_preview$$,
  array['94000000-0000-4000-8000-000000000002','94000000-0000-4000-8000-000000000003'],
  'preview identifies every non-Left Contact to reparent'
);
select is((select (plan->>'preservedHistoricalContactCount')::integer from history_preview),1,
  'preview counts Left Contacts as preserved history');
select set_eq(
  $$select jsonb_array_elements_text(plan->'preservedHistoricalContactIds') from history_preview$$,
  array['94000000-0000-4000-8000-000000000004'],
  'preview identifies the Left Contact retained on the duplicate tombstone'
);
create temporary table history_merge as select * from public.execute_entity_merge(
  '91000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000011',
  (select preview_id from history_preview),(select preview_token from history_preview),
  (select plan_hash from history_preview),(select survivor_version from history_preview),
  (select duplicate_version from history_preview));
reset role;
set local role postgres;
select is((select customer_id from public.contacts where id='94000000-0000-4000-8000-000000000002'),
  '92000000-0000-4000-8000-000000000011'::uuid,'Unknown Contact is reparented by Customer merge');
select is((select customer_id from public.contacts where id='94000000-0000-4000-8000-000000000003'),
  '92000000-0000-4000-8000-000000000011'::uuid,'Active Contact is reparented by Customer merge');
select is((select customer_id from public.contacts where id='94000000-0000-4000-8000-000000000004'),
  '92000000-0000-4000-8000-000000000012'::uuid,'Left Contact retains its historical duplicate Customer');
select is((select previous_contact_id from public.contacts where id='94000000-0000-4000-8000-000000000002'),
  '94000000-0000-4000-8000-000000000001'::uuid,'merge preserves the factual previous-contact pointer');

reset role;
set local role service_role;
create temporary table version_preview as select * from public.preview_entity_merge(
  '91000000-0000-4000-8000-000000000001','Customer',
  '92000000-0000-4000-8000-000000000021','92000000-0000-4000-8000-000000000022');
select throws_ok(format($f$select * from public.execute_entity_merge(
  '91000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000021',
  %L,%L,%L,null,%s)$f$,
  (select preview_id from version_preview),(select preview_token from version_preview),
  (select plan_hash from version_preview),(select duplicate_version from version_preview)),
  'P0001','merge entity versions are required','NULL survivor version is explicitly rejected');
select throws_ok(format($f$select * from public.execute_entity_merge(
  '91000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000022',
  %L,%L,%L,%s,null)$f$,
  (select preview_id from version_preview),(select preview_token from version_preview),
  (select plan_hash from version_preview),(select survivor_version from version_preview)),
  'P0001','merge entity versions are required','NULL duplicate version is explicitly rejected');

select * from finish();
rollback;
