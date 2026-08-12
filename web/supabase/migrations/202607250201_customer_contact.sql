create type public.customer_record_status as enum ('Active', 'Dormant', 'Archived');
create type public.external_reference_source as enum ('Manual', 'SAP', 'Tencent CRM', 'Excel Import', 'Official Website', 'Other');
create type public.preferred_contact_time as enum ('No Preference', 'Morning', 'Afternoon', 'Evening');
create type public.communication_preference as enum ('Email First', 'WeChat Preferred', 'Do Not Call');
create type public.employment_status as enum ('Active', 'Left', 'Unknown');
create type public.relationship_status as enum ('Unknown', 'New', 'Developing', 'Trusted', 'Dormant');
create type public.organization_influence as enum ('Unknown', 'Low', 'Medium', 'High');
create type public.customer_knowledge_direction as enum ('Applicable To', 'Sourced From');
create type public.customer_knowledge_applicability as enum ('Unknown', 'High', 'Medium', 'Low', 'Not Applicable');
create type public.merge_entity_type as enum ('Customer', 'Contact');

create function private.normalize_customer_name(p_name text)
returns text language sql immutable set search_path = '' as $$
  select lower(regexp_replace(translate(normalize(btrim(p_name), NFKC), '（）', '()'), '\s+', ' ', 'g'));
$$;

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  name text not null check (length(btrim(name)) between 1 and 300),
  normalized_name text not null check (length(normalized_name) between 1 and 300),
  aliases text[] not null default '{}' check (cardinality(aliases) <= 100),
  customer_type text not null check (length(btrim(customer_type)) between 1 and 100),
  education_segment text check (education_segment is null or length(btrim(education_segment)) between 1 and 100),
  region text check (region is null or length(btrim(region)) between 1 and 200),
  website text check (website is null or length(website) <= 2000),
  background text, business_context text, current_technology text,
  current_cloud_provider text, known_needs text, internal_assessment text,
  student_count_estimate integer check (student_count_estimate is null or student_count_estimate >= 0),
  faculty_count_estimate integer check (faculty_count_estimate is null or faculty_count_estimate >= 0),
  campus_count integer check (campus_count is null or campus_count >= 0),
  organization_stats_as_of date,
  organization_stats_source text check (organization_stats_source is null or length(btrim(organization_stats_source)) between 1 and 2000),
  record_status public.customer_record_status not null default 'Active',
  merged_into_id uuid,
  data_level public.data_level not null default 'Level3' check (data_level = 'Level3'),
  classification_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0), deleted_at timestamptz, deleted_by uuid references auth.users(id),
  constraint customers_owner_identity unique(owner_id,id),
  constraint customers_owner_merged_into_fk foreign key(owner_id,merged_into_id) references public.customers(owner_id,id),
  constraint customers_stats_provenance check (
    (student_count_estimate is null and faculty_count_estimate is null and campus_count is null)
    or (organization_stats_as_of is not null and organization_stats_source is not null)
  ),
  constraint customers_tombstone_consistent check (
    (merged_into_id is null) or (deleted_at is not null and deleted_by is not null and merged_into_id <> id)
  )
);
create index customers_owner_normalized_name_idx on public.customers(owner_id,normalized_name) where deleted_at is null;

create table public.customer_external_references (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
  customer_id uuid not null, source_system public.external_reference_source not null,
  external_reference text not null check(length(btrim(external_reference)) between 1 and 300),
  created_at timestamptz not null default now(),
  constraint customer_external_references_owner_identity unique(owner_id,id),
  constraint customer_external_references_owner_customer_fk foreign key(owner_id,customer_id) references public.customers(owner_id,id),
  constraint customer_external_references_owner_source_value_unique unique(owner_id,source_system,external_reference)
);

create table public.contacts (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
  customer_id uuid not null, full_name text not null check(length(btrim(full_name)) between 1 and 300),
  preferred_name text check(preferred_name is null or length(btrim(preferred_name)) between 1 and 300),
  department text check(department is null or length(btrim(department)) between 1 and 300),
  position text check(position is null or length(btrim(position)) between 1 and 300),
  email text check(email is null or length(email) <= 320), mobile text check(mobile is null or length(mobile) <= 100),
  wechat text check(wechat is null or length(wechat) <= 300),
  preferred_channel text check(preferred_channel is null or length(btrim(preferred_channel)) between 1 and 80),
  preferred_contact_time public.preferred_contact_time not null default 'No Preference',
  communication_preferences public.communication_preference[] not null default '{}',
  employment_status public.employment_status not null default 'Unknown',
  relationship_status public.relationship_status not null default 'Unknown',
  organization_influence public.organization_influence not null default 'Unknown', influence_evidence text,
  previous_contact_id uuid, merged_into_id uuid,
  data_level public.data_level not null default 'Level3' check(data_level='Level3'), classification_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  version integer not null default 1 check(version>0), deleted_at timestamptz, deleted_by uuid references auth.users(id),
  constraint contacts_owner_identity unique(owner_id,id),
  constraint contacts_owner_customer_fk foreign key(owner_id,customer_id) references public.customers(owner_id,id),
  constraint contacts_owner_previous_fk foreign key(owner_id,previous_contact_id) references public.contacts(owner_id,id),
  constraint contacts_owner_merged_into_fk foreign key(owner_id,merged_into_id) references public.contacts(owner_id,id),
  constraint contacts_history_distinct check(previous_contact_id is null or previous_contact_id<>id),
  constraint contacts_influence_evidenced check(organization_influence='Unknown' or coalesce(length(btrim(influence_evidence)),0)>0),
  constraint contacts_tombstone_consistent check((merged_into_id is null) or (deleted_at is not null and deleted_by is not null and merged_into_id<>id))
);

