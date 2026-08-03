create function private.data_level_rank(p_level public.data_level)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_level when 'Level1' then 1 when 'Level2' then 2 when 'Level3' then 3 end;
$$;

create function private.data_level_from_rank(p_rank integer)
returns public.data_level
language sql
immutable
set search_path = ''
as $$
  select case p_rank when 1 then 'Level1'::public.data_level when 2 then 'Level2'::public.data_level else 'Level3'::public.data_level end;
$$;

create function private.validate_links_and_effective_data_level(
  p_owner_id uuid,
  p_base_data_level public.data_level,
  p_attachment_ids uuid[],
  p_tag_ids uuid[]
)
returns public.data_level
language plpgsql
security definer
set search_path = ''
as $$
declare
  attachment_ids uuid[] := coalesce(p_attachment_ids, '{}'::uuid[]);
  tag_ids uuid[] := coalesce(p_tag_ids, '{}'::uuid[]);
  effective_rank integer := private.data_level_rank(p_base_data_level);
  candidate_rank integer;
begin
  if cardinality(attachment_ids) <> (select count(distinct value) from unnest(attachment_ids) as item(value)) then
    raise exception using errcode = 'P0001', message = 'duplicate attachment reference';
  end if;
  if cardinality(tag_ids) <> (select count(distinct value) from unnest(tag_ids) as item(value)) then
    raise exception using errcode = 'P0001', message = 'duplicate tag reference';
  end if;

  if cardinality(attachment_ids) <> (
    select count(*) from public.attachments
    where owner_id = p_owner_id and id = any(attachment_ids)
      and storage_status = 'Available' and deleted_at is null
  ) then
    raise exception using errcode = 'P0001', message = 'attachment reference is unavailable';
  end if;
  if cardinality(tag_ids) <> (
    select count(*) from public.tags
    where owner_id = p_owner_id and id = any(tag_ids) and deleted_at is null
  ) then
    raise exception using errcode = 'P0001', message = 'tag reference is unavailable';
  end if;

  select max(private.data_level_rank(data_level)) into candidate_rank
  from public.attachments where owner_id = p_owner_id and id = any(attachment_ids);
  effective_rank := greatest(effective_rank, coalesce(candidate_rank, effective_rank));
  select max(private.data_level_rank(data_level)) into candidate_rank
  from public.tags where owner_id = p_owner_id and id = any(tag_ids);
  effective_rank := greatest(effective_rank, coalesce(candidate_rank, effective_rank));
  return private.data_level_from_rank(effective_rank);
end;
$$;

create function private.knowledge_content_attachment_ids(p_content_blocks jsonb)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct (block.value ->> 'attachmentId')::uuid order by (block.value ->> 'attachmentId')::uuid), '{}'::uuid[])
  from jsonb_array_elements(p_content_blocks -> 'blocks') as block(value)
  where block.value ->> 'type' in ('attachmentReference', 'imageReference');
$$;

