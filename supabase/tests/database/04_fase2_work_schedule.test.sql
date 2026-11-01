-- Uji Fase 2: Kerja, Jadwal, Tugas, & Proyek Freelance
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
  return v_result;
end;
$f$;

-- Buat 4 user pengujian
insert into auth.users (id, email, raw_user_meta_data) values
  ('b1000000-0000-0000-0000-000000000001', 'owner.f2@example.test', '{"full_name": "Owner F2"}'),
  ('b1000000-0000-0000-0000-000000000002', 'editor.f2@example.test', '{"full_name": "Editor F2"}'),
  ('b1000000-0000-0000-0000-000000000003', 'viewer.f2@example.test', '{"full_name": "Viewer F2"}'),
  ('b1000000-0000-0000-0000-000000000004', 'other.f2@example.test', '{"full_name": "Other F2"}');

create temp table ws_f2 as
select u.id as uid, w.id as wid,
  (select a.id from public.accounts a where a.workspace_id = w.id and a.name = 'Cash') as cash
from auth.users u
join public.workspaces w on w.owner_id = u.id and w.type = 'personal'
where u.id in (
  'b1000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000002',
  'b1000000-0000-0000-0000-000000000003',
  'b1000000-0000-0000-0000-000000000004'
);

-- Jadikan editor dan viewer di workspace owner
insert into public.workspace_members (workspace_id, user_id, role)
select (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'), 'b1000000-0000-0000-0000-000000000002', 'editor';

insert into public.workspace_members (workspace_id, user_id, role)
select (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'), 'b1000000-0000-0000-0000-000000000003', 'viewer';

-- ---------------------------------------------------------------------------
-- 1. Uji Proyek dan Project Payments RLS & IDOR
-- ---------------------------------------------------------------------------

-- Buat proyek freelance di W1 oleh editor
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.projects (id, workspace_id, kind, name, client_name, contract_value, currency, platform_fee_percent, fee_mode)
    values ('c1000000-0000-0000-0000-000000000001', %L, 'freelance', 'Web Redesign', 'PT Maju Terus', 10000000, 'IDR', 10, 'expense_transaction')
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

select is(
  (select count(*) from public.projects where id = 'c1000000-0000-0000-0000-000000000001'),
  1::bigint,
  'editor berhasil membuat proyek freelance di workspace'
);

-- Viewer mencoba insert payment -> ditolak RLS (42501)
select is(
  pg_temp.err_as(
    'b1000000-0000-0000-0000-000000000003',
    format($q$
      insert into public.project_payments (workspace_id, project_id, label, amount, due_date)
      values (%L, 'c1000000-0000-0000-0000-000000000001', 'Termin 1', 5000000, current_date + 7)
    $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
  ),
  '42501',
  'viewer ditolak saat menambah project_payments'
);

-- Outsider mencoba insert payment ke W1 -> ditolak RLS (42501 atau 23503)
select ok(
  pg_temp.err_as(
    'b1000000-0000-0000-0000-000000000004',
    format($q$
      insert into public.project_payments (workspace_id, project_id, label, amount, due_date)
      values (%L, 'c1000000-0000-0000-0000-000000000001', 'Termin Hacker', 5000000, current_date)
    $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
  ) in ('42501', '23503'),
  'outsider ditolak saat mencoba IDOR insert project_payments ke workspace lain'
);

-- Editor insert payment yang sah
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.project_payments (id, workspace_id, project_id, label, amount, due_date)
    values ('c2000000-0000-0000-0000-000000000001', %L, 'c1000000-0000-0000-0000-000000000001', 'DP 50%', 5000000, current_date - 1)
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

-- Viewer dapat membaca payment
select is(
  pg_temp.scalar_as(
    'b1000000-0000-0000-0000-000000000003',
    $q$select label from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'$q$
  ),
  'DP 50%',
  'viewer dapat membaca project_payments di workspace'
);

-- Outsider tidak dapat membaca payment (0 baris/null)
select is(
  pg_temp.scalar_as(
    'b1000000-0000-0000-0000-000000000004',
    $q$select label from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'$q$
  ),
  null,
  'outsider tidak dapat membaca project_payments workspace lain'
);

-- ---------------------------------------------------------------------------
-- 2. Uji fn_complete_task
-- ---------------------------------------------------------------------------

-- Editor membuat tugas dengan checklist dan tautan milestone
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.tasks (id, workspace_id, project_id, kind, title, priority, due_at, milestone_payment_id)
    values ('c3000000-0000-0000-0000-000000000001', %L, 'c1000000-0000-0000-0000-000000000001', 'freelance', 'Desain Mockup Figma', 'tinggi', current_date, 'c2000000-0000-0000-0000-000000000001');

    insert into public.task_checklist_items (task_id, text, done, sort_order) values
      ('c3000000-0000-0000-0000-000000000001', 'Wireframe', true, 1),
      ('c3000000-0000-0000-0000-000000000001', 'Visual Design', false, 2);
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

-- Viewer mencoba fn_complete_task -> ditolak
select is(
  pg_temp.err_as(
    'b1000000-0000-0000-0000-000000000003',
    $q$select public.fn_complete_task('c3000000-0000-0000-0000-000000000001')$q$
  ),
  '42501',
  'viewer ditolak saat memanggil fn_complete_task'
);

-- Editor memanggil fn_complete_task -> status menjadi done, completed_at terisi
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  $q$select public.fn_complete_task('c3000000-0000-0000-0000-000000000001')$q$
);

select is(
  (select status::text from public.tasks where id = 'c3000000-0000-0000-0000-000000000001'),
  'done',
  'tugas berhasil ditandai selesai (status = done)'
);

select ok(
  (select completed_at is not null from public.tasks where id = 'c3000000-0000-0000-0000-000000000001'),
  'tugas selesai memiliki timestamp completed_at'
);

-- Editor memanggil fn_complete_task lagi -> toggle kembali ke todo
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  $q$select public.fn_complete_task('c3000000-0000-0000-0000-000000000001')$q$
);

select is(
  (select status::text from public.tasks where id = 'c3000000-0000-0000-0000-000000000001'),
  'todo',
  'fn_complete_task kedua kali toggle status kembali ke todo'
);

select ok(
  (select completed_at is null from public.tasks where id = 'c3000000-0000-0000-0000-000000000001'),
  'tugas todo memiliki completed_at bernilai null'
);

-- ---------------------------------------------------------------------------
-- 3. Uji fn_mark_payment_paid (Atomik lunas dan batalkan lunas)
-- ---------------------------------------------------------------------------

-- Viewer mencoba fn_mark_payment_paid -> ditolak
select is(
  pg_temp.err_as(
    'b1000000-0000-0000-0000-000000000003',
    format(
      $q$select public.fn_mark_payment_paid('c2000000-0000-0000-0000-000000000001', %L)$q$,
      (select cash from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001')
    )
  ),
  '42501',
  'viewer ditolak saat menandai pembayaran lunas'
);

-- Editor mencoba menandai lunas dengan akun milik workspace lain -> ditolak (23503)
select is(
  pg_temp.err_as(
    'b1000000-0000-0000-0000-000000000002',
    format(
      $q$select public.fn_mark_payment_paid('c2000000-0000-0000-0000-000000000001', %L)$q$,
      (select cash from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000004')
    )
  ),
  '23503',
  'menandai lunas dengan akun workspace lain ditolak (23503)'
);

-- Editor menandai lunas dengan akun Cash yang sah
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format(
    $q$select public.fn_mark_payment_paid('c2000000-0000-0000-0000-000000000001', %L)$q$,
    (select cash from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001')
  )
);

-- Periksa status payment dan transaksi yang dihasilkan
select is(
  (select status from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'),
  'paid',
  'status payment menjadi paid'
);

select is(
  (select paid_amount from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'),
  5000000.0000::numeric,
  'paid_amount sesuai nominal pembayaran'
);

select ok(
  (select transaction_id is not null from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'),
  'transaction_id tercatat di payment'
);

select is(
  (
    select t.amount
    from public.transactions t
    join public.project_payments pm on pm.transaction_id = t.id
    where pm.id = 'c2000000-0000-0000-0000-000000000001'
  ),
  5000000.0000::numeric,
  'transaksi pemasukan dibuat dengan nominal 5,000,000'
);

select is(
  (
    select t.source::text
    from public.transactions t
    join public.project_payments pm on pm.transaction_id = t.id
    where pm.id = 'c2000000-0000-0000-0000-000000000001'
  ),
  'freelance',
  'sumber transaksi pemasukan adalah freelance'
);

-- Karena proyek memiliki fee_mode = expense_transaction dan platform_fee_percent = 10, periksa transaksi potongan platform (10% x 5jt = 500rb)
select is(
  (
    select t.amount
    from public.transactions t
    join public.project_payments pm on pm.fee_transaction_id = t.id
    where pm.id = 'c2000000-0000-0000-0000-000000000001'
  ),
  500000.0000::numeric,
  'transaksi fee dibuat otomatis dengan nominal 500,000 (10%%)'
);

-- Batalkan status lunas (p_account_id = null)
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  $q$select public.fn_mark_payment_paid('c2000000-0000-0000-0000-000000000001', null)$q$
);

select is(
  (select status from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'),
  'pending',
  'status payment kembali ke pending setelah pembatalan'
);

select is(
  (select paid_amount from public.project_payments where id = 'c2000000-0000-0000-0000-000000000001'),
  0.0000::numeric,
  'paid_amount kembali ke 0'
);

-- Verifikasi transaksi pemasukan dan fee dihapus lunak (deleted_at is not null)
select ok(
  (select count(*) from public.transactions where project_id = 'c1000000-0000-0000-0000-000000000001' and deleted_at is not null) >= 2,
  'transaksi pemasukan dan fee dihapus lunak saat status lunas dibatalkan'
);

-- ---------------------------------------------------------------------------
-- 4. Uji v_project_profit & v_receivables
-- ---------------------------------------------------------------------------

-- Tandai lunas lagi untuk pengujian view
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format(
    $q$select public.fn_mark_payment_paid('c2000000-0000-0000-0000-000000000001', %L)$q$,
    (select cash from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001')
  )
);

-- Tambah pembayaran termin 2 belum lunas (overdue: due_date kemarin)
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.project_payments (id, workspace_id, project_id, label, amount, due_date)
    values ('c2000000-0000-0000-0000-000000000002', %L, 'c1000000-0000-0000-0000-000000000001', 'Pelunasan 50%', 5000000, current_date - 2)
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

-- Uji v_project_profit
select is(
  (select total_invoiced from public.v_project_profit where project_id = 'c1000000-0000-0000-0000-000000000001'),
  10000000.0000::numeric,
  'v_project_profit: total_invoiced = 10,000,000'
);

select is(
  (select total_paid from public.v_project_profit where project_id = 'c1000000-0000-0000-0000-000000000001'),
  5000000.0000::numeric,
  'v_project_profit: total_paid = 5,000,000'
);

select is(
  (select total_expense from public.v_project_profit where project_id = 'c1000000-0000-0000-0000-000000000001'),
  500000.0000::numeric,
  'v_project_profit: total_expense (potongan platform) = 500,000'
);

select is(
  (select net_profit from public.v_project_profit where project_id = 'c1000000-0000-0000-0000-000000000001'),
  4500000.0000::numeric,
  'v_project_profit: net_profit = 4,500,000 (5jt - 500rb)'
);

-- Uji v_receivables
select is(
  (select count(*) from public.v_receivables where project_id = 'c1000000-0000-0000-0000-000000000001'),
  1::bigint,
  'v_receivables hanya menampilkan pembayaran belum lunas (1 baris termin 2)'
);

select is(
  (select status from public.v_receivables where payment_id = 'c2000000-0000-0000-0000-000000000002'),
  'overdue',
  'v_receivables menandai status overdue jika tanggal jatuh tempo telah lewat'
);

select ok(
  (select days_overdue >= 2 from public.v_receivables where payment_id = 'c2000000-0000-0000-0000-000000000002'),
  'v_receivables menghitung days_overdue dengan benar'
);

-- Outsider membaca view -> 0 baris
select is(
  pg_temp.scalar_as(
    'b1000000-0000-0000-0000-000000000004',
    $q$select count(*)::text from public.v_project_profit where project_id = 'c1000000-0000-0000-0000-000000000001'$q$
  ),
  '0',
  'outsider tidak melihat project_profit workspace lain (security_invoker)'
);

-- ---------------------------------------------------------------------------
-- 5. Uji fn_agenda (Event tunggal, berulang, skip exception, tugas, & filter)
-- ---------------------------------------------------------------------------

-- Buat event tunggal (Rabu 04 Nov 2026 10:00 - 12:00)
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.events (id, workspace_id, kind, title, starts_at, ends_at, timezone)
    values ('c4000000-0000-0000-0000-000000000001', %L, 'intern', 'Sprint Planning Magang', '2026-11-04 10:00+07', '2026-11-04 12:00+07', 'Asia/Jakarta')
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

-- Buat event mingguan kuliah setiap Senin (02 Nov, 09 Nov, 16 Nov 2026 08:00 - 10:00)
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.events (id, workspace_id, kind, title, starts_at, ends_at, timezone, recurrence)
    values (
      'c4000000-0000-0000-0000-000000000002',
      %L,
      'kuliah',
      'Kuliah Basis Data',
      '2026-11-02 08:00+07',
      '2026-11-02 10:00+07',
      'Asia/Jakarta',
      '{"freq":"weekly","byweekday":[1]}'::jsonb
    )
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

-- Tambah pengecualian libur (skip) pada 09 Nov 2026
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  $q$
    insert into public.event_exceptions (event_id, original_date, action)
    values ('c4000000-0000-0000-0000-000000000002', '2026-11-09', 'skip')
  $q$
);

-- Panggil fn_agenda untuk rentang 01 Nov - 16 Nov 2026
select is(
  (
    select count(*)
    from public.fn_agenda(
      (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'),
      '2026-11-01',
      '2026-11-16'
    )
    where title = 'Kuliah Basis Data'
  ),
  2::bigint,
  'fn_agenda mengembalikan 2 kejadian kuliah (Senin 02 Nov dan 16 Nov, sedangkan 09 Nov dilewati/skip)'
);

select ok(
  exists (
    select 1
    from public.fn_agenda(
      (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'),
      '2026-11-01',
      '2026-11-16'
    )
    where title = 'Sprint Planning Magang'
  ),
  'fn_agenda mengembalikan event tunggal'
);

-- Uji filter jenis: fn_agenda dengan p_kind = 'kuliah'
select ok(
  not exists (
    select 1
    from public.fn_agenda(
      (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'),
      '2026-11-01',
      '2026-11-16',
      'kuliah'
    )
    where kind <> 'kuliah'
  ),
  'fn_agenda dengan filter kind = kuliah hanya mengembalikan kegiatan kuliah'
);

-- ---------------------------------------------------------------------------
-- 6. Uji fn_detect_conflicts (Deteksi benturan & penanda hari padat)
-- ---------------------------------------------------------------------------

-- Tambahkan event yang bentrok dengan 'Sprint Planning Magang' pada 04 Nov 2026 (11:00 - 13:00)
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.events (id, workspace_id, kind, title, starts_at, ends_at, timezone)
    values ('c4000000-0000-0000-0000-000000000003', %L, 'kuliah', 'Asistensi Lab', '2026-11-04 11:00+07', '2026-11-04 13:00+07', 'Asia/Jakarta')
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

-- fn_detect_conflicts pada 04 Nov mendeteksi benturan Sprint Planning vs Asistensi Lab
select is(
  (
    select count(*)
    from public.fn_detect_conflicts(
      (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'),
      '2026-11-04',
      '2026-11-04'
    )
    where event1_title in ('Sprint Planning Magang', 'Asistensi Lab')
      and event2_title in ('Sprint Planning Magang', 'Asistensi Lab')
  ),
  1::bigint,
  'fn_detect_conflicts mendeteksi tumpang tindih waktu antara dua event pada 04 Nov'
);

-- Tambah event 8 jam pada 05 Nov 2026 (08:00 - 17:00) untuk uji penanda hari padat
select pg_temp.exec_as(
  'b1000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.events (id, workspace_id, kind, title, starts_at, ends_at, timezone)
    values ('c4000000-0000-0000-0000-000000000004', %L, 'intern', 'Full day workshop', '2026-11-05 08:00+07', '2026-11-05 17:00+07', 'Asia/Jakarta')
  $q$, (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'))
);

select ok(
  (
    select is_heavy_day
    from public.fn_detect_conflicts(
      (select wid from ws_f2 where uid = 'b1000000-0000-0000-0000-000000000001'),
      '2026-11-05',
      '2026-11-05'
    )
    limit 1
  ),
  'fn_detect_conflicts menandai hari padat (is_heavy_day = true) jika durasi >= 8 jam'
);

rollback;
