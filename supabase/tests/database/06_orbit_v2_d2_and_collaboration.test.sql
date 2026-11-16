-- ==============================================================================
-- Uji pgTAP Orbit v2: Alur Kerja D.2 (Revisi, Progres, History), Kolaborasi,
-- Saved Views, Pelacakan Waktu, Search Global, & Isolasi RLS Lintas Workspace
-- ==============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.exec_as(p_user uuid, p_sql text) returns void
language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql;
  reset role;
exception
  when others then
    reset role;
    raise;
end;
$f$;

create function pg_temp.scalar_as(p_user uuid, p_sql text) returns text
language plpgsql as $f$
declare
  v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
exception
  when others then
    reset role;
    raise;
end;
$f$;

create function pg_temp.err_as(p_user uuid, p_sql text) returns text
language plpgsql as $f$
declare
  v_result text := 'ok';
begin
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
    set local role authenticated;
    execute p_sql;
    raise exception 'rollback' using errcode = 'XXRBK';
  exception
    when sqlstate 'XXRBK' then
      null;
    when others then
      v_result := sqlstate;
  end;
  reset role;
  return v_result;
end;
$f$;

-- 1. User dan workspace uji
insert into auth.users (id, email, raw_user_meta_data) values
  ('d2000000-0000-0000-0000-000000000001', 'owner.v2@example.test', '{"full_name": "Owner V2"}'),
  ('d2000000-0000-0000-0000-000000000002', 'editor.v2@example.test', '{"full_name": "Editor V2"}'),
  ('d2000000-0000-0000-0000-000000000003', 'viewer.v2@example.test', '{"full_name": "Viewer V2"}'),
  ('d2000000-0000-0000-0000-000000000004', 'outsider.v2@example.test', '{"full_name": "Outsider V2"}');

create temp table ws_v2 as
select u.id as uid, w.id as wid
from auth.users u
join public.workspaces w on w.owner_id = u.id and w.type = 'personal'
where u.id in (
  'd2000000-0000-0000-0000-000000000001',
  'd2000000-0000-0000-0000-000000000002',
  'd2000000-0000-0000-0000-000000000003',
  'd2000000-0000-0000-0000-000000000004'
);