create function private.validate_knowledge_attachments(p_content_blocks jsonb, p_attachment_ids uuid[])
returns uuid[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  derived_ids uuid[] := private.knowledge_content_attachment_ids(p_content_blocks);
  supplied_ids uuid[];
begin
  select coalesce(array_agg(distinct value order by value), '{}'::uuid[]) into supplied_ids
  from unnest(coalesce(p_attachment_ids, '{}'::uuid[])) as item(value);
  if cardinality(coalesce(p_attachment_ids, '{}'::uuid[])) <> cardinality(supplied_ids)
    or supplied_ids is distinct from derived_ids then
    raise exception using errcode = 'P0001', message = 'attachment references do not match content blocks';
  end if;
  return derived_ids;
end;
$$;

create function private.replace_knowledge_links(
  p_owner_id uuid,
  p_knowledge_id uuid,
  p_attachment_ids uuid[],
  p_tag_ids uuid[],
  p_relations jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare relation jsonb;
begin
  if jsonb_typeof(p_relations) is distinct from 'array' or jsonb_array_length(p_relations) > 100 then
    raise exception using errcode = 'P0001', message = 'invalid knowledge relations';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_relations) as item(value)
    where not private.jsonb_has_only_keys(value, array['relatedKnowledgeId','relationType'])
      or jsonb_typeof(value -> 'relatedKnowledgeId') is distinct from 'string'
      or value ->> 'relatedKnowledgeId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(value -> 'relationType') is distinct from 'string'
      or length(btrim(value ->> 'relationType')) not between 1 and 80
  ) then raise exception using errcode = 'P0001', message = 'invalid knowledge relations'; end if;
  if jsonb_array_length(p_relations) <> (
    select count(distinct (value ->> 'relatedKnowledgeId', btrim(value ->> 'relationType')))
    from jsonb_array_elements(p_relations)
  ) then raise exception using errcode = 'P0001', message = 'duplicate knowledge relation'; end if;

  for relation in select value from jsonb_array_elements(p_relations) loop
    if (relation ->> 'relatedKnowledgeId')::uuid = p_knowledge_id then
      raise exception using errcode = 'P0001', message = 'knowledge cannot relate to itself';
    end if;
    if not exists (
      select 1 from public.knowledge
      where owner_id = p_owner_id and id = (relation ->> 'relatedKnowledgeId')::uuid and deleted_at is null
    ) then raise exception using errcode = 'P0001', message = 'related knowledge not found'; end if;
  end loop;

  delete from public.attachment_links where owner_id = p_owner_id and knowledge_id = p_knowledge_id;
  insert into public.attachment_links(owner_id, attachment_id, knowledge_id)
  select p_owner_id, id, p_knowledge_id from unnest(coalesce(p_attachment_ids, '{}'::uuid[])) as item(id);
  delete from public.tag_links where owner_id = p_owner_id and knowledge_id = p_knowledge_id;
  insert into public.tag_links(owner_id, tag_id, knowledge_id)
  select p_owner_id, id, p_knowledge_id from unnest(coalesce(p_tag_ids, '{}'::uuid[])) as item(id);
  delete from public.knowledge_relations where owner_id = p_owner_id and knowledge_id = p_knowledge_id;
  insert into public.knowledge_relations(owner_id, knowledge_id, related_knowledge_id, relation_type)
  select p_owner_id, p_knowledge_id, (value ->> 'relatedKnowledgeId')::uuid, btrim(value ->> 'relationType')
  from jsonb_array_elements(p_relations);
end;
$$;