create table public.customer_knowledge_links (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
  customer_id uuid not null, knowledge_id uuid not null, direction public.customer_knowledge_direction not null,
  applicability public.customer_knowledge_applicability, applicability_reason text,
  data_level public.data_level not null default 'Level3' check(data_level='Level3'), created_at timestamptz not null default now(),
  constraint customer_knowledge_links_owner_identity unique(owner_id,id),
  constraint customer_knowledge_links_owner_customer_fk foreign key(owner_id,customer_id) references public.customers(owner_id,id),
  constraint customer_knowledge_links_owner_knowledge_fk foreign key(owner_id,knowledge_id) references public.knowledge(owner_id,id),
  constraint customer_knowledge_links_unique unique(owner_id,customer_id,knowledge_id,direction),
  constraint customer_knowledge_links_direction_consistent check(
    (direction='Sourced From' and applicability is null)
    or (direction='Applicable To' and applicability is not null)
  ),
  constraint customer_knowledge_links_reason_required check(applicability not in ('Low','Not Applicable') or length(btrim(applicability_reason))>0)
);

create table public.merge_previews (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id),
  entity_type public.merge_entity_type not null,
  customer_survivor_id uuid, customer_duplicate_id uuid, contact_survivor_id uuid, contact_duplicate_id uuid,
  survivor_id uuid generated always as (coalesce(customer_survivor_id,contact_survivor_id)) stored,
  duplicate_id uuid generated always as (coalesce(customer_duplicate_id,contact_duplicate_id)) stored,
  survivor_version integer not null check(survivor_version>0), duplicate_version integer not null check(duplicate_version>0),
  plan jsonb not null check(jsonb_typeof(plan)='object'), plan_hash text not null check(plan_hash~'^[a-f0-9]{64}$'),
  token_hash text not null check(token_hash~'^[a-f0-9]{64}$'), expires_at timestamptz not null,
  used_at timestamptz, created_at timestamptz not null default now(),
  constraint merge_previews_owner_identity unique(owner_id,id),
  constraint merge_previews_owner_customer_survivor_fk foreign key(owner_id,customer_survivor_id) references public.customers(owner_id,id),
  constraint merge_previews_owner_customer_duplicate_fk foreign key(owner_id,customer_duplicate_id) references public.customers(owner_id,id),
  constraint merge_previews_owner_contact_survivor_fk foreign key(owner_id,contact_survivor_id) references public.contacts(owner_id,id),
  constraint merge_previews_owner_contact_duplicate_fk foreign key(owner_id,contact_duplicate_id) references public.contacts(owner_id,id),
  constraint merge_previews_entity_targets_consistent check(
    (entity_type='Customer' and customer_survivor_id is not null and customer_duplicate_id is not null and contact_survivor_id is null and contact_duplicate_id is null)
    or (entity_type='Contact' and contact_survivor_id is not null and contact_duplicate_id is not null and customer_survivor_id is null and customer_duplicate_id is null)
  ),
  constraint merge_previews_distinct_entities check(survivor_id<>duplicate_id),
  constraint merge_previews_token_unique unique(owner_id,token_hash)
);

create function private.derive_customer_normalized_name() returns trigger language plpgsql set search_path='' as $$
begin new.name:=btrim(new.name); new.normalized_name:=private.normalize_customer_name(new.name); return new; end; $$;
create trigger customers_derive_normalized_name before insert or update of name,normalized_name on public.customers
for each row execute function private.derive_customer_normalized_name();
create trigger customers_guard_mutation before update on public.customers for each row execute function public.guard_mutable_entity();
create trigger contacts_guard_mutation before update on public.contacts for each row execute function public.guard_mutable_entity();
create trigger customers_reject_physical_delete before delete on public.customers for each row execute function public.reject_mutable_entity_delete();
create trigger contacts_reject_physical_delete before delete on public.contacts for each row execute function public.reject_mutable_entity_delete();

create function private.validate_contact_history() returns trigger language plpgsql set search_path='' as $$
declare previous public.contacts%rowtype;
begin
  if new.previous_contact_id is null then return new; end if;
  select * into previous from public.contacts where owner_id=new.owner_id and id=new.previous_contact_id;
  if previous.id is null or previous.employment_status<>'Left' or previous.customer_id=new.customer_id then
    raise exception using errcode='P0001',message='previous contact must be a departed employment at another customer';
  end if;
  return new;
end; $$;
create trigger contacts_validate_history before insert or update of previous_contact_id,customer_id on public.contacts
for each row execute function private.validate_contact_history();

