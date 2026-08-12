alter function public.complete_learning(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb)
  set schema private;
alter function private.complete_learning(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb)
  rename to execute_complete_learning;
revoke all on function private.execute_complete_learning(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb)
  from public, anon, authenticated, service_role;

create function public.complete_learning_exact(
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
  supplied_count integer;
  supplied_distinct_count integer;
  linked_count integer;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  if exists (
    select 1 from public.command_receipts receipt
    where receipt.owner_id = p_verified_user_id
      and receipt.client_request_id = p_client_request_id
      and receipt.command_type = 'CompleteLearning'
      and receipt.status = 'Completed'
  ) then
    return query select * from private.execute_complete_learning(
      p_verified_user_id, p_client_request_id, p_learning_id, p_expected_version,
      p_completed_at, p_duration_minutes, p_takeaway, p_practice_result, p_learning_outcome, p_knowledge_mastery
    );
    return;
  end if;
  if jsonb_typeof(p_knowledge_mastery) is distinct from 'array' then
    raise exception using errcode = 'P0001', message = 'learning mastery must match every linked knowledge exactly';
  end if;
  select jsonb_array_length(p_knowledge_mastery), count(distinct value ->> 'knowledgeId')
  into supplied_count, supplied_distinct_count
  from jsonb_array_elements(p_knowledge_mastery);
  select count(*) into linked_count
  from public.learning_knowledge_links
  where owner_id = p_verified_user_id and learning_id = p_learning_id;
  if supplied_count <> supplied_distinct_count or supplied_count <> linked_count
    or exists (
      select knowledge_id::text from public.learning_knowledge_links
      where owner_id = p_verified_user_id and learning_id = p_learning_id
      except select value ->> 'knowledgeId' from jsonb_array_elements(p_knowledge_mastery)
    ) or exists (
      select value ->> 'knowledgeId' from jsonb_array_elements(p_knowledge_mastery)
      except select knowledge_id::text from public.learning_knowledge_links
      where owner_id = p_verified_user_id and learning_id = p_learning_id
    ) then
    raise exception using errcode = 'P0001', message = 'learning mastery must match every linked knowledge exactly';
  end if;
  return query select * from private.execute_complete_learning(
    p_verified_user_id, p_client_request_id, p_learning_id, p_expected_version,
    p_completed_at, p_duration_minutes, p_takeaway, p_practice_result, p_learning_outcome, p_knowledge_mastery
  );
end;
$$;

revoke all on function public.complete_learning_exact(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb)
  from public, anon, authenticated;
grant execute on function public.complete_learning_exact(uuid,uuid,uuid,integer,timestamptz,integer,text,text,public.learning_outcome,jsonb)
  to service_role;

create or replace function public.create_review_learning(
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
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  if exists (
    select 1 from public.command_receipts receipt
    where receipt.owner_id = p_verified_user_id
      and receipt.client_request_id = p_client_request_id
      and receipt.command_type = 'CreateReviewLearning'
      and receipt.status = 'Completed'
  ) then
    return query select * from private.execute_create_learning(
      p_verified_user_id, p_client_request_id, 'CreateReviewLearning', p_title, 'Review', p_status,
      p_objective, p_started_at, p_completed_at, p_duration_minutes, p_takeaway, p_practice_result,
      p_learning_outcome, p_parent_learning_id, p_data_level, p_classification_reason,
      p_attachment_ids, p_tag_ids, p_knowledge_links
    );
    return;
  end if;
  if not exists (
    select 1 from public.learning parent
    where parent.owner_id = p_verified_user_id and parent.id = p_parent_learning_id
      and parent.deleted_at is null and parent.status = 'Completed'
  ) then
    raise exception using errcode = 'P0001', message = 'review parent must be completed';
  end if;
  return query select * from private.execute_create_learning(
    p_verified_user_id, p_client_request_id, 'CreateReviewLearning', p_title, 'Review', p_status,
    p_objective, p_started_at, p_completed_at, p_duration_minutes, p_takeaway, p_practice_result,
    p_learning_outcome, p_parent_learning_id, p_data_level, p_classification_reason,
    p_attachment_ids, p_tag_ids, p_knowledge_links
  );
end;
$$;
