-- Uji fungsi, trigger, view, dan constraint database (Fase 1).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Menjalankan pernyataan sebagai pengguna (tanpa rollback). Kesalahan diteruskan ke pemanggil.
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

-- Mengambil nilai pertama sebagai teks, sebagai pengguna tertentu.
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

-- Kode kesalahan sebagai pengguna tertentu (rollback ke savepoint).
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

insert into auth.users (id, email, raw_user_meta_data) values
  ('a1000000-0000-0000-0000-000000000001', 'budi.santoso@example.test', '{"full_name": "Budi"}'),
  ('a1000000-0000-0000-0000-000000000002', 'sari@example.test', '{}'),
  ('a1000000-0000-0000-0000-000000000003', 'hapus@example.test', '{}');

create temp table ws as
select u.id as uid, w.id as wid,
  (select a.id from public.accounts a where a.workspace_id = w.id and a.name = 'Cash') as cash,
  (select c.id from public.categories c where c.workspace_id = w.id and c.name = 'Makan') as c_makan,
  (select c.id from public.categories c where c.workspace_id = w.id and c.name = 'Gaji/Uang Saku Intern') as c_gaji,
  (select c.id from public.categories c where c.workspace_id = w.id and c.type = 'expense' and c.name = 'Lainnya') as c_lain
from auth.users u
join public.workspaces w on w.owner_id = u.id and w.type = 'personal'
where u.id in ('a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000003');

