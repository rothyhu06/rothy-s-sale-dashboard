begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

select has_table('public', 'customers', 'Customer authority exists');
select has_table('public', 'customer_external_references', 'external references are separate facts');
select has_table('public', 'contacts', 'Contact employment authority exists');
select has_table('public', 'customer_knowledge_links', 'CustomerKnowledgeLink exists');
select has_table('public', 'merge_previews', 'merge preview registry exists');
select has_function('public', 'create_customer', 'Customer create is atomic');
select has_function('public', 'create_contact', 'Contact create is atomic');
select has_function('public', 'preview_entity_merge', 'merge preview command exists');
select has_function('public', 'execute_entity_merge', 'merge execution command exists');
select ok(exists(select 1 from pg_constraint where conname='customer_external_references_owner_customer_fk' and contype='f'), 'external reference owner uses a real composite FK');
select ok(exists(select 1 from pg_constraint where conname='contacts_owner_customer_fk' and contype='f'), 'Contact customer uses a real composite FK');
select ok(exists(select 1 from pg_constraint where conname='customer_knowledge_links_owner_knowledge_fk' and contype='f'), 'CustomerKnowledgeLink targets Knowledge through a true owner FK');
select ok(exists(select 1 from pg_constraint where conname='merge_previews_owner_customer_survivor_fk' and contype='f'), 'Customer merge previews use a true owner-aware survivor FK');
select ok(exists(select 1 from pg_constraint where conname='merge_previews_owner_contact_duplicate_fk' and contype='f'), 'Contact merge previews use a true owner-aware duplicate FK');
select ok(not exists(select 1 from pg_indexes where tablename='customers' and indexdef ilike '%unique%normalized_name%'), 'normalized Customer names are advisory, not unique');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
('71000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','customer-owner@example.test','',now(),now()),
('71000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','customer-other@example.test','',now(),now());

set local role postgres;
insert into public.knowledge(id,owner_id,title,knowledge_type,status,confidence,source_type,content_blocks) values
('72000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001','客户案例','Case Reference','Ready','Verified','Customer','{"schemaVersion":1,"blocks":[]}'::jsonb),
('72000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000002','其他知识','General','Ready','Verified','Personal Note','{"schemaVersion":1,"blocks":[]}'::jsonb);
reset role;

select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$insert into public.customers(name,normalized_name,customer_type) values('browser','browser','University')$$,'42501',null,'browser cannot bypass Customer commands');
select throws_ok($$select * from public.create_customer('71000000-0000-4000-8000-000000000001',gen_random_uuid(),'browser','{}'::text[],'University',null,null,null,null,null,null,null,null,null,null,null,null,null,null,'Active','Level3',null,'[]','[]')$$,'42501',null,'browser cannot call service Customer command');
reset role;

select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
create temporary table created_customer as select * from public.create_customer(
'71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000001','  华南  师范大学（大学城校区） ','{}'::text[],'University','Higher Education','华南','https://example.test','背景','业务上下文','私有云','Tencent Cloud','AI 教学',null,36000,2800,3,'2026-07-01','学校官网年报','Active','Level3','客户敏感资料',
'[{"sourceSystem":"SAP","externalReference":"EDU-42"}]'::jsonb,
'[{"knowledgeId":"72000000-0000-4000-8000-000000000001","direction":"Applicable To","applicability":"Low","applicabilityReason":"仅实验室"}]'::jsonb);
reset role;
set local role postgres;
select is((select normalized_name from public.customers where id=(select id from created_customer)),'华南 师范大学(大学城校区)','normalized name is derived in PostgreSQL');
select is((select data_level from public.customers where id=(select id from created_customer)),'Level3'::public.data_level,'Customer is Level3');
select is((select count(*) from public.customer_external_references where customer_id=(select id from created_customer)),1::bigint,'Customer create writes owner-aware refs atomically');
select is((select count(*) from public.customer_knowledge_links where customer_id=(select id from created_customer)),1::bigint,'Customer create writes Knowledge links atomically');
select is((select count(*) from public.search_documents where source_type='Customer' and source_id=(select id from created_customer)),1::bigint,'Customer SearchDocument refreshes atomically');
select ok((select search_text not like '%EDU-42%' from public.search_documents where source_type='Customer' and source_id=(select id from created_customer)),'broad search excludes external reference values');
select is((select count(*) from public.command_receipts where command_type='CreateCustomer' and client_request_id='73000000-0000-4000-8000-000000000001'),1::bigint,'Customer command receipt completes');
select is((select count(*) from public.audit_logs where action='CustomerCreated' and entity_id=(select id from created_customer)),1::bigint,'Customer audit appends');
reset role; set local role service_role;
create temporary table replayed_customer as select * from public.create_customer(
'71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000001','ignored replay','{}'::text[],'Other',null,null,null,null,null,null,null,null,null,null,null,null,null,null,'Dormant','Level3',null,'[]','[]');
reset role; set local role postgres;
select is((select id from replayed_customer),(select id from created_customer),'replayed Customer create returns the original authority');
select is((select operation_id from replayed_customer),(select operation_id from created_customer),'replayed Customer create preserves operation_id');

