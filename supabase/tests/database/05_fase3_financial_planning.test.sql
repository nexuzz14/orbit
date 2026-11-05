-- ==============================================================================
-- Orbit Uji pgTAP Fase 3: Perencanaan Keuangan (PRD v5.1 M4, M5, M7e, M8, M13)
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

-- -----------------------------------------------------------------------------
-- Fixture Data: Users (Trigger otomatis membuat profil, workspace, kategori, akun Cash)
-- -----------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('b3000000-0000-0000-0000-000000000001', 'owner.f3@example.test', '{"full_name": "Owner F3"}'),
  ('b3000000-0000-0000-0000-000000000002', 'editor.f3@example.test', '{"full_name": "Editor F3"}'),
  ('b3000000-0000-0000-0000-000000000003', 'viewer.f3@example.test', '{"full_name": "Viewer F3"}'),
  ('b3000000-0000-0000-0000-000000000004', 'other.f3@example.test', '{"full_name": "Other F3"}');

create temp table ws_f3 as
select u.id as uid, w.id as wid,
  (select a.id from public.accounts a where a.workspace_id = w.id and a.name = 'Cash') as cash,
  (select c.id from public.categories c where c.workspace_id = w.id and c.type = 'expense' limit 1) as cat_exp,
  (select c.id from public.categories c where c.workspace_id = w.id and c.type = 'income' limit 1) as cat_inc
from auth.users u
join public.workspaces w on w.owner_id = u.id and w.type = 'personal'
where u.id in (
  'b3000000-0000-0000-0000-000000000001',
  'b3000000-0000-0000-0000-000000000002',
  'b3000000-0000-0000-0000-000000000003',
  'b3000000-0000-0000-0000-000000000004'
);

-- Jadikan editor dan viewer di workspace owner (w1)
insert into public.workspace_members (workspace_id, user_id, role)
select (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), 'b3000000-0000-0000-0000-000000000002', 'editor';

insert into public.workspace_members (workspace_id, user_id, role)
select (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), 'b3000000-0000-0000-0000-000000000003', 'viewer';

-- -----------------------------------------------------------------------------
-- 1. Uji RLS Matriks & IDOR Tabel Fase 3
-- -----------------------------------------------------------------------------
-- Owner dapat membuat budget
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    format($q$
      insert into public.budgets (id, workspace_id, category_id, amount, period, rollover)
      values ('bb300000-0000-0000-0000-000000000001', %L, %L, 1500000.0000, 'monthly', true)
      returning amount::text;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cat_exp from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '1500000.0000',
  'Owner berhasil membuat anggaran kategori (budgets)'
);

