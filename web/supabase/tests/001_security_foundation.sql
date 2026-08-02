begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(57);

select has_type('public', 'data_level', 'data_level enum exists');
select has_type('public', 'command_status', 'command_status enum exists');
select col_not_null('public', 'command_receipts', 'owner_id', 'command receipt owner is required');
select col_not_null('public', 'audit_logs', 'owner_id', 'audit log owner is required');
select ok(
  to_regprocedure(
    'private.append_audit_log(uuid,text,text,uuid,uuid,uuid,uuid,jsonb,jsonb,text,text,text,text)'
  ) is not null,
  'composable audit primitive exists for future atomic business command RPCs'
);
select policies_are(
  'public',
  'command_receipts',
  array[
    'command_receipts_delete_denied',
    'command_receipts_insert_owner',
    'command_receipts_select_owner',
    'command_receipts_update_owner'
  ],
  'command receipts define an explicit policy for every CRUD operation'
);
select policies_are(
  'public',
  'audit_logs',
  array[
    'audit_logs_delete_denied',
    'audit_logs_insert_denied',
    'audit_logs_select_owner',
    'audit_logs_update_denied'
  ],
  'audit logs define an explicit policy for every CRUD operation'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, created_at, updated_at
) values
  (
    '10000000-0000-4000-8000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'security-owner@example.test', '', now(), now()
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'other-owner@example.test', '', now(), now()
  );

insert into public.command_receipts (
  owner_id, client_request_id, command_type, operation_id, status
) values (
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'CreateCustomer',
  '30000000-0000-4000-8000-000000000001',
  'Processing'
);

select throws_ok(
  $$
    insert into public.command_receipts (
      owner_id, client_request_id, command_type, operation_id, status
    ) values (
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      'CreateCustomer',
      '30000000-0000-4000-8000-000000000002',
      'Processing'
    )
  $$,
  '23505',
  null,
  'command receipt idempotency key is unique per owner and command'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$
    insert into public.command_receipts (client_request_id, command_type)
    values ('20000000-0000-4000-8000-000000000099', 'BrowserBypass')
  $$,
  '42501', null,
  'authenticated clients cannot insert command receipts directly'
);
select throws_ok(
  $$ update public.command_receipts set status = 'Completed', completed_at = now() $$,
  '42501', null,
  'authenticated clients cannot update command receipts directly'
);
select throws_ok(
  $$
    select public.write_audit_log(
      '10000000-0000-4000-8000-000000000001',
      'BrowserBypass', 'AuditLog', null, null, null, null,
      '[]'::jsonb, '{}'::jsonb, null, 'pgTAP', 'Success', null
    )
  $$,
  '42501', null,
  'authenticated clients cannot invoke the audit writer'
);
select throws_ok(
  $$
    select public.claim_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      'BrowserBypass',
      '20000000-0000-4000-8000-000000000090'
    )
  $$,
  '42501', null,
  'authenticated clients cannot invoke the public Saga claim RPC'
);
select throws_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000091',
      '30000000-0000-4000-8000-000000000091',
      'Completed', null, null, null
    )
  $$,
  '42501', null,
  'authenticated clients cannot invoke the public Saga complete RPC'
);
select throws_ok(
  $$
    select public.retry_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      'BrowserBypass',
      '20000000-0000-4000-8000-000000000090',
      '20000000-0000-4000-8000-000000000091',
      '30000000-0000-4000-8000-000000000091'
    )
  $$,
  '42501', null,
  'authenticated clients cannot invoke the public Saga retry RPC'
);
select throws_ok(
  $$
    select private.append_audit_log(
      '10000000-0000-4000-8000-000000000001',
      'BrowserBypass', 'AuditLog', null, null, null, null,
      '[]'::jsonb, '{}'::jsonb, null, 'pgTAP', 'Success', null
    )
  $$,
  '42501', null,
  'authenticated clients cannot invoke the composable audit primitive'
);
select throws_ok(
  $$
    insert into public.audit_logs (owner_id, actor_id, action, entity_type, result)
    values (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      'Bypass', 'AuditLog', 'Success'
    )
  $$,
  '42501', null,
  'authenticated clients cannot insert audit rows directly'
);
reset role;

