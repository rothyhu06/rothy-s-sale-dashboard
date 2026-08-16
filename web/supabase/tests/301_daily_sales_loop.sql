begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at)values
('b1000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','loop-owner@example.test','',now(),now()),
('b1000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','loop-other@example.test','',now(),now());
set local role postgres;
insert into public.customers(id,owner_id,name,normalized_name,customer_type)values('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','Daily Loop University','ignored','University');
select has_table('public','interactions','Interaction authority exists');
select has_table('public','tasks','Task authority exists');
select has_table('public','task_status_history','Task history exists');
select has_table('public','insights','Insight authority exists');
select has_table('public','reports','Report authority exists');
select col_not_null('public','interactions','owner_id','Interaction owner is required');
select col_not_null('public','tasks','owner_id','Task owner is required');
select col_not_null('public','insights','owner_id','Insight owner is required');
select col_not_null('public','reports','owner_id','Report owner is required');

reset role;select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
create temporary table made_interaction as select * from public.create_interaction('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001',null,null,'Meeting','2026-08-17T10:00:00+08','Discovery meeting','Confirmed teaching assistant need','Meeting notes','Positive','Move to solution discovery',true,'[{"name":"Director Li"}]');
create temporary table made_task as select * from public.create_task('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000002','Prepare discovery questions','Before next meeting','2026-08-18T09:00:00+08',30,'b2000000-0000-4000-8000-000000000001',null,null,(select id from made_interaction));
create temporary table completed_task as select * from public.change_task_status('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000003',(select id from made_task),1,'Completed');
create temporary table made_insight as select * from public.create_insight('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000004','Start with workflow friction','Customer Insight','Teachers describe time cost before technology requirements','Lead with business process', (select id from made_interaction),null,null,null,null);
create temporary table validated_insight as select * from public.change_insight_status('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000007',(select id from made_insight),1,'Validated',4::smallint);
create temporary table made_report as select * from public.save_report('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000005','Daily','2026-08-17',null,null,'Asia/Shanghai','Discovery','Good progress','Budget unclear','Create solution outline');
create temporary table made_weekly_report as select * from public.save_report('b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000006','Weekly',null,'2026-08-17T00:00:00+08','2026-08-24T00:00:00+08','Asia/Shanghai','Move discovery','Evidence grew','Budget unclear','Prepare solution');
reset role;set local role postgres;
select is((select count(*) from public.interactions),1::bigint,'Interaction command writes one fact');
select is((select count(*) from public.tasks),1::bigint,'Task command writes one commitment');
select is((select count(*) from public.task_status_history),2::bigint,'Task history keeps Initial and Completed facts');
select is((select status::text from public.tasks),'Completed','Task projection state follows history command');
select is((select count(*) from public.insights),1::bigint,'Insight is grounded in evidence');
select is((select status::text from public.insights),'Validated','Insight validation is an explicit command');
select is((select count(*) from public.reports),2::bigint,'Daily and Weekly report narratives are saved');
select ok(exists(select 1 from public.search_documents where source_type='Interaction'),'Interaction search projection is refreshed');
select ok(exists(select 1 from public.search_documents where source_type='Task'),'Task search projection is refreshed');
select ok(exists(select 1 from public.search_documents where source_type='Insight'),'Insight search projection is refreshed');
select ok(exists(select 1 from public.audit_logs where action='InteractionCreated'),'Interaction command is audited');
select throws_ok('update public.task_status_history set to_status=''Open''','P0001','task status history is append-only','Task history cannot be changed');

reset role;select set_config('request.jwt.claims','{"role":"authenticated","sub":"b1000000-0000-4000-8000-000000000002"}',true);set local role authenticated;
select is((select count(*) from public.interactions),0::bigint,'Other owner cannot read Interaction');
select is((select count(*) from public.tasks),0::bigint,'Other owner cannot read Task');
select is((select count(*) from public.insights),0::bigint,'Other owner cannot read Insight');
select throws_ok($$select * from public.create_task('b1000000-0000-4000-8000-000000000002',gen_random_uuid(),'Forged',null,null,null,null,null,null,null)$$,'42501','permission denied for function create_task','Browser cannot execute service command');
select * from finish();rollback;
