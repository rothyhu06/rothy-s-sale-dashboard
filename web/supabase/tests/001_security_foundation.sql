begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(21);

select has_type('public', 'data_level', 'data_level enum exists');
select has_type('public', 'command_status', 'command_status enum exists');
select col_not_null('public', 'command_receipts', 'owner_id', 'command receipt owner is required');
select col_not_null('public', 'audit_logs', 'owner_id', 'audit log owner is required');
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
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  created_at,
  updated_at
) values (
  '10000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'security-owner@example.test',
  '',
  now(),
  now()
);

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  created_at,
  updated_at
) values (
  '10000000-0000-4000-8000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'other-owner@example.test',
  '',
  now(),
  now()
);

insert into public.command_receipts (
  owner_id,
  client_request_id,
  command_type,
  operation_id,
  status
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
      owner_id,
      client_request_id,
      command_type,
      operation_id,
      status
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

select lives_ok(
  $$
    select public.write_audit_log(
      'SignedIn',
      'AuthSession',
      null,
      null,
      null,
      null,
      '[]'::jsonb,
      '{}'::jsonb,
      null,
      'pgTAP',
      'Success',
      null
    )
  $$,
  'authenticated owner can append an audit row through the controlled function'
);

select throws_ok(
  $$
    insert into public.audit_logs (owner_id, actor_id, action, entity_type, result)
    values (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      'Bypass',
      'AuditLog',
      'Success'
    )
  $$,
  '42501',
  null,
  'authenticated users cannot insert audit rows directly'
);

reset role;

select throws_ok(
  $$ update public.audit_logs set action = 'Tampered' $$,
  'P0001',
  'audit logs are append-only',
  'audit rows reject updates even for a role that bypasses RLS'
);
select throws_ok(
  $$ delete from public.audit_logs $$,
  'P0001',
  'audit logs are append-only',
  'audit rows reject deletes even for a role that bypasses RLS'
);

set local role anon;
select is((select count(*) from public.command_receipts), 0::bigint, 'anon cannot read command receipts');
select is((select count(*) from public.audit_logs), 0::bigint, 'anon cannot read audit logs');
reset role;

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
  '42501',
  null,
  'owner cannot delete command receipts'
);
reset role;
select throws_ok(
  $$
    update public.command_receipts
    set operation_id = gen_random_uuid()
    where owner_id = '10000000-0000-4000-8000-000000000001'
  $$,
  'P0001',
  'command receipt identity is immutable',
  'operation id cannot be replaced even by a role that bypasses RLS'
);

select enum_has_labels(
  'public',
  'data_level',
  array['Level1', 'Level2', 'Level3'],
  'data levels are frozen'
);
select enum_has_labels(
  'public',
  'command_status',
  array['Processing', 'Completed', 'Failed'],
  'command statuses are frozen'
);

select * from finish();
rollback;
