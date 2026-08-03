begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

select has_function('public', 'create_knowledge', 'Knowledge create is a domain RPC');
select has_function('public', 'update_knowledge', 'Knowledge update is a domain RPC');
select has_function('public', 'create_learning', 'Learning create is a domain RPC');
select has_function('public', 'complete_learning', 'Learning completion is a domain RPC');
select has_function('public', 'create_review_learning', 'Review creation is a distinct domain RPC');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('61000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'command-owner@example.test', '', now(), now()),
  ('61000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'command-other@example.test', '', now(), now());

set local role postgres;
insert into public.attachments (
  id, owner_id, original_filename, safe_filename, object_path, mime_type, file_extension,
  size_bytes, checksum_sha256, file_category, storage_status, data_level, uploaded_at, prepared_operation_id
) values
  ('62000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001',
   'owner.pdf', 'owner.pdf', '61000000-0000-4000-8000-000000000001/62000000-0000-4000-8000-000000000001/owner.pdf',
   'application/pdf', 'pdf', 1, repeat('a', 64), 'Document', 'Available', 'Level3', now(), '62000000-0000-4000-8000-000000000011'),
  ('62000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000002',
   'other.pdf', 'other.pdf', '61000000-0000-4000-8000-000000000002/62000000-0000-4000-8000-000000000002/other.pdf',
   'application/pdf', 'pdf', 1, repeat('b', 64), 'Document', 'Available', 'Level1', now(), '62000000-0000-4000-8000-000000000012');
insert into public.tags (id, owner_id, name, normalized_name, data_level)
values
  ('62000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000001', 'AI', 'ai', 'Level2'),
  ('62000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000002', 'Other', 'other', 'Level1');
insert into public.knowledge (
  id, owner_id, title, knowledge_type, status, confidence, source_type, content_blocks
) values
  ('62000000-0000-4000-8000-000000000005', '61000000-0000-4000-8000-000000000001',
   'Related', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}'::jsonb),
  ('62000000-0000-4000-8000-000000000006', '61000000-0000-4000-8000-000000000002',
   'Other Knowledge', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}'::jsonb);
insert into public.learning (id, owner_id, title, learning_type, status)
values
  ('62000000-0000-4000-8000-000000000007', '61000000-0000-4000-8000-000000000001', 'Parent', 'Study', 'Completed'),
  ('62000000-0000-4000-8000-000000000008', '61000000-0000-4000-8000-000000000002', 'Other Parent', 'Study', 'Completed');
reset role;

select set_config('request.jwt.claims', '{"sub":"61000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ select * from public.create_knowledge(
    '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000001',
    'Browser bypass', 'General', 'Draft', 'Hypothesis', 'Personal Note', null, null,
    null, null, null, null, null, null, null, null,
    '{"schemaVersion":1,"blocks":[]}'::jsonb, 'Level1', null, '{}', '{}', '[]'::jsonb
  ) $$,
  '42501', null,
  'authenticated browser clients cannot execute service-only Knowledge commands'
);
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
create temporary table created_knowledge as
select * from public.create_knowledge(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000002',
  '腾讯云 AI 助教', 'Tencent Cloud Product', 'Ready', 'Official', 'Official Doc', '白皮书', 'https://example.test/ai',
  '摘要', '原理', '价值', '教学', '痛点', '表达', '问题', '竞品',
  '{"schemaVersion":1,"blocks":[{"id":"p","type":"paragraph","text":"数据库派生"},{"id":"a","type":"attachmentReference","attachmentId":"62000000-0000-4000-8000-000000000001","caption":"白皮书"}]}'::jsonb,
  'Level1', null,
  array['62000000-0000-4000-8000-000000000001']::uuid[],
  array['62000000-0000-4000-8000-000000000003']::uuid[],
  '[{"relatedKnowledgeId":"62000000-0000-4000-8000-000000000005","relationType":"Depends On"}]'::jsonb
);
reset role;
set local role postgres;
select is((select owner_id from public.knowledge where id = (select id from created_knowledge)), '61000000-0000-4000-8000-000000000001'::uuid,
  'Knowledge owner comes from the verified server session argument');
select is((select content_plaintext from public.knowledge where id = (select id from created_knowledge)), E'数据库派生\n白皮书',
  'Knowledge plaintext is derived inside PostgreSQL');
select is((select data_level from public.knowledge where id = (select id from created_knowledge)), 'Level3'::public.data_level,
  'available attachment classification raises effective Knowledge data level');
select is((select count(*) from public.attachment_links where knowledge_id = (select id from created_knowledge)), 1::bigint,
  'Knowledge command writes real attachment links');
select is((select count(*) from public.tag_links where knowledge_id = (select id from created_knowledge)), 1::bigint,
  'Knowledge command writes real tag links');
select is((select count(*) from public.knowledge_relations where knowledge_id = (select id from created_knowledge)), 1::bigint,
  'Knowledge command writes explicit owner-aware relations');
select is((select count(*) from public.search_documents where source_type = 'Knowledge' and source_id = (select id from created_knowledge)), 1::bigint,
  'Knowledge create refreshes its minimal SearchDocument');
select is((select count(*) from public.audit_logs where action = 'KnowledgeCreated' and entity_id = (select id from created_knowledge)), 1::bigint,
  'Knowledge create appends one audit row');
select is((select count(*) from public.command_receipts where command_type = 'CreateKnowledge' and client_request_id = '63000000-0000-4000-8000-000000000002'), 1::bigint,
  'Knowledge create completes one command receipt');

reset role;
set local role service_role;
create temporary table replayed_knowledge as
select * from public.create_knowledge(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000002',
  'ignored replay payload', 'General', 'Draft', 'Hypothesis', 'Personal Note', null, null,
  null, null, null, null, null, null, null, null,
  '{"schemaVersion":1,"blocks":[]}'::jsonb, 'Level1', null, '{}', '{}', '[]'::jsonb
);
reset role;
set local role postgres;
select is((select id from replayed_knowledge), (select id from created_knowledge), 'idempotent Knowledge replay returns the original entity');
select is((select operation_id from replayed_knowledge), (select operation_id from created_knowledge), 'idempotent Knowledge replay preserves operation_id');
select is((select count(*) from public.knowledge where owner_id = '61000000-0000-4000-8000-000000000001' and title = '腾讯云 AI 助教'), 1::bigint,
  'idempotent replay never duplicates the Knowledge authority');

reset role;
set local role service_role;
select throws_ok(
  $$ select * from public.create_knowledge(
    '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000003',
    'Cross owner attachment', 'General', 'Draft', 'Hypothesis', 'Personal Note', null, null,
    null, null, null, null, null, null, null, null,
    '{"schemaVersion":1,"blocks":[{"id":"a","type":"attachmentReference","attachmentId":"62000000-0000-4000-8000-000000000002"}]}'::jsonb,
    'Level1', null, array['62000000-0000-4000-8000-000000000002']::uuid[], '{}', '[]'::jsonb
  ) $$,
  'P0001', 'attachment reference is unavailable',
  'Knowledge command rejects a cross-owner attachment'
);
reset role;
set local role postgres;
select is((select count(*) from public.command_receipts where client_request_id = '63000000-0000-4000-8000-000000000003'), 0::bigint,
  'failed pure database Knowledge command rolls its receipt back');
select is((select count(*) from public.knowledge where title = 'Cross owner attachment'), 0::bigint,
  'failed Knowledge validation rolls authority writes back');

reset role;
set local role service_role;
select throws_ok(
  format($f$ select * from public.update_knowledge(
    '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000004', %L,
    99, 'Conflict title', 'General', 'Ready', 'Verified', 'Personal Note', null, null,
    null, null, null, null, null, null, null, null,
    '{"schemaVersion":1,"blocks":[]}'::jsonb, 'Level1', null, '{}', '{}', '[]'::jsonb
  ) $f$, (select id from created_knowledge)),
  '40001', 'knowledge version conflict',
  'Knowledge update reports an optimistic-lock conflict with a dedicated SQLSTATE'
);
reset role;
set local role postgres;
select is((select count(*) from public.command_receipts where client_request_id = '63000000-0000-4000-8000-000000000004'), 0::bigint,
  'version conflict rolls the pure database receipt back');

reset role;
set local role service_role;
create temporary table updated_knowledge as
select * from public.update_knowledge(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000011',
  (select id from created_knowledge), 1,
  '腾讯云 AI 助教更新', 'Tencent Cloud Product', 'Ready', 'Official', 'Official Doc', '白皮书', 'https://example.test/ai',
  '更新摘要', '原理', '价值', '教学', '痛点', '表达', '问题', '竞品',
  '{"schemaVersion":1,"blocks":[{"id":"p","type":"paragraph","text":"更新内容"},{"id":"a","type":"attachmentReference","attachmentId":"62000000-0000-4000-8000-000000000001","caption":"白皮书"}]}'::jsonb,
  'Level1', null,
  array['62000000-0000-4000-8000-000000000001']::uuid[],
  array['62000000-0000-4000-8000-000000000003']::uuid[],
  '[{"relatedKnowledgeId":"62000000-0000-4000-8000-000000000005","relationType":"Depends On"}]'::jsonb
);
reset role;
set local role postgres;
select is((select version from updated_knowledge), 2, 'successful Knowledge update advances optimistic version');
select is((select data_level from updated_knowledge), 'Level3'::public.data_level,
  'Knowledge update cannot lower the existing effective data level');
select matches((select search_text from public.search_documents where source_type = 'Knowledge' and source_id = (select id from created_knowledge)), '更新内容',
  'Knowledge update refreshes the affected SearchDocument');
select is((select count(*) from public.audit_logs where action = 'KnowledgeUpdated' and entity_id = (select id from created_knowledge)), 1::bigint,
  'Knowledge update appends audit in its transaction');
reset role;
set local role service_role;
create temporary table replayed_update as
select * from public.update_knowledge(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000011',
  (select id from created_knowledge), 99,
  'ignored', 'General', 'Draft', 'Hypothesis', 'Personal Note', null, null,
  null, null, null, null, null, null, null, null,
  '{"schemaVersion":1,"blocks":[]}'::jsonb, 'Level1', null, '{}', '{}', '[]'::jsonb
);
reset role;
set local role postgres;
select is((select operation_id from replayed_update), (select operation_id from updated_knowledge),
  'Knowledge update replay returns the original stable operation_id before rechecking stale input');
select is((select version from replayed_update), 2, 'Knowledge update replay does not apply a second mutation');

reset role;
set local role service_role;
create temporary table created_learning as
select * from public.create_learning(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000005',
  '学习 AI 助教', 'Study', 'In Progress', '掌握产品', now(), null, null, null, null, null, null,
  'Level1', null, '{}', array['62000000-0000-4000-8000-000000000003']::uuid[],
  format('[{"knowledgeId":"%s","masteryBefore":"Aware","masteryAfter":"Understand"}]', (select id from created_knowledge))::jsonb
);
reset role;
set local role postgres;
select is((select owner_id from public.learning where id = (select id from created_learning)), '61000000-0000-4000-8000-000000000001'::uuid,
  'Learning owner comes only from the verified session');
select is((select data_level from public.learning where id = (select id from created_learning)), 'Level2'::public.data_level,
  'tag classification can only raise Learning effective data level');
select is((select count(*) from public.learning_knowledge_links where learning_id = (select id from created_learning)), 1::bigint,
  'Learning create writes the explicit Knowledge link');
select is((select count(*) from public.search_documents where source_type = 'Learning' and source_id = (select id from created_learning)), 1::bigint,
  'Learning create refreshes its projection in the command transaction');

reset role;
set local role service_role;
select throws_ok(
  $$ select * from public.create_learning(
    '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000006',
    'Regressing mastery', 'Study', 'Planned', null, null, null, null, null, null, null, null,
    'Level2', null, '{}', '{}',
    format('[{"knowledgeId":"%s","masteryBefore":"Apply","masteryAfter":"Understand"}]', (select id from created_knowledge))::jsonb
  ) $$,
  'P0001', 'mastery cannot decrease',
  'database command enforces mastery ordering independently of TypeScript'
);
reset role;
set local role postgres;
select is((select count(*) from public.command_receipts where client_request_id = '63000000-0000-4000-8000-000000000006'), 0::bigint,
  'invalid mastery rolls back the Learning receipt');

reset role;
set local role service_role;
create temporary table created_review as
select * from public.create_review_learning(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000007',
  '复习 AI 助教', 'Planned', '巩固产品', null, null, null, null, null, null,
  '62000000-0000-4000-8000-000000000007', 'Level2', null, '{}', '{}', '[]'::jsonb
);
reset role;
set local role postgres;
select isnt((select id from created_review), '62000000-0000-4000-8000-000000000007'::uuid,
  'Review command creates a new Learning fact instead of overwriting its parent');
select is((select parent_learning_id from public.learning where id = (select id from created_review)), '62000000-0000-4000-8000-000000000007'::uuid,
  'Review fact preserves its same-owner parent');
reset role;
set local role service_role;
select throws_ok(
  $$ select * from public.create_review_learning(
    '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000008',
    'Cross owner review', 'Planned', null, null, null, null, null, null, null,
    '62000000-0000-4000-8000-000000000008', 'Level2', null, '{}', '{}', '[]'::jsonb
  ) $$,
  'P0001', 'parent learning not found',
  'Review command rejects another owner parent without leaking it'
);
reset role;
set local role postgres;
select is((select count(*) from public.command_receipts where client_request_id = '63000000-0000-4000-8000-000000000008'), 0::bigint,
  'cross-owner Review failure rolls its receipt back');

reset role;
set local role service_role;
select throws_ok(
  format($f$ select * from public.complete_learning(
    '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000009', %L,
    88, now(), 45, '掌握', null, 'Passed', '[]'::jsonb
  ) $f$, (select id from created_learning)),
  '40001', 'learning version conflict',
  'Learning completion enforces expectedVersion'
);
reset role;
set local role postgres;
select is((select count(*) from public.command_receipts where client_request_id = '63000000-0000-4000-8000-000000000009'), 0::bigint,
  'Learning conflict rolls its receipt back');

reset role;
set local role service_role;
create temporary table completed_learning as
select * from public.complete_learning(
  '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000010',
  (select id from created_learning), 1, now(), 45, '掌握', '完成演练', 'Passed',
  format('[{"knowledgeId":"%s","masteryAfter":"Explain"}]', (select id from created_knowledge))::jsonb
);
reset role;
set local role postgres;
select is((select status from public.learning where id = (select id from created_learning)), 'Completed'::public.learning_status,
  'completion records Completed status as a new successful command');
select is((select mastery_after from public.learning_knowledge_links where learning_id = (select id from created_learning)), 'Explain'::public.mastery,
  'completion advances linked Knowledge mastery within the fixed scale');
select is((select count(*) from public.audit_logs where action = 'LearningCompleted' and entity_id = (select id from created_learning)), 1::bigint,
  'Learning completion appends audit in the same transaction');
select is((select operation_id from completed_learning),
  (select operation_id from public.command_receipts where client_request_id = '63000000-0000-4000-8000-000000000010'),
  'returned Learning operation_id is generated and owned by its receipt');

reset role;
select * from finish();
rollback;