-- ---------------------------------------------------------------------------
-- Pengguna baru
-- ---------------------------------------------------------------------------
select is((select display_name from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'), 'Budi', 'profil memakai nama dari metadata');
select is((select display_name from public.profiles where id = 'a1000000-0000-0000-0000-000000000002'), 'sari', 'profil memakai bagian lokal email bila nama kosong');
select is((select count(*) from ws), 3::bigint, 'setiap pengguna punya satu workspace pribadi');
select is((select role::text from public.workspace_members m join ws on ws.wid = m.workspace_id and ws.uid = m.user_id where ws.uid = 'a1000000-0000-0000-0000-000000000001'), 'owner', 'pengguna menjadi owner workspace pribadi');
select is((select count(*) from public.categories where workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')), 16::bigint, 'kategori default: 12 pengeluaran + 4 pemasukan');
select results_eq(
  format($q$select name from public.categories where workspace_id = %L and type = 'expense' order by sort_order$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  $q$values ('Makan'), ('Transport'), ('Kos'), ('Pulsa/Internet'), ('Kuliah'), ('Langganan'), ('Hiburan'), ('Tools Proyek'), ('Belanja'), ('Kesehatan'), ('Koreksi saldo'), ('Lainnya')$q$,
  'kategori pengeluaran default sesuai PRD');
select results_eq(
  format($q$select name from public.categories where workspace_id = %L and type = 'income' order by sort_order$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  $q$values ('Gaji/Uang Saku Intern'), ('Proyek Freelance'), ('Kiriman'), ('Lainnya')$q$,
  'kategori pemasukan default sesuai PRD');
select is((select count(*) from public.accounts a where a.workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')), 1::bigint, 'satu akun awal');
select is((select type::text || '/' || currency from public.accounts where id = (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001')), 'cash/IDR', 'akun Cash bertipe cash dan mata uang IDR');
select is((select count(*) from public.workspaces where owner_id = 'a1000000-0000-0000-0000-000000000001' and type = 'personal'), 1::bigint, 'hanya satu workspace pribadi per pengguna');

-- ---------------------------------------------------------------------------
-- Transaksi, saldo, transfer
-- ---------------------------------------------------------------------------
create temp table acc2 as
with ins as (
  insert into public.accounts (workspace_id, name, type, currency, initial_balance, created_by)
  select wid, 'Bank', 'bank', 'IDR', 50000, uid from ws where uid = 'a1000000-0000-0000-0000-000000000001'
  returning id, workspace_id
)
select id, workspace_id from ins;

insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, source, occurred_at)
select wid, cash, c_gaji, 'income', 'confirmed', 100000, 'IDR', 'intern', '2026-10-26 10:00+07' from ws where uid = 'a1000000-0000-0000-0000-000000000001';
insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, source, occurred_at, merchant)
select wid, cash, c_makan, 'expense', 'confirmed', 25000, 'IDR', 'personal', '2026-11-24 12:00+07', 'Indomaret, JKT 01!' from ws where uid = 'a1000000-0000-0000-0000-000000000001';
insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, source, occurred_at)
select wid, cash, c_makan, 'expense', 'confirmed', 7000, 'IDR', 'personal', '2026-11-25 12:00+07' from ws where uid = 'a1000000-0000-0000-0000-000000000001';
insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, occurred_at)
select wid, cash, null, 'expense', 'draft', 5000, 'IDR', '2026-11-20 12:00+07' from ws where uid = 'a1000000-0000-0000-0000-000000000001';
insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, source, occurred_at, deleted_at)
select wid, cash, c_makan, 'expense', 'confirmed', 9000, 'IDR', 'personal', '2026-11-20 12:00+07', now() from ws where uid = 'a1000000-0000-0000-0000-000000000001';

select is((select merchant_normalized from public.transactions where merchant is not null limit 1), 'indomaret', 'merchant dinormalkan: huruf kecil, tanpa kode lokasi dan tanda baca');
select is(public.fn_normalize_merchant('Warung  Bu-Siti, Bandung'), 'warung bu siti', 'normalisasi merchant menghapus tanda baca dan spasi ganda');
select is((select amount_base from public.transactions where amount = 100000), 100000.0000::numeric, 'amount_base mengikuti mata uang dasar');

-- Saldo: draft dan transaksi terhapus tidak dihitung.
select is(
  (select balance from public.v_account_balances where account_id = (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  68000.0000::numeric, 'saldo Cash = 100000 - 25000 - 7000 (draft dan terhapus tidak dihitung)');
select is(
  (select balance from public.v_account_balances where account_id = (select id from acc2)),
  50000.0000::numeric, 'saldo Bank = saldo awal');

-- Transfer lewat fungsi database.
select lives_ok(
  format($q$select pg_temp.exec_as(%L, format($i$select public.fn_create_transfer(%%L, %%L, %%L, 10000, '2026-11-10 10:00+07', 'tarik', null, 500, %%L)$i$, %L, %L, %L, %L))$q$,
    'a1000000-0000-0000-0000-000000000001', (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'),
    (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select id from acc2),
    'a1000000-0000-0000-0000-0000000000aa'),
  'fn_create_transfer berhasil');
select is((select count(*) from public.transactions where transfer_group_id = 'a1000000-0000-0000-0000-0000000000aa'), 3::bigint, 'transfer membuat dua sisi dan satu biaya admin');
select is(
  (select balance from public.v_account_balances where account_id = (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  57500.0000::numeric, 'saldo Cash turun oleh transfer dan biaya admin');
select is(
  (select balance from public.v_account_balances where account_id = (select id from acc2)),
  60000.0000::numeric, 'saldo Bank naik oleh transfer masuk');
select lives_ok(
  format($q$select pg_temp.exec_as(%L, format($i$select public.fn_create_transfer(%%L, %%L, %%L, 10000, '2026-11-10 10:00+07', 'tarik', null, 500, %%L)$i$, %L, %L, %L, %L))$q$,
    'a1000000-0000-0000-0000-000000000001', (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'),
    (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select id from acc2),
    'a1000000-0000-0000-0000-0000000000aa'),
  'fn_create_transfer idempoten untuk group id yang sama');
select is((select count(*) from public.transactions where transfer_group_id = 'a1000000-0000-0000-0000-0000000000aa'), 3::bigint, 'pemanggilan ulang tidak membuat baris ganda');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000001', format($q$select public.fn_create_transfer(%L, %L, %L, 100)$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '23514', 'transfer ke akun yang sama ditolak');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000001', format($q$update public.transactions set amount = 1 where transfer_group_id = %L$q$, 'a1000000-0000-0000-0000-0000000000aa')),
  '42501', 'sisi transfer tidak dapat diubah langsung');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000001', format($q$insert into public.transactions (workspace_id, account_id, type, amount, currency, source, transfer_group_id, transfer_direction) values (%L, %L, 'transfer', 5, 'IDR', 'personal', gen_random_uuid(), 'out')$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '42501', 'baris transfer tidak dapat dibuat langsung dari client');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000001', format($q$update public.transactions set deleted_at = now() where transfer_group_id = %L and type = 'transfer'$q$, 'a1000000-0000-0000-0000-0000000000aa')),
  '42501', 'sisi transfer tidak dapat dihapus lunak langsung');

-- Hapus dan pulihkan transfer sebagai satu kelompok.
select lives_ok(
  format($q$select pg_temp.exec_as(%L, format($i$select public.fn_delete_transaction(%%L)$i$, (select id from public.transactions where transfer_group_id = %L and transfer_direction = 'in')))$q$,
    'a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-0000000000aa'),
  'fn_delete_transaction pada sisi transfer');
select is((select count(*) from public.transactions where transfer_group_id = 'a1000000-0000-0000-0000-0000000000aa' and deleted_at is not null), 3::bigint, 'hapus transfer menghapus kedua sisi dan biaya');
select is(
  (select balance from public.v_account_balances where account_id = (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  68000.0000::numeric, 'saldo Cash kembali setelah transfer dihapus');
select lives_ok(
  format($q$select pg_temp.exec_as(%L, format($i$select public.fn_restore_transaction(%%L)$i$, (select id from public.transactions where transfer_group_id = %L and transfer_direction = 'out')))$q$,
    'a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-0000000000aa'),
  'fn_restore_transaction memulihkan transfer');
select is((select count(*) from public.transactions where transfer_group_id = 'a1000000-0000-0000-0000-0000000000aa' and deleted_at is null), 3::bigint, 'pemulihan memulihkan seluruh kelompok');

-- ---------------------------------------------------------------------------
-- Ringkasan bulanan (siklus mulai tanggal 25)
-- ---------------------------------------------------------------------------
update public.profiles set month_start_day = 25 where id = 'a1000000-0000-0000-0000-000000000001';
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000001', format($q$select income::text from public.v_monthly_summary where workspace_id = %L and month_start = '2026-10-25' and is_total$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '100000.0000', 'siklus 25 Okt: pemasukan 100.000');
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000001', format($q$select expense::text from public.v_monthly_summary where workspace_id = %L and month_start = '2026-10-25' and is_total$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '25500.0000', 'siklus 25 Okt: pengeluaran 25.000 + biaya admin 500, transfer tidak dihitung');
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000001', format($q$select expense::text from public.v_monthly_summary where workspace_id = %L and month_start = '2026-11-25' and is_total$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '7000.0000', 'siklus 25 Nov dimulai pada tanggal 25');
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000001', format($q$select income::text from public.v_monthly_summary where workspace_id = %L and month_start = '2026-10-25' and source = 'intern'$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '100000.0000', 'ringkasan per sumber intern');
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000001', format($q$select net::text from public.v_monthly_summary where workspace_id = %L and month_start = '2026-10-25' and is_total$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'))),
  '74500.0000', 'selisih = pemasukan - pengeluaran');

-- ---------------------------------------------------------------------------
-- fn_confirm_draft
-- ---------------------------------------------------------------------------
create temp table drafts as
with ins as (
  insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, source, origin)
  select wid, cash, null, 'expense', 'draft', 11000, 'IDR', null, 'notification' from ws where uid = 'a1000000-0000-0000-0000-000000000002'
  returning id, 'expense'::text as k
), ins2 as (
  insert into public.transactions (workspace_id, account_id, category_id, type, status, amount, currency, source, origin)
  select wid, cash, null, 'income', 'draft', 22000, 'IDR', null, 'notification' from ws where uid = 'a1000000-0000-0000-0000-000000000002'
  returning id, 'income'::text as k
)
select * from ins union all select * from ins2;

select is((select count(*) from public.transactions where status = 'draft' and draft_state = 'baru' and origin = 'notification'), 2::bigint, 'draft baru bernilai draft_state baru');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000002', format($q$select public.fn_confirm_draft(%L)$q$, (select id from drafts where k = 'expense'))),
  '23514', 'konfirmasi draft tanpa kategori ditolak');
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000002', format($q$select (public.fn_confirm_draft(%L, %L)).status::text$q$, (select id from drafts where k = 'expense'), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000002'))),
  'confirmed', 'draft pengeluaran dikonfirmasi dengan kategori');