-- Viewer dilarang menambah budget
select isnt(
  pg_temp.err_as(
    'b3000000-0000-0000-0000-000000000003',
    format($q$
      insert into public.budgets (workspace_id, category_id, amount, period)
      values (%L, %L, 500000.0000, 'monthly');
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cat_exp from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  'ok',
  'Viewer dilarang membuat anggaran kategori (RLS deny insert)'
);

-- IDOR: User 4 dilarang melihat budget milik Workspace 1
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000004',
    format($q$
      select count(*)::text from public.budgets where workspace_id = %L;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '0',
  'IDOR: User lain tidak dapat melihat anggaran workspace orang lain'
);

-- -----------------------------------------------------------------------------
-- 2. Uji View v_budget_progress (Kalkulasi Pengeluaran & Sisa Anggaran)
-- -----------------------------------------------------------------------------
-- Catat transaksi pengeluaran bulan ini sebesar 500,000 oleh editor
select pg_temp.exec_as(
  'b3000000-0000-0000-0000-000000000002',
  format($q$
    insert into public.transactions (
      workspace_id, account_id, category_id, type, status, amount, amount_base, currency, source, occurred_at
    ) values (
      %L, %L, %L, 'expense', 'confirmed', 500000.0000, 500000.0000, 'IDR', 'personal', current_date
    );
  $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cash from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cat_exp from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
);

-- Cek pengeluaran dan sisa di v_budget_progress
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    format($q$
      select spent_amount::text from public.v_budget_progress
      where workspace_id = %L and category_id = %L;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cat_exp from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '500000.0000',
  'v_budget_progress menghitung total pengeluaran bulan berjalan secara akurat'
);

select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    format($q$
      select remaining_amount::text from public.v_budget_progress
      where workspace_id = %L and category_id = %L;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cat_exp from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '2500000.0000',
  'v_budget_progress menyajikan sisa anggaran efektif dengan rollover ((1,500,000 + 1,500,000) - 500,000 = 2,500,000)'
);

-- -----------------------------------------------------------------------------
-- 3. Uji Idempotensi fn_generate_due_bill_drafts (Tagihan Rutin)
-- -----------------------------------------------------------------------------
-- Tambah tagihan rutin yang jatuh tempo hari ini
select pg_temp.exec_as(
  'b3000000-0000-0000-0000-000000000001',
  format($q$
    insert into public.recurring_bills (
      id, workspace_id, name, amount, category_id, account_id, schedule_type, schedule_value
    ) values (
      'eb300000-0000-0000-0000-000000000001', %L, 'Langganan Fiber Optik', 350000.0000, %L, %L, 'monthly', %s
    );
  $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cat_exp from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), (select cash from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'), extract(day from current_date)::integer)
);

-- Panggilan pertama: menghasilkan 1 draft
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    $$ select public.fn_generate_due_bill_drafts(current_date)::text; $$
  ),
  '1',
  'fn_generate_due_bill_drafts menghasilkan 1 draft tagihan saat jatuh tempo'
);

-- Panggilan kedua pada hari yang sama: 0 (idempoten via recurring_bill_instances)
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    $$ select public.fn_generate_due_bill_drafts(current_date)::text; $$
  ),
  '0',
  'fn_generate_due_bill_drafts idempoten (0 draft baru saat dipanggil ulang pada hari yang sama)'
);

