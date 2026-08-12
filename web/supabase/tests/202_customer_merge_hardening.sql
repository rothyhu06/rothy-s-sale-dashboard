begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
('81000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','merge-hardening@example.test','',now(),now()),
('81000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','merge-other@example.test','',now(),now());

set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('82000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','Null Token Survivor','ignored','University'),
('82000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000001','Null Token Duplicate','ignored','University'),
('82000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000001','Null Hash Survivor','ignored','University'),
('82000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000001','Null Hash Duplicate','ignored','University'),
('82000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000001','Wrong Hash Survivor','ignored','University'),
('82000000-0000-4000-8000-000000000006','81000000-0000-4000-8000-000000000001','Wrong Hash Duplicate','ignored','University'),
('82000000-0000-4000-8000-000000000007','81000000-0000-4000-8000-000000000001','Expired Survivor','ignored','University'),
('82000000-0000-4000-8000-000000000008','81000000-0000-4000-8000-000000000001','Expired Duplicate','ignored','University');
reset role;

select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
create temporary table null_token_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000002');
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000001',%L,null,%L,%s,%s)$f$,
(select preview_id from null_token_preview),(select plan_hash from null_token_preview),(select survivor_version from null_token_preview),(select duplicate_version from null_token_preview)),
'P0001','merge preview token is required','NULL merge token is rejected before hashing');
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000005',%L,'   ',%L,%s,%s)$f$,
(select preview_id from null_token_preview),(select plan_hash from null_token_preview),(select survivor_version from null_token_preview),(select duplicate_version from null_token_preview)),
'P0001','merge preview token is required','blank merge token is rejected before hashing');
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000006',%L,'wrong-token',%L,%s,%s)$f$,
(select preview_id from null_token_preview),(select plan_hash from null_token_preview),(select survivor_version from null_token_preview),(select duplicate_version from null_token_preview)),
'P0001','merge preview validation failed','wrong merge token is rejected');

create temporary table null_hash_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000003','82000000-0000-4000-8000-000000000004');
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000002',%L,%L,null,%s,%s)$f$,
(select preview_id from null_hash_preview),(select preview_token from null_hash_preview),(select survivor_version from null_hash_preview),(select duplicate_version from null_hash_preview)),
'P0001','merge plan hash is required','NULL plan hash is rejected before comparison');
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000007',%L,%L,' ',%s,%s)$f$,
(select preview_id from null_hash_preview),(select preview_token from null_hash_preview),(select survivor_version from null_hash_preview),(select duplicate_version from null_hash_preview)),
'P0001','merge plan hash is required','blank plan hash is rejected before comparison');

create temporary table wrong_hash_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000005','82000000-0000-4000-8000-000000000006');
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000003',%L,%L,%L,%s,%s)$f$,
(select preview_id from wrong_hash_preview),(select preview_token from wrong_hash_preview),repeat('0',64),(select survivor_version from wrong_hash_preview),(select duplicate_version from wrong_hash_preview)),
'P0001','merge preview validation failed','wrong plan hash is rejected');

create temporary table expired_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000007','82000000-0000-4000-8000-000000000008');
reset role; set local role postgres;
update public.merge_previews set expires_at=now()-interval '1 second' where id=(select preview_id from expired_preview);
reset role; set local role service_role;
select throws_ok(format($f$select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000004',%L,%L,%L,%s,%s)$f$,
(select preview_id from expired_preview),(select preview_token from expired_preview),(select plan_hash from expired_preview),(select survivor_version from expired_preview),(select duplicate_version from expired_preview)),
'P0001','merge preview expired','expired preview is rejected');

select has_table('private','merge_hook_manifests','merge hooks have an explicit expected manifest');

reset role; set local role postgres;
create table public.test_future_customer_dependents(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id), customer_id uuid not null,
 unique(owner_id,id), foreign key(owner_id,customer_id) references public.customers(owner_id,id)
);
update private.merge_hook_manifests set expected_dependencies=array_append(expected_dependencies,'future_opportunities') where entity_type='Customer';
reset role; set local role service_role;
select throws_ok($$select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000002')$$,
'P0001','merge reassignment manifest is incomplete','declared future dependency without a concrete hook fails preview closed');
reset role; set local role postgres;
update private.merge_hook_manifests set expected_dependencies=array_remove(expected_dependencies,'future_opportunities') where entity_type='Customer';

insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('82000000-0000-4000-8000-000000000011','81000000-0000-4000-8000-000000000001','Chain A','ignored','University'),
('82000000-0000-4000-8000-000000000012','81000000-0000-4000-8000-000000000001','Chain B','ignored','University'),
('82000000-0000-4000-8000-000000000013','81000000-0000-4000-8000-000000000001','Chain C','ignored','University');
reset role; set local role service_role;
create temporary table chain_ab_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000012','82000000-0000-4000-8000-000000000011');
create temporary table chain_ab_result as select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000011',(select preview_id from chain_ab_preview),(select preview_token from chain_ab_preview),(select plan_hash from chain_ab_preview),(select survivor_version from chain_ab_preview),(select duplicate_version from chain_ab_preview));
create temporary table chain_bc_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000013','82000000-0000-4000-8000-000000000012');
select ok((select (plan->>'inboundTombstoneCount')::integer=1 and plan->'inboundTombstoneIds' @> '["82000000-0000-4000-8000-000000000011"]'::jsonb from chain_bc_preview),'repeat merge plan includes inbound tombstones');
create temporary table chain_bc_result as select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000012',(select preview_id from chain_bc_preview),(select preview_token from chain_bc_preview),(select plan_hash from chain_bc_preview),(select survivor_version from chain_bc_preview),(select duplicate_version from chain_bc_preview));
reset role; set local role postgres;
select is((select merged_into_id from public.customers where id='82000000-0000-4000-8000-000000000011'),'82000000-0000-4000-8000-000000000013'::uuid,'A tombstone flattens directly to final C survivor');
select is((select metadata->>'mergedIntoId' from public.search_documents where source_type='Customer' and source_id='82000000-0000-4000-8000-000000000011'),'82000000-0000-4000-8000-000000000013','flattened A SearchDocument refreshes to C');
reset role; set local role postgres; grant select on chain_bc_preview to authenticated; reset role;
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select is(public.resolve_customer_detail('82000000-0000-4000-8000-000000000011')->>'mergedIntoId','82000000-0000-4000-8000-000000000013','stale A URL routes to final C survivor');

reset role; set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('82000000-0000-4000-8000-000000000021','81000000-0000-4000-8000-000000000001','History Origin','ignored','University'),
('82000000-0000-4000-8000-000000000022','81000000-0000-4000-8000-000000000001','History Current','ignored','University');
insert into public.contacts(id,owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence) values
('84000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000021','Departed Record','Left','Dormant','Unknown'),
('84000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000021','Duplicate Employment Record','Active','Developing','Unknown'),
('84000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000022','Later Employment','Active','Developing','Unknown');
update public.contacts set previous_contact_id='84000000-0000-4000-8000-000000000001' where id='84000000-0000-4000-8000-000000000003';
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
create temporary table history_contact_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Contact','84000000-0000-4000-8000-000000000002','84000000-0000-4000-8000-000000000001');
create temporary table history_contact_result as select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000021',(select preview_id from history_contact_preview),(select preview_token from history_contact_preview),(select plan_hash from history_contact_preview),(select survivor_version from history_contact_preview),(select duplicate_version from history_contact_preview));
reset role; set local role postgres;
select is((select previous_contact_id from public.contacts where id='84000000-0000-4000-8000-000000000003'),'84000000-0000-4000-8000-000000000001'::uuid,'Contact merge preserves factual departure history reference');
select is((select customer_id from public.contacts where id='84000000-0000-4000-8000-000000000001'),'82000000-0000-4000-8000-000000000021'::uuid,'departed Contact keeps its historical Customer reference');

