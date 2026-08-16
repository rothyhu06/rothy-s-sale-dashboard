create type public.opportunity_type as enum ('New Business','Expansion','Renewal');
create type public.opportunity_source_type as enum ('Inbound','Outbound','Partner','Existing Customer','Marketing','Referral','Event','Internal','Other');
create type public.opportunity_stage as enum ('Lead','Discovery','Needs Confirmed','Solution Design','POC','Commercial Negotiation','Closed Won','Closed Lost');
create type public.opportunity_transition_type as enum ('Initial','Forward','Backward','Skip','Reopen');
create type public.opportunity_changed_source as enum ('Manual','Workflow','Import','Migration');
create type public.opportunity_outcome_type as enum ('Won','Lost');
create type public.opportunity_support_level as enum ('Unknown','Opposed','Neutral','Supportive','Champion');

create function private.is_iso_4217(p_currency text) returns boolean language sql immutable set search_path='' as $$
 select p_currency=any(array[
 'AED','AFN','ALL','AMD','ANG','AOA','ARS','AUD','AWG','AZN','BAM','BBD','BDT','BGN','BHD','BIF','BMD','BND','BOB','BOV','BRL','BSD','BTN','BWP','BYN','BZD','CAD','CDF','CHE','CHF','CHW','CLF','CLP','CNY','COP','COU','CRC','CUC','CUP','CVE','CZK','DJF','DKK','DOP','DZD','EGP','ERN','ETB','EUR','FJD','FKP','GBP','GEL','GHS','GIP','GMD','GNF','GTQ','GYD','HKD','HNL','HRK','HTG','HUF','IDR','ILS','INR','IQD','IRR','ISK','JMD','JOD','JPY','KES','KGS','KHR','KMF','KPW','KRW','KWD','KYD','KZT','LAK','LBP','LKR','LRD','LSL','LYD','MAD','MDL','MGA','MKD','MMK','MNT','MOP','MRU','MUR','MVR','MWK','MXN','MXV','MYR','MZN','NAD','NGN','NIO','NOK','NPR','NZD','OMR','PAB','PEN','PGK','PHP','PKR','PLN','PYG','QAR','RON','RSD','RUB','RWF','SAR','SBD','SCR','SDG','SEK','SGD','SHP','SLE','SOS','SRD','SSP','STN','SVC','SYP','SZL','THB','TJS','TMT','TND','TOP','TRY','TTD','TWD','TZS','UAH','UGX','USD','USN','UYI','UYU','UYW','UZS','VED','VES','VND','VUV','WST','XAF','XAG','XAU','XBA','XBB','XBC','XBD','XCD','XCG','XDR','XOF','XPD','XPF','XPT','XSU','XTS','XUA','XXX','YER','ZAR','ZMW','ZWG'
 ]::text[]);
$$;

create table public.opportunities(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
 customer_id uuid not null, parent_opportunity_id uuid, name text not null check(length(btrim(name)) between 1 and 300),
 opportunity_type public.opportunity_type not null, source_type public.opportunity_source_type, source_contact_id uuid,
 scenario text, customer_need text, desired_outcome text, solution_direction text, constraints text,
 estimated_amount numeric(20,2) check(estimated_amount is null or estimated_amount>=0), currency text,
 amount_basis text check(amount_basis is null or length(btrim(amount_basis)) between 1 and 2000), amount_as_of date,
 expected_decision_date date, data_level public.data_level not null default 'Level3' check(data_level='Level3'),
 classification_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 version integer not null default 1 check(version>0), deleted_at timestamptz, deleted_by uuid references auth.users(id),
 constraint opportunities_owner_identity unique(owner_id,id),
 constraint opportunities_owner_customer_fk foreign key(owner_id,customer_id) references public.customers(owner_id,id),
 constraint opportunities_owner_parent_fk foreign key(owner_id,parent_opportunity_id) references public.opportunities(owner_id,id),
 constraint opportunities_owner_source_contact_fk foreign key(owner_id,source_contact_id) references public.contacts(owner_id,id),
 constraint opportunities_parent_distinct check(parent_opportunity_id is null or parent_opportunity_id<>id),
 constraint opportunities_currency_valid check(currency is null or private.is_iso_4217(currency)),
 constraint opportunities_amount_currency_pair check((estimated_amount is null)=(currency is null)),
 constraint opportunities_amount_provenance check(estimated_amount is null or (amount_basis is not null and amount_as_of is not null))
);

