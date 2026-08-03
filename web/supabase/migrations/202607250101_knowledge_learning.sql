create type public.knowledge_type as enum (
  'Tencent Cloud Product', 'AI Technology', 'Education Industry', 'Sales Method',
  'Solution Reference', 'Case Reference', 'General'
);
create type public.knowledge_status as enum ('Draft', 'Learning', 'Ready', 'Archived');
create type public.knowledge_confidence as enum ('Official', 'Verified', 'Observed', 'Hypothesis');
create type public.knowledge_source_type as enum (
  'Official Doc', 'Training', 'Meeting', 'Customer', 'Book', 'Website',
  'Internal Material', 'AI Generated', 'Personal Note'
);
create type public.learning_type as enum ('Study', 'Review', 'Practice', 'Course', 'Product Training', 'Case Analysis');
create type public.learning_status as enum ('Planned', 'In Progress', 'Completed', 'Cancelled');
create type public.learning_outcome as enum ('Passed', 'Needs Practice', 'Blocked', 'Applied', 'Shared');
create type public.mastery as enum ('Aware', 'Understand', 'Explain', 'Apply', 'Teach');

create function private.content_block_document_v1_is_valid(p_document jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  block jsonb;
  item jsonb;
begin
  if jsonb_typeof(p_document) is distinct from 'object'
    or jsonb_typeof(p_document -> 'schemaVersion') is distinct from 'number'
    or p_document -> 'schemaVersion' <> '1'::jsonb
    or jsonb_typeof(p_document -> 'blocks') is distinct from 'array'
    or jsonb_array_length(p_document -> 'blocks') > 1000 then
    return false;
  end if;

  for block in select value from jsonb_array_elements(p_document -> 'blocks') loop
    if jsonb_typeof(block) is distinct from 'object'
      or jsonb_typeof(block -> 'id') is distinct from 'string'
      or length(btrim(block ->> 'id')) not between 1 and 100
      or jsonb_typeof(block -> 'type') is distinct from 'string' then
      return false;
    end if;

    case block ->> 'type'
      when 'paragraph' then
        if jsonb_typeof(block -> 'text') is distinct from 'string' or length(block ->> 'text') > 100000 then return false; end if;
      when 'quote' then
        if jsonb_typeof(block -> 'text') is distinct from 'string' or length(block ->> 'text') > 100000
          or (block ? 'citation' and (jsonb_typeof(block -> 'citation') is distinct from 'string' or length(btrim(block ->> 'citation')) > 500)) then return false; end if;
      when 'callout' then
        if jsonb_typeof(block -> 'text') is distinct from 'string' or length(block ->> 'text') > 100000
          or block ->> 'tone' not in ('info', 'success', 'warning') then return false; end if;
      when 'heading' then
        if jsonb_typeof(block -> 'text') is distinct from 'string' or length(block ->> 'text') > 100000
          or jsonb_typeof(block -> 'level') is distinct from 'number'
          or block ->> 'level' not in ('1', '2', '3') then return false; end if;
      when 'list' then
        if block ->> 'style' not in ('ordered', 'unordered') or jsonb_typeof(block -> 'items') is distinct from 'array'
          or jsonb_array_length(block -> 'items') > 500 then return false; end if;
        if exists (select 1 from jsonb_array_elements(block -> 'items') as list_item(value)
          where jsonb_typeof(value) is distinct from 'string' or length(value #>> '{}') > 100000) then return false; end if;
      when 'checklist' then
        if jsonb_typeof(block -> 'items') is distinct from 'array' or jsonb_array_length(block -> 'items') > 500 then return false; end if;
        for item in select value from jsonb_array_elements(block -> 'items') loop
          if jsonb_typeof(item) is distinct from 'object'
            or jsonb_typeof(item -> 'id') is distinct from 'string'
            or length(btrim(item ->> 'id')) not between 1 and 100
            or jsonb_typeof(item -> 'text') is distinct from 'string'
            or length(item ->> 'text') > 100000
            or jsonb_typeof(item -> 'checked') is distinct from 'boolean' then return false; end if;
        end loop;
      when 'code' then
        if jsonb_typeof(block -> 'code') is distinct from 'string' or length(block ->> 'code') > 100000
          or (block ? 'language' and (jsonb_typeof(block -> 'language') is distinct from 'string' or length(btrim(block ->> 'language')) > 50)) then return false; end if;
      when 'attachmentReference', 'imageReference' then
        if jsonb_typeof(block -> 'attachmentId') is distinct from 'string'
          or block ->> 'attachmentId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          or (block ? 'caption' and (jsonb_typeof(block -> 'caption') is distinct from 'string' or length(btrim(block ->> 'caption')) > 500)) then return false; end if;
      else return false;
    end case;
  end loop;

  if exists (
    select 1 from jsonb_array_elements(p_document -> 'blocks') as block(value)
    group by value ->> 'id' having count(*) > 1
  ) then return false; end if;
  return true;
end;
$$;

create function private.extract_content_block_plaintext(p_document jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    string_agg(btrim(part.value), E'\n' order by block.block_ordinality, part.part_ordinality)
      filter (where nullif(btrim(part.value), '') is not null),
    ''
  )
  from jsonb_array_elements(p_document -> 'blocks') with ordinality as block(value, block_ordinality)
  cross join lateral jsonb_array_elements_text(
    case block.value ->> 'type'
      when 'paragraph' then jsonb_build_array(block.value ->> 'text')
      when 'heading' then jsonb_build_array(block.value ->> 'text')
      when 'list' then block.value -> 'items'
      when 'quote' then jsonb_build_array(block.value ->> 'text', block.value ->> 'citation')
      when 'callout' then jsonb_build_array(block.value ->> 'text')
      when 'checklist' then coalesce((
        select jsonb_agg(item.value ->> 'text' order by item.item_ordinality)
        from jsonb_array_elements(block.value -> 'items') with ordinality as item(value, item_ordinality)
      ), '[]'::jsonb)
      when 'code' then jsonb_build_array(block.value ->> 'code')
      when 'attachmentReference' then jsonb_build_array(block.value ->> 'caption')
      when 'imageReference' then jsonb_build_array(block.value ->> 'caption')
      else '[]'::jsonb
    end
  ) with ordinality as part(value, part_ordinality);
$$;

create function public.derive_knowledge_content_plaintext()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.content_block_document_v1_is_valid(new.content_blocks) then
    raise exception using errcode = '23514', message = 'invalid ContentBlockDocument V1';
  end if;
  new.content_schema_version := 1;
  new.content_plaintext := private.extract_content_block_plaintext(new.content_blocks);
  return new;
end;
$$;

create table public.knowledge (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  title text not null check (length(btrim(title)) between 1 and 300),
  knowledge_type public.knowledge_type not null,
  status public.knowledge_status not null default 'Draft',
  confidence public.knowledge_confidence not null default 'Hypothesis',
  source_type public.knowledge_source_type not null,
  source_name text check (source_name is null or length(btrim(source_name)) between 1 and 300),
  source_url text check (source_url is null or length(source_url) <= 2000),
  summary text,
  technical_principle text,
  business_value text,
  education_scenario text,
  customer_pain_point text,
  sales_expression text,
  customer_questions text,
  competitive_note text,
  content_blocks jsonb not null default '{"schemaVersion":1,"blocks":[]}'::jsonb,
  content_schema_version integer not null default 1 check (content_schema_version = 1),
  content_plaintext text not null default '',
  data_level public.data_level not null default 'Level1',
  classification_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  constraint knowledge_owner_identity unique (owner_id, id),
  constraint knowledge_content_block_v1 check (
    private.content_block_document_v1_is_valid(content_blocks)
  )
);

create unique index knowledge_active_title_unique
on public.knowledge(owner_id, title)
where deleted_at is null;

create table public.learning (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  title text not null check (length(btrim(title)) between 1 and 300),
  learning_type public.learning_type not null,
  status public.learning_status not null default 'Planned',
  objective text,
  started_at timestamptz,
  completed_at timestamptz,
  duration_minutes integer check (duration_minutes is null or duration_minutes between 0 and 1440),
  takeaway text,
  practice_result text,
  learning_outcome public.learning_outcome,
  parent_learning_id uuid,
  data_level public.data_level not null default 'Level2',
  classification_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  constraint learning_owner_identity unique (owner_id, id),
  constraint learning_owner_parent_fk foreign key (owner_id, parent_learning_id)
    references public.learning(owner_id, id),
  constraint learning_parent_is_not_self check (parent_learning_id is null or parent_learning_id <> id),
  constraint learning_review_chain_consistent check (
    (learning_type = 'Review' and parent_learning_id is not null)
    or (learning_type <> 'Review' and parent_learning_id is null)
  ),
  constraint learning_completion_time_order check (completed_at is null or started_at is null or completed_at >= started_at)
);

create table public.learning_knowledge_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  learning_id uuid not null,
  knowledge_id uuid not null,
  mastery_before public.mastery not null,
  mastery_after public.mastery not null,
  created_at timestamptz not null default now(),
  constraint learning_knowledge_links_owner_identity unique (owner_id, id),
  constraint learning_knowledge_links_owner_learning_fk foreign key (owner_id, learning_id)
    references public.learning(owner_id, id),
  constraint learning_knowledge_links_owner_knowledge_fk foreign key (owner_id, knowledge_id)
    references public.knowledge(owner_id, id),
  constraint learning_knowledge_links_unique unique (owner_id, learning_id, knowledge_id)
);

create table public.knowledge_relations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  knowledge_id uuid not null,
  related_knowledge_id uuid not null,
  relation_type text not null check (length(btrim(relation_type)) between 1 and 80),
  created_at timestamptz not null default now(),
  constraint knowledge_relations_owner_identity unique (owner_id, id),
  constraint knowledge_relations_owner_knowledge_fk foreign key (owner_id, knowledge_id)
    references public.knowledge(owner_id, id),
  constraint knowledge_relations_owner_related_knowledge_fk foreign key (owner_id, related_knowledge_id)
    references public.knowledge(owner_id, id),
  constraint knowledge_relations_distinct_targets check (knowledge_id <> related_knowledge_id),
  constraint knowledge_relations_unique unique (owner_id, knowledge_id, related_knowledge_id, relation_type)
);

alter table public.attachment_links drop constraint attachment_links_target_not_installed;
alter table public.attachment_links add column knowledge_id uuid;
alter table public.attachment_links add column learning_id uuid;
alter table public.attachment_links add constraint attachment_links_owner_knowledge_fk
  foreign key (owner_id, knowledge_id) references public.knowledge(owner_id, id);
alter table public.attachment_links add constraint attachment_links_owner_learning_fk
  foreign key (owner_id, learning_id) references public.learning(owner_id, id);
alter table public.attachment_links add constraint attachment_links_exactly_one_target
  check (num_nonnulls(knowledge_id, learning_id) = 1);
create unique index attachment_links_owner_attachment_knowledge_unique
on public.attachment_links(owner_id, attachment_id, knowledge_id)
where knowledge_id is not null;
create unique index attachment_links_owner_attachment_learning_unique
on public.attachment_links(owner_id, attachment_id, learning_id)
where learning_id is not null;

alter table public.tag_links drop constraint tag_links_target_not_installed;
alter table public.tag_links add column knowledge_id uuid;
alter table public.tag_links add column learning_id uuid;
alter table public.tag_links add constraint tag_links_owner_knowledge_fk
  foreign key (owner_id, knowledge_id) references public.knowledge(owner_id, id);
alter table public.tag_links add constraint tag_links_owner_learning_fk
  foreign key (owner_id, learning_id) references public.learning(owner_id, id);
alter table public.tag_links add constraint tag_links_exactly_one_target
  check (num_nonnulls(knowledge_id, learning_id) = 1);
create unique index tag_links_owner_tag_knowledge_unique
on public.tag_links(owner_id, tag_id, knowledge_id)
where knowledge_id is not null;
create unique index tag_links_owner_tag_learning_unique
on public.tag_links(owner_id, tag_id, learning_id)
where learning_id is not null;

create table public.search_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  source_type text not null check (length(btrim(source_type)) between 1 and 100),
  source_id uuid not null,
  title text not null check (length(btrim(title)) between 1 and 300),
  subtitle text,
  search_text text not null,
  search_vector tsvector generated always as (to_tsvector('simple', title || ' ' || search_text)) stored,
  exact_lookup_hashes text[] not null default '{}',
  route text not null check (length(route) between 1 and 1000 and left(route, 1) = '/'),
  data_level public.data_level not null,
  visibility_state text not null check (length(btrim(visibility_state)) between 1 and 80),
  source_created_at timestamptz not null,
  source_updated_at timestamptz not null,
  projection_schema_version integer not null check (projection_schema_version > 0),
  indexed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint search_documents_owner_identity unique (owner_id, id),
  constraint search_documents_source_identity unique (owner_id, source_type, source_id),
  constraint search_documents_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create trigger knowledge_guard_mutation
before update on public.knowledge
for each row execute function public.guard_mutable_entity();
create trigger knowledge_derive_content_plaintext
before insert or update of content_blocks, content_schema_version, content_plaintext on public.knowledge
for each row execute function public.derive_knowledge_content_plaintext();
create trigger learning_guard_mutation
before update on public.learning
for each row execute function public.guard_mutable_entity();
create trigger knowledge_reject_physical_delete
before delete on public.knowledge
for each row execute function public.reject_mutable_entity_delete();
create trigger learning_reject_physical_delete
before delete on public.learning
for each row execute function public.reject_mutable_entity_delete();

alter table public.knowledge enable row level security;
alter table public.knowledge force row level security;
alter table public.learning enable row level security;
alter table public.learning force row level security;
alter table public.learning_knowledge_links enable row level security;
alter table public.learning_knowledge_links force row level security;
alter table public.knowledge_relations enable row level security;
alter table public.knowledge_relations force row level security;
alter table public.search_documents enable row level security;
alter table public.search_documents force row level security;

create policy knowledge_select_owner on public.knowledge for select to authenticated
using (auth.uid() = owner_id and deleted_at is null);
create policy knowledge_insert_denied on public.knowledge for insert to authenticated with check (false);
create policy knowledge_update_denied on public.knowledge for update to authenticated using (false) with check (false);
create policy knowledge_delete_denied on public.knowledge for delete to authenticated using (false);
create policy learning_select_owner on public.learning for select to authenticated
using (auth.uid() = owner_id and deleted_at is null);
create policy learning_insert_denied on public.learning for insert to authenticated with check (false);
create policy learning_update_denied on public.learning for update to authenticated using (false) with check (false);
create policy learning_delete_denied on public.learning for delete to authenticated using (false);
create policy learning_knowledge_links_select_owner on public.learning_knowledge_links for select to authenticated
using (auth.uid() = owner_id);
create policy learning_knowledge_links_insert_denied on public.learning_knowledge_links for insert to authenticated with check (false);
create policy learning_knowledge_links_update_denied on public.learning_knowledge_links for update to authenticated using (false) with check (false);
create policy learning_knowledge_links_delete_denied on public.learning_knowledge_links for delete to authenticated using (false);
create policy knowledge_relations_select_owner on public.knowledge_relations for select to authenticated
using (auth.uid() = owner_id);
create policy knowledge_relations_insert_denied on public.knowledge_relations for insert to authenticated with check (false);
create policy knowledge_relations_update_denied on public.knowledge_relations for update to authenticated using (false) with check (false);
create policy knowledge_relations_delete_denied on public.knowledge_relations for delete to authenticated using (false);
create policy search_documents_select_owner on public.search_documents for select to authenticated
using (auth.uid() = owner_id);
create policy search_documents_insert_denied on public.search_documents for insert to authenticated with check (false);
create policy search_documents_update_denied on public.search_documents for update to authenticated using (false) with check (false);
create policy search_documents_delete_denied on public.search_documents for delete to authenticated using (false);

grant select, insert, update, delete on public.knowledge, public.learning,
  public.learning_knowledge_links, public.knowledge_relations, public.search_documents
to authenticated;
grant select, insert, update, delete on public.knowledge, public.learning,
  public.learning_knowledge_links, public.knowledge_relations, public.search_documents
to service_role;
