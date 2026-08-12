begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

select has_function('public', 'delete_knowledge', 'Knowledge has a transactional soft-delete RPC');
select has_function('public', 'delete_learning', 'Learning has a transactional soft-delete RPC');
select has_function('public', 'get_continue_learning', 'Continue Learning has a fact-backed RLS query');
select has_function('public', 'update_knowledge', array['uuid','uuid','uuid','integer','jsonb'], 'Knowledge update accepts a presence-safe JSON patch');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('71000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hardening-owner@example.test', '', now(), now()),
  ('71000000-0000-4000-8000-000000000002', '00000000-0000-0000-8000-000000000000', 'authenticated', 'authenticated', 'hardening-other@example.test', '', now(), now());

set local role postgres;
insert into public.attachments (
  id, owner_id, original_filename, safe_filename, object_path, mime_type, file_extension,
  size_bytes, checksum_sha256, file_category, storage_status, data_level, uploaded_at, prepared_operation_id
) values
  ('72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', 'low.pdf', 'low.pdf',
   '71000000-0000-4000-8000-000000000001/72000000-0000-4000-8000-000000000001/low.pdf', 'application/pdf', 'pdf', 1, repeat('a',64), 'Document', 'Available', 'Level1', now(), '72000000-0000-4000-8000-000000000011'),
  ('72000000-0000-4000-8000-000000000002', '71000000-0000-4000-8000-000000000001', 'low.png', 'low.png',
   '71000000-0000-4000-8000-000000000001/72000000-0000-4000-8000-000000000002/low.png', 'image/png', 'png', 1, repeat('b',64), 'Image', 'Available', 'Level1', now(), '72000000-0000-4000-8000-000000000012'),
  ('72000000-0000-4000-8000-000000000003', '71000000-0000-4000-8000-000000000001', 'wrong.pdf', 'wrong.pdf',
   '71000000-0000-4000-8000-000000000001/72000000-0000-4000-8000-000000000003/wrong.pdf', 'application/pdf', 'pdf', 1, repeat('c',64), 'Document', 'Available', 'Level1', now(), '72000000-0000-4000-8000-000000000013'),
  ('72000000-0000-4000-8000-000000000004', '71000000-0000-4000-8000-000000000001', 'learning.pdf', 'learning.pdf',
   '71000000-0000-4000-8000-000000000001/72000000-0000-4000-8000-000000000004/learning.pdf', 'application/pdf', 'pdf', 1, repeat('d',64), 'Document', 'Available', 'Level1', now(), '72000000-0000-4000-8000-000000000014'),
  ('72000000-0000-4000-8000-000000000005', '71000000-0000-4000-8000-000000000001', 'review.pdf', 'review.pdf',
   '71000000-0000-4000-8000-000000000001/72000000-0000-4000-8000-000000000005/review.pdf', 'application/pdf', 'pdf', 1, repeat('e',64), 'Document', 'Available', 'Level1', now(), '72000000-0000-4000-8000-000000000015'),
  ('72000000-0000-4000-8000-000000000006', '71000000-0000-4000-8000-000000000002', 'other.pdf', 'other.pdf',
   '71000000-0000-4000-8000-000000000002/72000000-0000-4000-8000-000000000006/other.pdf', 'application/pdf', 'pdf', 1, repeat('f',64), 'Document', 'Available', 'Level1', now(), '72000000-0000-4000-8000-000000000016');
insert into public.tags (id, owner_id, name, normalized_name, data_level)
values
  ('72000000-0000-4000-8000-000000000007', '71000000-0000-4000-8000-000000000001', 'Low', 'low', 'Level1'),
  ('72000000-0000-4000-8000-000000000008', '71000000-0000-4000-8000-000000000001', 'High', 'high', 'Level3');
