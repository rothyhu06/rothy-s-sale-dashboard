begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('81000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'propagation-owner@example.test', '', now(), now());

set local role postgres;
insert into public.attachments (
  id, owner_id, original_filename, safe_filename, object_path, mime_type, file_extension,
  size_bytes, checksum_sha256, file_category, storage_status, data_level, uploaded_at, prepared_operation_id
) values
  ('82000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 'shared.pdf', 'shared.pdf',
   '81000000-0000-4000-8000-000000000001/82000000-0000-4000-8000-000000000001/shared.pdf', 'application/pdf', 'pdf', 1, repeat('a',64), 'Document', 'Available', 'Level1', now(), '82000000-0000-4000-8000-000000000011'),
  ('82000000-0000-4000-8000-000000000002', '81000000-0000-4000-8000-000000000001', 'history.pdf', 'history.pdf',
   '81000000-0000-4000-8000-000000000001/82000000-0000-4000-8000-000000000002/history.pdf', 'application/pdf', 'pdf', 1, repeat('b',64), 'Document', 'Available', 'Level1', now(), '82000000-0000-4000-8000-000000000012');
insert into public.tags (id, owner_id, name, normalized_name, data_level)
values ('82000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001', 'Historical', 'historical', 'Level1');

insert into public.knowledge (id, owner_id, title, knowledge_type, status, confidence, source_type, content_blocks, data_level)
values
  ('83000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 'Source', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1'),
  ('83000000-0000-4000-8000-000000000002', '81000000-0000-4000-8000-000000000001', 'Relation A', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1'),
  ('83000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001', 'Relation cycle B', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1'),
  ('83000000-0000-4000-8000-000000000004', '81000000-0000-4000-8000-000000000001', 'Shared attachment K', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[{"id":"a","type":"attachmentReference","attachmentId":"82000000-0000-4000-8000-000000000001"}]}', 'Level1'),
  ('83000000-0000-4000-8000-000000000005', '81000000-0000-4000-8000-000000000001', 'Historical K target', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level1'),
  ('83000000-0000-4000-8000-000000000006', '81000000-0000-4000-8000-000000000001', 'Historical K consumer', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[{"id":"h","type":"attachmentReference","attachmentId":"82000000-0000-4000-8000-000000000002"}]}', 'Level1'),
  ('83000000-0000-4000-8000-000000000007', '81000000-0000-4000-8000-000000000001', 'Parent source high', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}', 'Level3');

insert into public.learning (id, owner_id, title, learning_type, status, parent_learning_id, data_level)
values
  ('84000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 'Source learning consumer', 'Study', 'In Progress', null, 'Level1'),
  ('84000000-0000-4000-8000-000000000002', '81000000-0000-4000-8000-000000000001', 'Shared attachment L', 'Study', 'In Progress', null, 'Level1'),
  ('84000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001', 'Parent to complete', 'Study', 'In Progress', null, 'Level1'),
  ('84000000-0000-4000-8000-000000000004', '81000000-0000-4000-8000-000000000001', 'Review child', 'Review', 'In Progress', '84000000-0000-4000-8000-000000000003', 'Level1'),
  ('84000000-0000-4000-8000-000000000005', '81000000-0000-4000-8000-000000000001', 'Historical parent', 'Study', 'Completed', null, 'Level1'),
  ('84000000-0000-4000-8000-000000000006', '81000000-0000-4000-8000-000000000001', 'Historical completion', 'Review', 'In Progress', '84000000-0000-4000-8000-000000000005', 'Level1');

insert into public.attachment_links(owner_id, attachment_id, knowledge_id)
values
  ('81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000004'),
  ('81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002', '83000000-0000-4000-8000-000000000006');
insert into public.attachment_links(owner_id, attachment_id, learning_id)
values
  ('81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000002'),
  ('81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002', '84000000-0000-4000-8000-000000000006');
insert into public.tag_links(owner_id, tag_id, knowledge_id)
values ('81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000006');
insert into public.tag_links(owner_id, tag_id, learning_id)
values ('81000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000003', '84000000-0000-4000-8000-000000000006');
insert into public.knowledge_relations(owner_id, knowledge_id, related_knowledge_id, relation_type)
values
  ('81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000002', '83000000-0000-4000-8000-000000000001', 'Depends On'),
  ('81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000002', '83000000-0000-4000-8000-000000000003', 'Cycle'),
  ('81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000002', 'Cycle'),
  ('81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000006', '83000000-0000-4000-8000-000000000005', 'Historical');
insert into public.learning_knowledge_links(owner_id, learning_id, knowledge_id, mastery_before, mastery_after)
values
  ('81000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000001', 'Aware', 'Aware'),
  ('81000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000007', 'Aware', 'Aware'),
  ('81000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000006', '83000000-0000-4000-8000-000000000005', 'Aware', 'Aware');

select private.refresh_knowledge_search('81000000-0000-4000-8000-000000000001', id)
from public.knowledge where owner_id = '81000000-0000-4000-8000-000000000001';
select private.refresh_learning_search('81000000-0000-4000-8000-000000000001', id)
from public.learning where owner_id = '81000000-0000-4000-8000-000000000001';

reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
create temporary table shared_raise as select * from public.create_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000001',
  'Shared raiser', 'General', 'Ready', 'Verified', 'Personal Note', null, null,
  null, null, null, null, null, null, null, null,
  '{"schemaVersion":1,"blocks":[{"id":"s","type":"attachmentReference","attachmentId":"82000000-0000-4000-8000-000000000001"}]}',
  'Level3', null, array['82000000-0000-4000-8000-000000000001']::uuid[], '{}', '[]'
);
reset role;
set local role postgres;
select results_eq(
  $$ select entity_type, entity_id, data_level::text from (
    select 'Knowledge'::text entity_type, id entity_id, data_level from public.knowledge where id = '83000000-0000-4000-8000-000000000004'
    union all select 'Learning', id, data_level from public.learning where id = '84000000-0000-4000-8000-000000000002'
  ) facts order by entity_type $$,
  $$ values ('Knowledge'::text, '83000000-0000-4000-8000-000000000004'::uuid, 'Level3'::text),
            ('Learning'::text, '84000000-0000-4000-8000-000000000002'::uuid, 'Level3'::text) $$,
  'raising a shared Attachment raises every pre-existing active Knowledge and Learning consumer');
select is((select count(*) from public.audit_logs where action = 'ClassificationRaised'
  and entity_id in ('83000000-0000-4000-8000-000000000004','84000000-0000-4000-8000-000000000002')), 2::bigint,
  'shared Attachment propagation appends one sanitized classification audit per changed consumer');

reset role;
set local role service_role;
create temporary table source_raise as select * from public.update_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000002',
  '83000000-0000-4000-8000-000000000001', 1, '{"dataLevel":"Level3"}'
);
reset role;
set local role postgres;
select results_eq(
  $$ select id, data_level from public.knowledge where id in ('83000000-0000-4000-8000-000000000002','83000000-0000-4000-8000-000000000003') order by id $$,
  $$ values ('83000000-0000-4000-8000-000000000002'::uuid, 'Level3'::public.data_level),
            ('83000000-0000-4000-8000-000000000003'::uuid, 'Level3'::public.data_level) $$,
  'Knowledge rise propagates transitively across related Knowledge and terminates safely through a cycle');
select is((select data_level from public.learning where id = '84000000-0000-4000-8000-000000000001'), 'Level3'::public.data_level,
  'Knowledge rise propagates to a pre-existing linked Learning');
select is((select count(*) from public.search_documents where source_id in (
  '83000000-0000-4000-8000-000000000002','83000000-0000-4000-8000-000000000003','84000000-0000-4000-8000-000000000001'
) and data_level = 'Level3'), 3::bigint, 'transitively raised consumers have final SearchDocument levels');
select is((select count(*) from public.audit_logs where action = 'ClassificationRaised'
  and entity_id in ('83000000-0000-4000-8000-000000000002','83000000-0000-4000-8000-000000000003','84000000-0000-4000-8000-000000000001')), 3::bigint,
  'transitive Knowledge propagation audits every changed consumer exactly once');

reset role;
set local role service_role;
create temporary table parent_complete as select * from public.complete_learning_exact(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000003',
  '84000000-0000-4000-8000-000000000003', 2, now(), 10, 'done', null, 'Passed',
  '[{"knowledgeId":"83000000-0000-4000-8000-000000000007","masteryAfter":"Apply"}]'
);
reset role;
set local role postgres;
select is((select data_level from public.learning where id = '84000000-0000-4000-8000-000000000004'), 'Level3'::public.data_level,
  'parent Learning rise propagates to active Review descendants');
select is((select data_level from public.search_documents where source_type = 'Learning' and source_id = '84000000-0000-4000-8000-000000000004'), 'Level3'::public.data_level,
  'Review descendant SearchDocument matches its propagated final level');

set local role postgres;
update public.attachments set storage_status = 'DeletePending', deleted_at = now(),
  deleted_by = '81000000-0000-4000-8000-000000000001', delete_operation_id = '85000000-0000-4000-8000-000000000010'
where id = '82000000-0000-4000-8000-000000000002';
update public.tags set deleted_at = now(), deleted_by = '81000000-0000-4000-8000-000000000001'
where id = '82000000-0000-4000-8000-000000000003';
update public.knowledge set deleted_at = now(), deleted_by = '81000000-0000-4000-8000-000000000001'
where id = '83000000-0000-4000-8000-000000000005';
update public.learning set deleted_at = now(), deleted_by = '81000000-0000-4000-8000-000000000001'
where id = '84000000-0000-4000-8000-000000000005';

reset role;
set local role service_role;
create temporary table preserved_patch as select * from public.update_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000004',
  '83000000-0000-4000-8000-000000000006', 1, '{"title":"Historical links preserved"}'
);
reset role;
set local role postgres;
select is((select count(*) from public.attachment_links where knowledge_id = '83000000-0000-4000-8000-000000000006'), 1::bigint,
  'title-only Knowledge patch preserves a tombstoned Attachment link without revalidation');
select is((select count(*) from public.tag_links where knowledge_id = '83000000-0000-4000-8000-000000000006'), 1::bigint,
  'title-only Knowledge patch preserves a tombstoned Tag link without revalidation');
select is((select count(*) from public.knowledge_relations where knowledge_id = '83000000-0000-4000-8000-000000000006'), 1::bigint,
  'title-only Knowledge patch preserves a tombstoned Knowledge relation without revalidation');

reset role;
set local role service_role;
select throws_ok($$ select * from public.update_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000005',
  '83000000-0000-4000-8000-000000000006', 2,
  '{"contentBlocks":{"schemaVersion":1,"blocks":[{"id":"h","type":"attachmentReference","attachmentId":"82000000-0000-4000-8000-000000000002"}]},"attachmentIds":["82000000-0000-4000-8000-000000000002"]}'
) $$, 'P0001', 'attachment reference is unavailable', 'explicit replacement rejects a tombstoned Attachment');
select throws_ok($$ select * from public.update_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000008',
  '83000000-0000-4000-8000-000000000006', 2,
  '{"tagIds":["82000000-0000-4000-8000-000000000003"]}'
) $$, 'P0001', 'tag reference is unavailable', 'explicit replacement rejects a tombstoned Tag');
select throws_ok($$ select * from public.update_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000009',
  '83000000-0000-4000-8000-000000000006', 2,
  '{"relations":[{"relatedKnowledgeId":"83000000-0000-4000-8000-000000000005","relationType":"Historical"}]}'
) $$, 'P0001', 'knowledge link target not found', 'explicit replacement rejects a tombstoned Knowledge target');
create temporary table cleared_history as select * from public.update_knowledge(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000006',
  '83000000-0000-4000-8000-000000000006', 2,
  '{"contentBlocks":{"schemaVersion":1,"blocks":[]},"attachmentIds":[],"tagIds":[],"relations":[]}'
);
reset role;
set local role postgres;
select is((select count(*) from public.attachment_links where knowledge_id = '83000000-0000-4000-8000-000000000006'), 0::bigint,
  'explicit empty replacement clears preserved historical links');

reset role;
set local role service_role;
create temporary table historical_complete as select * from public.complete_learning_exact(
  '81000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000007',
  '84000000-0000-4000-8000-000000000006', 1, now(), 10, 'historical complete', null, 'Passed',
  '[{"knowledgeId":"83000000-0000-4000-8000-000000000005","masteryAfter":"Apply"}]'
);
reset role;
set local role postgres;
select is((select status from public.learning where id = '84000000-0000-4000-8000-000000000006'), 'Completed'::public.learning_status,
  'Learning completion succeeds with preserved tombstoned Attachment, Tag, Knowledge, and parent links');

reset role;
select * from finish();
rollback;
