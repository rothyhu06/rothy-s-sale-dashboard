begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(5);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('91000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'page-integrity@example.test', '', now(), now());

set local role postgres;
insert into public.knowledge (id, owner_id, title, knowledge_type, status, confidence, source_type, content_blocks, data_level)
values
  ('92000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'One', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1'),
  ('92000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', 'Two', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1'),
  ('92000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000001', 'Extra', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1');
insert into public.learning (id, owner_id, title, learning_type, status, data_level)
values
  ('93000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'Exact set', 'Study', 'In Progress', 'Level1'),
  ('93000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', 'Incomplete parent', 'Study', 'In Progress', 'Level1'),
  ('93000000-0000-4000-8000-000000000003', '91000000-0000-4000-8000-000000000001', 'Completed parent', 'Study', 'Completed', 'Level1');
insert into public.learning_knowledge_links(owner_id, learning_id, knowledge_id, mastery_before, mastery_after)
values
  ('91000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', 'Aware', 'Aware'),
  ('91000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000002', 'Aware', 'Aware');

reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select throws_ok($$ select * from public.complete_learning_exact(
  '91000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',1,
  now(),10,'done',null,'Passed','[{"knowledgeId":"92000000-0000-4000-8000-000000000001","masteryAfter":"Apply"}]'
) $$, 'P0001', 'learning mastery must match every linked knowledge exactly', 'subset mastery is rejected');
select throws_ok($$ select * from public.complete_learning_exact(
  '91000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000001',1,
  now(),10,'done',null,'Passed','[{"knowledgeId":"92000000-0000-4000-8000-000000000001","masteryAfter":"Apply"},{"knowledgeId":"92000000-0000-4000-8000-000000000002","masteryAfter":"Apply"},{"knowledgeId":"92000000-0000-4000-8000-000000000003","masteryAfter":"Apply"}]'
) $$, 'P0001', 'learning mastery must match every linked knowledge exactly', 'extra mastery is rejected');
select throws_ok($$ select * from public.complete_learning_exact(
  '91000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001',1,
  now(),10,'done',null,'Passed','[{"knowledgeId":"92000000-0000-4000-8000-000000000001","masteryAfter":"Apply"},{"knowledgeId":"92000000-0000-4000-8000-000000000001","masteryAfter":"Teach"}]'
) $$, 'P0001', 'learning mastery must match every linked knowledge exactly', 'duplicate mastery is rejected');

select throws_ok($$ select * from public.create_review_learning(
  '91000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000004','Bad review','Planned',null,null,null,null,null,null,null,
  '93000000-0000-4000-8000-000000000002','Level1',null,'{}','{}','[]'
) $$, 'P0001', 'review parent must be completed', 'Review requires a Completed parent');

select lives_ok($$ select * from public.create_review_learning(
  '91000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000005','Good review','Planned',null,null,null,null,null,null,null,
  '93000000-0000-4000-8000-000000000003','Level1',null,'{}','{}','[]'
) $$, 'Review accepts a Completed parent');

select * from finish();
rollback;