create table public.opportunity_stage_history(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id), opportunity_id uuid not null,
 from_stage public.opportunity_stage, to_stage public.opportunity_stage not null,
 transition_type public.opportunity_transition_type not null, changed_source public.opportunity_changed_source not null,
 changed_at timestamptz not null default now(), recorded_at timestamptz not null default clock_timestamp(), reason text,
 amount_snapshot numeric(20,2) check(amount_snapshot is null or amount_snapshot>=0), expected_decision_date_snapshot date,
 operation_id uuid not null, constraint opportunity_stage_history_owner_identity unique(owner_id,id),
 constraint opportunity_stage_history_owner_opportunity_fk foreign key(owner_id,opportunity_id) references public.opportunities(owner_id,id),
 constraint opportunity_stage_history_initial_consistent check((transition_type='Initial')=(from_stage is null)),
 constraint opportunity_stage_history_change_consistent check(from_stage is null or from_stage<>to_stage)
);
create index opportunity_stage_history_current_idx on public.opportunity_stage_history(owner_id,opportunity_id,recorded_at desc,id desc);

create table public.opportunity_outcomes(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id), opportunity_id uuid not null,
 outcome_type public.opportunity_outcome_type not null, final_amount numeric(20,2) not null check(final_amount>=0),
 currency text not null check(private.is_iso_4217(currency)), decision_date date not null,
 reason text not null check(length(btrim(reason)) between 1 and 10000), competitor text,
 decision_factors jsonb not null default '[]' check(jsonb_typeof(decision_factors)='array'), customer_value text, lessons text,
 review_completed_at timestamptz, voided_at timestamptz, created_at timestamptz not null default now(), operation_id uuid not null,
 constraint opportunity_outcomes_owner_identity unique(owner_id,id),
 constraint opportunity_outcomes_owner_opportunity_fk foreign key(owner_id,opportunity_id) references public.opportunities(owner_id,id),
 constraint opportunity_outcomes_void_order check(voided_at is null or voided_at>=created_at)
);
create unique index opportunity_outcomes_one_active_idx on public.opportunity_outcomes(owner_id,opportunity_id) where voided_at is null;

create table public.opportunity_contact_roles(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id), opportunity_id uuid not null, contact_id uuid not null,
 role text not null check(length(btrim(role)) between 1 and 100), support_level public.opportunity_support_level not null default 'Unknown',
 notes text, created_at timestamptz not null default now(),
 constraint opportunity_contact_roles_owner_identity unique(owner_id,id),
 constraint opportunity_contact_roles_owner_opportunity_fk foreign key(owner_id,opportunity_id) references public.opportunities(owner_id,id),
 constraint opportunity_contact_roles_owner_contact_fk foreign key(owner_id,contact_id) references public.contacts(owner_id,id),
 constraint opportunity_contact_roles_unique unique(owner_id,opportunity_id,contact_id,role)
);

create trigger opportunities_guard_mutation before update on public.opportunities for each row execute function public.guard_mutable_entity();
create trigger opportunities_reject_physical_delete before delete on public.opportunities for each row execute function public.reject_mutable_entity_delete();
create function private.reject_opportunity_history_mutation() returns trigger language plpgsql set search_path='' as $$begin raise exception using errcode='P0001',message='opportunity stage history is append-only';end;$$;
create trigger opportunity_stage_history_append_only before update or delete on public.opportunity_stage_history for each row execute function private.reject_opportunity_history_mutation();
create table private.opportunity_outcome_void_capabilities(transaction_id xid8 not null,backend_pid integer not null,owner_id uuid not null,outcome_id uuid not null,primary key(transaction_id,backend_pid,owner_id,outcome_id));
revoke all on private.opportunity_outcome_void_capabilities from public,anon,authenticated,service_role;
create function private.guard_opportunity_outcome_mutation() returns trigger language plpgsql security definer set search_path='' as $$begin
 if tg_op='UPDATE' and new is not distinct from jsonb_populate_record(old,to_jsonb(old)||jsonb_build_object('voided_at',new.voided_at))
   and old.voided_at is null and new.voided_at is not null
   and exists(select 1 from private.opportunity_outcome_void_capabilities c where c.transaction_id=pg_current_xact_id() and c.backend_pid=pg_backend_pid() and c.owner_id=old.owner_id and c.outcome_id=old.id) then return new; end if;
 raise exception using errcode='P0001',message='opportunity outcomes are immutable except controlled voiding';
