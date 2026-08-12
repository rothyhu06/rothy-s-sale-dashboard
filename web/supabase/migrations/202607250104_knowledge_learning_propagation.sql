create function private.calculate_active_effective_data_level(
  p_owner_id uuid, p_floor public.data_level,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_ids uuid[], p_parent_learning_id uuid
)
returns public.data_level
language sql
stable
security definer
set search_path = ''
as $$
  select private.data_level_from_rank(greatest(
    private.data_level_rank(p_floor),
    coalesce((select max(private.data_level_rank(data_level)) from public.attachments
      where owner_id = p_owner_id and id = any(coalesce(p_attachment_ids, '{}'::uuid[]))
        and deleted_at is null and storage_status = 'Available'), 0),
    coalesce((select max(private.data_level_rank(data_level)) from public.tags
      where owner_id = p_owner_id and id = any(coalesce(p_tag_ids, '{}'::uuid[])) and deleted_at is null), 0),
    coalesce((select max(private.data_level_rank(data_level)) from public.knowledge
      where owner_id = p_owner_id and id = any(coalesce(p_knowledge_ids, '{}'::uuid[])) and deleted_at is null), 0),
    coalesce((select private.data_level_rank(data_level) from public.learning
      where owner_id = p_owner_id and id = p_parent_learning_id and deleted_at is null), 0)
  ));
$$;

