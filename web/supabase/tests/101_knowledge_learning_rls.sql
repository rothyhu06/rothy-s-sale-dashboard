begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

select has_table('public', 'knowledge', 'knowledge authority table exists');
select has_table('public', 'learning', 'learning authority table exists');
select has_table('public', 'learning_knowledge_links', 'learning-to-knowledge link table exists');
select has_table('public', 'knowledge_relations', 'knowledge relation table exists');
select has_table('public', 'search_documents', 'disposable SearchDocument projection table exists');
select has_type('public', 'knowledge_status', 'knowledge status is frozen as an enum');
select has_type('public', 'knowledge_confidence', 'knowledge confidence is frozen as an enum');
select has_type('public', 'knowledge_source_type', 'knowledge source type is frozen as an enum');
select has_type('public', 'learning_outcome', 'learning outcome is frozen as an enum');
select has_type('public', 'mastery', 'mastery is frozen as an enum');
select ok(exists (select 1 from pg_constraint where conname = 'learning_owner_parent_fk' and contype = 'f'), 'learning parent uses a real owner-aware foreign key');
select ok(exists (select 1 from pg_constraint where conname = 'learning_knowledge_links_owner_knowledge_fk' and contype = 'f'), 'learning link targets Knowledge with an owner-aware foreign key');
select ok(exists (select 1 from pg_constraint where conname = 'attachment_links_owner_knowledge_fk' and contype = 'f'), 'attachments can target Knowledge with an owner-aware foreign key');
select ok(exists (select 1 from pg_constraint where conname = 'tag_links_owner_learning_fk' and contype = 'f'), 'tags can target Learning with an owner-aware foreign key');
select col_is_pk('public', 'search_documents', array['id'], 'SearchDocument has a projection-local identity');
select col_not_null('public', 'knowledge', 'content_blocks', 'Knowledge always contains a ContentBlock envelope');
select col_not_null('public', 'knowledge', 'content_plaintext', 'Knowledge stores server-derived plaintext');
select is(array_to_string(enum_range(null::public.knowledge_status)::text[], ','), 'Draft,Learning,Ready,Archived', 'Knowledge status labels are exact');
select is(array_to_string(enum_range(null::public.knowledge_type)::text[], ','), 'Tencent Cloud Product,AI Technology,Education Industry,Sales Method,Solution Reference,Case Reference,General', 'Knowledge type labels are exact');
select is(array_to_string(enum_range(null::public.knowledge_confidence)::text[], ','), 'Official,Verified,Observed,Hypothesis', 'Knowledge confidence labels are exact');
select is(array_to_string(enum_range(null::public.knowledge_source_type)::text[], ','), 'Official Doc,Training,Meeting,Customer,Book,Website,Internal Material,AI Generated,Personal Note', 'Knowledge source labels are exact');
select is(array_to_string(enum_range(null::public.learning_type)::text[], ','), 'Study,Review,Practice,Course,Product Training,Case Analysis', 'Learning type labels are exact');
select is(array_to_string(enum_range(null::public.learning_status)::text[], ','), 'Planned,In Progress,Completed,Cancelled', 'Learning status labels are exact');
select is(array_to_string(enum_range(null::public.learning_outcome)::text[], ','), 'Passed,Needs Practice,Blocked,Applied,Shared', 'Learning outcome labels are exact');
select is(array_to_string(enum_range(null::public.mastery)::text[], ','), 'Aware,Understand,Explain,Apply,Teach', 'Mastery labels are exact');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('51000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'knowledge-owner@example.test', '', now(), now()),
  ('51000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'knowledge-other@example.test', '', now(), now());

select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ insert into public.knowledge (title, knowledge_type, status, confidence, source_type, content_blocks, content_plaintext)
     values ('browser bypass', 'General', 'Draft', 'Hypothesis', 'Personal Note', '{"schemaVersion":1,"blocks":[]}'::jsonb, 'forged') $$,
  '42501', null,
  'browser clients cannot forge Knowledge plaintext or bypass the server command boundary'
);
reset role;
set local role service_role;
insert into public.knowledge (
  id, owner_id,
  title, knowledge_type, status, confidence, source_type, content_blocks, content_plaintext
) values (
  '53000000-0000-4000-8000-000000000001',
  '51000000-0000-4000-8000-000000000001',
  'AI 教学助手', 'Tencent Cloud Product', 'Draft', 'Official', 'Official Doc',
  '{"schemaVersion":1,"blocks":[{"id":"p1","type":"paragraph","text":"可复用知识"}]}'::jsonb,
  '可复用知识'
) ;

insert into public.learning (id, owner_id, title, learning_type, status, learning_outcome)
values ('53000000-0000-4000-8000-000000000002', '51000000-0000-4000-8000-000000000001', '学习 AI 教学助手', 'Study', 'Planned', 'Passed');
reset role;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is((select owner_id from public.knowledge where id = '53000000-0000-4000-8000-000000000001'), '51000000-0000-4000-8000-000000000001'::uuid, 'Knowledge owner is derived from the authenticated owner');
select is((select owner_id from public.learning where id = '53000000-0000-4000-8000-000000000002'), '51000000-0000-4000-8000-000000000001'::uuid, 'Learning owner is derived from the authenticated owner');
reset role;
set local role service_role;
select lives_ok(
  $$ update public.knowledge set summary = '已验证' where id = '53000000-0000-4000-8000-000000000001' $$,
  'server command path can update active Knowledge'
);
reset role;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select version from public.knowledge where id = '53000000-0000-4000-8000-000000000001'), 2, 'Knowledge updates increment version');
reset role;
set local role service_role;
select lives_ok(
  $$ update public.knowledge set deleted_at = now(), deleted_by = '51000000-0000-4000-8000-000000000001' where id = '53000000-0000-4000-8000-000000000001' $$,
  'server command path supports Knowledge soft deletion'
);
reset role;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.knowledge where id = '53000000-0000-4000-8000-000000000001'), 0::bigint, 'soft-deleted Knowledge is hidden from ordinary owner reads');
reset role;
set local role service_role;
select lives_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks, content_plaintext)
     values ('51000000-0000-4000-8000-000000000001', 'AI 教学助手', 'Tencent Cloud Product', 'Draft', 'Official', 'Official Doc', '{"schemaVersion":1,"blocks":[]}'::jsonb, '') $$,
  'soft deletion releases the active Knowledge title uniqueness key'
);
reset role;
set local role postgres;
select throws_ok(
  $$ delete from public.learning where id = '53000000-0000-4000-8000-000000000002' $$,
  'P0001', 'business entities use soft delete',
  'Learning rejects physical deletion even for a role that bypasses RLS'
);
reset role;