alter table public.customers enable row level security; alter table public.customers force row level security;
alter table public.customer_external_references enable row level security; alter table public.customer_external_references force row level security;
alter table public.contacts enable row level security; alter table public.contacts force row level security;
alter table public.customer_knowledge_links enable row level security; alter table public.customer_knowledge_links force row level security;
alter table public.merge_previews enable row level security; alter table public.merge_previews force row level security;
create policy customers_select_owner on public.customers for select to authenticated using(auth.uid()=owner_id and deleted_at is null);
create policy contacts_select_owner on public.contacts for select to authenticated using(auth.uid()=owner_id and deleted_at is null);
create policy customer_external_references_select_owner on public.customer_external_references for select to authenticated using(auth.uid()=owner_id);
create policy customer_knowledge_links_select_owner on public.customer_knowledge_links for select to authenticated using(auth.uid()=owner_id);
create policy merge_previews_select_denied on public.merge_previews for select to authenticated using(false);
create policy customers_mutation_denied on public.customers for all to authenticated using(false) with check(false);
create policy contacts_mutation_denied on public.contacts for all to authenticated using(false) with check(false);
create policy customer_external_references_mutation_denied on public.customer_external_references for all to authenticated using(false) with check(false);
create policy customer_knowledge_links_mutation_denied on public.customer_knowledge_links for all to authenticated using(false) with check(false);
create policy merge_previews_mutation_denied on public.merge_previews for all to authenticated using(false) with check(false);
grant select,insert,update,delete on public.customers,public.contacts,public.customer_external_references,public.customer_knowledge_links,public.merge_previews to authenticated,service_role;

