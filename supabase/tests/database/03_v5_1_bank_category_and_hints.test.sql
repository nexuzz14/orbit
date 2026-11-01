-- Uji skema dan fungsi migrasi v5.1 (bank_category, match_hints, category_rules, immutable cascade).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- 1. Uji kolom accounts.match_hints
select has_column('public', 'accounts', 'match_hints', 'kolom accounts.match_hints ada');
select col_type_is('public', 'accounts', 'match_hints', 'text[]', 'tipe accounts.match_hints adalah text[]');

-- 2. Uji kolom transactions.bank_category
select has_column('public', 'transactions', 'bank_category', 'kolom transactions.bank_category ada');
select col_type_is('public', 'transactions', 'bank_category', 'text', 'tipe transactions.bank_category adalah text');

-- 3. Uji constraint category_rules match_field 'bank_category'
insert into auth.users (id, email) values ('a2000000-0000-0000-0000-000000000001', 'u51@example.test');
select lives_ok(
  $q$insert into public.category_rules (workspace_id, match_field, pattern, category_id)
     select w.id, 'bank_category', 'gaji', (select c.id from public.categories c where c.workspace_id = w.id limit 1)
     from public.workspaces w where w.owner_id = 'a2000000-0000-0000-0000-000000000001'$q$,
  'category_rules menerima match_field bank_category'
);

-- 4. Uji accounts.match_hints dapat diisi label produk rekening
select lives_ok(
  $q$update public.accounts
     set match_hints = array['TAHAPAN XPRESI', 'Tahapan BCA']
     where workspace_id = (select id from public.workspaces where owner_id = 'a2000000-0000-0000-0000-000000000001')$q$,
  'accounts.match_hints dapat diperbarui dengan array label produk'
);

-- 5. Uji fn_protect_immutable tetap menolak update langsung created_by
select throws_ok(
  $q$update public.accounts
     set created_by = gen_random_uuid()
     where workspace_id = (select id from public.workspaces where owner_id = 'a2000000-0000-0000-0000-000000000001')$q$,
  '42501',
  null,
  'update created_by secara langsung tetap ditolak'
);

select * from finish();
rollback;
