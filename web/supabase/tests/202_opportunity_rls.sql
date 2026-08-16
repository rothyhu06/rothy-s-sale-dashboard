begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
('a1000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','opp-owner@example.test','',now(),now()),
('a1000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','opp-other@example.test','',now(),now());

set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type) values
('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Opportunity Customer','ignored','University'),
('a2000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','Other Customer','ignored','University');
insert into public.contacts(id,owner_id,customer_id,full_name,employment_status,relationship_status,organization_influence) values
('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','Decision Maker','Active','Developing','Unknown'),
('a3000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000002','Other Contact','Active','Developing','Unknown');

select has_table('public','opportunities','Opportunity authority exists');
select has_table('public','opportunity_stage_history','stage history authority exists');
select has_table('public','opportunity_outcomes','immutable outcome authority exists');
select has_table('public','opportunity_contact_roles','roles are separate from Contact position');
select col_not_null('public','opportunity_stage_history','owner_id','history is owner-aware');
select col_not_null('public','opportunity_outcomes','owner_id','outcome is owner-aware');
select col_not_null('public','opportunity_contact_roles','owner_id','role is owner-aware');
select has_fk('public','opportunities','Opportunity has real composite owner FKs');
select has_fk('public','opportunity_stage_history','history has real composite owner FK');
select has_fk('public','opportunity_outcomes','outcome has real composite owner FK');
select has_fk('public','opportunity_contact_roles','role has real composite owner FKs');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='opportunities' and column_name in ('current_stage','probability','final_amount')),'Opportunity stores no stage, probability, or final amount authority');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='opportunity_stage_history' and column_name='probability'),'stage never implies probability');
select ok(exists(select 1 from private.merge_hook_manifests where entity_type='Customer' and 'public.opportunities.customer_id'=any(expected_dependencies)),'Customer merge manifest registers Opportunity dependency');
select ok(exists(select 1 from private.merge_hook_manifests where entity_type='Contact' and 'public.opportunity_contact_roles.contact_id'=any(expected_dependencies)),'Contact merge manifest registers role dependency');

reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
create temporary table created as select * from public.create_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001',
 'a2000000-0000-4000-8000-000000000001',null,'Campus AI','New Business','Inbound',
 'a3000000-0000-4000-8000-000000000001','Campus modernization','Need','Outcome','Direction','Constraints',
 200000,'CNY','Customer budget','2026-08-01','2026-10-01','Lead','Manual',
 '[{"contactId":"a3000000-0000-4000-8000-000000000001","role":"Decision Maker","supportLevel":"Supportive"}]'::jsonb
);
reset role;set local role postgres;
select is((select to_stage::text from public.opportunity_stage_history where opportunity_id=(select id from created) order by recorded_at desc,id desc limit 1),'Lead','create appends Initial Lead history');
select is((select transition_type::text from public.opportunity_stage_history where opportunity_id=(select id from created)),'Initial','initial transition classification is derived');
select is((select count(*) from public.opportunity_contact_roles where opportunity_id=(select id from created)),1::bigint,'create atomically inserts Contact roles');
select is((select estimated_amount from public.opportunities where id=(select id from created)),200000::numeric,'estimated amount remains on Opportunity');
select is((select currency from public.opportunities where id=(select id from created)),'CNY','Opportunity currency is ISO 4217');
select ok(exists(select 1 from public.search_documents where source_type='Opportunity' and source_id=(select id from created)),'create atomically refreshes SearchDocument');
select ok(exists(select 1 from public.audit_logs where action='OpportunityCreated' and entity_id=(select id from created)),'create atomically appends Audit');

reset role; set local role service_role;
create temporary table replay as select * from public.create_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001',
 'a2000000-0000-4000-8000-000000000001',null,'IGNORED','New Business',null,null,null,null,null,null,null,null,
 null,null,null,null,'Lead','Manual','[]'::jsonb);
reset role;set local role postgres;
select is((select id from replay),(select id from created),'completed create receipt replays original entity');
select is((select operation_id from replay),(select operation_id from created),'replay preserves operation identity');
select is((select count(*) from public.opportunities),1::bigint,'replay creates no duplicate Opportunity');

reset role; set local role service_role;
create temporary table forward_step as select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000002',(select id from created),1,(select current_stage_history_id from created),'Discovery','Manual','Discovery started');
create temporary table skip_step as select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000003',(select id from created),2,(select stage_history_id from forward_step),'POC','Manual','Fast track');
create temporary table backward_step as select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000004',(select id from created),3,(select stage_history_id from skip_step),'Solution Design','Manual','Revise solution');
reset role;set local role postgres;
select is((select transition_type::text from forward_step),'Forward','adjacent advance derives Forward');
select is((select transition_type::text from skip_step),'Skip','multi-stage advance derives Skip');
select is((select transition_type::text from backward_step),'Backward','reverse derives Backward');

reset role; set local role service_role;
select throws_ok(format($f$select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000005',%L,4,%L,'Closed Won','Manual',null)$f$,
 (select id from created),(select stage_history_id from backward_step)),'P0001','terminal stage requires outcome','generic transition cannot create half-closed state');
select throws_ok(format($f$select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000006',%L,3,%L,'Commercial Negotiation','Manual',null)$f$,
 (select id from created),(select stage_history_id from backward_step)),'40001','opportunity version conflict','stale version is rejected');
select throws_ok(format($f$select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000007',%L,4,'a4000000-0000-4000-8000-000000000099','Commercial Negotiation','Manual',null)$f$,
 (select id from created)),'40001','opportunity history conflict','stale current-history identity is rejected');