select is((select source::text || '/' || coalesce(draft_state::text, 'null') from public.transactions where id = (select id from drafts where k = 'expense')), 'personal/null', 'sumber pengeluaran default personal, draft_state kosong');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000002', format($q$select public.fn_confirm_draft(%L, %L)$q$, (select id from drafts where k = 'income'), (select c_gaji from ws where uid = 'a1000000-0000-0000-0000-000000000002'))),
  '23514', 'draft pemasukan tanpa sumber ditolak');
select is(
  pg_temp.scalar_as('a1000000-0000-0000-0000-000000000002', format($q$select (public.fn_confirm_draft(%L, %L, null, 'freelance'))."source"::text$q$, (select id from drafts where k = 'income'), (select c_gaji from ws where uid = 'a1000000-0000-0000-0000-000000000002'))),
  'freelance', 'draft pemasukan dikonfirmasi dengan sumber');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000002', format($q$select public.fn_confirm_draft(%L)$q$, (select id from drafts where k = 'income'))),
  '22023', 'draft yang sudah dikonfirmasi tidak dapat dikonfirmasi lagi');
select is(
  (select balance from public.v_account_balances where account_id = (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000002')),
  11000.0000::numeric, 'saldo menghitung draft hanya setelah konfirmasi (22000 - 11000)');

-- ---------------------------------------------------------------------------
-- Multi mata uang: amount_base dihitung database
-- ---------------------------------------------------------------------------
create temp table usd as
with ins as (
  insert into public.accounts (workspace_id, name, type, currency, created_by)
  select wid, 'Dolar', 'bank', 'USD', uid from ws where uid = 'a1000000-0000-0000-0000-000000000002'
  returning id, workspace_id
)
select id, workspace_id from ins;

select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source, occurred_at) values (%L, %L, %L, 'expense', 10, 'USD', 'personal', '2026-10-20 10:00+00')$q$,
    (select workspace_id from usd), (select id from usd), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000002')),
  '23514', null, 'transaksi mata uang asing tanpa kurs ditolak');