set local role postgres;
insert into public.knowledge (id, owner_id, title, knowledge_type, status, confidence, source_type, content_blocks, content_plaintext)
values (
  '52000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000002',
  'Other owner knowledge', 'General', 'Ready', 'Verified', 'Personal Note', '{"schemaVersion":1,"blocks":[]}'::jsonb, ''
);
select throws_ok(
  $$ insert into public.learning (owner_id, title, learning_type, status, parent_learning_id)
     values ('51000000-0000-4000-8000-000000000001', '跨用户复习', 'Review', 'Planned', '52000000-0000-4000-8000-000000000001') $$,
  '23503', null,
  'Learning chain composite foreign key rejects another owner parent'
);
select throws_ok(
  $$ insert into public.learning_knowledge_links (owner_id, learning_id, knowledge_id, mastery_before, mastery_after)
     values ('51000000-0000-4000-8000-000000000001', '53000000-0000-4000-8000-000000000002', '52000000-0000-4000-8000-000000000001', 'Aware', 'Understand') $$,
  '23503', null,
  'Learning-to-Knowledge composite foreign key rejects another owner target'
);
reset role;

set local role service_role;
insert into public.knowledge (
  id, owner_id, title, knowledge_type, status, confidence, source_type, content_blocks, content_plaintext
) values (
  '54000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001',
  '全文抽取', 'General', 'Ready', 'Verified', 'Internal Material',
  '{"schemaVersion":1,"blocks":[
    {"id":"p","type":"paragraph","text":" Paragraph "},
    {"id":"h","type":"heading","level":2,"text":" Heading "},
    {"id":"l","type":"list","style":"unordered","items":[" one "," two "]},
    {"id":"q","type":"quote","text":" Quote ","citation":" Cite "},
    {"id":"c","type":"callout","tone":"info","text":" Callout "},
    {"id":"k","type":"checklist","items":[{"id":"ki","text":" Check ","checked":true}]},
    {"id":"code","type":"code","language":"sql","code":" select 1 "},
    {"id":"a","type":"attachmentReference","attachmentId":"7738b1f3-760a-49b0-bb86-f7f9ed51784c","caption":" Attachment "},
    {"id":"i","type":"imageReference","attachmentId":"60d74e72-8209-42df-ab94-eace52caf1b3","caption":" Image "}
  ]}'::jsonb,
  'forged plaintext'
), (
  '54000000-0000-4000-8000-000000000002', '51000000-0000-4000-8000-000000000001',
  '省略明文', 'General', 'Ready', 'Verified', 'Internal Material',
  '{"schemaVersion":1,"blocks":[{"id":"p","type":"paragraph","text":"仅来自区块"}]}'::jsonb,
  default
);
select is(
  (select content_plaintext from public.knowledge where id = '54000000-0000-4000-8000-000000000001'),
  E'Paragraph\nHeading\none\ntwo\nQuote\nCite\nCallout\nCheck\nselect 1\nAttachment\nImage',
  'every ContentBlock V1 kind derives plaintext instead of persisting forged caller input'
);
select is(
  (select content_plaintext from public.knowledge where id = '54000000-0000-4000-8000-000000000002'),
  '仅来自区块',
  'omitted plaintext is derived from authoritative blocks'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '不支持区块', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"html","type":"html","html":"<script/>"}]}'::jsonb) $$,
  '23514', null,
  'unsupported ContentBlock envelopes are rejected by the database'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '格式错误区块', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"p","type":"paragraph"}]}'::jsonb) $$,
  '23514', null,
  'malformed ContentBlock envelopes are rejected by the database'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '缺少提示类型', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"c","type":"callout","text":"缺少 tone"}]}'::jsonb) $$,
  '23514', null,
  'callout requires a string enum tone'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '缺少列表类型', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"l","type":"list","items":["one"]}]}'::jsonb) $$,
  '23514', null,
  'list requires a string enum style'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '根额外字段', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[],"unknown":true}'::jsonb) $$,
  '23514', null,
  'unknown root keys are rejected'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '区块额外字段', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"p","type":"paragraph","text":"x","unknown":true}]}'::jsonb) $$,
  '23514', null,
  'unknown block keys are rejected'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '嵌套额外字段', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"k","type":"checklist","items":[{"id":"i","text":"x","checked":true,"unknown":false}]}]}'::jsonb) $$,
  '23514', null,
  'unknown checklist item keys are rejected'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '标准化重复', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"p","type":"paragraph","text":"one"},{"id":" p ","type":"paragraph","text":"two"}]}'::jsonb) $$,
  '23514', null,
  'block ids that normalize to the same value are rejected'
);
select throws_ok(
  $$ insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
     values ('51000000-0000-4000-8000-000000000001', '空白嵌套标识', 'General', 'Draft', 'Hypothesis', 'Personal Note',
       '{"schemaVersion":1,"blocks":[{"id":"k","type":"checklist","items":[{"id":" ","text":"x","checked":true}]}]}'::jsonb) $$,
  '23514', null,
  'blank-after-trim checklist item ids are rejected'
);
insert into public.knowledge (owner_id, title, knowledge_type, status, confidence, source_type, content_blocks)
values ('51000000-0000-4000-8000-000000000001', '标识标准化', 'General', 'Draft', 'Hypothesis', 'Personal Note',
  '{"schemaVersion":1,"blocks":[{"id":" p ","type":"checklist","items":[{"id":" i ","text":"x","checked":true}]}]}'::jsonb);