create temporary table closed as select * from public.record_opportunity_outcome(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000008',(select id from created),4,(select stage_history_id from backward_step),
 'Won',188000,'CNY','2026-08-13','Value and fit',null,'["value"]'::jsonb,'Delivered value','Lessons',null);
reset role;set local role postgres;
select is((select to_stage::text from public.opportunity_stage_history where opportunity_id=(select id from created) order by recorded_at desc,id desc limit 1),'Closed Won','recordOutcome atomically appends matching closed stage');
select is((select outcome_type::text from public.opportunity_outcomes where id=(select outcome_id from closed)),'Won','recordOutcome atomically inserts matching active Outcome');
select is((select final_amount from public.opportunity_outcomes where id=(select outcome_id from closed)),188000::numeric,'final amount is separate on Outcome');
select is((select estimated_amount from public.opportunities where id=(select id from created)),200000::numeric,'closing does not overwrite estimated amount');
select throws_ok(format('update public.opportunity_stage_history set reason=''tamper'' where id=%L',(select stage_history_id from closed)),'P0001','opportunity stage history is append-only','history update is rejected');
select throws_ok(format('delete from public.opportunity_stage_history where id=%L',(select stage_history_id from closed)),'P0001','opportunity stage history is append-only','history delete is rejected');
select throws_ok(format('update public.opportunity_outcomes set reason=''tamper'' where id=%L',(select outcome_id from closed)),'P0001','opportunity outcomes are immutable except controlled voiding','outcome mutation is rejected');
select throws_ok(format('delete from public.opportunity_outcomes where id=%L',(select outcome_id from closed)),'P0001','opportunity outcomes are immutable except controlled voiding','outcome delete is rejected');

reset role;set local role service_role;
select throws_ok(format($f$select * from public.transition_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000009',%L,5,%L,'Discovery','Manual',null)$f$,
 (select id from created),(select stage_history_id from closed)),'P0001','closed opportunity must be reopened','closed opportunity rejects ordinary transitions');
create temporary table reopened as select * from public.reopen_opportunity(
 'a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000010',(select id from created),5,(select stage_history_id from closed),'Commercial Negotiation','Manual','Procurement reopened');
reset role;set local role postgres;
select is((select transition_type::text from reopened),'Reopen','reopen derives Reopen classification');
select ok((select voided_at is not null from public.opportunity_outcomes where id=(select outcome_id from closed)),'reopen voids prior Outcome without overwriting evidence');
select is((select count(*) from public.opportunity_outcomes where opportunity_id=(select id from created)),1::bigint,'reopen preserves old Outcome row');
select is((select to_stage::text from public.opportunity_stage_history where opportunity_id=(select id from created) order by recorded_at desc,id desc limit 1),'Commercial Negotiation','reopen appends nonterminal current history');

select throws_ok($$insert into public.opportunities(owner_id,customer_id,name,opportunity_type,estimated_amount,currency)
 values('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','Bad currency','New Business',1,'ZZZ')$$,
 '23514',null,'database rejects non-ISO currency');
select throws_ok($$insert into public.opportunities(owner_id,customer_id,name,opportunity_type,currency)
 values('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','No amount','New Business','CNY')$$,
 '23514',null,'currency and estimated amount must appear together');

reset role;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.opportunities),1::bigint,'owner can read own Opportunity');
select is((select count(*) from public.opportunity_stage_history),6::bigint,'owner can read own append-only history');
select is((select count(*) from public.opportunity_outcomes),1::bigint,'owner can read own Outcome evidence');
select throws_ok($$insert into public.opportunity_stage_history(owner_id,opportunity_id,to_stage,transition_type,changed_source,operation_id)
 values('a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000099','Lead','Initial','Manual',gen_random_uuid())$$,
 '42501',null,'browser cannot append history directly');

reset role;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.opportunities),0::bigint,'other owner cannot read Opportunity');
select is((select count(*) from public.opportunity_stage_history),0::bigint,'other owner cannot read history');
select is((select count(*) from public.opportunity_outcomes),0::bigint,'other owner cannot read Outcome');
select is((select count(*) from public.opportunity_contact_roles),0::bigint,'other owner cannot read roles');

reset role;set local role postgres;
insert into public.opportunities(id,owner_id,customer_id,name,opportunity_type) values
('a4000000-0000-4000-8000-000000000020','a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','Stalled','New Business');
insert into public.opportunity_stage_history(id,owner_id,opportunity_id,to_stage,transition_type,changed_source,changed_at,operation_id) values
('a5000000-0000-4000-8000-000000000020','a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000020','Discovery','Initial','Migration','2026-07-01 00:00:00+00',gen_random_uuid());
reset role;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select is((select is_stalled from public.get_opportunity_projection('a4000000-0000-4000-8000-000000000020','2026-07-14 23:59:59+00',14)),false,'stalled threshold is false just before boundary');
select is((select is_stalled from public.get_opportunity_projection('a4000000-0000-4000-8000-000000000020','2026-07-15 00:00:00+00',14)),true,'stalled threshold is deterministic at as_of boundary');
select is((select days_in_stage from public.get_opportunity_projection('a4000000-0000-4000-8000-000000000020','2026-07-20 12:00:00+00',14)),19,'days in stage uses completed UTC durations');
select is((select next_task_due_at from public.get_opportunity_projection('a4000000-0000-4000-8000-000000000020','2026-07-20 12:00:00+00',14)),null::timestamptz,'next task remains null until Task slice');
select is((select forecast_category from public.get_opportunity_projection('a4000000-0000-4000-8000-000000000020','2026-07-20 12:00:00+00',14)),null::text,'forecast category remains future-derived');

select * from finish();
rollback;