set local role anon;
select throws_ok(
  $$
    select public.write_audit_log(
      '10000000-0000-4000-8000-000000000001',
      'AnonymousBypass', 'AuditLog', null, null, null, null,
      '[]'::jsonb, '{}'::jsonb, null, 'pgTAP', 'Success', null
    )
  $$,
  '42501', null,
  'anonymous clients cannot invoke the audit writer'
);
select throws_ok(
  $$
    select public.claim_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      'AnonymousBypass',
      '20000000-0000-4000-8000-000000000092'
    )
  $$,
  '42501', null,
  'anonymous clients cannot invoke the public Saga claim RPC'
);
select throws_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000093',
      '30000000-0000-4000-8000-000000000093',
      'Completed', null, null, null
    )
  $$,
  '42501', null,
  'anonymous clients cannot invoke the public Saga complete RPC'
);
select throws_ok(
  $$
    select public.retry_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      'AnonymousBypass',
      '20000000-0000-4000-8000-000000000092',
      '20000000-0000-4000-8000-000000000093',
      '30000000-0000-4000-8000-000000000093'
    )
  $$,
  '42501', null,
  'anonymous clients cannot invoke the public Saga retry RPC'
);
select is((select count(*) from public.command_receipts), 0::bigint, 'anon cannot read command receipts');
select is((select count(*) from public.audit_logs), 0::bigint, 'anon cannot read audit logs');
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select lives_ok(
  $$
    select public.write_audit_log(
      '10000000-0000-4000-8000-000000000001',
      'SignedIn', 'AuthSession', null, null, null, null,
      '[]'::jsonb, '{}'::jsonb, null, 'pgTAP', 'Success', null
    )
  $$,
  'service-only writer appends an audit row'
);
reset role;

select is(
  (select owner_id from public.audit_logs limit 1),
  '10000000-0000-4000-8000-000000000001'::uuid,
  'audit owner is derived from the server-verified user id'
);
select is(
  (select actor_id from public.audit_logs limit 1),
  '10000000-0000-4000-8000-000000000001'::uuid,
  'audit actor is derived from the server-verified user id'
);
select throws_ok(
  $$ update public.audit_logs set action = 'Tampered' $$,
  'P0001', 'audit logs are append-only',
  'audit rows reject updates even for a role that bypasses RLS'
);
select throws_ok(
  $$ delete from public.audit_logs $$,
  'P0001', 'audit logs are append-only',
  'audit rows reject deletes even for a role that bypasses RLS'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select is((select count(*) from public.command_receipts), 0::bigint, 'another owner cannot read command receipts');
select is((select count(*) from public.audit_logs), 0::bigint, 'another owner cannot read audit logs');
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select is((select count(*) from public.command_receipts), 1::bigint, 'owner can read their command receipt');
select is((select count(*) from public.audit_logs), 1::bigint, 'owner can read their audit log');
select throws_ok(
  $$ delete from public.command_receipts $$,
  '42501', null,
  'owner cannot delete command receipts'
);
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
create temporary table first_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '10000000-0000-4000-8000-000000000001',
  'CreateOpportunity',
  '20000000-0000-4000-8000-000000000010'
);
create temporary table retry_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '10000000-0000-4000-8000-000000000001',
  'CreateOpportunity',
  '20000000-0000-4000-8000-000000000010'
);
select is((select status::text from first_claim), 'Processing', 'new command is reported as Processing');
select is(
  (select operation_id from retry_claim),
  (select operation_id from first_claim),
  'retry returns the original operation id'
);
select is(
  (select id from retry_claim),
  (select id from first_claim),
  'retry returns the original receipt id'
);
select lives_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      (select id from first_claim),
      (select operation_id from first_claim),
      'Completed',
      'Opportunity',
      '40000000-0000-4000-8000-000000000001',
      '{"entityType":"Opportunity","entityId":"40000000-0000-4000-8000-000000000001"}'::jsonb
    )
  $$,
  'Processing receipt can transition to Completed'
);
create temporary table completed_replay on commit drop as
select * from public.claim_saga_command_receipt(
  '10000000-0000-4000-8000-000000000001',
  'CreateOpportunity',
  '20000000-0000-4000-8000-000000000010'
);
select is((select status::text from completed_replay), 'Completed', 'completed retry is reported as Completed');
select is(
  (select operation_id from completed_replay),
  (select operation_id from first_claim),
  'completed retry keeps the original operation id'
);
select is(
  (select result_reference ->> 'entityId' from completed_replay),
  '40000000-0000-4000-8000-000000000001',
  'completed retry returns the original lightweight result reference'
);
select throws_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      (select id from first_claim),
      (select operation_id from first_claim),
      'Failed', null, null, null
    )
  $$,
  'P0001', 'terminal command receipts are immutable',
  'Completed cannot transition to Failed'
);
reset role;
select throws_ok(
  $$
    update public.command_receipts
    set completed_at = completed_at + interval '1 second'
    where id = (select id from first_claim)
  $$,
  'P0001', 'terminal command receipts are immutable',
  'terminal receipt timestamps cannot be mutated through a bypass role'
);

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
create temporary table failed_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '10000000-0000-4000-8000-000000000001',
  'DeleteAttachment',
  '20000000-0000-4000-8000-000000000020'
);
select lives_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      (select id from failed_claim),
      (select operation_id from failed_claim),
      'Failed',
      'Attachment',
      '40000000-0000-4000-8000-000000000020',
      '{"errorCode":"StorageUnavailable"}'::jsonb
    )
  $$,
  'Processing receipt can transition to Failed'
);
create temporary table failed_replay on commit drop as
select * from public.claim_saga_command_receipt(
  '10000000-0000-4000-8000-000000000001',
  'DeleteAttachment',
  '20000000-0000-4000-8000-000000000020'
);
select is((select status::text from failed_replay), 'Failed', 'failed retry is reported deterministically');
select is(
  (select operation_id from failed_replay),
  (select operation_id from failed_claim),
  'failed retry keeps the original operation id'
);
select throws_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      (select id from failed_claim),
      (select operation_id from failed_claim),
      'Completed', null, null, '{}'::jsonb
    )
  $$,
  'P0001', 'terminal command receipts are immutable',
  'Failed cannot transition to Completed'
);
reset role;

