create function public.rebuild_search_documents(p_verified_user_id uuid,p_client_request_id uuid,p_projection_schema_version integer default 1)
returns table(indexed_count integer,operation_id uuid)language plpgsql security definer set search_path='' as $$declare r record;item record;counted integer;begin
 if auth.role()<>'service_role'then raise exception using errcode='42501',message='service role required';end if;
 if p_projection_schema_version<>1 then raise exception using errcode='P0001',message='unsupported projection schema version';end if;
 select * into r from private.claim_command_receipt(p_verified_user_id,'RebuildSearchDocuments',p_client_request_id);
 if r.status='Completed'then return query select (r.result_reference->>'indexedCount')::integer,r.operation_id;return;end if;
 delete from public.search_documents where owner_id=p_verified_user_id;
 for item in select id from public.knowledge where owner_id=p_verified_user_id loop perform private.refresh_knowledge_search(p_verified_user_id,item.id);end loop;
 for item in select id from public.learning where owner_id=p_verified_user_id loop perform private.refresh_learning_search(p_verified_user_id,item.id);end loop;
 for item in select id from public.customers where owner_id=p_verified_user_id loop perform private.refresh_customer_search(p_verified_user_id,item.id);end loop;
 for item in select id from public.contacts where owner_id=p_verified_user_id loop perform private.refresh_contact_search(p_verified_user_id,item.id);end loop;
 for item in select id from public.opportunities where owner_id=p_verified_user_id loop perform private.refresh_opportunity_search(p_verified_user_id,item.id);end loop;
 for item in select id from public.interactions where owner_id=p_verified_user_id loop perform private.refresh_daily_search(p_verified_user_id,'Interaction',item.id);end loop;
 for item in select id from public.tasks where owner_id=p_verified_user_id loop perform private.refresh_daily_search(p_verified_user_id,'Task',item.id);end loop;
 for item in select id from public.insights where owner_id=p_verified_user_id loop perform private.refresh_daily_search(p_verified_user_id,'Insight',item.id);end loop;
 select count(*) into counted from public.search_documents where owner_id=p_verified_user_id;
 perform private.append_audit_log(p_verified_user_id,'SearchProjectionRebuilt','SearchDocument',null,null,p_client_request_id,r.operation_id,'[]',jsonb_build_object('indexedCount',counted,'projectionSchemaVersion',1),null,null,'Success',null);
 perform private.complete_command_receipt(p_verified_user_id,r.id,r.operation_id,'Completed','SearchDocument',null,jsonb_build_object('indexedCount',counted));
 return query select counted,r.operation_id;
end$$;
revoke all on function public.rebuild_search_documents(uuid,uuid,integer)from public,anon,authenticated;
grant execute on function public.rebuild_search_documents(uuid,uuid,integer)to service_role;