create function private.refresh_customer_search(p_owner_id uuid,p_customer_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare e public.customers%rowtype; survivor_name text;
begin
 select * into e from public.customers where owner_id=p_owner_id and id=p_customer_id;
 if e.id is null then raise exception using errcode='P0001',message='customer not found'; end if;
 if e.merged_into_id is not null then select name into survivor_name from public.customers where owner_id=p_owner_id and id=e.merged_into_id; end if;
 insert into public.search_documents(owner_id,source_type,source_id,title,subtitle,search_text,route,data_level,visibility_state,source_created_at,source_updated_at,projection_schema_version,indexed_at,metadata)
 values(p_owner_id,'Customer',e.id,e.name,e.customer_type,concat_ws(E'\n',e.name,array_to_string(e.aliases,E'\n'),e.customer_type,e.education_segment,e.region,e.background,e.business_context,e.current_technology,e.current_cloud_provider,e.known_needs,e.internal_assessment),
 '/customers/'||e.id,'Level3',case when e.merged_into_id is not null then 'Merged' when e.deleted_at is not null then 'Deleted' else e.record_status::text end,e.created_at,e.updated_at,1,now(),
 jsonb_strip_nulls(jsonb_build_object('customerType',e.customer_type,'recordStatus',e.record_status,'mergedIntoId',e.merged_into_id,'survivorName',survivor_name)))
 on conflict(owner_id,source_type,source_id) do update set title=excluded.title,subtitle=excluded.subtitle,search_text=excluded.search_text,route=excluded.route,data_level=excluded.data_level,visibility_state=excluded.visibility_state,source_updated_at=excluded.source_updated_at,indexed_at=excluded.indexed_at,metadata=excluded.metadata;
end; $$;

create function private.refresh_contact_search(p_owner_id uuid,p_contact_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare e public.contacts%rowtype; customer_name text; survivor_name text;
begin
 select * into e from public.contacts where owner_id=p_owner_id and id=p_contact_id;
 if e.id is null then raise exception using errcode='P0001',message='contact not found'; end if;
 select name into customer_name from public.customers where owner_id=p_owner_id and id=e.customer_id;
 if e.merged_into_id is not null then select full_name into survivor_name from public.contacts where owner_id=p_owner_id and id=e.merged_into_id; end if;
 insert into public.search_documents(owner_id,source_type,source_id,title,subtitle,search_text,route,data_level,visibility_state,source_created_at,source_updated_at,projection_schema_version,indexed_at,metadata)
 values(p_owner_id,'Contact',e.id,e.full_name,concat_ws(' · ',e.position,customer_name),concat_ws(E'\n',e.full_name,e.preferred_name,e.department,e.position,customer_name),
 '/contacts/'||e.id,'Level3',case when e.merged_into_id is not null then 'Merged' when e.deleted_at is not null then 'Deleted' else e.employment_status::text end,e.created_at,e.updated_at,1,now(),
 jsonb_strip_nulls(jsonb_build_object('customerId',e.customer_id,'employmentStatus',e.employment_status,'mergedIntoId',e.merged_into_id,'survivorName',survivor_name)))
 on conflict(owner_id,source_type,source_id) do update set title=excluded.title,subtitle=excluded.subtitle,search_text=excluded.search_text,route=excluded.route,data_level=excluded.data_level,visibility_state=excluded.visibility_state,source_updated_at=excluded.source_updated_at,indexed_at=excluded.indexed_at,metadata=excluded.metadata;
end; $$;

create function private.validate_customer_links(p_owner_id uuid,p_customer_id uuid,p_external_references jsonb,p_knowledge_links jsonb) returns void language plpgsql security definer set search_path='' as $$
declare item jsonb;
begin
 if jsonb_typeof(p_external_references)<>'array' or jsonb_array_length(p_external_references)>100
   or exists(select 1 from jsonb_array_elements(p_external_references) x where not private.jsonb_has_only_keys(x.value,array['sourceSystem','externalReference']) or x.value->>'sourceSystem' not in ('Manual','SAP','Tencent CRM','Excel Import','Official Website','Other') or length(btrim(x.value->>'externalReference')) not between 1 and 300)
 then raise exception using errcode='P0001',message='invalid customer external references'; end if;
 if jsonb_array_length(p_external_references)<>(select count(distinct (x.value->>'sourceSystem',btrim(x.value->>'externalReference'))) from jsonb_array_elements(p_external_references)x)
 then raise exception using errcode='P0001',message='duplicate customer external reference'; end if;
 if jsonb_typeof(p_knowledge_links)<>'array' or jsonb_array_length(p_knowledge_links)>100
   or exists(select 1 from jsonb_array_elements(p_knowledge_links)x where not private.jsonb_has_only_keys(x.value,array['knowledgeId','direction','applicability','applicabilityReason']) or x.value->>'knowledgeId'!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or x.value->>'direction' not in ('Applicable To','Sourced From'))
 then raise exception using errcode='P0001',message='invalid customer knowledge links'; end if;
 for item in select value from jsonb_array_elements(p_knowledge_links) loop
   if not exists(select 1 from public.knowledge where owner_id=p_owner_id and id=(item->>'knowledgeId')::uuid and deleted_at is null) then raise exception using errcode='P0001',message='knowledge link target not found'; end if;
   if item->>'direction'='Applicable To' and coalesce(item->>'applicability','') not in ('Unknown','High','Medium','Low','Not Applicable') then raise exception using errcode='P0001',message='applicability is required'; end if;
   if item->>'direction'='Sourced From' and item ? 'applicability' and item->'applicability'<>'null'::jsonb then raise exception using errcode='P0001',message='source link cannot carry applicability'; end if;
   if item->>'applicability' in ('Low','Not Applicable') and length(btrim(coalesce(item->>'applicabilityReason','')))=0 then raise exception using errcode='P0001',message='applicability reason is required'; end if;
 end loop;
 insert into public.customer_external_references(owner_id,customer_id,source_system,external_reference)
 select p_owner_id,p_customer_id,(value->>'sourceSystem')::public.external_reference_source,btrim(value->>'externalReference') from jsonb_array_elements(p_external_references);
 insert into public.customer_knowledge_links(owner_id,customer_id,knowledge_id,direction,applicability,applicability_reason,data_level)
 select p_owner_id,p_customer_id,(value->>'knowledgeId')::uuid,(value->>'direction')::public.customer_knowledge_direction,
 case when value->>'direction'='Applicable To' then (value->>'applicability')::public.customer_knowledge_applicability else null end,
 nullif(btrim(value->>'applicabilityReason'),''),'Level3' from jsonb_array_elements(p_knowledge_links);
end; $$;

create function public.create_customer(
 p_verified_user_id uuid,p_client_request_id uuid,p_name text,p_aliases text[],p_customer_type text,p_education_segment text,p_region text,p_website text,
 p_background text,p_business_context text,p_current_technology text,p_current_cloud_provider text,p_known_needs text,p_internal_assessment text,
 p_student_count_estimate integer,p_faculty_count_estimate integer,p_campus_count integer,p_organization_stats_as_of date,p_organization_stats_source text,
 p_record_status public.customer_record_status,p_data_level public.data_level,p_classification_reason text,p_external_references jsonb,p_knowledge_links jsonb
) returns table(id uuid,name text,normalized_name text,version integer,operation_id uuid) language plpgsql security definer set search_path='' as $$
declare receipt record;e public.customers%rowtype;
begin
 if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required'; end if;
 select * into receipt from private.claim_command_receipt(p_verified_user_id,'CreateCustomer',p_client_request_id);
 if receipt.status='Completed' then select * into e from public.customers where owner_id=p_verified_user_id and customers.id=(receipt.result_reference->>'customerId')::uuid; return query select e.id,e.name,e.normalized_name,e.version,receipt.operation_id; return; end if;
 if p_data_level<>'Level3' then raise exception using errcode='P0001',message='Customer must be Level3'; end if;
 insert into public.customers(owner_id,name,normalized_name,aliases,customer_type,education_segment,region,website,background,business_context,current_technology,current_cloud_provider,known_needs,internal_assessment,student_count_estimate,faculty_count_estimate,campus_count,organization_stats_as_of,organization_stats_source,record_status,data_level,classification_reason)
 values(p_verified_user_id,btrim(p_name),private.normalize_customer_name(p_name),coalesce(p_aliases,'{}'),btrim(p_customer_type),nullif(btrim(p_education_segment),''),nullif(btrim(p_region),''),p_website,p_background,p_business_context,p_current_technology,p_current_cloud_provider,p_known_needs,p_internal_assessment,p_student_count_estimate,p_faculty_count_estimate,p_campus_count,p_organization_stats_as_of,nullif(btrim(p_organization_stats_source),''),p_record_status,'Level3',p_classification_reason) returning * into e;
 perform private.validate_customer_links(p_verified_user_id,e.id,p_external_references,p_knowledge_links);
 perform private.refresh_customer_search(p_verified_user_id,e.id);
 perform private.append_audit_log(p_verified_user_id,'CustomerCreated','Customer',e.id,null,p_client_request_id,receipt.operation_id,array_to_json(array['name','customer_type','record_status','data_level'])::jsonb,jsonb_build_object('externalReferenceCount',jsonb_array_length(p_external_references),'knowledgeLinkCount',jsonb_array_length(p_knowledge_links)),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,receipt.id,receipt.operation_id,'Completed','Customer',e.id,jsonb_build_object('customerId',e.id));
 return query select e.id,e.name,e.normalized_name,e.version,receipt.operation_id;
end; $$;

create function public.create_contact(
 p_verified_user_id uuid,p_client_request_id uuid,p_customer_id uuid,p_full_name text,p_preferred_name text,p_department text,p_position text,p_email text,p_mobile text,p_wechat text,
 p_preferred_channel text,p_preferred_contact_time public.preferred_contact_time,p_communication_preferences text[],p_employment_status public.employment_status,
 p_relationship_status public.relationship_status,p_organization_influence public.organization_influence,p_influence_evidence text,p_previous_contact_id uuid,p_data_level public.data_level,p_classification_reason text
) returns table(id uuid,full_name text,version integer,operation_id uuid) language plpgsql security definer set search_path='' as $$
declare receipt record;e public.contacts%rowtype;preferences public.communication_preference[];
begin
 if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required'; end if;
 select * into receipt from private.claim_command_receipt(p_verified_user_id,'CreateContact',p_client_request_id);
 if receipt.status='Completed' then select * into e from public.contacts where owner_id=p_verified_user_id and contacts.id=(receipt.result_reference->>'contactId')::uuid; return query select e.id,e.full_name,e.version,receipt.operation_id; return; end if;
 if not exists(select 1 from public.customers where owner_id=p_verified_user_id and customers.id=p_customer_id and deleted_at is null) then raise exception using errcode='P0001',message='customer not found'; end if;
 if p_data_level<>'Level3' then raise exception using errcode='P0001',message='Contact must be Level3'; end if;
 select coalesce(array_agg(distinct value::public.communication_preference),'{}') into preferences from unnest(coalesce(p_communication_preferences,'{}'))x(value) where value in ('Email First','WeChat Preferred','Do Not Call');
 if cardinality(preferences)<>cardinality(coalesce(p_communication_preferences,'{}')) then raise exception using errcode='P0001',message='invalid communication preferences'; end if;
 insert into public.contacts(owner_id,customer_id,full_name,preferred_name,department,position,email,mobile,wechat,preferred_channel,preferred_contact_time,communication_preferences,employment_status,relationship_status,organization_influence,influence_evidence,previous_contact_id,data_level,classification_reason)
 values(p_verified_user_id,p_customer_id,btrim(p_full_name),nullif(btrim(p_preferred_name),''),nullif(btrim(p_department),''),nullif(btrim(p_position),''),nullif(btrim(p_email),''),nullif(btrim(p_mobile),''),nullif(btrim(p_wechat),''),nullif(btrim(p_preferred_channel),''),p_preferred_contact_time,preferences,p_employment_status,p_relationship_status,p_organization_influence,nullif(btrim(p_influence_evidence),''),p_previous_contact_id,'Level3',p_classification_reason) returning * into e;
 perform private.refresh_contact_search(p_verified_user_id,e.id);
 perform private.append_audit_log(p_verified_user_id,'ContactCreated','Contact',e.id,null,p_client_request_id,receipt.operation_id,array_to_json(array['customer_id','full_name','employment_status','data_level'])::jsonb,jsonb_build_object('hasEmail',e.email is not null,'hasMobile',e.mobile is not null,'hasWechat',e.wechat is not null),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,receipt.id,receipt.operation_id,'Completed','Contact',e.id,jsonb_build_object('contactId',e.id));
 return query select e.id,e.full_name,e.version,receipt.operation_id;
end; $$;

create function public.find_customer_duplicate_warnings(p_normalized_name text,p_exclude_customer_id uuid default null)
returns table(id uuid,name text,normalized_name text) language sql stable security invoker set search_path='' as $$
 select c.id,c.name,c.normalized_name from public.customers c where c.owner_id=auth.uid() and c.deleted_at is null and c.normalized_name=private.normalize_customer_name(p_normalized_name) and (p_exclude_customer_id is null or c.id<>p_exclude_customer_id) order by c.updated_at desc;
$$;

create function public.resolve_customer_detail(p_customer_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.customers%rowtype;s public.customers%rowtype;
begin select * into e from public.customers where owner_id=auth.uid() and id=p_customer_id; if e.id is null then raise exception using errcode='P0002',message='Customer not found'; end if;
 if e.merged_into_id is not null then select * into s from public.customers where owner_id=auth.uid() and id=e.merged_into_id; return jsonb_build_object('state','Merged','tombstoneId',e.id,'mergedIntoId',s.id,'survivorName',s.name,'route','/customers/'||s.id); end if;
 if e.deleted_at is not null then raise exception using errcode='P0002',message='Customer not found'; end if; return to_jsonb(e)-array['owner_id','deleted_by']; end; $$;
create function public.resolve_contact_detail(p_contact_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.contacts%rowtype;s public.contacts%rowtype;
begin select * into e from public.contacts where owner_id=auth.uid() and id=p_contact_id; if e.id is null then raise exception using errcode='P0002',message='Contact not found'; end if;
 if e.merged_into_id is not null then select * into s from public.contacts where owner_id=auth.uid() and id=e.merged_into_id; return jsonb_build_object('state','Merged','tombstoneId',e.id,'mergedIntoId',s.id,'survivorName',s.full_name,'route','/contacts/'||s.id); end if;
 if e.deleted_at is not null then raise exception using errcode='P0002',message='Contact not found'; end if; return to_jsonb(e)-array['owner_id','deleted_by']; end; $$;

-- Explicit extension registry. A later migration that adds a child relation which must
-- follow merges registers a concrete, tested reassignment function here.
create table private.merge_reassignment_hooks(
  entity_type public.merge_entity_type not null,
  hook_name text not null check(hook_name~'^[a-z][a-z0-9_]{0,62}$'),
  function_name regprocedure not null,
  execution_order integer not null,
  primary key(entity_type,hook_name), unique(entity_type,execution_order)
);

create function private.reassign_customer_builtin_links(p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare contact_count integer;external_count integer;knowledge_count integer;contact_record record;
begin
 update public.contacts set customer_id=p_survivor_id where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null; get diagnostics contact_count=row_count;
 for contact_record in select id from public.contacts where owner_id=p_owner_id and customer_id=p_survivor_id and deleted_at is null loop
   perform private.refresh_contact_search(p_owner_id,contact_record.id);
 end loop;
 insert into public.customer_external_references(owner_id,customer_id,source_system,external_reference,created_at)
 select owner_id,p_survivor_id,source_system,external_reference,created_at from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id
 on conflict(owner_id,source_system,external_reference) do nothing;
 delete from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id; get diagnostics external_count=row_count;
 insert into public.customer_knowledge_links(owner_id,customer_id,knowledge_id,direction,applicability,applicability_reason,data_level,created_at)
 select owner_id,p_survivor_id,knowledge_id,direction,applicability,applicability_reason,data_level,created_at from public.customer_knowledge_links where owner_id=p_owner_id and customer_id=p_duplicate_id
 on conflict(owner_id,customer_id,knowledge_id,direction) do nothing;
 delete from public.customer_knowledge_links where owner_id=p_owner_id and customer_id=p_duplicate_id; get diagnostics knowledge_count=row_count;
 return jsonb_build_object('contactsReassigned',contact_count,'externalReferencesProcessed',external_count,'knowledgeLinksProcessed',knowledge_count);
end; $$;
create function private.reassign_contact_builtin_links(p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare history_count integer;
begin update public.contacts set previous_contact_id=p_survivor_id where owner_id=p_owner_id and previous_contact_id=p_duplicate_id; get diagnostics history_count=row_count;
 return jsonb_build_object('contactHistoryReassigned',history_count); end; $$;
insert into private.merge_reassignment_hooks values
('Customer','customer_builtin_links','private.reassign_customer_builtin_links(uuid,uuid,uuid)'::regprocedure,10),
('Contact','contact_builtin_links','private.reassign_contact_builtin_links(uuid,uuid,uuid)'::regprocedure,10);

create function private.merge_plan(p_owner_id uuid,p_entity_type public.merge_entity_type,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare plan jsonb;
begin
 if p_entity_type='Customer' then
   select jsonb_build_object(
     'contactCount',(select count(*) from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null),
     'contactIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null),
     'externalReferenceCount',(select count(*) from public.customer_external_references where owner_id=p_owner_id and customer_id=p_duplicate_id),
     'externalReferenceIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customer_external_references where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)),
     'knowledgeLinkCount',(select count(*) from public.customer_knowledge_links where owner_id=p_owner_id and customer_id=p_duplicate_id),
     'knowledgeLinkIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.customer_knowledge_links where owner_id=p_owner_id and customer_id in(p_survivor_id,p_duplicate_id)),
     'fieldChoice','Survivor','reassignmentHooks',(select jsonb_agg(hook_name order by execution_order) from private.merge_reassignment_hooks where entity_type='Customer')) into plan;
 else
   select jsonb_build_object('historyReferenceCount',(select count(*) from public.contacts where owner_id=p_owner_id and previous_contact_id=p_duplicate_id),'historyReferenceIds',(select coalesce(jsonb_agg(id order by id),'[]') from public.contacts where owner_id=p_owner_id and previous_contact_id=p_duplicate_id),'fieldChoice','Survivor','reassignmentHooks',(select jsonb_agg(hook_name order by execution_order) from private.merge_reassignment_hooks where entity_type='Contact')) into plan;
 end if; return plan;
end; $$;

create function public.preview_entity_merge(p_verified_user_id uuid,p_entity_type public.merge_entity_type,p_survivor_id uuid,p_duplicate_id uuid)
returns table(preview_id uuid,preview_token text,plan_hash text,expires_at timestamptz,entity_type public.merge_entity_type,survivor_id uuid,duplicate_id uuid,survivor_version integer,duplicate_version integer,plan jsonb)
language plpgsql security definer set search_path='' as $$
declare survivor_v integer;duplicate_v integer;token text;plan_value jsonb;preview public.merge_previews%rowtype;
begin
 if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required'; end if;
 if p_survivor_id=p_duplicate_id then raise exception using errcode='P0001',message='merge entities must be distinct'; end if;
 if p_entity_type='Customer' then
   select version into survivor_v from public.customers where owner_id=p_verified_user_id and id=p_survivor_id and deleted_at is null and merged_into_id is null;
   select version into duplicate_v from public.customers where owner_id=p_verified_user_id and id=p_duplicate_id and deleted_at is null and merged_into_id is null;
 else
   select version into survivor_v from public.contacts where owner_id=p_verified_user_id and id=p_survivor_id and deleted_at is null and merged_into_id is null;
   select version into duplicate_v from public.contacts where owner_id=p_verified_user_id and id=p_duplicate_id and deleted_at is null and merged_into_id is null
     and customer_id=(select customer_id from public.contacts where owner_id=p_verified_user_id and id=p_survivor_id and deleted_at is null and merged_into_id is null);
 end if;
 if survivor_v is null or duplicate_v is null then raise exception using errcode='P0001',message='merge target not found'; end if;
 token:=encode(extensions.gen_random_bytes(32),'hex'); plan_value:=private.merge_plan(p_verified_user_id,p_entity_type,p_survivor_id,p_duplicate_id);
 insert into public.merge_previews(owner_id,entity_type,customer_survivor_id,customer_duplicate_id,contact_survivor_id,contact_duplicate_id,survivor_version,duplicate_version,plan,plan_hash,token_hash,expires_at)
 values(p_verified_user_id,p_entity_type,case when p_entity_type='Customer' then p_survivor_id end,case when p_entity_type='Customer' then p_duplicate_id end,case when p_entity_type='Contact' then p_survivor_id end,case when p_entity_type='Contact' then p_duplicate_id end,survivor_v,duplicate_v,plan_value,encode(extensions.digest(plan_value::text,'sha256'),'hex'),encode(extensions.digest(token,'sha256'),'hex'),now()+interval '10 minutes') returning * into preview;
 return query select preview.id,token,preview.plan_hash,preview.expires_at,preview.entity_type,preview.survivor_id,preview.duplicate_id,preview.survivor_version,preview.duplicate_version,preview.plan;
end; $$;

create function private.run_merge_hooks(p_entity_type public.merge_entity_type,p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare hook record;result jsonb:='{}'::jsonb;piece jsonb;
begin
 if not exists(select 1 from private.merge_reassignment_hooks where entity_type=p_entity_type) then raise exception using errcode='P0001',message='merge reassignment hooks not registered'; end if;
 for hook in select hook_name,function_name from private.merge_reassignment_hooks where entity_type=p_entity_type order by execution_order loop
   execute format('select %s($1,$2,$3)',split_part(hook.function_name::text,'(',1)) into piece using p_owner_id,p_survivor_id,p_duplicate_id;
   result:=result||jsonb_build_object(hook.hook_name,piece);
 end loop; return result;
end; $$;

create function public.execute_entity_merge(p_verified_user_id uuid,p_client_request_id uuid,p_preview_id uuid,p_preview_token text,p_plan_hash text,p_survivor_version integer,p_duplicate_version integer)
returns table(entity_type public.merge_entity_type,survivor_id uuid,duplicate_id uuid,survivor_version integer,operation_id uuid,receipt jsonb)
language plpgsql security definer set search_path='' as $$
declare command record;preview public.merge_previews%rowtype;current_survivor integer;current_duplicate integer;hook_results jsonb;new_version integer;
begin
 if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required'; end if;
 select * into command from private.claim_command_receipt(p_verified_user_id,'ExecuteEntityMerge',p_client_request_id);
 if command.status='Completed' then return query select (command.result_reference->>'entityType')::public.merge_entity_type,(command.result_reference->>'survivorId')::uuid,(command.result_reference->>'duplicateId')::uuid,(command.result_reference->>'survivorVersion')::integer,command.operation_id,command.result_reference; return; end if;
 select * into preview from public.merge_previews where owner_id=p_verified_user_id and id=p_preview_id for update;
 if preview.id is null then raise exception using errcode='P0001',message='merge preview not found'; end if;
 if preview.used_at is not null then raise exception using errcode='P0001',message='merge preview already used'; end if;
 if preview.expires_at<=now() then raise exception using errcode='P0001',message='merge preview expired'; end if;
 if preview.token_hash<>encode(extensions.digest(p_preview_token,'sha256'),'hex') or preview.plan_hash<>p_plan_hash or preview.plan_hash<>encode(extensions.digest(preview.plan::text,'sha256'),'hex') then raise exception using errcode='P0001',message='merge preview validation failed'; end if;
 if preview.survivor_version<>p_survivor_version or preview.duplicate_version<>p_duplicate_version then raise exception using errcode='40001',message='merge preview is stale'; end if;
 if preview.entity_type='Customer' then
   perform 1 from public.customers where owner_id=p_verified_user_id and id in(preview.survivor_id,preview.duplicate_id) order by id for update;
   select version into current_survivor from public.customers where owner_id=p_verified_user_id and id=preview.survivor_id and deleted_at is null and merged_into_id is null;
   select version into current_duplicate from public.customers where owner_id=p_verified_user_id and id=preview.duplicate_id and deleted_at is null and merged_into_id is null;
 else
   perform 1 from public.contacts where owner_id=p_verified_user_id and id in(preview.survivor_id,preview.duplicate_id) order by id for update;
   select version into current_survivor from public.contacts where owner_id=p_verified_user_id and id=preview.survivor_id and deleted_at is null and merged_into_id is null;
   select version into current_duplicate from public.contacts where owner_id=p_verified_user_id and id=preview.duplicate_id and deleted_at is null and merged_into_id is null;
 end if;
 if current_survivor is distinct from preview.survivor_version or current_duplicate is distinct from preview.duplicate_version or private.merge_plan(p_verified_user_id,preview.entity_type,preview.survivor_id,preview.duplicate_id) is distinct from preview.plan then raise exception using errcode='40001',message='merge preview is stale'; end if;
 hook_results:=private.run_merge_hooks(preview.entity_type,p_verified_user_id,preview.survivor_id,preview.duplicate_id);
 if preview.entity_type='Customer' then
   update public.customers set updated_at=now() where owner_id=p_verified_user_id and id=preview.survivor_id returning version into new_version;
   update public.customers set merged_into_id=preview.survivor_id,deleted_at=now(),deleted_by=p_verified_user_id where owner_id=p_verified_user_id and id=preview.duplicate_id;
   perform private.refresh_customer_search(p_verified_user_id,preview.survivor_id); perform private.refresh_customer_search(p_verified_user_id,preview.duplicate_id);
 else
   update public.contacts set updated_at=now() where owner_id=p_verified_user_id and id=preview.survivor_id returning version into new_version;
   update public.contacts set merged_into_id=preview.survivor_id,deleted_at=now(),deleted_by=p_verified_user_id where owner_id=p_verified_user_id and id=preview.duplicate_id;
   perform private.refresh_contact_search(p_verified_user_id,preview.survivor_id); perform private.refresh_contact_search(p_verified_user_id,preview.duplicate_id);
 end if;
 update public.merge_previews set used_at=now() where id=preview.id;
 perform private.append_audit_log(p_verified_user_id,preview.entity_type::text||'Merged',preview.entity_type::text,preview.survivor_id,null,p_client_request_id,command.operation_id,array_to_json(array['merged_into_id','deleted_at','child_reassignment'])::jsonb,jsonb_build_object('duplicateId',preview.duplicate_id,'previewId',preview.id,'planHash',preview.plan_hash,'hookResults',hook_results),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,command.id,command.operation_id,'Completed',preview.entity_type::text,preview.survivor_id,jsonb_build_object('entityType',preview.entity_type,'survivorId',preview.survivor_id,'duplicateId',preview.duplicate_id,'survivorVersion',new_version));
 return query select preview.entity_type,preview.survivor_id,preview.duplicate_id,new_version,command.operation_id,jsonb_build_object('hookResults',hook_results);
end; $$;

revoke all on function public.create_customer(uuid,uuid,text,text[],text,text,text,text,text,text,text,text,text,text,integer,integer,integer,date,text,public.customer_record_status,public.data_level,text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.create_contact(uuid,uuid,uuid,text,text,text,text,text,text,text,text,public.preferred_contact_time,text[],public.employment_status,public.relationship_status,public.organization_influence,text,uuid,public.data_level,text) from public,anon,authenticated;
revoke all on function public.preview_entity_merge(uuid,public.merge_entity_type,uuid,uuid) from public,anon,authenticated;
revoke all on function public.execute_entity_merge(uuid,uuid,uuid,text,text,integer,integer) from public,anon,authenticated;
grant execute on function public.create_customer(uuid,uuid,text,text[],text,text,text,text,text,text,text,text,text,text,integer,integer,integer,date,text,public.customer_record_status,public.data_level,text,jsonb,jsonb) to service_role;
grant execute on function public.create_contact(uuid,uuid,uuid,text,text,text,text,text,text,text,text,public.preferred_contact_time,text[],public.employment_status,public.relationship_status,public.organization_influence,text,uuid,public.data_level,text) to service_role;
grant execute on function public.preview_entity_merge(uuid,public.merge_entity_type,uuid,uuid),public.execute_entity_merge(uuid,uuid,uuid,text,text,integer,integer) to service_role;
grant execute on function public.find_customer_duplicate_warnings(text,uuid),public.resolve_customer_detail(uuid),public.resolve_contact_detail(uuid) to authenticated;
revoke all on function private.normalize_customer_name(text),private.derive_customer_normalized_name(),private.validate_contact_history(),private.refresh_customer_search(uuid,uuid),private.refresh_contact_search(uuid,uuid),private.validate_customer_links(uuid,uuid,jsonb,jsonb),private.reassign_customer_builtin_links(uuid,uuid,uuid),private.reassign_contact_builtin_links(uuid,uuid,uuid),private.merge_plan(uuid,public.merge_entity_type,uuid,uuid),private.run_merge_hooks(public.merge_entity_type,uuid,uuid,uuid) from public,anon,authenticated,service_role;