end;$$;
create trigger opportunity_outcomes_immutable before update or delete on public.opportunity_outcomes for each row execute function private.guard_opportunity_outcome_mutation();

alter table public.opportunities enable row level security;alter table public.opportunities force row level security;
alter table public.opportunity_stage_history enable row level security;alter table public.opportunity_stage_history force row level security;
alter table public.opportunity_outcomes enable row level security;alter table public.opportunity_outcomes force row level security;
alter table public.opportunity_contact_roles enable row level security;alter table public.opportunity_contact_roles force row level security;
create policy opportunities_select_owner on public.opportunities for select to authenticated using(auth.uid()=owner_id and deleted_at is null);
create policy opportunities_mutation_denied on public.opportunities for all to authenticated using(false) with check(false);
create policy opportunity_stage_history_select_owner on public.opportunity_stage_history for select to authenticated using(auth.uid()=owner_id);
create policy opportunity_stage_history_mutation_denied on public.opportunity_stage_history for all to authenticated using(false) with check(false);
create policy opportunity_outcomes_select_owner on public.opportunity_outcomes for select to authenticated using(auth.uid()=owner_id);
create policy opportunity_outcomes_mutation_denied on public.opportunity_outcomes for all to authenticated using(false) with check(false);
create policy opportunity_contact_roles_select_owner on public.opportunity_contact_roles for select to authenticated using(auth.uid()=owner_id);
create policy opportunity_contact_roles_mutation_denied on public.opportunity_contact_roles for all to authenticated using(false) with check(false);
grant select,insert,update,delete on public.opportunities,public.opportunity_stage_history,public.opportunity_outcomes,public.opportunity_contact_roles to authenticated,service_role;

create function private.opportunity_stage_rank(p_stage public.opportunity_stage) returns integer language sql immutable set search_path='' as $$
 select case p_stage when 'Lead' then 1 when 'Discovery' then 2 when 'Needs Confirmed' then 3 when 'Solution Design' then 4 when 'POC' then 5 when 'Commercial Negotiation' then 6 else 7 end;
