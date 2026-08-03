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

select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.knowledge), 1::bigint, 'second owner only reads its own active Knowledge');
select is((select count(*) from public.learning), 0::bigint, 'second owner cannot read first owner Learning');
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