create function private.refresh_knowledge_search(p_owner_id uuid, p_knowledge_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare entity public.knowledge%rowtype;
begin
  select * into entity from public.knowledge where owner_id = p_owner_id and id = p_knowledge_id;
  if entity.id is null then raise exception using errcode = 'P0001', message = 'knowledge not found'; end if;
  insert into public.search_documents (
    owner_id, source_type, source_id, title, subtitle, search_text, route, data_level,
    visibility_state, source_created_at, source_updated_at, projection_schema_version, indexed_at, metadata
  ) values (
    p_owner_id, 'Knowledge', entity.id, entity.title, entity.summary,
    concat_ws(E'\n', entity.title, entity.source_name, entity.summary, entity.technical_principle,
      entity.business_value, entity.education_scenario, entity.customer_pain_point,
      entity.sales_expression, entity.customer_questions, entity.competitive_note, entity.content_plaintext),
    '/knowledge/' || entity.id::text, entity.data_level, entity.status::text,
    entity.created_at, entity.updated_at, 1, now(),
    jsonb_build_object('knowledgeType', entity.knowledge_type, 'confidence', entity.confidence, 'sourceType', entity.source_type)
  )
  on conflict (owner_id, source_type, source_id) do update set
    title = excluded.title, subtitle = excluded.subtitle, search_text = excluded.search_text,
    route = excluded.route, data_level = excluded.data_level, visibility_state = excluded.visibility_state,
    source_created_at = excluded.source_created_at, source_updated_at = excluded.source_updated_at,
    projection_schema_version = excluded.projection_schema_version, indexed_at = excluded.indexed_at,
    metadata = excluded.metadata;
end;
$$;

create function private.refresh_learning_search(p_owner_id uuid, p_learning_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare entity public.learning%rowtype;
begin
  select * into entity from public.learning where owner_id = p_owner_id and id = p_learning_id;
  if entity.id is null then raise exception using errcode = 'P0001', message = 'learning not found'; end if;
  insert into public.search_documents (
    owner_id, source_type, source_id, title, subtitle, search_text, route, data_level,
    visibility_state, source_created_at, source_updated_at, projection_schema_version, indexed_at, metadata
  ) values (
    p_owner_id, 'Learning', entity.id, entity.title, entity.objective,
    concat_ws(E'\n', entity.title, entity.objective, entity.takeaway, entity.practice_result),
    '/learning/' || entity.id::text, entity.data_level, entity.status::text,
    entity.created_at, entity.updated_at, 1, now(),
    jsonb_build_object('learningType', entity.learning_type, 'learningOutcome', entity.learning_outcome,
      'parentLearningId', entity.parent_learning_id)
  )
  on conflict (owner_id, source_type, source_id) do update set
    title = excluded.title, subtitle = excluded.subtitle, search_text = excluded.search_text,
    route = excluded.route, data_level = excluded.data_level, visibility_state = excluded.visibility_state,
    source_created_at = excluded.source_created_at, source_updated_at = excluded.source_updated_at,
    projection_schema_version = excluded.projection_schema_version, indexed_at = excluded.indexed_at,
    metadata = excluded.metadata;
end;
$$;

create function public.create_knowledge(
  p_verified_user_id uuid, p_client_request_id uuid,
  p_title text, p_knowledge_type public.knowledge_type, p_status public.knowledge_status,
  p_confidence public.knowledge_confidence, p_source_type public.knowledge_source_type,
  p_source_name text, p_source_url text, p_summary text, p_technical_principle text,
  p_business_value text, p_education_scenario text, p_customer_pain_point text,
  p_sales_expression text, p_customer_questions text, p_competitive_note text,
  p_content_blocks jsonb, p_data_level public.data_level, p_classification_reason text,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_relations jsonb
)
returns table (id uuid, title text, content_plaintext text, data_level public.data_level, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  receipt record;
  entity public.knowledge%rowtype;
  attachment_ids uuid[];
  effective_level public.data_level;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'CreateKnowledge', p_client_request_id);
  if receipt.status = 'Completed' then
    select * into entity from public.knowledge where owner_id = p_verified_user_id
      and knowledge.id = (receipt.result_reference ->> 'knowledgeId')::uuid;
    return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
    return;
  end if;

  attachment_ids := private.validate_knowledge_attachments(p_content_blocks, p_attachment_ids);
  effective_level := private.validate_links_and_effective_data_level(p_verified_user_id, p_data_level, attachment_ids, p_tag_ids);
  insert into public.knowledge (
    owner_id, title, knowledge_type, status, confidence, source_type, source_name, source_url,
    summary, technical_principle, business_value, education_scenario, customer_pain_point,
    sales_expression, customer_questions, competitive_note, content_blocks, data_level, classification_reason
  ) values (
    p_verified_user_id, btrim(p_title), p_knowledge_type, p_status, p_confidence, p_source_type,
    nullif(btrim(p_source_name), ''), p_source_url, p_summary, p_technical_principle, p_business_value,
    p_education_scenario, p_customer_pain_point, p_sales_expression, p_customer_questions,
    p_competitive_note, p_content_blocks, effective_level, p_classification_reason
  ) returning * into entity;
  perform private.replace_knowledge_links(p_verified_user_id, entity.id, attachment_ids, p_tag_ids, p_relations);
  perform private.refresh_knowledge_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id, 'KnowledgeCreated', 'Knowledge', entity.id,
    null, p_client_request_id, receipt.operation_id,
    array_to_json(array['title','knowledge_type','status','confidence','source_type','content_blocks','data_level'])::jsonb,
    jsonb_build_object('attachmentCount', cardinality(attachment_ids), 'tagCount', cardinality(coalesce(p_tag_ids, '{}'::uuid[]))),
    null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Knowledge', entity.id, jsonb_build_object('knowledgeId', entity.id));
  return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
end;
$$;

create function public.update_knowledge(
  p_verified_user_id uuid, p_client_request_id uuid, p_knowledge_id uuid, p_expected_version integer,
  p_title text, p_knowledge_type public.knowledge_type, p_status public.knowledge_status,
  p_confidence public.knowledge_confidence, p_source_type public.knowledge_source_type,
  p_source_name text, p_source_url text, p_summary text, p_technical_principle text,
  p_business_value text, p_education_scenario text, p_customer_pain_point text,
  p_sales_expression text, p_customer_questions text, p_competitive_note text,
  p_content_blocks jsonb, p_data_level public.data_level, p_classification_reason text,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_relations jsonb
)
returns table (id uuid, title text, content_plaintext text, data_level public.data_level, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  receipt record;
  entity public.knowledge%rowtype;
  attachment_ids uuid[];
  effective_level public.data_level;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'UpdateKnowledge', p_client_request_id);
  if receipt.status = 'Completed' then
    select * into entity from public.knowledge where owner_id = p_verified_user_id
      and knowledge.id = (receipt.result_reference ->> 'knowledgeId')::uuid;
    return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
    return;
  end if;

  select * into entity from public.knowledge where owner_id = p_verified_user_id and knowledge.id = p_knowledge_id
    and deleted_at is null for update;
  if entity.id is null then raise exception using errcode = 'P0001', message = 'knowledge not found'; end if;
  if entity.version <> p_expected_version then raise exception using errcode = '40001', message = 'knowledge version conflict'; end if;
  attachment_ids := private.validate_knowledge_attachments(p_content_blocks, p_attachment_ids);
  effective_level := private.validate_links_and_effective_data_level(
    p_verified_user_id, private.data_level_from_rank(greatest(private.data_level_rank(entity.data_level), private.data_level_rank(p_data_level))),
    attachment_ids, p_tag_ids
  );
  update public.knowledge as target set
    title = btrim(p_title), knowledge_type = p_knowledge_type, status = p_status, confidence = p_confidence,
    source_type = p_source_type, source_name = nullif(btrim(p_source_name), ''), source_url = p_source_url,
    summary = p_summary, technical_principle = p_technical_principle, business_value = p_business_value,
    education_scenario = p_education_scenario, customer_pain_point = p_customer_pain_point,
    sales_expression = p_sales_expression, customer_questions = p_customer_questions,
    competitive_note = p_competitive_note, content_blocks = p_content_blocks,
    data_level = effective_level, classification_reason = p_classification_reason
  where target.owner_id = p_verified_user_id and target.id = p_knowledge_id
  returning target.* into entity;
  perform private.replace_knowledge_links(p_verified_user_id, entity.id, attachment_ids, p_tag_ids, p_relations);
  perform private.refresh_knowledge_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id, 'KnowledgeUpdated', 'Knowledge', entity.id,
    null, p_client_request_id, receipt.operation_id,
    array_to_json(array['title','knowledge_type','status','confidence','source_type','content_blocks','data_level','links'])::jsonb,
    '{}'::jsonb, null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Knowledge', entity.id, jsonb_build_object('knowledgeId', entity.id));
  return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
end;
$$;

create function private.mastery_rank(p_mastery public.mastery)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_mastery when 'Aware' then 1 when 'Understand' then 2 when 'Explain' then 3 when 'Apply' then 4 when 'Teach' then 5 end;
$$;

create function private.insert_learning_links(
  p_owner_id uuid, p_learning_id uuid, p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_links jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p_knowledge_links) is distinct from 'array' or jsonb_array_length(p_knowledge_links) > 100 then
    raise exception using errcode = 'P0001', message = 'invalid learning knowledge links';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_knowledge_links) as item(value)
    where not private.jsonb_has_only_keys(value, array['knowledgeId','masteryBefore','masteryAfter'])
      or jsonb_typeof(value -> 'knowledgeId') is distinct from 'string'
      or value ->> 'knowledgeId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(value -> 'masteryBefore') is distinct from 'string'
      or jsonb_typeof(value -> 'masteryAfter') is distinct from 'string'
      or value ->> 'masteryBefore' not in ('Aware','Understand','Explain','Apply','Teach')
      or value ->> 'masteryAfter' not in ('Aware','Understand','Explain','Apply','Teach')
  ) then raise exception using errcode = 'P0001', message = 'invalid learning knowledge links'; end if;
  if jsonb_array_length(p_knowledge_links) <> (
    select count(distinct value ->> 'knowledgeId') from jsonb_array_elements(p_knowledge_links)
  ) then raise exception using errcode = 'P0001', message = 'duplicate learning knowledge link'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_knowledge_links) as item(value)
    where private.mastery_rank((value ->> 'masteryAfter')::public.mastery)
      < private.mastery_rank((value ->> 'masteryBefore')::public.mastery)
  ) then raise exception using errcode = 'P0001', message = 'mastery cannot decrease'; end if;
  if jsonb_array_length(p_knowledge_links) <> (
    select count(*) from public.knowledge
    where owner_id = p_owner_id and deleted_at is null
      and id in (select (value ->> 'knowledgeId')::uuid from jsonb_array_elements(p_knowledge_links))
  ) then raise exception using errcode = 'P0001', message = 'knowledge link target not found'; end if;

  insert into public.attachment_links(owner_id, attachment_id, learning_id)
  select p_owner_id, id, p_learning_id from unnest(coalesce(p_attachment_ids, '{}'::uuid[])) as item(id);
  insert into public.tag_links(owner_id, tag_id, learning_id)
  select p_owner_id, id, p_learning_id from unnest(coalesce(p_tag_ids, '{}'::uuid[])) as item(id);
  insert into public.learning_knowledge_links(owner_id, learning_id, knowledge_id, mastery_before, mastery_after)
  select p_owner_id, p_learning_id, (value ->> 'knowledgeId')::uuid,
    (value ->> 'masteryBefore')::public.mastery, (value ->> 'masteryAfter')::public.mastery
  from jsonb_array_elements(p_knowledge_links);