insert into public.exchange_rates (date, from_currency, to_currency, rate, source) values ('2026-10-19', 'USD', 'IDR', 16000, 'uji');
insert into public.transactions (id, workspace_id, account_id, category_id, type, amount, currency, source, occurred_at, amount_base)
select 'a1000000-0000-0000-0000-0000000000b1', workspace_id, (select id from usd), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000002'), 'expense', 10, 'USD', 'personal', '2026-10-20 10:00+00', 1
from usd;
select is((select amount_base from public.transactions where id = 'a1000000-0000-0000-0000-0000000000b1'), 160000.0000::numeric, 'amount_base dihitung dari kurs; nilai client diabaikan');
select is((select fx_rate from public.transactions where id = 'a1000000-0000-0000-0000-0000000000b1'), 16000.00000000::numeric, 'kurs terakhir sebelum tanggal transaksi dipakai');
insert into public.transactions (id, workspace_id, account_id, category_id, type, amount, currency, fx_rate, source, occurred_at)
select 'a1000000-0000-0000-0000-0000000000b2', workspace_id, (select id from usd), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000002'), 'expense', 10, 'USD', 15000, 'personal', '2026-10-20 10:00+00'
from usd;
select is((select amount_base from public.transactions where id = 'a1000000-0000-0000-0000-0000000000b2'), 150000.0000::numeric, 'kurs manual per transaksi dihormati');
select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values (%L, %L, %L, 'expense', 10, 'IDR', 'personal')$q$,
    (select workspace_id from usd), (select id from usd), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000002')),
  '23514', null, 'mata uang transaksi harus sama dengan akun');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000002', format($q$update public.transactions set amount_base = 1 where id = 'a1000000-0000-0000-0000-0000000000b2'$q$)) || ':' ||
  (select amount_base::text from public.transactions where id = 'a1000000-0000-0000-0000-0000000000b2'),
  'ok:150000.0000', 'amount_base tidak dapat diubah client');