create function private.propagate_data_levels(
  p_owner_id uuid, p_client_request_id uuid, p_operation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  desired_levels jsonb;
  desired jsonb;
  changed_id uuid;
begin
  with recursive
  nodes(kind, id, level_rank) as (
    select 'Attachment'::text, id, private.data_level_rank(data_level)
    from public.attachments where owner_id = p_owner_id and deleted_at is null and storage_status = 'Available'
    union all
    select 'Tag', id, private.data_level_rank(data_level)
    from public.tags where owner_id = p_owner_id and deleted_at is null
    union all
    select 'Knowledge', id, private.data_level_rank(data_level)
    from public.knowledge where owner_id = p_owner_id and deleted_at is null
    union all
    select 'Learning', id, private.data_level_rank(data_level)
    from public.learning where owner_id = p_owner_id and deleted_at is null
  ),
  edges(source_kind, source_id, target_kind, target_id) as (
    select 'Attachment', link.attachment_id, 'Knowledge', link.knowledge_id
    from public.attachment_links link
    join public.attachments source on source.owner_id = link.owner_id and source.id = link.attachment_id
      and source.deleted_at is null and source.storage_status = 'Available'
    join public.knowledge target on target.owner_id = link.owner_id and target.id = link.knowledge_id and target.deleted_at is null
    where link.owner_id = p_owner_id and link.knowledge_id is not null
    union all
    select 'Knowledge', link.knowledge_id, 'Attachment', link.attachment_id
    from public.attachment_links link
    join public.attachments target on target.owner_id = link.owner_id and target.id = link.attachment_id
      and target.deleted_at is null and target.storage_status = 'Available'
    join public.knowledge source on source.owner_id = link.owner_id and source.id = link.knowledge_id and source.deleted_at is null
    where link.owner_id = p_owner_id and link.knowledge_id is not null
    union all
    select 'Attachment', link.attachment_id, 'Learning', link.learning_id
    from public.attachment_links link
    join public.attachments source on source.owner_id = link.owner_id and source.id = link.attachment_id
      and source.deleted_at is null and source.storage_status = 'Available'
    join public.learning target on target.owner_id = link.owner_id and target.id = link.learning_id and target.deleted_at is null
    where link.owner_id = p_owner_id and link.learning_id is not null
    union all
    select 'Learning', link.learning_id, 'Attachment', link.attachment_id
    from public.attachment_links link
    join public.attachments target on target.owner_id = link.owner_id and target.id = link.attachment_id
      and target.deleted_at is null and target.storage_status = 'Available'
    join public.learning source on source.owner_id = link.owner_id and source.id = link.learning_id and source.deleted_at is null
    where link.owner_id = p_owner_id and link.learning_id is not null
    union all
    select 'Tag', link.tag_id, 'Knowledge', link.knowledge_id
    from public.tag_links link join public.tags source on source.owner_id = link.owner_id and source.id = link.tag_id and source.deleted_at is null
    join public.knowledge target on target.owner_id = link.owner_id and target.id = link.knowledge_id and target.deleted_at is null
    where link.owner_id = p_owner_id and link.knowledge_id is not null
    union all
    select 'Tag', link.tag_id, 'Learning', link.learning_id
    from public.tag_links link join public.tags source on source.owner_id = link.owner_id and source.id = link.tag_id and source.deleted_at is null
    join public.learning target on target.owner_id = link.owner_id and target.id = link.learning_id and target.deleted_at is null
    where link.owner_id = p_owner_id and link.learning_id is not null
    union all
    select 'Knowledge', relation.related_knowledge_id, 'Knowledge', relation.knowledge_id
    from public.knowledge_relations relation
    join public.knowledge source on source.owner_id = relation.owner_id and source.id = relation.related_knowledge_id and source.deleted_at is null
    join public.knowledge target on target.owner_id = relation.owner_id and target.id = relation.knowledge_id and target.deleted_at is null
    where relation.owner_id = p_owner_id
    union all
    select 'Knowledge', link.knowledge_id, 'Learning', link.learning_id
    from public.learning_knowledge_links link
    join public.knowledge source on source.owner_id = link.owner_id and source.id = link.knowledge_id and source.deleted_at is null
    join public.learning target on target.owner_id = link.owner_id and target.id = link.learning_id and target.deleted_at is null
    where link.owner_id = p_owner_id
    union all
    select 'Learning', child.parent_learning_id, 'Learning', child.id
    from public.learning child join public.learning parent
      on parent.owner_id = child.owner_id and parent.id = child.parent_learning_id and parent.deleted_at is null
    where child.owner_id = p_owner_id and child.deleted_at is null and child.learning_type = 'Review'
  ),
  reach(source_kind, source_id, source_rank, target_kind, target_id) as (
    select kind, id, level_rank, kind, id from nodes
    union
    select reach.source_kind, reach.source_id, reach.source_rank, edge.target_kind, edge.target_id
    from reach join edges edge on edge.source_kind = reach.target_kind and edge.source_id = reach.target_id
  ),
  maxima as (
    select target_kind kind, target_id id, max(source_rank) level_rank
    from reach group by target_kind, target_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('kind', maxima.kind, 'id', maxima.id, 'rank', maxima.level_rank)), '[]'::jsonb)
  into desired_levels
  from maxima join nodes current_node using (kind, id)
  where maxima.level_rank > current_node.level_rank and maxima.kind <> 'Tag';

  for desired in select value from jsonb_array_elements(desired_levels) loop
    changed_id := null;
    if desired ->> 'kind' = 'Knowledge' then
      update public.knowledge set data_level = private.data_level_from_rank((desired ->> 'rank')::integer)
      where owner_id = p_owner_id and id = (desired ->> 'id')::uuid and deleted_at is null
        and private.data_level_rank(data_level) < (desired ->> 'rank')::integer returning id into changed_id;
      if changed_id is not null then perform private.refresh_knowledge_search(p_owner_id, changed_id); end if;
    elsif desired ->> 'kind' = 'Learning' then
      update public.learning set data_level = private.data_level_from_rank((desired ->> 'rank')::integer)
      where owner_id = p_owner_id and id = (desired ->> 'id')::uuid and deleted_at is null
        and private.data_level_rank(data_level) < (desired ->> 'rank')::integer returning id into changed_id;
      if changed_id is not null then perform private.refresh_learning_search(p_owner_id, changed_id); end if;
    elsif desired ->> 'kind' = 'Attachment' then
      update public.attachments set data_level = private.data_level_from_rank((desired ->> 'rank')::integer)
      where owner_id = p_owner_id and id = (desired ->> 'id')::uuid and deleted_at is null and storage_status = 'Available'
        and private.data_level_rank(data_level) < (desired ->> 'rank')::integer returning id into changed_id;
    end if;
    if changed_id is not null then
      perform private.append_audit_log(
        p_owner_id, 'ClassificationRaised', desired ->> 'kind', changed_id,
        null, p_client_request_id, p_operation_id, jsonb_build_array('data_level'),
        jsonb_build_object('reason', 'dependencyPropagation'), null, null, 'Success', null
      );
    end if;
  end loop;