end;
$$;

create function private.execute_create_learning(
  p_verified_user_id uuid, p_client_request_id uuid, p_command_type text,
  p_title text, p_learning_type public.learning_type, p_status public.learning_status,
  p_objective text, p_started_at timestamptz, p_completed_at timestamptz, p_duration_minutes integer,
  p_takeaway text, p_practice_result text, p_learning_outcome public.learning_outcome,
  p_parent_learning_id uuid, p_data_level public.data_level, p_classification_reason text,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_links jsonb
)
returns table (id uuid, title text, status public.learning_status, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  receipt record;
  entity public.learning%rowtype;
  effective_level public.data_level;
begin
  select * into receipt from private.claim_command_receipt(p_verified_user_id, p_command_type, p_client_request_id);
  if receipt.status = 'Completed' then
    select * into entity from public.learning where owner_id = p_verified_user_id
      and learning.id = (receipt.result_reference ->> 'learningId')::uuid;
    return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
    return;
  end if;
  if p_learning_type = 'Review' then
    if p_parent_learning_id is null or not exists (
      select 1 from public.learning as parent
      where parent.owner_id = p_verified_user_id and parent.id = p_parent_learning_id and parent.deleted_at is null
    ) then raise exception using errcode = 'P0001', message = 'parent learning not found'; end if;
  elsif p_parent_learning_id is not null then
    raise exception using errcode = 'P0001', message = 'only Review can reference a parent learning';
  end if;
  effective_level := private.validate_links_and_effective_data_level(
    p_verified_user_id, p_data_level, p_attachment_ids, p_tag_ids
  );
  insert into public.learning (
    owner_id, title, learning_type, status, objective, started_at, completed_at, duration_minutes,
    takeaway, practice_result, learning_outcome, parent_learning_id, data_level, classification_reason
  ) values (
    p_verified_user_id, btrim(p_title), p_learning_type, p_status, p_objective, p_started_at, p_completed_at,
    p_duration_minutes, p_takeaway, p_practice_result, p_learning_outcome, p_parent_learning_id,
    effective_level, p_classification_reason
  ) returning * into entity;
  perform private.insert_learning_links(p_verified_user_id, entity.id, p_attachment_ids, p_tag_ids, p_knowledge_links);
  perform private.refresh_learning_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id,
    case when p_learning_type = 'Review' then 'ReviewLearningCreated' else 'LearningCreated' end,
    'Learning', entity.id, null, p_client_request_id, receipt.operation_id,
    array_to_json(array['title','learning_type','status','objective','data_level','links'])::jsonb,
    jsonb_build_object('parentLearningId', entity.parent_learning_id), null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Learning', entity.id, jsonb_build_object('learningId', entity.id));
  return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
end;
$$;

create function public.create_learning(
  p_verified_user_id uuid, p_client_request_id uuid,
  p_title text, p_learning_type public.learning_type, p_status public.learning_status,
  p_objective text, p_started_at timestamptz, p_completed_at timestamptz, p_duration_minutes integer,
  p_takeaway text, p_practice_result text, p_learning_outcome public.learning_outcome,
  p_parent_learning_id uuid, p_data_level public.data_level, p_classification_reason text,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_links jsonb
)
returns table (id uuid, title text, status public.learning_status, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  if p_learning_type = 'Review' then raise exception using errcode = 'P0001', message = 'use Review command for review learning'; end if;
  return query select * from private.execute_create_learning(
    p_verified_user_id, p_client_request_id, 'CreateLearning', p_title, p_learning_type, p_status,
    p_objective, p_started_at, p_completed_at, p_duration_minutes, p_takeaway, p_practice_result,
    p_learning_outcome, p_parent_learning_id, p_data_level, p_classification_reason,
    p_attachment_ids, p_tag_ids, p_knowledge_links
  );
end;
$$;

create function public.create_review_learning(
  p_verified_user_id uuid, p_client_request_id uuid,
  p_title text, p_status public.learning_status, p_objective text,
  p_started_at timestamptz, p_completed_at timestamptz, p_duration_minutes integer,
  p_takeaway text, p_practice_result text, p_learning_outcome public.learning_outcome,
  p_parent_learning_id uuid, p_data_level public.data_level, p_classification_reason text,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_links jsonb
)
returns table (id uuid, title text, status public.learning_status, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  return query select * from private.execute_create_learning(
    p_verified_user_id, p_client_request_id, 'CreateReviewLearning', p_title, 'Review', p_status,
    p_objective, p_started_at, p_completed_at, p_duration_minutes, p_takeaway, p_practice_result,
    p_learning_outcome, p_parent_learning_id, p_data_level, p_classification_reason,
    p_attachment_ids, p_tag_ids, p_knowledge_links
  );
end;
$$;

create function public.complete_learning(
  p_verified_user_id uuid, p_client_request_id uuid, p_learning_id uuid, p_expected_version integer,
  p_completed_at timestamptz, p_duration_minutes integer, p_takeaway text,
  p_practice_result text, p_learning_outcome public.learning_outcome, p_knowledge_mastery jsonb
)
returns table (id uuid, title text, status public.learning_status, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  receipt record;
  entity public.learning%rowtype;
  mastery_change jsonb;
  existing_link public.learning_knowledge_links%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'CompleteLearning', p_client_request_id);
  if receipt.status = 'Completed' then
    select * into entity from public.learning where owner_id = p_verified_user_id
      and learning.id = (receipt.result_reference ->> 'learningId')::uuid;
    return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
    return;
  end if;
  select * into entity from public.learning where owner_id = p_verified_user_id and learning.id = p_learning_id
    and deleted_at is null for update;
  if entity.id is null then raise exception using errcode = 'P0001', message = 'learning not found'; end if;
  if entity.version <> p_expected_version then raise exception using errcode = '40001', message = 'learning version conflict'; end if;
  if jsonb_typeof(p_knowledge_mastery) is distinct from 'array' or jsonb_array_length(p_knowledge_mastery) > 100 then
    raise exception using errcode = 'P0001', message = 'invalid learning mastery updates';
  end if;
  if jsonb_array_length(p_knowledge_mastery) <> (
    select count(distinct value ->> 'knowledgeId') from jsonb_array_elements(p_knowledge_mastery)
  ) then raise exception using errcode = 'P0001', message = 'duplicate learning mastery update'; end if;
  for mastery_change in select value from jsonb_array_elements(p_knowledge_mastery) loop
    if not private.jsonb_has_only_keys(mastery_change, array['knowledgeId','masteryAfter'])
      or jsonb_typeof(mastery_change -> 'knowledgeId') is distinct from 'string'
      or mastery_change ->> 'knowledgeId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(mastery_change -> 'masteryAfter') is distinct from 'string'
      or mastery_change ->> 'masteryAfter' not in ('Aware','Understand','Explain','Apply','Teach') then
      raise exception using errcode = 'P0001', message = 'invalid learning mastery updates';
    end if;
    select * into existing_link from public.learning_knowledge_links
    where owner_id = p_verified_user_id and learning_id = p_learning_id
      and knowledge_id = (mastery_change ->> 'knowledgeId')::uuid for update;
    if existing_link.id is null then raise exception using errcode = 'P0001', message = 'learning knowledge link not found'; end if;
    if private.mastery_rank((mastery_change ->> 'masteryAfter')::public.mastery)
      < private.mastery_rank(existing_link.mastery_after) then
      raise exception using errcode = 'P0001', message = 'mastery cannot decrease';
    end if;
    update public.learning_knowledge_links as target
    set mastery_after = (mastery_change ->> 'masteryAfter')::public.mastery
    where target.id = existing_link.id;
  end loop;
  update public.learning as target set status = 'Completed', completed_at = p_completed_at,
    duration_minutes = p_duration_minutes, takeaway = p_takeaway, practice_result = p_practice_result,
    learning_outcome = p_learning_outcome
  where target.owner_id = p_verified_user_id and target.id = p_learning_id
  returning target.* into entity;
  perform private.refresh_learning_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id, 'LearningCompleted', 'Learning', entity.id,
    null, p_client_request_id, receipt.operation_id,
    array_to_json(array['status','completed_at','duration_minutes','takeaway','practice_result','learning_outcome','mastery_after'])::jsonb,
    '{}'::jsonb, null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Learning', entity.id, jsonb_build_object('learningId', entity.id));
  return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
end;
$$;

revoke all on function public.create_knowledge(uuid,uuid,text,public.knowledge_type,public.knowledge_status,public.knowledge_confidence,public.knowledge_source_type,text,text,text,text,text,text,text,text,text,text,jsonb,public.data_level,text,uuid[],uuid[],jsonb) from public, anon, authenticated;
revoke all on function public.update_knowledge(uuid,uuid,uuid,integer,text,public.knowledge_type,public.knowledge_status,public.knowledge_confidence,public.knowledge_source_type,text,text,text,text,text,text,text,text,text,text,jsonb,public.data_level,text,uuid[],uuid[],jsonb) from public, anon, authenticated;
revoke all on function public.create_learning(uuid,uuid,text,public.learning_type,public.learning_status,text,timestamptz,timestamptz,integer,text,text,public.learning_outcome,uuid,public.data_level,text,uuid[],uuid[],jsonb) from public, anon, authenticated;
revoke all on function public.create_review_learning(uuid,uuid,text,public.learning_status,text,timestamptz,timestamptz,integer,text,text,public.learning_outcome,uuid,public.data_level,text,uuid[],uuid[],jsonb) from public, anon, authenticated;
revoke all on function public.complete_learning(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb) from public, anon, authenticated;

grant execute on function public.create_knowledge(uuid,uuid,text,public.knowledge_type,public.knowledge_status,public.knowledge_confidence,public.knowledge_source_type,text,text,text,text,text,text,text,text,text,text,jsonb,public.data_level,text,uuid[],uuid[],jsonb) to service_role;
grant execute on function public.update_knowledge(uuid,uuid,uuid,integer,text,public.knowledge_type,public.knowledge_status,public.knowledge_confidence,public.knowledge_source_type,text,text,text,text,text,text,text,text,text,text,jsonb,public.data_level,text,uuid[],uuid[],jsonb) to service_role;
grant execute on function public.create_learning(uuid,uuid,text,public.learning_type,public.learning_status,text,timestamptz,timestamptz,integer,text,text,public.learning_outcome,uuid,public.data_level,text,uuid[],uuid[],jsonb) to service_role;
grant execute on function public.create_review_learning(uuid,uuid,text,public.learning_status,text,timestamptz,timestamptz,integer,text,text,public.learning_outcome,uuid,public.data_level,text,uuid[],uuid[],jsonb) to service_role;
grant execute on function public.complete_learning(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb) to service_role;

revoke all on function private.data_level_rank(public.data_level) from public, anon, authenticated, service_role;
revoke all on function private.data_level_from_rank(integer) from public, anon, authenticated, service_role;
revoke all on function private.validate_links_and_effective_data_level(uuid,public.data_level,uuid[],uuid[]) from public, anon, authenticated, service_role;
revoke all on function private.knowledge_content_attachment_ids(jsonb) from public, anon, authenticated, service_role;
revoke all on function private.validate_knowledge_attachments(jsonb,uuid[]) from public, anon, authenticated, service_role;
revoke all on function private.replace_knowledge_links(uuid,uuid,uuid[],uuid[],jsonb) from public, anon, authenticated, service_role;
revoke all on function private.refresh_knowledge_search(uuid,uuid) from public, anon, authenticated, service_role;
revoke all on function private.refresh_learning_search(uuid,uuid) from public, anon, authenticated, service_role;
revoke all on function private.mastery_rank(public.mastery) from public, anon, authenticated, service_role;
revoke all on function private.insert_learning_links(uuid,uuid,uuid[],uuid[],jsonb) from public, anon, authenticated, service_role;
revoke all on function private.execute_create_learning(uuid,uuid,text,text,public.learning_type,public.learning_status,text,timestamptz,timestamptz,integer,text,text,public.learning_outcome,uuid,public.data_level,text,uuid[],uuid[],jsonb) from public, anon, authenticated, service_role;