-- Transfer beda mata uang butuh nominal masuk.
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000002', format($q$select public.fn_create_transfer(%L, %L, %L, 100)$q$,
    (select workspace_id from usd), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000002'), (select id from usd))),
  '23514', 'transfer beda mata uang tanpa nominal masuk ditolak');
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000002', format($q$select public.fn_create_transfer(%L, %L, %L, 160000, now(), null, 10)$q$,
    (select workspace_id from usd), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000002'), (select id from usd))),
  'ok', 'transfer beda mata uang dengan nominal masuk sendiri diterima');

-- ---------------------------------------------------------------------------
-- Constraint
-- ---------------------------------------------------------------------------
select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values (%L, %L, %L, 'expense', 0, 'IDR', 'personal')$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'nominal harus lebih dari 0');
select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source, occurred_at) values (%L, %L, %L, 'expense', 1, 'IDR', 'personal', now() + interval '400 days')$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'tanggal lebih dari 1 tahun ke depan ditolak');
select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source, external_id_hash) values (%L, %L, %L, 'expense', 1, 'IDR', 'personal', 'nomor-referensi-asli')$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'external_id_hash hanya menerima hash SHA-256');
select lives_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source, external_id_hash) values (%L, %L, %L, 'expense', 1, 'IDR', 'personal', %L)$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001'), repeat('a', 64)),
  'hash referensi valid diterima');
select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source, external_id_hash) values (%L, %L, %L, 'expense', 1, 'IDR', 'personal', %L)$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001'), repeat('a', 64)),
  '23505', null, 'external_id_hash unik per workspace');