select is(
  (select content_blocks #>> '{blocks,0,id}' from public.knowledge where title = '标识标准化'),
  'p',
  'block ids are persisted in the same trimmed form produced by Zod'
);
select is(
  (select content_blocks #>> '{blocks,0,items,0,id}' from public.knowledge where title = '标识标准化'),
  'i',
  'checklist item ids are persisted in the same trimmed form produced by Zod'
);
insert into public.learning (id, owner_id, title, learning_type, status)
values (
  '54000000-0000-4000-8000-000000000003', '51000000-0000-4000-8000-000000000001', '学习根节点', 'Study', 'Completed'
), (
  '54000000-0000-4000-8000-000000000004', '51000000-0000-4000-8000-000000000002', '其他用户学习', 'Study', 'Completed'
);
select throws_ok(
  $$ insert into public.learning (owner_id, title, learning_type, status)
     values ('51000000-0000-4000-8000-000000000001', '无父复习', 'Review', 'Planned') $$,
  '23514', null,
  'Review root without a parent is rejected'
);
select lives_ok(
  $$ insert into public.learning (owner_id, title, learning_type, status, parent_learning_id)
     values ('51000000-0000-4000-8000-000000000001', '有效复习子节点', 'Review', 'Planned', '54000000-0000-4000-8000-000000000003') $$,
  'same-owner Review child is accepted'
);
select throws_ok(
  $$ insert into public.learning (owner_id, title, learning_type, status, parent_learning_id)
     values ('51000000-0000-4000-8000-000000000001', '伪装链子节点', 'Practice', 'Planned', '54000000-0000-4000-8000-000000000003') $$,
  '23514', null,
  'non-Review Learning cannot masquerade as a chain child'
);
reset role;
set local role postgres;
insert into public.attachments (
  id, owner_id, original_filename, safe_filename, object_path, mime_type, file_extension,
  size_bytes, checksum_sha256, file_category, storage_status, data_level, uploaded_at, prepared_operation_id
) values (
  '54000000-0000-4000-8000-000000000005', '51000000-0000-4000-8000-000000000001',
  'knowledge.pdf', 'knowledge.pdf', '51000000-0000-4000-8000-000000000001/54000000-0000-4000-8000-000000000005/knowledge.pdf',
  'application/pdf', 'pdf', 1, repeat('a', 64), 'Document', 'Available', 'Level1', now(), '54000000-0000-4000-8000-000000000006'
);
insert into public.tags (id, owner_id, name, normalized_name, data_level)
values ('54000000-0000-4000-8000-000000000007', '51000000-0000-4000-8000-000000000001', '知识', '知识', 'Level1');
select throws_ok(
  $$ insert into public.attachment_links (owner_id, attachment_id, knowledge_id, learning_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005', '54000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000003') $$,
  '23514', null,
  'attachment links reject multiple Knowledge/Learning targets'
);
select throws_ok(
  $$ insert into public.attachment_links (owner_id, attachment_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005') $$,
  '23514', null,
  'attachment links reject missing Knowledge/Learning targets'
);
insert into public.attachment_links (owner_id, attachment_id, knowledge_id)
values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005', '54000000-0000-4000-8000-000000000001');
select throws_ok(
  $$ insert into public.attachment_links (owner_id, attachment_id, knowledge_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005', '54000000-0000-4000-8000-000000000001') $$,
  '23505', null,
  'attachment Knowledge partial unique index rejects duplicates'
);
insert into public.attachment_links (owner_id, attachment_id, learning_id)
values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005', '54000000-0000-4000-8000-000000000003');
select throws_ok(
  $$ insert into public.attachment_links (owner_id, attachment_id, learning_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005', '54000000-0000-4000-8000-000000000003') $$,
  '23505', null,
  'attachment Learning partial unique index rejects duplicates'
);
select throws_ok(
  $$ insert into public.attachment_links (owner_id, attachment_id, learning_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000005', '54000000-0000-4000-8000-000000000004') $$,
  '23503', null,
  'attachment Learning target composite FK rejects cross-owner rows'
);
select throws_ok(
  $$ insert into public.tag_links (owner_id, tag_id, knowledge_id, learning_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007', '54000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000003') $$,
  '23514', null,
  'tag links reject multiple Knowledge/Learning targets'
);
select throws_ok(
  $$ insert into public.tag_links (owner_id, tag_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007') $$,
  '23514', null,
  'tag links reject missing Knowledge/Learning targets'
);
insert into public.tag_links (owner_id, tag_id, learning_id)
values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007', '54000000-0000-4000-8000-000000000003');
select throws_ok(
  $$ insert into public.tag_links (owner_id, tag_id, learning_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007', '54000000-0000-4000-8000-000000000003') $$,
  '23505', null,
  'tag Learning partial unique index rejects duplicates'
);
insert into public.tag_links (owner_id, tag_id, knowledge_id)
values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007', '54000000-0000-4000-8000-000000000001');
select throws_ok(
  $$ insert into public.tag_links (owner_id, tag_id, knowledge_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007', '54000000-0000-4000-8000-000000000001') $$,
  '23505', null,
  'tag Knowledge partial unique index rejects duplicates'
);
select throws_ok(
  $$ insert into public.tag_links (owner_id, tag_id, knowledge_id)
     values ('51000000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000007', '52000000-0000-4000-8000-000000000001') $$,
  '23503', null,
  'tag Knowledge target composite FK rejects cross-owner rows'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.knowledge), 1::bigint, 'second owner only reads its own active Knowledge');
select is((select count(*) from public.learning), 1::bigint, 'second owner only reads its own Learning');
select is((select count(*) from public.search_documents), 0::bigint, 'second owner cannot read first owner SearchDocuments');
select results_eq(
  $$ update public.knowledge set summary = 'cross-owner write'
     where id = '53000000-0000-4000-8000-000000000001' returning id $$,
  $$ select null::uuid where false $$,
  'second owner cannot update another owner Knowledge because RLS never exposes that row'
);
select throws_ok(
  $$ insert into public.search_documents (source_type, source_id, title, search_text, route, data_level, visibility_state, source_created_at, source_updated_at, projection_schema_version)
     values ('Knowledge', '52000000-0000-4000-8000-000000000001', 'bypass', 'bypass', '/knowledge', 'Level1', 'Active', now(), now(), 1) $$,
  '42501', null,
  'browser clients cannot write disposable SearchDocuments'
);
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
insert into public.search_documents (
  owner_id, source_type, source_id, title, search_text, route, data_level, visibility_state,
  source_created_at, source_updated_at, projection_schema_version
) values (
  '51000000-0000-4000-8000-000000000001', 'Knowledge', '53000000-0000-4000-8000-000000000001', 'AI 教学助手',
  'AI 教学助手 可复用知识', '/knowledge', 'Level1', 'Active', now(), now(), 1
);
select throws_ok(
  $$ insert into public.search_documents (owner_id, source_type, source_id, title, search_text, route, data_level, visibility_state, source_created_at, source_updated_at, projection_schema_version)
     values ('51000000-0000-4000-8000-000000000001', 'Knowledge', '53000000-0000-4000-8000-000000000001', 'duplicate', 'duplicate', '/knowledge', 'Level1', 'Active', now(), now(), 1) $$,
  '23505', null,
  'SearchDocument has one disposable projection row per owner/source identity'
);
select lives_ok(
  $$ delete from public.search_documents where owner_id = '51000000-0000-4000-8000-000000000001' $$,
  'service rebuild can physically delete SearchDocuments without touching authority tables'
);
reset role;

select * from finish();
rollback;