insert into public.knowledge (id, owner_id, title, knowledge_type, status, confidence, source_type, content_blocks, data_level)
values
  ('72000000-0000-4000-8000-000000000009', '71000000-0000-4000-8000-000000000001', 'High relation', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level3'),
  ('72000000-0000-4000-8000-000000000010', '71000000-0000-4000-8000-000000000001', 'High learning knowledge', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level3');
insert into public.learning (id, owner_id, title, learning_type, status, data_level)
values
  ('72000000-0000-4000-8000-000000000020', '71000000-0000-4000-8000-000000000001', 'High parent', 'Study', 'Completed', 'Level3'),
  ('72000000-0000-4000-8000-000000000021', '71000000-0000-4000-8000-000000000002', 'Other parent', 'Study', 'Completed', 'Level1');
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select throws_ok(
  $$ select * from public.create_knowledge(
    '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001',
    'Wrong image', 'General', 'Draft', 'Hypothesis', 'Personal Note', null, null,
    null, null, null, null, null, null, null, null,
    '{"schemaVersion":1,"blocks":[{"id":"i","type":"imageReference","attachmentId":"72000000-0000-4000-8000-000000000003"}]}'::jsonb,
    'Level1', null, array['72000000-0000-4000-8000-000000000003']::uuid[], '{}', '[]'::jsonb
  ) $$,
  'P0001', 'image reference must target an image attachment',
  'direct service RPC rejects imageReference targeting a non-Image attachment'
);
reset role;
set local role postgres;
select is((select count(*) from public.command_receipts where client_request_id = '73000000-0000-4000-8000-000000000001'), 0::bigint,
  'image validation failure rolls back its receipt');

reset role;
set local role service_role;
create temporary table hardened_knowledge as
select * from public.create_knowledge(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000002',
  'Hardened Knowledge', 'General', 'Ready', 'Official', 'Official Doc', 'Source', null,
  'Preserve summary', 'Principle', 'Value', 'Scenario', 'Pain', 'Pitch', 'Questions', 'Competitive',
  '{"schemaVersion":1,"blocks":[{"id":"a","type":"attachmentReference","attachmentId":"72000000-0000-4000-8000-000000000001"},{"id":"i","type":"imageReference","attachmentId":"72000000-0000-4000-8000-000000000002"}]}'::jsonb,
  'Level1', 'Initial classification',
  array['72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002']::uuid[],
  array['72000000-0000-4000-8000-000000000007']::uuid[],
  '[{"relatedKnowledgeId":"72000000-0000-4000-8000-000000000009","relationType":"Builds On"}]'::jsonb
);
reset role;
set local role postgres;
select is((select data_level from hardened_knowledge), 'Level3'::public.data_level,
  'Knowledge effective level includes related Knowledge');
select results_eq(
  $$ select id, data_level, version from public.attachments where id in ('72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002') order by id $$,
  $$ values
    ('72000000-0000-4000-8000-000000000001'::uuid, 'Level3'::public.data_level, 2),
    ('72000000-0000-4000-8000-000000000002'::uuid, 'Level3'::public.data_level, 2) $$,
  'higher-level Knowledge promotes every lower-level linked Attachment in the same transaction'
);
select is((select count(*) from public.audit_logs where action = 'AttachmentDataLevelRaised'
  and entity_id in ('72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002')), 2::bigint,
  'attachment promotion increments version and appends one accurate audit per attachment');
select is((select data_level from public.search_documents where source_type = 'Knowledge' and source_id = (select id from hardened_knowledge)), 'Level3'::public.data_level,
  'Knowledge SearchDocument stores final effective level');

reset role;
set local role service_role;
create temporary table title_patch as
select * from public.update_knowledge(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000003',
  (select id from hardened_knowledge), 1, '{"title":"Title only"}'::jsonb
);
reset role;
set local role postgres;
select is((select summary from public.knowledge where id = (select id from hardened_knowledge)), 'Preserve summary',
  'title-only patch preserves omitted scalar fields');
select is((select count(*) from public.attachment_links where knowledge_id = (select id from hardened_knowledge)), 2::bigint,
  'title-only patch preserves omitted attachment links');
select is((select count(*) from public.tag_links where knowledge_id = (select id from hardened_knowledge)), 1::bigint,
  'title-only patch preserves omitted tag links');
select is((select count(*) from public.knowledge_relations where knowledge_id = (select id from hardened_knowledge)), 1::bigint,
  'title-only patch preserves omitted Knowledge relations');
select is((select changed_fields from public.audit_logs where action = 'KnowledgeUpdated'
  and operation_id = (select operation_id from title_patch)), '["title"]'::jsonb,
  'Knowledge update audit contains only the scalar that actually changed');

reset role;
set local role service_role;
create temporary table clear_patch as
select * from public.update_knowledge(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000004',
  (select id from hardened_knowledge), 2,
  '{"sourceName":null,"contentBlocks":{"schemaVersion":1,"blocks":[]},"attachmentIds":[],"tagIds":[],"relations":[],"classificationReason":null,"sourceType":"Personal Note","competitiveNote":null}'::jsonb
);
reset role;
set local role postgres;
select is((select source_name from public.knowledge where id = (select id from hardened_knowledge)), null,
  'explicit null clears a nullable scalar');
select is((select count(*) from public.attachment_links where knowledge_id = (select id from hardened_knowledge)), 0::bigint,
  'explicit empty attachment set clears attachment links');
select is((select count(*) from public.tag_links where knowledge_id = (select id from hardened_knowledge)), 0::bigint,
  'explicit empty tag set clears tag links');
select is((select count(*) from public.knowledge_relations where knowledge_id = (select id from hardened_knowledge)), 0::bigint,
  'explicit empty relation set clears Knowledge relations');
select is((select changed_fields from public.audit_logs where action = 'KnowledgeUpdated'
  and operation_id = (select operation_id from clear_patch)),
  '["source_type","source_name","competitive_note","content_blocks","classification_reason","attachment_links","tag_links","knowledge_relations"]'::jsonb,
  'update audit accurately lists every actual scalar and link change without values');
select is((select data_level from clear_patch), 'Level3'::public.data_level,
  'clearing high-level links never automatically lowers Knowledge classification');

reset role;
set local role service_role;
create temporary table deleted_knowledge as
select * from public.delete_knowledge(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000005',
  (select id from hardened_knowledge), 3
);
create temporary table replayed_delete_knowledge as
select * from public.delete_knowledge(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000005',
  (select id from hardened_knowledge), 999
);
reset role;
set local role postgres;
select ok((select deleted_at is not null and deleted_by = '71000000-0000-4000-8000-000000000001' from public.knowledge where id = (select id from hardened_knowledge)),
  'Knowledge delete records an owner tombstone instead of physical deletion');
select is((select count(*) from public.search_documents where source_type = 'Knowledge' and source_id = (select id from hardened_knowledge)), 0::bigint,
  'Knowledge delete removes its SearchDocument atomically');
select is((select operation_id from replayed_delete_knowledge), (select operation_id from deleted_knowledge),
  'Knowledge delete replay returns the original stable operation');
select is((select count(*) from public.audit_logs where action = 'KnowledgeDeleted' and entity_id = (select id from hardened_knowledge)), 1::bigint,
  'Knowledge delete appends exactly one audit row across replay');

reset role;
set local role service_role;
create temporary table hardened_learning as
select * from public.create_learning(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000006',
  'Linked learning', 'Study', 'In Progress', 'Objective', now(), null, null, null, null, null, null,
  'Level1', null, array['72000000-0000-4000-8000-000000000004']::uuid[], '{}',
  '[{"knowledgeId":"72000000-0000-4000-8000-000000000010","masteryBefore":"Aware","masteryAfter":"Understand"}]'::jsonb
);
create temporary table replayed_learning as
select * from public.create_learning(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000006',
  'ignored', 'Study', 'Planned', null, null, null, null, null, null, null, null,
  'Level1', null, array['72000000-0000-4000-8000-000000000006']::uuid[], '{}', '[]'::jsonb
);
reset role;
set local role postgres;
select is((select data_level from public.learning where id = (select id from hardened_learning)), 'Level3'::public.data_level,
  'Learning effective level includes linked Knowledge');
select is((select data_level from public.attachments where id = '72000000-0000-4000-8000-000000000004'), 'Level3'::public.data_level,
  'higher-level Learning promotes its lower-level Attachment');
select is((select operation_id from replayed_learning), (select operation_id from hardened_learning),
  'Learning create replay wins before current attachment validation');

reset role;
set local role service_role;
create temporary table hardened_review as
select * from public.create_review_learning(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000007',
  'Inherited review', 'In Progress', null, now(), null, null, null, null, null,
  '72000000-0000-4000-8000-000000000020', 'Level1', null,
  array['72000000-0000-4000-8000-000000000005']::uuid[], '{}', '[]'::jsonb
);
create temporary table replayed_review as
select * from public.create_review_learning(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000007',
  'ignored', 'Planned', null, null, null, null, null, null, null,
  '72000000-0000-4000-8000-000000000021', 'Level1', null, '{}', '{}', '[]'::jsonb
);
reset role;
set local role postgres;
select is((select data_level from public.learning where id = (select id from hardened_review)), 'Level3'::public.data_level,
  'Review inherits its same-owner parent classification');
select is((select data_level from public.attachments where id = '72000000-0000-4000-8000-000000000005'), 'Level3'::public.data_level,
  'Review parent classification promotes the Review attachment');
select is((select operation_id from replayed_review), (select operation_id from hardened_review),
  'Review replay returns before revalidating an invalid replacement parent');

reset role;
set local role service_role;
create temporary table completed_learning_hardened as
select * from public.complete_learning_exact(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000008',
  (select id from hardened_learning), 1, now(), 30, 'Takeaway', null, 'Passed',
  '[{"knowledgeId":"72000000-0000-4000-8000-000000000010","masteryAfter":"Explain"}]'::jsonb
);
create temporary table replayed_complete_hardened as
select * from public.complete_learning_exact(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000008',
  (select id from hardened_learning), 999, now(), 1, 'ignored', null, 'Blocked', '[]'::jsonb
);
reset role;
set local role postgres;
select is((select operation_id from replayed_complete_hardened), (select operation_id from completed_learning_hardened),
  'Learning completion replay wins before stale version and payload validation');

reset role;
set local role service_role;
create temporary table deleted_learning as
select * from public.delete_learning(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000009',
  (select id from hardened_learning), 2
);
create temporary table replayed_delete_learning as
select * from public.delete_learning(
  '71000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000009',
  (select id from hardened_learning), 999
);
reset role;
set local role postgres;
select ok((select deleted_at is not null from public.learning where id = (select id from hardened_learning)),
  'Learning delete records a tombstone');
select is((select count(*) from public.search_documents where source_type = 'Learning' and source_id = (select id from hardened_learning)), 0::bigint,
  'Learning delete removes its SearchDocument atomically');
select is((select operation_id from replayed_delete_learning), (select operation_id from deleted_learning),
  'Learning delete replay returns the original operation');

set local role postgres;
insert into public.learning (
  id, owner_id, title, learning_type, status, objective, parent_learning_id, updated_at, deleted_at, deleted_by
) values
  ('74000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', 'Completed parent', 'Study', 'Completed', null, null, now() - interval '3 hours', null, null),
  ('74000000-0000-4000-8000-000000000010', '71000000-0000-4000-8000-000000000001', 'Planned newest', 'Study', 'Planned', null, null, now() - interval '1 hour', null, null),
  ('74000000-0000-4000-8000-000000000020', '71000000-0000-4000-8000-000000000001', 'Progress tie low', 'Study', 'In Progress', null, null, now() + interval '2 hours', null, null),
  ('74000000-0000-4000-8000-000000000021', '71000000-0000-4000-8000-000000000001', 'Progress tie high review', 'Review', 'In Progress', null, '74000000-0000-4000-8000-000000000001', now() + interval '2 hours', null, null),
  ('74000000-0000-4000-8000-000000000030', '71000000-0000-4000-8000-000000000001', 'Deleted progress', 'Study', 'In Progress', null, null, now() + interval '3 hours', now(), '71000000-0000-4000-8000-000000000001');
reset role;
select set_config('request.jwt.claims', '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
create temporary table continue_rows as select row_number() over () as position, * from public.get_continue_learning(10);
select results_eq(
  $$ select position, title from continue_rows order by position $$,
  $$ values
    (1::bigint, 'Progress tie high review'::text),
    (2::bigint, 'Progress tie low'::text),
    (3::bigint, 'Inherited review'::text),
    (4::bigint, 'Planned newest'::text) $$,
  'Continue Learning orders active progress before planned with stable updated/id tie breaks and excludes terminal/deleted facts'
);
select is((select parent_learning_id from continue_rows where id = '74000000-0000-4000-8000-000000000021'), '74000000-0000-4000-8000-000000000001'::uuid,
  'Continue Learning returns parent chain identity');

reset role;
select * from finish();
rollback;