insert into public.workspace_members (workspace_id, user_id, role)
select (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'), 'd2000000-0000-0000-0000-000000000002', 'editor';

insert into public.workspace_members (workspace_id, user_id, role)
select (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'), 'd2000000-0000-0000-0000-000000000003', 'viewer';

-- 2. Uji D.2: Enum revisi, penolakan tanpa catatan, revision_count, dan task_status_history
select pg_temp.exec_as(
  'd2000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.tasks (id, workspace_id, kind, title, status, progress_percent)
    values ('e1000000-0000-0000-0000-000000000001', %L, 'freelance', 'API Checkout V2', 'doing', 40)
  $q$, (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'))
);

select is(
  pg_temp.err_as(
    'd2000000-0000-0000-0000-000000000002',
    $q$select public.fn_change_task_status('e1000000-0000-0000-0000-000000000001', 'revisi'::public.task_status, '   ')$q$
  ),
  '23514',
  'pindah status ke revisi tanpa catatan alasan ditolak (23514)'
);

select pg_temp.exec_as(
  'd2000000-0000-0000-0000-000000000002',
  $q$select public.fn_change_task_status('e1000000-0000-0000-0000-000000000001', 'revisi'::public.task_status, 'Perlu verifikasi HMAC signature')$q$
);

select is(
  (select status::text || ':' || revision_count::text from public.tasks where id = 'e1000000-0000-0000-0000-000000000001'),
  'revisi:1',
  'status revisi aktif dan revision_count bertambah menjadi 1'
);

select is(
  (select count(*) from public.task_status_history where task_id = 'e1000000-0000-0000-0000-000000000001' and to_status = 'revisi'),
  1::bigint,
  'task_status_history mencatat perpindahan ke status revisi'
);

-- Uji append-only task_status_history (update/delete harus ditolak 42501)
select ok(
  pg_temp.err_as(
    'd2000000-0000-0000-0000-000000000001',
    $q$update public.task_status_history set note = 'Dimodifikasi' where task_id = 'e1000000-0000-0000-0000-000000000001'$q$
  ) = '42501',
  'task_status_history menolak UPDATE (append-only)'
);

-- 3. Uji progres otomatis dari checklist (3/4 = 75%) & done = 100%
select pg_temp.exec_as(
  'd2000000-0000-0000-0000-000000000002',
  $q$
    insert into public.task_checklist_items (task_id, text, done, sort_order) values
      ('e1000000-0000-0000-0000-000000000001', 'Step 1', true, 1),
      ('e1000000-0000-0000-0000-000000000001', 'Step 2', true, 2),
      ('e1000000-0000-0000-0000-000000000001', 'Step 3', true, 3),
      ('e1000000-0000-0000-0000-000000000001', 'Step 4', false, 4);
  $q$
);

select is(
  (select progress_percent from public.tasks where id = 'e1000000-0000-0000-0000-000000000001'),
  75::smallint,
  'progress_percent otomatis dihitung menjadi 75 saat 3 dari 4 checklist selesai'
);

select pg_temp.exec_as(
  'd2000000-0000-0000-0000-000000000002',
  $q$select public.fn_change_task_status('e1000000-0000-0000-0000-000000000001', 'done'::public.task_status, null)$q$
);

select is(
  (select progress_percent from public.tasks where id = 'e1000000-0000-0000-0000-000000000001'),
  100::smallint,
  'pindah status ke done memaksa progress_percent menjadi 100'
);

-- 4. Uji komentar, saved_views, task_time_logs, user_devices & isolasi lintas workspace
select pg_temp.exec_as(
  'd2000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.comments (id, workspace_id, entity_type, entity_id, body)
    values ('e2000000-0000-0000-0000-000000000001', %L, 'task', 'e1000000-0000-0000-0000-000000000001', 'Sudah ditangani idempotency');

    insert into public.saved_views (id, workspace_id, name, scope, view_mode, is_pinned)
    values ('e3000000-0000-0000-0000-000000000001', %L, 'Terlambat & Revisi', 'tasks', 'board', true);

    insert into public.task_time_logs (id, workspace_id, task_id, started_at, ended_at, duration_seconds, mode)
    values ('e4000000-0000-0000-0000-000000000001', %L, 'e1000000-0000-0000-0000-000000000001', now() - interval '25 minutes', now(), 1500, 'pomodoro');
  $q$,
    (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'),
    (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'),
    (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001')
  )
);

-- Outsider tidak boleh membaca komentar atau saved_views
select is(
  pg_temp.scalar_as(
    'd2000000-0000-0000-0000-000000000004',
    $q$select count(*)::text from public.comments where id = 'e2000000-0000-0000-0000-000000000001'$q$
  ),
  '0',
  'outsider terblokir membaca komentar workspace lain'
);

-- Viewer tidak boleh menulis saved_views
select is(
  pg_temp.err_as(
    'd2000000-0000-0000-0000-000000000003',
    format($q$
      insert into public.saved_views (workspace_id, name, scope)
      values (%L, 'Unauthorized View', 'tasks')
    $q$, (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'))
  ),
  '42501',
  'viewer ditolak membuat saved_views (42501)'
);

-- Perangkat push bersifat privat per user
select pg_temp.exec_as(
  'd2000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.user_devices (id, user_id, workspace_id, platform, device_name)
    values ('e5000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000002', %L, 'android', 'Pixel Test')
  $q$, (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'))
);

select is(
  pg_temp.scalar_as(
    'd2000000-0000-0000-0000-000000000001',
    $q$select count(*)::text from public.user_devices where id = 'e5000000-0000-0000-0000-000000000001'$q$
  ),
  '0',
  'owner workspace pun tidak dapat membaca langganan perangkat user_devices milik user lain'
);

-- Uji pencarian global fn_global_search
select is(
  pg_temp.scalar_as(
    'd2000000-0000-0000-0000-000000000003',
    format($q$select title from public.fn_global_search(%L, 'Checkout', 10) limit 1$q$,
      (select wid from ws_v2 where uid = 'd2000000-0000-0000-0000-000000000001'))
  ),
  'API Checkout V2',
  'fn_global_search mengembalikan tugas sesuai kata kunci untuk anggota workspace'
);

select finish();
rollback;