end;
$$;

create or replace function private.calculate_effective_data_level(
  p_owner_id uuid, p_base_data_level public.data_level,
  p_attachment_ids uuid[], p_tag_ids uuid[], p_knowledge_ids uuid[], p_parent_learning_id uuid
)
returns public.data_level
language sql
stable
security definer
set search_path = ''
as $$
  select private.calculate_active_effective_data_level(
    p_owner_id, p_base_data_level, p_attachment_ids, p_tag_ids, p_knowledge_ids, p_parent_learning_id
  );
$$;

create function private.validate_new_attachment_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.knowledge_id is null and new.learning_id is null then return new; end if;
  if not exists (
    select 1 from public.attachments
    where owner_id = new.owner_id and id = new.attachment_id
      and deleted_at is null and storage_status = 'Available'
  ) then raise exception using errcode = 'P0001', message = 'attachment reference is unavailable'; end if;
  return new;
end;
$$;

create function private.validate_new_tag_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.knowledge_id is null and new.learning_id is null then return new; end if;
  if not exists (
    select 1 from public.tags where owner_id = new.owner_id and id = new.tag_id and deleted_at is null
  ) then raise exception using errcode = 'P0001', message = 'tag reference is unavailable'; end if;
  return new;
end;
$$;

create function private.validate_new_knowledge_relation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.knowledge
    where owner_id = new.owner_id and id = new.related_knowledge_id and deleted_at is null
  ) then raise exception using errcode = 'P0001', message = 'knowledge link target not found'; end if;
  return new;
end;
$$;

create trigger attachment_links_validate_new_active_target
before insert on public.attachment_links
for each row execute function private.validate_new_attachment_link();
create trigger tag_links_validate_new_active_target
before insert on public.tag_links
for each row execute function private.validate_new_tag_link();
create trigger knowledge_relations_validate_new_active_target
before insert on public.knowledge_relations
for each row execute function private.validate_new_knowledge_relation();

create or replace function private.validate_knowledge_content_references(
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
  if exists (
    select 1 from unnest(image_ids) item(id)
    join public.attachments attachment on attachment.owner_id = p_owner_id and attachment.id = item.id
    where attachment.file_category <> 'Image'
  ) then raise exception using errcode = 'P0001', message = 'image reference must target an image attachment'; end if;
  return attachment_ids;
end;
$$;

create or replace function private.promote_linked_attachments(
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
      and target.deleted_at is null and target.storage_status = 'Available'
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
  perform private.propagate_data_levels(p_owner_id, p_client_request_id, p_operation_id);
end;
$$;

revoke all on function private.calculate_active_effective_data_level(uuid,public.data_level,uuid[],uuid[],uuid[],uuid) from public, anon, authenticated, service_role;
revoke all on function private.propagate_data_levels(uuid,uuid,uuid) from public, anon, authenticated, service_role;
revoke all on function private.validate_new_attachment_link() from public, anon, authenticated, service_role;
revoke all on function private.validate_new_tag_link() from public, anon, authenticated, service_role;
revoke all on function private.validate_new_knowledge_relation() from public, anon, authenticated, service_role;