$$;
create function private.refresh_opportunity_search(p_owner_id uuid,p_opportunity_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare e public.opportunities%rowtype;c_name text;stage public.opportunity_stage;
begin select * into e from public.opportunities where owner_id=p_owner_id and id=p_opportunity_id;
 if e.id is null then raise exception using errcode='P0001',message='opportunity not found';end if;
 select name into c_name from public.customers where owner_id=p_owner_id and id=e.customer_id;
 select to_stage into stage from public.opportunity_stage_history where owner_id=p_owner_id and opportunity_id=e.id order by recorded_at desc,id desc limit 1;
 insert into public.search_documents(owner_id,source_type,source_id,title,subtitle,search_text,route,data_level,visibility_state,source_created_at,source_updated_at,projection_schema_version,indexed_at,metadata)
 values(p_owner_id,'Opportunity',e.id,e.name,concat_ws(' · ',c_name,stage::text),concat_ws(E'\n',e.name,c_name,e.scenario,e.customer_need,e.desired_outcome,e.solution_direction,e.constraints),'/opportunities/'||e.id,'Level3',case when e.deleted_at is not null then 'Deleted' when stage in('Closed Won','Closed Lost') then 'Closed' else 'Active' end,e.created_at,e.updated_at,1,now(),jsonb_strip_nulls(jsonb_build_object('customerId',e.customer_id,'currentStage',stage)))
 on conflict(owner_id,source_type,source_id) do update set title=excluded.title,subtitle=excluded.subtitle,search_text=excluded.search_text,visibility_state=excluded.visibility_state,source_updated_at=excluded.source_updated_at,indexed_at=excluded.indexed_at,metadata=excluded.metadata;
end;$$;

create function private.current_opportunity_history(p_owner_id uuid,p_opportunity_id uuid) returns public.opportunity_stage_history language sql stable security definer set search_path='' as $$
 select h from public.opportunity_stage_history h where h.owner_id=p_owner_id and h.opportunity_id=p_opportunity_id order by h.recorded_at desc,h.id desc limit 1;
$$;

create function public.create_opportunity(p_verified_user_id uuid,p_client_request_id uuid,p_customer_id uuid,p_parent_opportunity_id uuid,p_name text,p_opportunity_type public.opportunity_type,p_source_type public.opportunity_source_type,p_source_contact_id uuid,p_scenario text,p_customer_need text,p_desired_outcome text,p_solution_direction text,p_constraints text,p_estimated_amount numeric,p_currency text,p_amount_basis text,p_amount_as_of date,p_expected_decision_date date,p_initial_stage public.opportunity_stage,p_changed_source public.opportunity_changed_source,p_contact_roles jsonb)
returns table(id uuid,name text,version integer,current_stage_history_id uuid,operation_id uuid) language plpgsql security definer set search_path='' as $$
declare receipt record;e public.opportunities%rowtype;h_id uuid;item jsonb;parent_stage public.opportunity_stage;
begin if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required';end if;
 select * into receipt from private.claim_command_receipt(p_verified_user_id,'CreateOpportunity',p_client_request_id);
 if receipt.status='Completed' then select * into e from public.opportunities where owner_id=p_verified_user_id and opportunities.id=(receipt.result_reference->>'opportunityId')::uuid;return query select e.id,e.name,e.version,(receipt.result_reference->>'stageHistoryId')::uuid,receipt.operation_id;return;end if;
 if p_initial_stage<>'Lead' then raise exception using errcode='P0001',message='new opportunity must start at Lead';end if;
 if not exists(select 1 from public.customers where owner_id=p_verified_user_id and customers.id=p_customer_id and deleted_at is null and merged_into_id is null) then raise exception using errcode='P0001',message='customer not found';end if;
 if (p_source_contact_id is not null and not exists(select 1 from public.contacts c where c.owner_id=p_verified_user_id and c.id=p_source_contact_id and c.customer_id=p_customer_id and c.deleted_at is null and c.merged_into_id is null)) then raise exception using errcode='P0001',message='source contact not found at customer';end if;
 if p_opportunity_type='Renewal' then
  select h.to_stage into parent_stage from public.opportunities p join lateral private.current_opportunity_history(p_verified_user_id,p.id) h on true where p.owner_id=p_verified_user_id and p.id=p_parent_opportunity_id and p.deleted_at is null;
  if parent_stage is distinct from 'Closed Won' then raise exception using errcode='P0001',message='renewal requires a Closed Won parent opportunity';end if;
 elsif p_parent_opportunity_id is not null then raise exception using errcode='P0001',message='parent opportunity is reserved for Renewal';end if;
 if jsonb_typeof(p_contact_roles)<>'array' then raise exception using errcode='P0001',message='contact roles must be an array';end if;
 insert into public.opportunities(owner_id,customer_id,parent_opportunity_id,name,opportunity_type,source_type,source_contact_id,scenario,customer_need,desired_outcome,solution_direction,constraints,estimated_amount,currency,amount_basis,amount_as_of,expected_decision_date)
 values(p_verified_user_id,p_customer_id,p_parent_opportunity_id,btrim(p_name),p_opportunity_type,p_source_type,p_source_contact_id,p_scenario,p_customer_need,p_desired_outcome,p_solution_direction,p_constraints,p_estimated_amount,p_currency,p_amount_basis,p_amount_as_of,p_expected_decision_date) returning * into e;
 insert into public.opportunity_stage_history(owner_id,opportunity_id,from_stage,to_stage,transition_type,changed_source,amount_snapshot,expected_decision_date_snapshot,operation_id) values(p_verified_user_id,e.id,null,p_initial_stage,'Initial',p_changed_source,e.estimated_amount,e.expected_decision_date,receipt.operation_id) returning opportunity_stage_history.id into h_id;
 for item in select value from jsonb_array_elements(p_contact_roles) loop
  if not exists(select 1 from public.contacts c where c.owner_id=p_verified_user_id and c.id=(item->>'contactId')::uuid and c.customer_id=p_customer_id and c.deleted_at is null and c.merged_into_id is null) then raise exception using errcode='P0001',message='contact role target not found at customer';end if;
  insert into public.opportunity_contact_roles(owner_id,opportunity_id,contact_id,role,support_level,notes) values(p_verified_user_id,e.id,(item->>'contactId')::uuid,btrim(item->>'role'),coalesce((item->>'supportLevel')::public.opportunity_support_level,'Unknown'),nullif(btrim(item->>'notes'),''));
 end loop;
 perform private.refresh_opportunity_search(p_verified_user_id,e.id);
 perform private.append_audit_log(p_verified_user_id,'OpportunityCreated','Opportunity',e.id,null,p_client_request_id,receipt.operation_id,'["customer_id","name","opportunity_type","estimated_amount"]',jsonb_build_object('initialStage',p_initial_stage,'contactRoleCount',jsonb_array_length(p_contact_roles)),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,receipt.id,receipt.operation_id,'Completed','Opportunity',e.id,jsonb_build_object('opportunityId',e.id,'stageHistoryId',h_id));
 return query select e.id,e.name,e.version,h_id,receipt.operation_id;end;$$;

create function private.assert_opportunity_concurrency(p_owner_id uuid,p_opportunity_id uuid,p_expected_version integer,p_expected_history_id uuid) returns public.opportunity_stage_history language plpgsql security definer set search_path='' as $$
declare e public.opportunities%rowtype;h public.opportunity_stage_history%rowtype;begin
 select * into e from public.opportunities where owner_id=p_owner_id and id=p_opportunity_id and deleted_at is null for update;
 if e.id is null then raise exception using errcode='P0001',message='opportunity not found';end if;
 if e.version is distinct from p_expected_version then raise exception using errcode='40001',message='opportunity version conflict';end if;
 select * into h from private.current_opportunity_history(p_owner_id,p_opportunity_id);
 if h.id is distinct from p_expected_history_id then raise exception using errcode='40001',message='opportunity history conflict';end if;return h;end;$$;

create function public.transition_opportunity(p_verified_user_id uuid,p_client_request_id uuid,p_opportunity_id uuid,p_expected_version integer,p_expected_current_stage_history_id uuid,p_to_stage public.opportunity_stage,p_changed_source public.opportunity_changed_source,p_reason text)
returns table(opportunity_id uuid,version integer,stage_history_id uuid,current_stage public.opportunity_stage,transition_type public.opportunity_transition_type,operation_id uuid) language plpgsql security definer set search_path='' as $$
declare receipt record;e public.opportunities%rowtype;current_h public.opportunity_stage_history%rowtype;t public.opportunity_transition_type;h_id uuid;new_version integer;
begin if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required';end if;
 select * into receipt from private.claim_command_receipt(p_verified_user_id,'TransitionOpportunity',p_client_request_id);
 if receipt.status='Completed' then return query select p_opportunity_id,(receipt.result_reference->>'version')::integer,(receipt.result_reference->>'stageHistoryId')::uuid,(receipt.result_reference->>'currentStage')::public.opportunity_stage,(receipt.result_reference->>'transitionType')::public.opportunity_transition_type,receipt.operation_id;return;end if;
 current_h:=private.assert_opportunity_concurrency(p_verified_user_id,p_opportunity_id,p_expected_version,p_expected_current_stage_history_id);
 if current_h.to_stage in('Closed Won','Closed Lost') then raise exception using errcode='P0001',message='closed opportunity must be reopened';end if;
 if p_to_stage in('Closed Won','Closed Lost') then raise exception using errcode='P0001',message='terminal stage requires outcome';end if;
 if p_to_stage=current_h.to_stage then raise exception using errcode='P0001',message='stage must change';end if;
 t:=(case when private.opportunity_stage_rank(p_to_stage)<private.opportunity_stage_rank(current_h.to_stage) then 'Backward' when private.opportunity_stage_rank(p_to_stage)=private.opportunity_stage_rank(current_h.to_stage)+1 then 'Forward' else 'Skip' end)::public.opportunity_transition_type;
 select * into e from public.opportunities where owner_id=p_verified_user_id and id=p_opportunity_id;
 insert into public.opportunity_stage_history(owner_id,opportunity_id,from_stage,to_stage,transition_type,changed_source,reason,amount_snapshot,expected_decision_date_snapshot,operation_id) values(p_verified_user_id,p_opportunity_id,current_h.to_stage,p_to_stage,t,p_changed_source,p_reason,e.estimated_amount,e.expected_decision_date,receipt.operation_id) returning id into h_id;
 update public.opportunities set updated_at=now() where owner_id=p_verified_user_id and id=p_opportunity_id returning opportunities.version into new_version;
 perform private.refresh_opportunity_search(p_verified_user_id,p_opportunity_id);perform private.append_audit_log(p_verified_user_id,'OpportunityStageChanged','Opportunity',p_opportunity_id,null,p_client_request_id,receipt.operation_id,'["stage"]',jsonb_build_object('fromStage',current_h.to_stage,'toStage',p_to_stage,'transitionType',t),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,receipt.id,receipt.operation_id,'Completed','OpportunityStageHistory',h_id,jsonb_build_object('opportunityId',p_opportunity_id,'version',new_version,'stageHistoryId',h_id,'currentStage',p_to_stage,'transitionType',t));
 return query select p_opportunity_id,new_version,h_id,p_to_stage,t,receipt.operation_id;end;$$;

create function public.record_opportunity_outcome(p_verified_user_id uuid,p_client_request_id uuid,p_opportunity_id uuid,p_expected_version integer,p_expected_current_stage_history_id uuid,p_outcome_type public.opportunity_outcome_type,p_final_amount numeric,p_currency text,p_decision_date date,p_reason text,p_competitor text,p_decision_factors jsonb,p_customer_value text,p_lessons text,p_review_completed_at timestamptz)
returns table(opportunity_id uuid,outcome_id uuid,version integer,stage_history_id uuid,operation_id uuid) language plpgsql security definer set search_path='' as $$
declare receipt record;current_h public.opportunity_stage_history%rowtype;target public.opportunity_stage;o_id uuid;h_id uuid;new_version integer;
begin if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required';end if;
 select * into receipt from private.claim_command_receipt(p_verified_user_id,'RecordOpportunityOutcome',p_client_request_id);
 if receipt.status='Completed' then return query select p_opportunity_id,(receipt.result_reference->>'outcomeId')::uuid,(receipt.result_reference->>'version')::integer,(receipt.result_reference->>'stageHistoryId')::uuid,receipt.operation_id;return;end if;
 current_h:=private.assert_opportunity_concurrency(p_verified_user_id,p_opportunity_id,p_expected_version,p_expected_current_stage_history_id);
 if current_h.to_stage in('Closed Won','Closed Lost') then raise exception using errcode='P0001',message='opportunity already closed';end if;
 target:=(case p_outcome_type when 'Won' then 'Closed Won' else 'Closed Lost' end)::public.opportunity_stage;
 insert into public.opportunity_outcomes(owner_id,opportunity_id,outcome_type,final_amount,currency,decision_date,reason,competitor,decision_factors,customer_value,lessons,review_completed_at,operation_id) values(p_verified_user_id,p_opportunity_id,p_outcome_type,p_final_amount,p_currency,p_decision_date,btrim(p_reason),nullif(btrim(p_competitor),''),coalesce(p_decision_factors,'[]'),p_customer_value,p_lessons,p_review_completed_at,receipt.operation_id) returning id into o_id;
 insert into public.opportunity_stage_history(owner_id,opportunity_id,from_stage,to_stage,transition_type,changed_source,reason,amount_snapshot,expected_decision_date_snapshot,operation_id) values(p_verified_user_id,p_opportunity_id,current_h.to_stage,target,'Skip','Manual',p_reason,p_final_amount,p_decision_date,receipt.operation_id) returning id into h_id;
 update public.opportunities set updated_at=now() where owner_id=p_verified_user_id and id=p_opportunity_id returning opportunities.version into new_version;
 perform private.refresh_opportunity_search(p_verified_user_id,p_opportunity_id);perform private.append_audit_log(p_verified_user_id,'OpportunityOutcomeRecorded','OpportunityOutcome',o_id,null,p_client_request_id,receipt.operation_id,'["outcome_type","final_amount","currency","decision_date","stage"]',jsonb_build_object('opportunityId',p_opportunity_id,'stage',target),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,receipt.id,receipt.operation_id,'Completed','OpportunityOutcome',o_id,jsonb_build_object('opportunityId',p_opportunity_id,'outcomeId',o_id,'version',new_version,'stageHistoryId',h_id));
 return query select p_opportunity_id,o_id,new_version,h_id,receipt.operation_id;end;$$;

create function public.reopen_opportunity(p_verified_user_id uuid,p_client_request_id uuid,p_opportunity_id uuid,p_expected_version integer,p_expected_current_stage_history_id uuid,p_to_stage public.opportunity_stage,p_changed_source public.opportunity_changed_source,p_reason text)
returns table(opportunity_id uuid,version integer,stage_history_id uuid,current_stage public.opportunity_stage,transition_type public.opportunity_transition_type,operation_id uuid) language plpgsql security definer set search_path='' as $$
declare receipt record;e public.opportunities%rowtype;current_h public.opportunity_stage_history%rowtype;o public.opportunity_outcomes%rowtype;h_id uuid;new_version integer;
begin if auth.role()<>'service_role' then raise exception using errcode='42501',message='service role required';end if;
 select * into receipt from private.claim_command_receipt(p_verified_user_id,'ReopenOpportunity',p_client_request_id);
 if receipt.status='Completed' then return query select p_opportunity_id,(receipt.result_reference->>'version')::integer,(receipt.result_reference->>'stageHistoryId')::uuid,(receipt.result_reference->>'currentStage')::public.opportunity_stage,'Reopen'::public.opportunity_transition_type,receipt.operation_id;return;end if;
 current_h:=private.assert_opportunity_concurrency(p_verified_user_id,p_opportunity_id,p_expected_version,p_expected_current_stage_history_id);
 if current_h.to_stage not in('Closed Won','Closed Lost') or p_to_stage in('Closed Won','Closed Lost') then raise exception using errcode='P0001',message='reopen requires closed source and nonterminal target';end if;
 select x.* into o from public.opportunity_outcomes x where x.owner_id=p_verified_user_id and x.opportunity_id=p_opportunity_id and x.voided_at is null for update;
 if o.id is null or (current_h.to_stage='Closed Won')<>(o.outcome_type='Won') then raise exception using errcode='P0001',message='closed stage requires matching active outcome';end if;
 insert into private.opportunity_outcome_void_capabilities values(pg_current_xact_id(),pg_backend_pid(),p_verified_user_id,o.id);
 update public.opportunity_outcomes set voided_at=now() where id=o.id;
 delete from private.opportunity_outcome_void_capabilities where transaction_id=pg_current_xact_id() and backend_pid=pg_backend_pid() and owner_id=p_verified_user_id and outcome_id=o.id;
 select * into e from public.opportunities where owner_id=p_verified_user_id and id=p_opportunity_id;
 insert into public.opportunity_stage_history(owner_id,opportunity_id,from_stage,to_stage,transition_type,changed_source,reason,amount_snapshot,expected_decision_date_snapshot,operation_id) values(p_verified_user_id,p_opportunity_id,current_h.to_stage,p_to_stage,'Reopen',p_changed_source,p_reason,e.estimated_amount,e.expected_decision_date,receipt.operation_id) returning id into h_id;
 update public.opportunities set updated_at=now() where owner_id=p_verified_user_id and id=p_opportunity_id returning opportunities.version into new_version;
 perform private.refresh_opportunity_search(p_verified_user_id,p_opportunity_id);perform private.append_audit_log(p_verified_user_id,'OpportunityReopened','Opportunity',p_opportunity_id,null,p_client_request_id,receipt.operation_id,'["stage","outcome_voided_at"]',jsonb_build_object('voidedOutcomeId',o.id,'toStage',p_to_stage),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,receipt.id,receipt.operation_id,'Completed','OpportunityStageHistory',h_id,jsonb_build_object('opportunityId',p_opportunity_id,'version',new_version,'stageHistoryId',h_id,'currentStage',p_to_stage));
 return query select p_opportunity_id,new_version,h_id,p_to_stage,'Reopen'::public.opportunity_transition_type,receipt.operation_id;end;$$;

create function public.get_opportunity_projection(p_opportunity_id uuid,p_as_of timestamptz,p_stalled_after_days integer)
returns table(opportunity_id uuid,current_stage public.opportunity_stage,stage_entered_at timestamptz,days_in_stage integer,is_closed boolean,is_stalled boolean,last_progress_at timestamptz,next_task_due_at timestamptz,forecast_category text,outcome_review_missing boolean,projection_schema_version integer)
language sql stable security invoker set search_path='' as $$
 with history as(select h.* from public.opportunity_stage_history h join public.opportunities o on o.owner_id=h.owner_id and o.id=h.opportunity_id where o.owner_id=auth.uid() and o.id=p_opportunity_id and o.deleted_at is null and h.changed_at<=p_as_of),
 current_h as(select * from history order by recorded_at desc,id desc limit 1),
 progress as(select max(changed_at) as at from history where transition_type in('Initial','Forward','Skip','Reopen')),
 active_outcome as(select x.* from public.opportunity_outcomes x join public.opportunities o on o.owner_id=x.owner_id and o.id=x.opportunity_id where o.owner_id=auth.uid() and o.id=p_opportunity_id and x.voided_at is null limit 1)
 select p_opportunity_id,h.to_stage,h.changed_at,greatest(0,floor(extract(epoch from(p_as_of-h.changed_at))/86400)::integer),h.to_stage in('Closed Won','Closed Lost'),h.to_stage not in('Closed Won','Closed Lost') and p_as_of>=p.at+make_interval(days=>p_stalled_after_days),p.at,null::timestamptz,null::text,(h.to_stage in('Closed Won','Closed Lost') and x.id is not null and x.review_completed_at is null),1 from current_h h cross join progress p left join active_outcome x on true where p_stalled_after_days between 1 and 3650;
$$;

create function private.reassign_opportunity_customer_links(p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare moved integer;rid uuid;begin
 update public.opportunities set customer_id=p_survivor_id where owner_id=p_owner_id and customer_id=p_duplicate_id and deleted_at is null;get diagnostics moved=row_count;
 for rid in select id from public.opportunities where owner_id=p_owner_id and customer_id=p_survivor_id loop perform private.refresh_opportunity_search(p_owner_id,rid);end loop;
 return jsonb_build_object('opportunitiesReassigned',moved);end;$$;
create function private.reassign_opportunity_contact_links(p_owner_id uuid,p_survivor_id uuid,p_duplicate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare roles_moved integer;sources_moved integer;begin
 update public.opportunities set source_contact_id=p_survivor_id where owner_id=p_owner_id and source_contact_id=p_duplicate_id;get diagnostics sources_moved=row_count;
 update public.opportunity_contact_roles set contact_id=p_survivor_id where owner_id=p_owner_id and contact_id=p_duplicate_id and not exists(select 1 from public.opportunity_contact_roles s where s.owner_id=p_owner_id and s.opportunity_id=opportunity_contact_roles.opportunity_id and s.contact_id=p_survivor_id and s.role=opportunity_contact_roles.role);get diagnostics roles_moved=row_count;
 return jsonb_build_object('sourceContactsReassigned',sources_moved,'rolesReassigned',roles_moved,'roleEvidencePreserved',true);end;$$;
update private.merge_hook_manifests set expected_dependencies=array_cat(expected_dependencies,array['public.opportunities.customer_id']) where entity_type='Customer';
update private.merge_hook_manifests set expected_dependencies=array_cat(expected_dependencies,array['public.opportunities.source_contact_id','public.opportunity_contact_roles.contact_id']) where entity_type='Contact';
insert into private.merge_reassignment_hooks(entity_type,hook_name,function_name,execution_order,schema_version,covered_dependencies) values
('Customer','opportunity_customer_links','private.reassign_opportunity_customer_links(uuid,uuid,uuid)'::regprocedure,20,1,array['public.opportunities.customer_id']),
('Contact','opportunity_contact_links','private.reassign_opportunity_contact_links(uuid,uuid,uuid)'::regprocedure,20,1,array['public.opportunities.source_contact_id','public.opportunity_contact_roles.contact_id']);

revoke all on function public.create_opportunity(uuid,uuid,uuid,uuid,text,public.opportunity_type,public.opportunity_source_type,uuid,text,text,text,text,text,numeric,text,text,date,date,public.opportunity_stage,public.opportunity_changed_source,jsonb) from public,anon,authenticated;
revoke all on function public.transition_opportunity(uuid,uuid,uuid,integer,uuid,public.opportunity_stage,public.opportunity_changed_source,text) from public,anon,authenticated;
revoke all on function public.record_opportunity_outcome(uuid,uuid,uuid,integer,uuid,public.opportunity_outcome_type,numeric,text,date,text,text,jsonb,text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.reopen_opportunity(uuid,uuid,uuid,integer,uuid,public.opportunity_stage,public.opportunity_changed_source,text) from public,anon,authenticated;
grant execute on function public.create_opportunity(uuid,uuid,uuid,uuid,text,public.opportunity_type,public.opportunity_source_type,uuid,text,text,text,text,text,numeric,text,text,date,date,public.opportunity_stage,public.opportunity_changed_source,jsonb) to service_role;
grant execute on function public.transition_opportunity(uuid,uuid,uuid,integer,uuid,public.opportunity_stage,public.opportunity_changed_source,text) to service_role;
grant execute on function public.record_opportunity_outcome(uuid,uuid,uuid,integer,uuid,public.opportunity_outcome_type,numeric,text,date,text,text,jsonb,text,text,timestamptz) to service_role;
grant execute on function public.reopen_opportunity(uuid,uuid,uuid,integer,uuid,public.opportunity_stage,public.opportunity_changed_source,text) to service_role;