select throws_ok(
  $$
    update public.command_receipts
    set
      status = 'Processing',
      result_entity_type = null,
      result_entity_id = null,
      result_reference = null,
      completed_at = null
    where id = (select id from failed_claim)
  $$,
  'P0001', 'terminal command receipts are immutable',
  'Failed cannot be reopened by an arbitrary bypass update'
);

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select lives_ok(
  $$
    select public.retry_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      'DeleteAttachment',
      '20000000-0000-4000-8000-000000000020',
      (select id from failed_claim),
      (select operation_id from failed_claim)
    )
  $$,
  'dedicated Saga retry reopens Failed as Processing'
);
create temporary table resumed_claim on commit drop as
select * from public.claim_saga_command_receipt(
  '10000000-0000-4000-8000-000000000001',
  'DeleteAttachment',
  '20000000-0000-4000-8000-000000000020'
);
select is((select status::text from resumed_claim), 'Processing', 'Saga retry reports Processing');
select is(
  (select operation_id from resumed_claim),
  (select operation_id from failed_claim),
  'Saga retry preserves the original operation id'
);
select is(
  (select result_reference from resumed_claim),
  null::jsonb,
  'Saga retry clears the terminal result reference'
);
reset role;
select is(
  (
    select completed_at
    from public.command_receipts
    where id = (select id from resumed_claim)
  ),
  null::timestamptz,
  'Saga retry clears the prior completion timestamp'
);
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select lives_ok(
  $$
    select public.complete_saga_command_receipt(
      '10000000-0000-4000-8000-000000000001',
      (select id from resumed_claim),
      (select operation_id from resumed_claim),
      'Completed', 'Attachment',
      '40000000-0000-4000-8000-000000000020',
      '{"entityType":"Attachment","entityId":"40000000-0000-4000-8000-000000000020"}'::jsonb
    )
  $$,
  'retried Processing receipt can complete normally'
);
reset role;

select is(
  (
    select completed_at is not null
    from public.command_receipts
    where id = (select id from resumed_claim)
  ),
  true,
  'retried completion writes a new completion timestamp'
);
select is(
  (
    select result_reference ->> 'entityId'
    from public.command_receipts
    where id = (select id from resumed_claim)
  ),
  '40000000-0000-4000-8000-000000000020',
  'retried completion replaces the prior failure result only after controlled reopen'
);

select throws_ok(
  $$
    update public.command_receipts
    set operation_id = gen_random_uuid()
    where owner_id = '10000000-0000-4000-8000-000000000001'
  $$,
  'P0001', 'command receipt identity is immutable',
  'operation id cannot be replaced through a bypass role'
);
select enum_has_labels(
  'public', 'data_level', array['Level1', 'Level2', 'Level3'],
  'data levels are frozen'
);
select enum_has_labels(
  'public', 'command_status', array['Processing', 'Completed', 'Failed'],
  'command statuses are frozen'
);

select * from finish();
rollback;