reset role; set local role postgres;
insert into public.knowledge(id,owner_id,title,knowledge_type,status,confidence,source_type,content_blocks) values
('85000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','Collision Knowledge','General','Ready','Verified','Customer','{"schemaVersion":1,"blocks":[]}'::jsonb);
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('82000000-0000-4000-8000-000000000031','81000000-0000-4000-8000-000000000001','Link Survivor','ignored','University'),
('82000000-0000-4000-8000-000000000032','81000000-0000-4000-8000-000000000001','Link Duplicate','ignored','University');
insert into public.customer_knowledge_links(id,owner_id,customer_id,knowledge_id,direction,applicability,applicability_reason) values
('86000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000031','85000000-0000-4000-8000-000000000001','Applicable To','Low','Survivor evidence'),
('86000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000032','85000000-0000-4000-8000-000000000001','Applicable To','Not Applicable','Duplicate evidence');
reset role; set local role service_role;
create temporary table link_preview as select * from public.preview_entity_merge(
'81000000-0000-4000-8000-000000000001','Customer','82000000-0000-4000-8000-000000000031','82000000-0000-4000-8000-000000000032');
select ok((select plan->'knowledgeLinkCollisions' @> '[{"knowledgeId":"85000000-0000-4000-8000-000000000001","direction":"Applicable To","resolution":"PreserveBoth"}]'::jsonb from link_preview),'preview exposes deterministic evidence collision resolution');
create temporary table link_result as select * from public.execute_entity_merge(
'81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000031',(select preview_id from link_preview),(select preview_token from link_preview),(select plan_hash from link_preview),(select survivor_version from link_preview),(select duplicate_version from link_preview));
reset role; set local role postgres;
select is((select count(*) from public.customer_knowledge_links where customer_id='82000000-0000-4000-8000-000000000031' and knowledge_id='85000000-0000-4000-8000-000000000001'),2::bigint,'merge preserves both evidence-bearing Knowledge links');
select set_eq($$select applicability_reason from public.customer_knowledge_links where customer_id='82000000-0000-4000-8000-000000000031'$$,array['Survivor evidence','Duplicate evidence'],'neither applicability reason is silently lost');

reset role; set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('82000000-0000-4000-8000-000000000041','81000000-0000-4000-8000-000000000001','Contact Chain Customer','ignored','University');
insert into public.contacts(id,owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence) values
('84000000-0000-4000-8000-000000000011','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000041','Contact Chain A','Unknown','Unknown','Unknown'),
('84000000-0000-4000-8000-000000000012','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000041','Contact Chain B','Unknown','Unknown','Unknown'),
('84000000-0000-4000-8000-000000000013','81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000041','Contact Chain C','Unknown','Unknown','Unknown');
reset role; select set_config('request.jwt.claims','{"role":"service_role"}',true); set local role service_role;
create temporary table contact_ab_preview as select * from public.preview_entity_merge('81000000-0000-4000-8000-000000000001','Contact','84000000-0000-4000-8000-000000000012','84000000-0000-4000-8000-000000000011');
create temporary table contact_ab_result as select * from public.execute_entity_merge('81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000041',(select preview_id from contact_ab_preview),(select preview_token from contact_ab_preview),(select plan_hash from contact_ab_preview),(select survivor_version from contact_ab_preview),(select duplicate_version from contact_ab_preview));
create temporary table contact_bc_preview as select * from public.preview_entity_merge('81000000-0000-4000-8000-000000000001','Contact','84000000-0000-4000-8000-000000000013','84000000-0000-4000-8000-000000000012');
create temporary table contact_bc_result as select * from public.execute_entity_merge('81000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000042',(select preview_id from contact_bc_preview),(select preview_token from contact_bc_preview),(select plan_hash from contact_bc_preview),(select survivor_version from contact_bc_preview),(select duplicate_version from contact_bc_preview));
reset role; set local role postgres;
select is((select merged_into_id from public.contacts where id='84000000-0000-4000-8000-000000000011'),'84000000-0000-4000-8000-000000000013'::uuid,'Contact A tombstone flattens directly to C');
select is((select metadata->>'mergedIntoId' from public.search_documents where source_type='Contact' and source_id='84000000-0000-4000-8000-000000000011'),'84000000-0000-4000-8000-000000000013','flattened Contact tombstone SearchDocument refreshes');
reset role; select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}',true); set local role authenticated;
select is(public.resolve_contact_detail('84000000-0000-4000-8000-000000000011')->>'mergedIntoId','84000000-0000-4000-8000-000000000013','stale Contact A URL routes to final C survivor');