-- -----------------------------------------------------------------------------
-- 4. Uji Auto-Split fn_apply_income_split (Alokasi ke Savings Goals)
-- -----------------------------------------------------------------------------
-- Buat Target Tabungan & Aturan Split 20% dari intern
select pg_temp.exec_as(
  'b3000000-0000-0000-0000-000000000001',
  format($q$
    insert into public.savings_goals (id, workspace_id, name, target_amount, current_amount, currency)
    values ('fb300000-0000-0000-0000-000000000001', %L, 'Tabungan Darurat', 10000000.0000, 0.0000, 'IDR');

    insert into public.income_split_rules (workspace_id, source, goal_id, split_type, split_value, priority)
    values (%L, 'intern', 'fb300000-0000-0000-0000-000000000001', 'percentage', 20.0000, 1);

    insert into public.transactions (
      id, workspace_id, account_id, category_id, type, status, amount, amount_base, currency, source, note, occurred_at
    ) values (
      'fa300000-0000-0000-0000-000000000001', %L, %L, %L, 'income', 'confirmed', 2000000.0000, 2000000.0000, 'IDR', 'intern', 'Uang Saku Magang', current_date
    );
  $q$,
    (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'),
    (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'),
    (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'),
    (select cash from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'),
    (select cat_inc from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001')
  )
);

select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    $$ select public.fn_apply_income_split('fa300000-0000-0000-0000-000000000001')::text; $$
  ),
  '1',
  'fn_apply_income_split berhasil mengeksekusi 1 alokasi auto-split'
);

select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    $$ select current_amount::text from public.savings_goals where id = 'fb300000-0000-0000-0000-000000000001'; $$
  ),
  '400000.0000',
  'Target tabungan bertambah 20% (400,000 dari 2,000,000) secara atomik'
);

-- -----------------------------------------------------------------------------
-- 5. Uji Pencocokan & Konfirmasi Expected Income (fn_match & fn_confirm)
-- -----------------------------------------------------------------------------
-- Buat expected income dan draft transaksi yang cocok
select pg_temp.exec_as(
  'b3000000-0000-0000-0000-000000000001',
  format($q$
    insert into public.expected_incomes (
      id, workspace_id, label, source, amount, tolerance, expected_date, date_window_days, status
    ) values (
      'ea300000-0000-0000-0000-000000000001', %L, 'Uang Saku Magang Nov 2026', 'intern', 800000.0000, 0.0000, current_date, 3, 'pending'
    );

    insert into public.transactions (
      id, workspace_id, account_id, type, status, amount, amount_base, currency, source, bank_category, occurred_at
    ) values (
      'da300000-0000-0000-0000-000000000001', %L, %L, 'income', 'draft', 800000.0000, 800000.0000, 'IDR', 'personal', 'Gaji', current_date
    );
  $q$,
    (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'),
    (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'),
    (select cash from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001')
  )
);

-- fn_match_expected_income menghasilkan match confidence 'exact'
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    $$ select match_confidence from public.fn_match_expected_income('da300000-0000-0000-0000-000000000001'); $$
  ),
  'exact',
  'fn_match_expected_income mencocokkan draft pemasukan gaji dengan tingkat confidence exact'
);

-- Konfirmasi expected income
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    format($q$
      select public.fn_confirm_expected_income(
        'ea300000-0000-0000-0000-000000000001',
        'da300000-0000-0000-0000-000000000001',
        %L
      )::text;
    $q$, (select cash from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  'da300000-0000-0000-0000-000000000001',
  'fn_confirm_expected_income mengonfirmasi transaksi draft dan memperbarui status expected_income'
);

select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000001',
    $$ select status from public.expected_incomes where id = 'ea300000-0000-0000-0000-000000000001'; $$
  ),
  'confirmed',
  'Status expected_incomes berubah menjadi confirmed setelah dikonfirmasi'
);

-- -----------------------------------------------------------------------------
-- 6. Uji Batas Nilai & Constraint Integritas Tabungan / Alokasi
-- -----------------------------------------------------------------------------
-- Target Tabungan dilarang bernilai negatif (check current_amount >= 0)
select isnt(
  pg_temp.err_as(
    'b3000000-0000-0000-0000-000000000001',
    format($q$
      insert into public.savings_goals (workspace_id, name, target_amount, current_amount, currency)
      values (%L, 'Target Negatif', 1000000.0000, -50000.0000, 'IDR');
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  'ok',
  'Target tabungan dilarang bernilai saldo berjalan negatif (CHECK current_amount >= 0)'
);

-- Target amount dilarang <= 0
select isnt(
  pg_temp.err_as(
    'b3000000-0000-0000-0000-000000000001',
    format($q$
      insert into public.savings_goals (workspace_id, name, target_amount, current_amount, currency)
      values (%L, 'Target Nol', 0.0000, 0.0000, 'IDR');
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  'ok',
  'Target tabungan dilarang dengan target nominal <= 0 (CHECK target_amount > 0)'
);

-- -----------------------------------------------------------------------------
-- 7. Uji RLS Lintas Workspace Menyeluruh (IDOR Isolation)
-- -----------------------------------------------------------------------------
-- User lain (Other F3) dilarang melihat recurring_bills workspace lain
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000004',
    format($q$
      select count(*)::text from public.recurring_bills where workspace_id = %L;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '0',
  'RLS Lintas Workspace: User lain tidak dapat membaca recurring_bills workspace orang lain'
);

-- User lain dilarang melihat savings_goals workspace lain
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000004',
    format($q$
      select count(*)::text from public.savings_goals where workspace_id = %L;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '0',
  'RLS Lintas Workspace: User lain tidak dapat membaca savings_goals workspace orang lain'
);

-- User lain dilarang melihat expected_incomes workspace lain
select is(
  pg_temp.scalar_as(
    'b3000000-0000-0000-0000-000000000004',
    format($q$
      select count(*)::text from public.expected_incomes where workspace_id = %L;
    $q$, (select wid from ws_f3 where uid = 'b3000000-0000-0000-0000-000000000001'))
  ),
  '0',
  'RLS Lintas Workspace: User lain tidak dapat membaca expected_incomes workspace orang lain'
);

select * from finish();
rollback;