reset role; set local role service_role;
create temporary table duplicate_customer as select * from public.create_customer(
'71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000002','华南 师范大学(大学城校区)','{}'::text[],'University',null,null,null,null,null,null,null,null,null,null,null,null,null,null,'Active','Level3',null,'[]','[]');
create temporary table created_contact as select * from public.create_contact(
'71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000003',(select id from duplicate_customer),'张老师',null,'信息办','主任','zhang@example.test','13800138000','wx-zhang','WeChat','Afternoon',array['WeChat Preferred']::text[],'Active','Developing','High','牵头校级采购',null,'Level3','联系人敏感资料');
reset role; set local role postgres;
select is((select count(*) from public.customers where normalized_name=(select normalized_name from public.customers where id=(select id from created_customer))),2::bigint,'same normalized names remain allowed');
select is((select count(*) from public.search_documents where source_type='Contact' and source_id=(select id from created_contact)),1::bigint,'Contact SearchDocument refreshes atomically');
select ok((select search_text not like '%zhang@example.test%' and search_text not like '%13800138000%' and search_text not like '%wx-zhang%' from public.search_documents where source_type='Contact' and source_id=(select id from created_contact)),'broad Contact search excludes raw channels');
select throws_ok(format($f$insert into public.contacts(owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence) values('71000000-0000-4000-8000-000000000001',%L,'No evidence','Active','Unknown','High')$f$,(select id from created_customer)),'23514',null,'known influence requires evidence');
select throws_ok(format($f$insert into public.customer_knowledge_links(owner_id,customer_id,knowledge_id,direction,applicability) values('71000000-0000-4000-8000-000000000001',%L,'72000000-0000-4000-8000-000000000002','Applicable To','High')$f$,(select id from created_customer)),'23503',null,'true owner FK rejects cross-owner Knowledge');
reset role; set local role service_role;
create temporary table replayed_contact as select * from public.create_contact(
'71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000003',(select id from created_customer),'ignored replay',null,null,null,null,null,null,null,'No Preference','{}'::text[],'Unknown','Unknown','Unknown',null,null,'Level3',null);
reset role; set local role postgres;
select is((select id from replayed_contact),(select id from created_contact),'replayed Contact create returns the original employment authority');
select is((select operation_id from replayed_contact),(select operation_id from created_contact),'replayed Contact create preserves operation_id');

reset role; set local role service_role;
create temporary table merge_preview as select * from public.preview_entity_merge('71000000-0000-4000-8000-000000000001','Customer',(select id from created_customer),(select id from duplicate_customer));
reset role; set local role postgres;
select ok((select preview_token is not null and length(preview_token)>20 from merge_preview),'preview returns an opaque one-time token');
select ok((select p.token_hash<>m.preview_token from public.merge_previews p cross join merge_preview m where p.id=m.preview_id),'only token hash is persisted');
select is((select survivor_version from merge_preview),(select version from public.customers where id=(select id from created_customer)),'preview captures survivor version');
select is((select duplicate_version from merge_preview),(select version from public.customers where id=(select id from duplicate_customer)),'preview captures duplicate version');
select ok((select plan ? 'contactCount' and not plan ? 'customerPayload' from public.merge_previews where id=(select preview_id from merge_preview)),'merge plan stores counts/instructions but no full payload');