select throws_ok(
  format($q$insert into public.transactions (workspace_id, account_id, type, amount, currency, source) values (%L, %L, 'expense', 1, 'IDR', 'personal')$q$,
    (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'), (select cash from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'transaksi terkonfirmasi wajib berkategori');
select throws_ok(
  format($q$insert into public.accounts (workspace_id, name, type, currency) values (%L, 'cash', 'cash', 'IDR')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23505', null, 'nama akun unik per workspace tanpa membedakan huruf besar');
select throws_ok(
  format($q$insert into public.accounts (workspace_id, name, type, currency) values (%L, 'Rupiah', 'cash', 'rp')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'kode mata uang harus 3 huruf kapital');

-- Split harus sama dengan total.
select throws_ok(
  format($q$insert into public.transaction_items (transaction_id, name, qty, unit_price, category_id) values (%L, 'a', 1, 10, %L); set constraints all immediate$q$,
    (select id from public.transactions where amount = 25000 and workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
    (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'jumlah split harus sama dengan total transaksi');

-- Subkategori.
create temp table sub as
with p as (select c_makan as id, wid from ws where uid = 'a1000000-0000-0000-0000-000000000001'),
ins as (
  insert into public.categories (workspace_id, name, type, parent_id)
  select wid, 'Makan Siang', 'expense', id from p
  returning id, workspace_id
)
select id, workspace_id from ins;
select throws_ok(
  format($q$insert into public.categories (workspace_id, name, type, parent_id) values (%L, 'Level Tiga', 'expense', %L)$q$, (select workspace_id from sub), (select id from sub)),
  '23514', null, 'subkategori maksimal 2 level');
select throws_ok(
  format($q$insert into public.categories (workspace_id, name, type, parent_id) values (%L, 'Beda Jenis', 'income', %L)$q$, (select workspace_id from sub), (select c_makan from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'jenis subkategori harus sama dengan induk');

-- Proyek/kegiatan: field khusus jenis lain tidak dapat terisi.
select throws_ok(
  format($q$insert into public.projects (workspace_id, kind, name, contract_value, currency) values (%L, 'kuliah', 'Algoritma', 1000, 'IDR')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'kuliah tidak boleh memiliki field freelance');
select throws_ok(
  format($q$insert into public.projects (workspace_id, kind, name, semester) values (%L, 'freelance', 'Situs', 3)$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'freelance tidak boleh memiliki field kuliah');
select throws_ok(
  format($q$insert into public.projects (workspace_id, kind, name, stipend_amount, stipend_day) values (%L, 'pribadi', 'Rutin', 1000000, 1)$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'selain magang tidak boleh memiliki field uang saku');
select lives_ok(
  format($q$insert into public.projects (workspace_id, kind, name, client_name, contract_value, currency, platform_fee_percent, fee_mode) values (%L, 'freelance', 'Situs', 'Klien', 5000000, 'IDR', 10, 'profit_deduction')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  'proyek freelance lengkap diterima');
select lives_ok(
  format($q$insert into public.projects (workspace_id, kind, name, client_name, stipend_amount, stipend_day) values (%L, 'intern', 'Magang', 'PT Contoh', 2000000, 25)$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  'proyek magang dengan uang saku diterima');
select lives_ok(
  format($q$insert into public.projects (workspace_id, kind, name, semester, course_code, credits) values (%L, 'kuliah', 'Basis Data', 5, 'IF301', 3)$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  'mata kuliah dengan field kuliah diterima');

-- Tugas dan event.
insert into public.tasks (id, workspace_id, kind, title, status)
select 'a1000000-0000-0000-0000-0000000000c1', wid, 'kuliah', 'Laporan', 'done' from ws where uid = 'a1000000-0000-0000-0000-000000000001';
select ok((select completed_at is not null from public.tasks where id = 'a1000000-0000-0000-0000-0000000000c1'), 'tugas selesai mengisi completed_at');
update public.tasks set status = 'todo' where id = 'a1000000-0000-0000-0000-0000000000c1';
select ok((select completed_at is null from public.tasks where id = 'a1000000-0000-0000-0000-0000000000c1'), 'tugas dibuka kembali mengosongkan completed_at');
select throws_ok(
  format($q$insert into public.tasks (workspace_id, kind, title, due_is_date_only) values (%L, 'pribadi', 'x', true)$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'tenggat hanya tanggal membutuhkan tenggat');
select throws_ok(
  format($q$insert into public.events (workspace_id, kind, title, starts_at, ends_at) values (%L, 'kuliah', 'x', now() + interval '2 hours', now())$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'event berakhir sebelum mulai ditolak');
select throws_ok(
  format($q$insert into public.events (workspace_id, kind, title, starts_at, ends_at, recurrence) values (%L, 'kuliah', 'x', now(), now(), '{"freq":"yearly"}')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'bentuk recurrence divalidasi');
select throws_ok(
  format($q$insert into public.events (workspace_id, kind, title, starts_at, ends_at, reminder_minutes) values (%L, 'kuliah', 'x', now(), now(), '{-5}')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '23514', null, 'pengingat tidak boleh negatif');
select throws_ok(
  format($q$insert into public.events (workspace_id, kind, title, starts_at, ends_at, timezone) values (%L, 'kuliah', 'x', now(), now(), 'Mars/Olympus')$q$, (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  '22023', null, 'zona waktu tidak dikenal ditolak');
insert into public.events (id, workspace_id, kind, title, location, starts_at, ends_at, recurrence)
select 'a1000000-0000-0000-0000-0000000000d1', wid, 'kuliah', 'Basis Data', 'Gedung Rahasia 42', '2026-11-02 08:00+07', '2026-11-02 10:00+07',
  '{"freq":"weekly","interval":1,"byweekday":[1]}'::jsonb
from ws where uid = 'a1000000-0000-0000-0000-000000000001';
select throws_ok(
  $q$insert into public.event_exceptions (event_id, original_date, action, override_title) values ('a1000000-0000-0000-0000-0000000000d1', '2026-11-09', 'skip', 'x')$q$,
  '23514', null, 'pengecualian skip tidak boleh membawa field override');

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------
select ok(exists (select 1 from public.audit_log where table_name = 'events' and row_id = 'a1000000-0000-0000-0000-0000000000d1' and action = 'insert'), 'insert event tercatat di audit_log');
select ok(not exists (select 1 from public.audit_log where diff::text like '%Gedung Rahasia%'), 'lokasi event tidak masuk audit_log');
insert into public.workspace_invites (workspace_id, email, role, token_hash, expires_at)
select 'b0000000-0000-0000-0000-000000000009', 'x@example.test', 'viewer', repeat('c', 64), now() + interval '1 day' where false;
select ok(not exists (select 1 from public.audit_log where diff::text like '%token_hash%'), 'token_hash tidak pernah masuk audit_log');
select throws_ok($q$update public.audit_log set action = 'delete'$q$, '42501', null, 'audit_log tidak dapat diubah');
select throws_ok($q$delete from public.audit_log$q$, '42501', null, 'audit_log tidak dapat dihapus');
select lives_ok(
  format($q$select pg_temp.exec_as(%L, format($i$select public.fn_log_sync_conflict(%%L, 'transactions', gen_random_uuid(), '{"amount": 1}'::jsonb)$i$, %L))$q$,
    'a1000000-0000-0000-0000-000000000001', (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')),
  'fn_log_sync_conflict mencatat versi yang kalah');
select ok(exists (select 1 from public.audit_log where action = 'conflict'), 'konflik sinkronisasi tercatat');

-- Retensi.
insert into public.audit_log (workspace_id, table_name, action, at)
select wid, 'transactions', 'insert', now() - interval '13 months' from ws where uid = 'a1000000-0000-0000-0000-000000000001';
update public.transactions set deleted_at = now() - interval '31 days'
where workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001') and amount = 9000;
select public.fn_purge_expired();
select is((select count(*) from public.audit_log where at < now() - interval '12 months'), 0::bigint, 'audit log lebih dari 12 bulan dihapus job retensi');
select is((select count(*) from public.transactions where amount = 9000 and workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')), 0::bigint, 'transaksi terhapus lebih dari 30 hari dibersihkan');
select ok(exists (select 1 from public.audit_log where action = 'insert'), 'audit log baru tetap ada setelah retensi');

-- Pemulihan setelah lewat 30 hari ditolak.
update public.transactions set deleted_at = now() - interval '40 days'
where workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001') and amount = 7000;
select is(
  pg_temp.err_as('a1000000-0000-0000-0000-000000000001', format($q$select public.fn_restore_transaction(%L)$q$,
    (select id from public.transactions where amount = 7000 and workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000001')))),
  '22023', 'pemulihan setelah 30 hari ditolak');

-- ---------------------------------------------------------------------------
-- Sesi
-- ---------------------------------------------------------------------------
select is(pg_temp.scalar_as('a1000000-0000-0000-0000-000000000001', 'select count(*)::text from public.fn_my_sessions()'), '0', 'fn_my_sessions hanya mengembalikan sesi milik pemanggil');

-- ---------------------------------------------------------------------------
-- Hapus akun: seluruh data pribadi ikut terhapus (termasuk audit log)
-- ---------------------------------------------------------------------------
insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source)
select wid, cash, c_makan, 'expense', 1234, 'IDR', 'personal' from ws where uid = 'a1000000-0000-0000-0000-000000000003';
select lives_ok($q$delete from auth.users where id = 'a1000000-0000-0000-0000-000000000003'$q$, 'akun dapat dihapus meski punya data dan audit log');
select is((select count(*) from public.workspaces where owner_id = 'a1000000-0000-0000-0000-000000000003'), 0::bigint, 'workspace terhapus bersama akun');
select is((select count(*) from public.transactions where amount = 1234), 0::bigint, 'transaksi terhapus bersama akun');
select is((select count(*) from public.audit_log where workspace_id = (select wid from ws where uid = 'a1000000-0000-0000-0000-000000000003')), 0::bigint, 'audit log terhapus bersama akun');
select is((select count(*) from public.profiles where id = 'a1000000-0000-0000-0000-000000000003'), 0::bigint, 'profil terhapus bersama akun');

-- Storage helper.
select is(public.fn_storage_workspace('bukan-uuid/x.png'), null::uuid, 'path Storage tanpa uuid menghasilkan null');
select is(public.fn_storage_workspace('b0000000-0000-0000-0000-000000000001/x.png'), 'b0000000-0000-0000-0000-000000000001'::uuid, 'path Storage menghasilkan workspace_id');

select * from finish();
rollback;