reset role; set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type,merged_into_id,deleted_at,deleted_by) values
('82000000-0000-4000-8000-000000000061','81000000-0000-4000-8000-000000000001','Cycle One','ignored','University',null,now(),'81000000-0000-4000-8000-000000000001'),
('82000000-0000-4000-8000-000000000062','81000000-0000-4000-8000-000000000001','Cycle Two','ignored','University','82000000-0000-4000-8000-000000000061',now(),'81000000-0000-4000-8000-000000000001');
update public.customers set merged_into_id='82000000-0000-4000-8000-000000000062' where id='82000000-0000-4000-8000-000000000061';
reset role; select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}',true); set local role authenticated;
select throws_ok($$select public.resolve_customer_detail('82000000-0000-4000-8000-000000000061')$$,'P0001','Customer merge redirect cycle','Customer resolver detects a redirect cycle without looping');

reset role; set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('82000000-0000-4000-8000-000000000051','81000000-0000-4000-8000-000000000002','Other Owner Customer','ignored','University');
insert into public.contacts(id,owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence) values
('84000000-0000-4000-8000-000000000051','81000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000051','Other Owner Contact','Unknown','Unknown','Unknown');
insert into public.customer_external_references(id,owner_id,customer_id,source_system,external_reference) values
('87000000-0000-4000-8000-000000000051','81000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000051','Manual','OTHER-51');
insert into public.knowledge(id,owner_id,title,knowledge_type,status,confidence,source_type,content_blocks) values
('85000000-0000-4000-8000-000000000051','81000000-0000-4000-8000-000000000002','Other Link Knowledge','General','Ready','Verified','Personal Note','{"schemaVersion":1,"blocks":[]}'::jsonb);
insert into public.customer_knowledge_links(id,owner_id,customer_id,knowledge_id,direction,applicability) values
('86000000-0000-4000-8000-000000000051','81000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000051','85000000-0000-4000-8000-000000000051','Applicable To','High');
reset role;
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}',true); set local role authenticated;
select is((select count(*) from public.customers where id='82000000-0000-4000-8000-000000000051'),0::bigint,'cross-owner Customer read is hidden');
select is((select count(*) from public.contacts where id='84000000-0000-4000-8000-000000000051'),0::bigint,'cross-owner Contact read is hidden');
select is((select count(*) from public.customer_external_references where id='87000000-0000-4000-8000-000000000051'),0::bigint,'cross-owner external-reference read is hidden');
select is((select count(*) from public.customer_knowledge_links where id='86000000-0000-4000-8000-000000000051'),0::bigint,'cross-owner Knowledge-link read is hidden');
create temporary table cross_owner_mutation_counts(value bigint);
with changed as(update public.customers set name='stolen' where id='82000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from changed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner Customer update affects zero rows');
with changed as(update public.contacts set full_name='stolen' where id='84000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from changed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner Contact update affects zero rows');
with changed as(update public.customer_external_references set external_reference='stolen' where id='87000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from changed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner external-reference update affects zero rows');
with changed as(update public.customer_knowledge_links set applicability='Unknown' where id='86000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from changed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner Knowledge-link update affects zero rows');
with removed as(delete from public.customers where id='82000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from removed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner Customer delete affects zero rows');
with removed as(delete from public.contacts where id='84000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from removed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner Contact delete affects zero rows');
with removed as(delete from public.customer_external_references where id='87000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from removed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner external-reference delete affects zero rows');
with removed as(delete from public.customer_knowledge_links where id='86000000-0000-4000-8000-000000000051' returning 1) insert into cross_owner_mutation_counts select count(*) from removed;
select is((select value from cross_owner_mutation_counts order by ctid desc limit 1),0::bigint,'cross-owner Knowledge-link delete affects zero rows');
select throws_ok($$insert into public.customers(owner_id,name,normalized_name,customer_type) values('81000000-0000-4000-8000-000000000002','forged','forged','University')$$,'42501',null,'cross-owner Customer insert is denied');
select throws_ok($$insert into public.contacts(owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence) values('81000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000051','forged','Unknown','Unknown','Unknown')$$,'42501',null,'cross-owner Contact insert is denied');
select throws_ok($$insert into public.customer_external_references(owner_id,customer_id,source_system,external_reference) values('81000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000051','Manual','forged')$$,'42501',null,'cross-owner external-reference insert is denied');
select throws_ok($$insert into public.customer_knowledge_links(owner_id,customer_id,knowledge_id,direction,applicability) values('81000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000051','85000000-0000-4000-8000-000000000051','Applicable To','High')$$,'42501',null,'cross-owner Knowledge-link insert is denied');

select * from finish();
rollback;