reset role; set local role service_role;
select lives_ok(format($f$update public.customers set background='changed' where id=%L$f$,(select id from duplicate_customer)),'fixture makes preview stale');
select throws_ok(format($f$select * from public.execute_entity_merge('71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000004',%L,%L,%L,%s,%s)$f$,
(select preview_id from merge_preview),(select preview_token from merge_preview),(select plan_hash from merge_preview),(select survivor_version from merge_preview),(select duplicate_version from merge_preview)),
'40001','merge preview is stale','stale preview rejects execution');
create temporary table fresh_preview as select * from public.preview_entity_merge('71000000-0000-4000-8000-000000000001','Customer',(select id from created_customer),(select id from duplicate_customer));
insert into public.customer_external_references(owner_id,customer_id,source_system,external_reference) values('71000000-0000-4000-8000-000000000001',(select id from duplicate_customer),'Manual','added-after-preview');
select throws_ok(format($f$select * from public.execute_entity_merge('71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000009',%L,%L,%L,%s,%s)$f$,
(select preview_id from fresh_preview),(select preview_token from fresh_preview),(select plan_hash from fresh_preview),(select survivor_version from fresh_preview),(select duplicate_version from fresh_preview)),
'40001','merge preview is stale','relationship identity changes invalidate a merge preview even when entity versions do not change');
drop table fresh_preview;
create temporary table fresh_preview as select * from public.preview_entity_merge('71000000-0000-4000-8000-000000000001','Customer',(select id from created_customer),(select id from duplicate_customer));
create temporary table merge_result as select * from public.execute_entity_merge('71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000005',(select preview_id from fresh_preview),(select preview_token from fresh_preview),(select plan_hash from fresh_preview),(select survivor_version from fresh_preview),(select duplicate_version from fresh_preview));
reset role; set local role postgres;
select is((select customer_id from public.contacts where id=(select id from created_contact)),(select id from created_customer),'Customer merge reparents Contacts deterministically');
select is((select metadata->>'customerId' from public.search_documents where source_type='Contact' and source_id=(select id from created_contact)),(select id::text from created_customer),'reparented Contact SearchDocument refreshes in the merge transaction');
select is((select merged_into_id from public.customers where id=(select id from duplicate_customer)),(select id from created_customer),'duplicate becomes a redirect tombstone');
select ok((select deleted_at is not null from public.customers where id=(select id from duplicate_customer)),'merge never physically deletes duplicate');
select is((select used_at is not null from public.merge_previews where id=(select preview_id from fresh_preview)),true,'preview token is consumed once');
select throws_ok(format($f$select * from public.execute_entity_merge('71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000006',%L,%L,%L,%s,%s)$f$,
(select preview_id from fresh_preview),(select preview_token from fresh_preview),(select plan_hash from fresh_preview),(select survivor_version from fresh_preview),(select duplicate_version from fresh_preview)),
'P0001','merge preview already used','one-time token cannot execute twice under a different command id');
reset role; set local role service_role;
create temporary table replayed_merge as select * from public.execute_entity_merge('71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000005',(select preview_id from fresh_preview),'wrong-replay-token',(select plan_hash from fresh_preview),999,999);
reset role; set local role postgres;
select is((select operation_id from replayed_merge),(select operation_id from merge_result),'same merge command replay returns its completed receipt before stale token/version validation');
select is((select visibility_state from public.search_documents where source_type='Customer' and source_id=(select id from duplicate_customer)),'Merged','duplicate SearchDocument routes to survivor context');

reset role;
set local role postgres;
grant select on duplicate_customer,created_customer to authenticated;
reset role;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select is((select public.resolve_customer_detail((select id from duplicate_customer))->>'state'),'Merged','historical Customer URL resolves a Merged tombstone');
select is((select public.resolve_customer_detail((select id from duplicate_customer))->>'mergedIntoId'),(select id::text from created_customer),'Customer tombstone identifies its survivor');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
create temporary table second_contact as select * from public.create_contact(
'71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000007',(select id from created_customer),'张老师（重复）',null,'信息办','主任',null,null,null,null,'No Preference','{}'::text[],'Unknown','Unknown','Unknown',null,null,'Level3',null);
create temporary table contact_preview as select * from public.preview_entity_merge('71000000-0000-4000-8000-000000000001','Contact',(select id from created_contact),(select id from second_contact));
create temporary table contact_merge as select * from public.execute_entity_merge('71000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000008',(select preview_id from contact_preview),(select preview_token from contact_preview),(select plan_hash from contact_preview),(select survivor_version from contact_preview),(select duplicate_version from contact_preview));
reset role; set local role postgres;
select is((select merged_into_id from public.contacts where id=(select id from second_contact)),(select id from created_contact),'Contact duplicate becomes a redirect tombstone');
select is((select visibility_state from public.search_documents where source_type='Contact' and source_id=(select id from second_contact)),'Merged','Contact tombstone SearchDocument preserves routing context');
reset role;
set local role postgres;
grant select on second_contact to authenticated;
reset role;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select is((select public.resolve_contact_detail((select id from second_contact))->>'state'),'Merged','historical Contact URL resolves a Merged tombstone');
select is((select count(*) from public.merge_previews),0::bigint,'merge previews are never browser-readable');

select * from finish();
rollback;
