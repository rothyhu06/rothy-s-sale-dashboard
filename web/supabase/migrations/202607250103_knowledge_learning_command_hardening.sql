create function private.uuid_array_from_jsonb(p_value jsonb, p_label text)
returns uuid[]
language plpgsql
immutable
set search_path = ''
as $$
declare result uuid[];
begin
  if jsonb_typeof(p_value) is distinct from 'array' or jsonb_array_length(p_value) > 100 then
    raise exception using errcode = 'P0001', message = 'invalid ' || p_label;
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_value) as item(value)
    where jsonb_typeof(value) is distinct from 'string'
      or value #>> '{}' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) then raise exception using errcode = 'P0001', message = 'invalid ' || p_label; end if;
  select coalesce(array_agg((value #>> '{}')::uuid order by (value #>> '{}')::uuid), '{}'::uuid[])
  into result from jsonb_array_elements(p_value);
  if cardinality(result) <> (select count(distinct value) from unnest(result) as item(value)) then
    raise exception using errcode = 'P0001', message = 'duplicate ' || p_label;
  end if;
  return result;
end;
$$;

create function private.normalize_knowledge_relations(p_relations jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare result jsonb;
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
  select coalesce(jsonb_agg(
    jsonb_build_object('relatedKnowledgeId', value ->> 'relatedKnowledgeId', 'relationType', btrim(value ->> 'relationType'))
    order by value ->> 'relatedKnowledgeId', btrim(value ->> 'relationType')
  ), '[]'::jsonb) into result from jsonb_array_elements(p_relations);
  if jsonb_array_length(result) <> (
    select count(distinct (value ->> 'relatedKnowledgeId', value ->> 'relationType')) from jsonb_array_elements(result)
  ) then raise exception using errcode = 'P0001', message = 'duplicate knowledge relation'; end if;
  return result;
end;
$$;

create function private.knowledge_relation_ids(p_relations jsonb)
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct (value ->> 'relatedKnowledgeId')::uuid order by (value ->> 'relatedKnowledgeId')::uuid), '{}'::uuid[])
  from jsonb_array_elements(private.normalize_knowledge_relations(p_relations));
$$;

create function private.learning_knowledge_ids(p_links jsonb)
returns uuid[]
language plpgsql
immutable
set search_path = ''
as $$
declare result uuid[];
begin
  if jsonb_typeof(p_links) is distinct from 'array' or jsonb_array_length(p_links) > 100 then
    raise exception using errcode = 'P0001', message = 'invalid learning knowledge links';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_links) as item(value)
    where jsonb_typeof(value -> 'knowledgeId') is distinct from 'string'
      or value ->> 'knowledgeId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) then raise exception using errcode = 'P0001', message = 'invalid learning knowledge links'; end if;
  select coalesce(array_agg((value ->> 'knowledgeId')::uuid order by (value ->> 'knowledgeId')::uuid), '{}'::uuid[])
  into result from jsonb_array_elements(p_links);
  if cardinality(result) <> (select count(distinct value) from unnest(result) as item(value)) then
    raise exception using errcode = 'P0001', message = 'duplicate learning knowledge link';
  end if;
  return result;
end;
$$;

create function private.validate_knowledge_content_references(
  p_owner_id uuid, p_content_blocks jsonb, p_attachment_ids uuid[]
)
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  attachment_ids uuid[] := private.validate_knowledge_attachments(p_content_blocks, p_attachment_ids);
  image_ids uuid[];
begin
  select coalesce(array_agg(distinct (value ->> 'attachmentId')::uuid), '{}'::uuid[]) into image_ids
  from jsonb_array_elements(p_content_blocks -> 'blocks')
  where value ->> 'type' = 'imageReference';
  if cardinality(image_ids) <> (
    select count(*) from public.attachments
    where owner_id = p_owner_id and id = any(image_ids) and file_category = 'Image'
      and storage_status = 'Available' and deleted_at is null
  ) then raise exception using errcode = 'P0001', message = 'image reference must target an image attachment'; end if;
  return attachment_ids;
end;
$$;

create function private.calculate_effective_data_level(
  p_owner_id uuid, p_base_data_level public.data_level,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_ids uuid[], p_parent_learning_id uuid
)
returns public.data_level
language plpgsql
security definer
set search_path = ''
as $$
declare
  effective_level public.data_level;
  effective_rank integer;
  candidate_rank integer;
  knowledge_ids uuid[] := coalesce(p_knowledge_ids, '{}'::uuid[]);
begin
  effective_level := private.validate_links_and_effective_data_level(
    p_owner_id, p_base_data_level, p_attachment_ids, p_tag_ids
  );
  effective_rank := private.data_level_rank(effective_level);
  if cardinality(knowledge_ids) <> (select count(distinct value) from unnest(knowledge_ids) as item(value)) then
    raise exception using errcode = 'P0001', message = 'duplicate knowledge link target';
  end if;
  if cardinality(knowledge_ids) <> (
    select count(*) from public.knowledge
    where owner_id = p_owner_id and id = any(knowledge_ids) and deleted_at is null
  ) then raise exception using errcode = 'P0001', message = 'knowledge link target not found'; end if;
  select max(private.data_level_rank(data_level)) into candidate_rank
  from public.knowledge where owner_id = p_owner_id and id = any(knowledge_ids) and deleted_at is null;
  effective_rank := greatest(effective_rank, coalesce(candidate_rank, effective_rank));
  if p_parent_learning_id is not null then
    select private.data_level_rank(data_level) into candidate_rank
    from public.learning where owner_id = p_owner_id and id = p_parent_learning_id and deleted_at is null;
    if candidate_rank is null then raise exception using errcode = 'P0001', message = 'parent learning not found'; end if;
    effective_rank := greatest(effective_rank, candidate_rank);
  end if;
  return private.data_level_from_rank(effective_rank);
end;
$$;

create function private.promote_linked_attachments(
  p_owner_id uuid, p_attachment_ids uuid[], p_effective_level public.data_level,
  p_client_request_id uuid, p_operation_id uuid, p_source_entity_type text, p_source_entity_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare promoted record;
begin
  for promoted in
    update public.attachments as target set data_level = p_effective_level
    where target.owner_id = p_owner_id and target.id = any(coalesce(p_attachment_ids, '{}'::uuid[]))
      and target.deleted_at is null
      and private.data_level_rank(target.data_level) < private.data_level_rank(p_effective_level)
    returning target.id, target.version
  loop
    perform private.append_audit_log(
      p_owner_id, 'AttachmentDataLevelRaised', 'Attachment', promoted.id,
      null, p_client_request_id, p_operation_id, jsonb_build_array('data_level'),
      jsonb_build_object('sourceEntityType', p_source_entity_type, 'sourceEntityId', p_source_entity_id,
        'attachmentVersion', promoted.version), null, null, 'Success', null
    );
  end loop;
end;
$$;

create or replace function public.create_knowledge(
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
  normalized_relations jsonb;
  relation_ids uuid[];
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
  attachment_ids := private.validate_knowledge_content_references(p_verified_user_id, p_content_blocks, p_attachment_ids);
  normalized_relations := private.normalize_knowledge_relations(p_relations);
  relation_ids := private.knowledge_relation_ids(normalized_relations);
  effective_level := private.calculate_effective_data_level(
    p_verified_user_id, p_data_level, attachment_ids, p_tag_ids, relation_ids, null
  );
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
  perform private.replace_knowledge_links(p_verified_user_id, entity.id, attachment_ids, p_tag_ids, normalized_relations);
  perform private.promote_linked_attachments(
    p_verified_user_id, attachment_ids, effective_level, p_client_request_id, receipt.operation_id, 'Knowledge', entity.id
  );
  perform private.refresh_knowledge_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id, 'KnowledgeCreated', 'Knowledge', entity.id,
    null, p_client_request_id, receipt.operation_id,
    array_to_json(array['title','knowledge_type','status','confidence','source_type','content_blocks','data_level','attachment_links','tag_links','knowledge_relations'])::jsonb,
    jsonb_build_object('attachmentCount', cardinality(attachment_ids), 'tagCount', cardinality(coalesce(p_tag_ids, '{}'::uuid[]))),
    null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Knowledge', entity.id, jsonb_build_object('knowledgeId', entity.id));
  return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
end;
$$;

drop function public.update_knowledge(
  uuid,uuid,uuid,integer,text,public.knowledge_type,public.knowledge_status,
  public.knowledge_confidence,public.knowledge_source_type,text,text,text,text,text,text,text,text,text,text,
  jsonb,public.data_level,text,uuid[],uuid[],jsonb
);

create function public.update_knowledge(
  p_verified_user_id uuid, p_client_request_id uuid, p_knowledge_id uuid,
  p_expected_version integer, p_patch jsonb
)
returns table (id uuid, title text, content_plaintext text, data_level public.data_level, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  receipt record;
  entity public.knowledge%rowtype;
  final_title text; final_knowledge_type public.knowledge_type; final_status public.knowledge_status;
  final_confidence public.knowledge_confidence; final_source_type public.knowledge_source_type;
  final_source_name text; final_source_url text; final_summary text; final_technical_principle text;
  final_business_value text; final_education_scenario text; final_customer_pain_point text;
  final_sales_expression text; final_customer_questions text; final_competitive_note text;
  final_content_blocks jsonb; requested_level public.data_level; final_level public.data_level;
  final_classification_reason text;
  old_attachment_ids uuid[]; final_attachment_ids uuid[]; old_tag_ids uuid[]; final_tag_ids uuid[];
  old_relations jsonb; final_relations jsonb; relation_ids uuid[];
  changed_fields text[] := '{}'::text[];
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'UpdateKnowledge', p_client_request_id);
  if receipt.status = 'Completed' then
    select * into entity from public.knowledge where owner_id = p_verified_user_id
      and knowledge.id = (receipt.result_reference ->> 'knowledgeId')::uuid;
    return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
    return;
  end if;
  if jsonb_typeof(p_patch) is distinct from 'object' or not private.jsonb_has_only_keys(p_patch, array[
    'title','knowledgeType','status','confidence','sourceType','sourceName','sourceUrl','summary',
    'technicalPrinciple','businessValue','educationScenario','customerPainPoint','salesExpression',
    'customerQuestions','competitiveNote','contentBlocks','dataLevel','classificationReason',
    'attachmentIds','tagIds','relations'
  ]) then raise exception using errcode = 'P0001', message = 'invalid Knowledge patch'; end if;
  select * into entity from public.knowledge where owner_id = p_verified_user_id and knowledge.id = p_knowledge_id
    and deleted_at is null for update;
  if entity.id is null then raise exception using errcode = 'P0001', message = 'knowledge not found'; end if;
  if entity.version <> p_expected_version then raise exception using errcode = '40001', message = 'knowledge version conflict'; end if;

  select coalesce(array_agg(attachment_id order by attachment_id), '{}'::uuid[]) into old_attachment_ids
  from public.attachment_links where owner_id = p_verified_user_id and knowledge_id = entity.id;
  select coalesce(array_agg(tag_id order by tag_id), '{}'::uuid[]) into old_tag_ids
  from public.tag_links where owner_id = p_verified_user_id and knowledge_id = entity.id;
  select coalesce(jsonb_agg(jsonb_build_object('relatedKnowledgeId', related_knowledge_id, 'relationType', relation_type)
    order by related_knowledge_id, relation_type), '[]'::jsonb) into old_relations
  from public.knowledge_relations where owner_id = p_verified_user_id and knowledge_id = entity.id;

  final_title := case when p_patch ? 'title' then p_patch ->> 'title' else entity.title end;
  final_knowledge_type := case when p_patch ? 'knowledgeType' then (p_patch ->> 'knowledgeType')::public.knowledge_type else entity.knowledge_type end;
  final_status := case when p_patch ? 'status' then (p_patch ->> 'status')::public.knowledge_status else entity.status end;
  final_confidence := case when p_patch ? 'confidence' then (p_patch ->> 'confidence')::public.knowledge_confidence else entity.confidence end;
  final_source_type := case when p_patch ? 'sourceType' then (p_patch ->> 'sourceType')::public.knowledge_source_type else entity.source_type end;
  final_source_name := case when p_patch ? 'sourceName' then p_patch ->> 'sourceName' else entity.source_name end;
  final_source_url := case when p_patch ? 'sourceUrl' then p_patch ->> 'sourceUrl' else entity.source_url end;
  final_summary := case when p_patch ? 'summary' then p_patch ->> 'summary' else entity.summary end;
  final_technical_principle := case when p_patch ? 'technicalPrinciple' then p_patch ->> 'technicalPrinciple' else entity.technical_principle end;
  final_business_value := case when p_patch ? 'businessValue' then p_patch ->> 'businessValue' else entity.business_value end;
  final_education_scenario := case when p_patch ? 'educationScenario' then p_patch ->> 'educationScenario' else entity.education_scenario end;
  final_customer_pain_point := case when p_patch ? 'customerPainPoint' then p_patch ->> 'customerPainPoint' else entity.customer_pain_point end;
  final_sales_expression := case when p_patch ? 'salesExpression' then p_patch ->> 'salesExpression' else entity.sales_expression end;
  final_customer_questions := case when p_patch ? 'customerQuestions' then p_patch ->> 'customerQuestions' else entity.customer_questions end;
  final_competitive_note := case when p_patch ? 'competitiveNote' then p_patch ->> 'competitiveNote' else entity.competitive_note end;
  final_content_blocks := case when p_patch ? 'contentBlocks' then private.normalize_content_block_document_v1(p_patch -> 'contentBlocks') else entity.content_blocks end;
  requested_level := case when p_patch ? 'dataLevel' then (p_patch ->> 'dataLevel')::public.data_level else entity.data_level end;
  final_classification_reason := case when p_patch ? 'classificationReason' then p_patch ->> 'classificationReason' else entity.classification_reason end;
  final_attachment_ids := case when p_patch ? 'attachmentIds' then private.uuid_array_from_jsonb(p_patch -> 'attachmentIds', 'attachment references') else old_attachment_ids end;
  final_tag_ids := case when p_patch ? 'tagIds' then private.uuid_array_from_jsonb(p_patch -> 'tagIds', 'tag references') else old_tag_ids end;
  final_relations := case when p_patch ? 'relations' then private.normalize_knowledge_relations(p_patch -> 'relations') else old_relations end;
  perform private.validate_knowledge_content_references(p_verified_user_id, final_content_blocks, final_attachment_ids);
  relation_ids := private.knowledge_relation_ids(final_relations);
  if entity.id = any(relation_ids) then raise exception using errcode = 'P0001', message = 'knowledge cannot relate to itself'; end if;
  final_level := private.calculate_effective_data_level(
    p_verified_user_id,
    private.data_level_from_rank(greatest(private.data_level_rank(entity.data_level), private.data_level_rank(requested_level))),
    final_attachment_ids, final_tag_ids, relation_ids, null
  );

  if final_title is distinct from entity.title then changed_fields := array_append(changed_fields, 'title'); end if;
  if final_knowledge_type is distinct from entity.knowledge_type then changed_fields := array_append(changed_fields, 'knowledge_type'); end if;
  if final_status is distinct from entity.status then changed_fields := array_append(changed_fields, 'status'); end if;
  if final_confidence is distinct from entity.confidence then changed_fields := array_append(changed_fields, 'confidence'); end if;
  if final_source_type is distinct from entity.source_type then changed_fields := array_append(changed_fields, 'source_type'); end if;
  if final_source_name is distinct from entity.source_name then changed_fields := array_append(changed_fields, 'source_name'); end if;
  if final_source_url is distinct from entity.source_url then changed_fields := array_append(changed_fields, 'source_url'); end if;
  if final_summary is distinct from entity.summary then changed_fields := array_append(changed_fields, 'summary'); end if;
  if final_technical_principle is distinct from entity.technical_principle then changed_fields := array_append(changed_fields, 'technical_principle'); end if;
  if final_business_value is distinct from entity.business_value then changed_fields := array_append(changed_fields, 'business_value'); end if;
  if final_education_scenario is distinct from entity.education_scenario then changed_fields := array_append(changed_fields, 'education_scenario'); end if;
  if final_customer_pain_point is distinct from entity.customer_pain_point then changed_fields := array_append(changed_fields, 'customer_pain_point'); end if;
  if final_sales_expression is distinct from entity.sales_expression then changed_fields := array_append(changed_fields, 'sales_expression'); end if;
  if final_customer_questions is distinct from entity.customer_questions then changed_fields := array_append(changed_fields, 'customer_questions'); end if;
  if final_competitive_note is distinct from entity.competitive_note then changed_fields := array_append(changed_fields, 'competitive_note'); end if;
  if final_content_blocks is distinct from entity.content_blocks then changed_fields := array_append(changed_fields, 'content_blocks'); end if;
  if final_level is distinct from entity.data_level then changed_fields := array_append(changed_fields, 'data_level'); end if;
  if final_classification_reason is distinct from entity.classification_reason then changed_fields := array_append(changed_fields, 'classification_reason'); end if;
  if final_attachment_ids is distinct from old_attachment_ids then changed_fields := array_append(changed_fields, 'attachment_links'); end if;
  if final_tag_ids is distinct from old_tag_ids then changed_fields := array_append(changed_fields, 'tag_links'); end if;
  if final_relations is distinct from old_relations then changed_fields := array_append(changed_fields, 'knowledge_relations'); end if;

  update public.knowledge as target set
    title = final_title, knowledge_type = final_knowledge_type, status = final_status,
    confidence = final_confidence, source_type = final_source_type, source_name = final_source_name,
    source_url = final_source_url, summary = final_summary, technical_principle = final_technical_principle,
    business_value = final_business_value, education_scenario = final_education_scenario,
    customer_pain_point = final_customer_pain_point, sales_expression = final_sales_expression,
    customer_questions = final_customer_questions, competitive_note = final_competitive_note,
    content_blocks = final_content_blocks, data_level = final_level, classification_reason = final_classification_reason
  where target.owner_id = p_verified_user_id and target.id = entity.id returning target.* into entity;
  if p_patch ? 'attachmentIds' then
    delete from public.attachment_links where owner_id = p_verified_user_id and knowledge_id = entity.id;
    insert into public.attachment_links(owner_id, attachment_id, knowledge_id)
    select p_verified_user_id, value, entity.id from unnest(final_attachment_ids) as item(value);
  end if;
  if p_patch ? 'tagIds' then
    delete from public.tag_links where owner_id = p_verified_user_id and knowledge_id = entity.id;
    insert into public.tag_links(owner_id, tag_id, knowledge_id)
    select p_verified_user_id, value, entity.id from unnest(final_tag_ids) as item(value);
  end if;
  if p_patch ? 'relations' then
    delete from public.knowledge_relations where owner_id = p_verified_user_id and knowledge_id = entity.id;
    insert into public.knowledge_relations(owner_id, knowledge_id, related_knowledge_id, relation_type)
    select p_verified_user_id, entity.id, (value ->> 'relatedKnowledgeId')::uuid, value ->> 'relationType'
    from jsonb_array_elements(final_relations);
  end if;
  perform private.promote_linked_attachments(
    p_verified_user_id, final_attachment_ids, final_level, p_client_request_id, receipt.operation_id, 'Knowledge', entity.id
  );
  perform private.refresh_knowledge_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id, 'KnowledgeUpdated', 'Knowledge', entity.id,
    null, p_client_request_id, receipt.operation_id, to_jsonb(changed_fields), '{}'::jsonb,
    null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Knowledge', entity.id, jsonb_build_object('knowledgeId', entity.id));
  return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
end;
$$;

create or replace function private.execute_create_learning(
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
  knowledge_ids uuid[];
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
      select 1 from public.learning as parent where parent.owner_id = p_verified_user_id
        and parent.id = p_parent_learning_id and parent.deleted_at is null
    ) then raise exception using errcode = 'P0001', message = 'parent learning not found'; end if;
  elsif p_parent_learning_id is not null then
    raise exception using errcode = 'P0001', message = 'only Review can reference a parent learning';
  end if;
  knowledge_ids := private.learning_knowledge_ids(p_knowledge_links);
  effective_level := private.calculate_effective_data_level(
    p_verified_user_id, p_data_level, p_attachment_ids, p_tag_ids, knowledge_ids, p_parent_learning_id
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
  perform private.promote_linked_attachments(
    p_verified_user_id, p_attachment_ids, effective_level, p_client_request_id, receipt.operation_id, 'Learning', entity.id
  );
  perform private.refresh_learning_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id,
    case when p_learning_type = 'Review' then 'ReviewLearningCreated' else 'LearningCreated' end,
    'Learning', entity.id, null, p_client_request_id, receipt.operation_id,
    array_to_json(array['title','learning_type','status','objective','data_level','attachment_links','tag_links','knowledge_links'])::jsonb,
    jsonb_build_object('parentLearningId', entity.parent_learning_id), null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Learning', entity.id, jsonb_build_object('learningId', entity.id));
  return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
end;
$$;

create or replace function public.complete_learning(
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
  receipt record; entity public.learning%rowtype; mastery_change jsonb;
  existing_link public.learning_knowledge_links%rowtype;
  attachment_ids uuid[]; tag_ids uuid[]; knowledge_ids uuid[]; effective_level public.data_level;
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
    set mastery_after = (mastery_change ->> 'masteryAfter')::public.mastery where target.id = existing_link.id;
  end loop;
  select coalesce(array_agg(attachment_id), '{}'::uuid[]) into attachment_ids
  from public.attachment_links where owner_id = p_verified_user_id and learning_id = entity.id;
  select coalesce(array_agg(tag_id), '{}'::uuid[]) into tag_ids
  from public.tag_links where owner_id = p_verified_user_id and learning_id = entity.id;
  select coalesce(array_agg(knowledge_id), '{}'::uuid[]) into knowledge_ids
  from public.learning_knowledge_links where owner_id = p_verified_user_id and learning_id = entity.id;
  effective_level := private.calculate_effective_data_level(
    p_verified_user_id, entity.data_level, attachment_ids, tag_ids, knowledge_ids, entity.parent_learning_id
  );
  update public.learning as target set status = 'Completed', completed_at = p_completed_at,
    duration_minutes = p_duration_minutes, takeaway = p_takeaway, practice_result = p_practice_result,
    learning_outcome = p_learning_outcome, data_level = effective_level
  where target.owner_id = p_verified_user_id and target.id = p_learning_id returning target.* into entity;
  perform private.promote_linked_attachments(
    p_verified_user_id, attachment_ids, effective_level, p_client_request_id, receipt.operation_id, 'Learning', entity.id
  );
  perform private.refresh_learning_search(p_verified_user_id, entity.id);
  perform private.append_audit_log(p_verified_user_id, 'LearningCompleted', 'Learning', entity.id,
    null, p_client_request_id, receipt.operation_id,
    array_to_json(array['status','completed_at','duration_minutes','takeaway','practice_result','learning_outcome','mastery_after','data_level'])::jsonb,
    '{}'::jsonb, null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Learning', entity.id, jsonb_build_object('learningId', entity.id));
  return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
end;
$$;

create function public.delete_knowledge(
  p_verified_user_id uuid, p_client_request_id uuid, p_knowledge_id uuid, p_expected_version integer
)
returns table (id uuid, title text, content_plaintext text, data_level public.data_level, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare receipt record; entity public.knowledge%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'DeleteKnowledge', p_client_request_id);
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
  update public.knowledge as target set deleted_at = now(), deleted_by = p_verified_user_id
  where target.owner_id = p_verified_user_id and target.id = entity.id returning target.* into entity;
  delete from public.search_documents where owner_id = p_verified_user_id and source_type = 'Knowledge' and source_id = entity.id;
  perform private.append_audit_log(p_verified_user_id, 'KnowledgeDeleted', 'Knowledge', entity.id,
    null, p_client_request_id, receipt.operation_id, jsonb_build_array('deleted_at','deleted_by'), '{}'::jsonb,
    null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Knowledge', entity.id, jsonb_build_object('knowledgeId', entity.id));
  return query select entity.id, entity.title, entity.content_plaintext, entity.data_level, entity.version, receipt.operation_id;
end;
$$;

create function public.delete_learning(
  p_verified_user_id uuid, p_client_request_id uuid, p_learning_id uuid, p_expected_version integer
)
returns table (id uuid, title text, status public.learning_status, version integer, operation_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare receipt record; entity public.learning%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception using errcode = '42501', message = 'service role required'; end if;
  select * into receipt from private.claim_command_receipt(p_verified_user_id, 'DeleteLearning', p_client_request_id);
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
  update public.learning as target set deleted_at = now(), deleted_by = p_verified_user_id
  where target.owner_id = p_verified_user_id and target.id = entity.id returning target.* into entity;
  delete from public.search_documents where owner_id = p_verified_user_id and source_type = 'Learning' and source_id = entity.id;
  perform private.append_audit_log(p_verified_user_id, 'LearningDeleted', 'Learning', entity.id,
    null, p_client_request_id, receipt.operation_id, jsonb_build_array('deleted_at','deleted_by'), '{}'::jsonb,
    null, null, 'Success', null);
  perform private.complete_command_receipt(p_verified_user_id, receipt.id, receipt.operation_id, 'Completed',
    'Learning', entity.id, jsonb_build_object('learningId', entity.id));
  return query select entity.id, entity.title, entity.status, entity.version, receipt.operation_id;
end;
$$;

create function public.get_continue_learning(p_limit integer default 4)
returns table (
  id uuid, title text, learning_type public.learning_type, status public.learning_status,
  objective text, started_at timestamptz, completed_at timestamptz,
  learning_outcome public.learning_outcome, parent_learning_id uuid, updated_at timestamptz, version integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select item.id, item.title, item.learning_type, item.status, item.objective, item.started_at,
    item.completed_at, item.learning_outcome, item.parent_learning_id, item.updated_at, item.version
  from public.learning as item
  where item.owner_id = auth.uid() and item.deleted_at is null and item.status in ('In Progress','Planned')
  order by case item.status when 'In Progress' then 1 when 'Planned' then 2 else 3 end,
    item.updated_at desc, item.id desc
  limit least(greatest(p_limit, 1), 20);
$$;

revoke all on function public.update_knowledge(uuid,uuid,uuid,integer,jsonb) from public, anon, authenticated;
revoke all on function public.delete_knowledge(uuid,uuid,uuid,integer) from public, anon, authenticated;
revoke all on function public.delete_learning(uuid,uuid,uuid,integer) from public, anon, authenticated;
revoke all on function public.get_continue_learning(integer) from public, anon;
grant execute on function public.update_knowledge(uuid,uuid,uuid,integer,jsonb) to service_role;
grant execute on function public.delete_knowledge(uuid,uuid,uuid,integer) to service_role;
grant execute on function public.delete_learning(uuid,uuid,uuid,integer) to service_role;
grant execute on function public.get_continue_learning(integer) to authenticated;

revoke all on function private.uuid_array_from_jsonb(jsonb,text) from public, anon, authenticated, service_role;
revoke all on function private.normalize_knowledge_relations(jsonb) from public, anon, authenticated, service_role;
revoke all on function private.knowledge_relation_ids(jsonb) from public, anon, authenticated, service_role;
revoke all on function private.learning_knowledge_ids(jsonb) from public, anon, authenticated, service_role;
revoke all on function private.validate_knowledge_content_references(uuid,jsonb,uuid[]) from public, anon, authenticated, service_role;
revoke all on function private.calculate_effective_data_level(uuid,public.data_level,uuid[],uuid[],uuid[],uuid) from public, anon, authenticated, service_role;
revoke all on function private.promote_linked_attachments(uuid,uuid[],public.data_level,uuid,uuid,text,uuid) from public, anon, authenticated, service_role;
