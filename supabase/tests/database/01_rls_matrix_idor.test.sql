-- Uji RLS: matriks peran x tabel x operasi, uji IDOR dan eskalasi peran, serta uji struktur keamanan.
-- Peran: owner, editor, viewer (anggota workspace berbagi S), outsider (bukan anggota), anon.
-- Hasil klasifikasi: allow = berhasil mengenai baris; deny = 0 baris atau ditolak (42501).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Menjalankan satu pernyataan sebagai pengguna tertentu. Selalu di-rollback sehingga kasus saling terisolasi.
create function pg_temp.run_as(p_who text, p_sql text) returns text
language plpgsql as $f$
declare
  v_result text;
  v_n bigint;
begin
  begin
    if p_who = 'anon' then
      perform set_config('request.jwt.claims', '{"role":"anon"}', true);
      set local role anon;
    else
      perform set_config('request.jwt.claims', json_build_object('sub', p_who, 'role', 'authenticated')::text, true);
      set local role authenticated;
    end if;
    execute p_sql;
    get diagnostics v_n = row_count;
    v_result := 'ok:' || v_n;
    raise exception 'rollback' using errcode = 'XXRBK';
  exception
    when sqlstate 'XXRBK' then
      null;
    when others then
      v_result := 'err:' || sqlstate;
  end;
  return v_result;
end;
$f$;

create function pg_temp.classify(p text) returns text language sql immutable as $f$
  select case when p ~ '^ok:[1-9]' then 'allow' when p in ('ok:0', 'err:42501', 'err:23503') then 'deny' else p end
$f$;

-- Pengguna uji.
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'owner@example.test'),
  ('a0000000-0000-0000-0000-000000000002', 'editor@example.test'),
  ('a0000000-0000-0000-0000-000000000003', 'viewer@example.test'),
  ('a0000000-0000-0000-0000-000000000004', 'outsider@example.test');

-- Workspace berbagi S dengan tiga peran.
insert into public.workspaces (id, name, type, owner_id)
values ('b0000000-0000-0000-0000-000000000001', 'Workspace S', 'shared', 'a0000000-0000-0000-0000-000000000001');
insert into public.workspace_members (workspace_id, user_id, role) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'owner'),
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'editor'),
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'viewer');

-- Data uji di workspace S.
insert into public.accounts (id, workspace_id, name, type, currency, visibility, created_by) values
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Bank S', 'bank', 'IDR', 'shared', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'Kosong', 'cash', 'IDR', 'shared', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Privat Editor', 'bank', 'IDR', 'private', 'a0000000-0000-0000-0000-000000000002');
insert into public.categories (id, workspace_id, name, type) values
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Kategori S', 'expense'),
  ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'Kategori Kosong', 'expense');
insert into public.category_rules (id, workspace_id, match_field, pattern, category_id) values
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'merchant', 'abc', 'd0000000-0000-0000-0000-000000000001');
insert into public.projects (id, workspace_id, kind, name) values
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'pribadi', 'Proyek S'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'pribadi', 'Proyek Kosong');
insert into public.transactions (id, workspace_id, account_id, category_id, type, status, amount, currency, source) values
  ('10000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'expense', 'confirmed', 1000, 'IDR', 'personal'),
  ('10000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', null, 'expense', 'draft', 500, 'IDR', null),
  ('10000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'expense', 'confirmed', 700, 'IDR', 'personal');
insert into public.transaction_items (id, transaction_id, name, unit_price) values
  ('11000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'item', 100);
insert into public.attachments (id, workspace_id, owner_table, owner_id, storage_path, mime, size) values
  ('12000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'transactions', '10000000-0000-0000-0000-000000000001',
   'b0000000-0000-0000-0000-000000000001/a.png', 'image/png', 10);
insert into public.workspace_invites (id, workspace_id, email, role, token_hash, expires_at) values
  ('13000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'tamu@example.test', 'viewer', repeat('a', 64), now() + interval '7 days');
insert into public.tasks (id, workspace_id, kind, title) values
  ('14000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'pribadi', 'Tugas S'),
  ('14000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'pribadi', 'Tugas Kosong');
insert into public.task_checklist_items (id, task_id, text) values
  ('15000000-0000-0000-0000-000000000001', '14000000-0000-0000-0000-000000000001', 'langkah');
insert into public.events (id, workspace_id, kind, title, starts_at, ends_at) values
  ('16000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'kuliah', 'Kelas S', now(), now() + interval '1 hour'),
  ('16000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'kuliah', 'Kelas Kosong', now(), now() + interval '1 hour');
insert into public.event_exceptions (id, event_id, original_date, action) values
  ('17000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000001', '2026-11-02', 'skip');
insert into public.exchange_rates (date, from_currency, to_currency, rate, source) values ('2026-11-01', 'USD', 'IDR', 16000, 'uji');
insert into public.security_events (id, user_id, type) values
  ('18000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'login');
insert into storage.objects (bucket_id, name, owner_id)
values ('attachments', 'b0000000-0000-0000-0000-000000000001/a.png', null);

create temp table tok (k text primary key, v text);
insert into tok values
  ('{S}', 'b0000000-0000-0000-0000-000000000001'),
  ('{O}', 'a0000000-0000-0000-0000-000000000001'), ('{E}', 'a0000000-0000-0000-0000-000000000002'),
  ('{V}', 'a0000000-0000-0000-0000-000000000003'), ('{X}', 'a0000000-0000-0000-0000-000000000004'),
  ('{A}', 'c0000000-0000-0000-0000-000000000001'), ('{ADEL}', 'c0000000-0000-0000-0000-000000000002'),
  ('{APRIV}', 'c0000000-0000-0000-0000-000000000003'),
  ('{C}', 'd0000000-0000-0000-0000-000000000001'), ('{CDEL}', 'd0000000-0000-0000-0000-000000000002'),
  ('{R}', 'e0000000-0000-0000-0000-000000000001'),
  ('{P}', 'f0000000-0000-0000-0000-000000000001'), ('{PDEL}', 'f0000000-0000-0000-0000-000000000002'),
  ('{T}', '10000000-0000-0000-0000-000000000001'), ('{TDRAFT}', '10000000-0000-0000-0000-000000000002'),
  ('{TPRIV}', '10000000-0000-0000-0000-000000000003'),
  ('{I}', '11000000-0000-0000-0000-000000000001'), ('{AT}', '12000000-0000-0000-0000-000000000001'),
  ('{INV}', '13000000-0000-0000-0000-000000000001'),
  ('{K}', '14000000-0000-0000-0000-000000000001'), ('{KDEL}', '14000000-0000-0000-0000-000000000002'),
  ('{CI}', '15000000-0000-0000-0000-000000000001'),
  ('{EV}', '16000000-0000-0000-0000-000000000001'), ('{EVDEL}', '16000000-0000-0000-0000-000000000002'),
  ('{EX}', '17000000-0000-0000-0000-000000000001');

create function pg_temp.expand(p_sql text) returns text language plpgsql as $f$
declare
  r record;
  v_sql text := p_sql;
begin
  for r in select t.k, t.v as val from pg_temp.tok t loop
    v_sql := replace(v_sql, r.k, r.val);
  end loop;
  return v_sql;
end;
$f$;

-- Definisi operasi. Urutan ekspektasi: owner, editor, viewer, outsider, anon.
create temp table ops (tbl text, op text, sql text, owner text, editor text, viewer text, outsider text, anon text);
insert into ops values
  ('profiles', 'select', $q$select 1 from public.profiles where id = '{O}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('profiles', 'insert', $q$insert into public.profiles (id) values (gen_random_uuid())$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('profiles', 'update', $q$update public.profiles set display_name = 'x' where id = '{O}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('profiles', 'delete', $q$delete from public.profiles where id = '{O}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),

  ('workspaces', 'select', $q$select 1 from public.workspaces where id = '{S}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('workspaces', 'insert', $q$insert into public.workspaces (name, owner_id, type) values ('x', '{O}', 'shared')$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('workspaces', 'update', $q$update public.workspaces set name = 'Baru' where id = '{S}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('workspaces', 'delete', $q$delete from public.workspaces where id = '{S}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),

  ('workspace_members', 'select', $q$select 1 from public.workspace_members where workspace_id = '{S}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('workspace_members', 'insert', $q$insert into public.workspace_members (workspace_id, user_id, role) values ('{S}', '{X}', 'viewer')$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('workspace_members', 'update', $q$update public.workspace_members set role = 'editor' where workspace_id = '{S}' and user_id = '{V}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('workspace_members', 'delete', $q$delete from public.workspace_members where workspace_id = '{S}' and user_id = '{V}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('workspace_invites', 'select', $q$select 1 from public.workspace_invites where workspace_id = '{S}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('workspace_invites', 'insert', $q$insert into public.workspace_invites (workspace_id, email, role, token_hash, expires_at) values ('{S}', 'x@example.test', 'viewer', repeat('b', 64), now() + interval '7 days')$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('workspace_invites', 'update', $q$update public.workspace_invites set revoked_at = now() where id = '{INV}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('workspace_invites', 'delete', $q$delete from public.workspace_invites where id = '{INV}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('accounts', 'select', $q$select 1 from public.accounts where id = '{A}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('accounts', 'insert', $q$insert into public.accounts (workspace_id, name, type, currency) values ('{S}', 'Baru', 'bank', 'IDR')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('accounts', 'update', $q$update public.accounts set name = 'Ubah' where id = '{A}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('accounts', 'delete', $q$delete from public.accounts where id = '{ADEL}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('categories', 'select', $q$select 1 from public.categories where id = '{C}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('categories', 'insert', $q$insert into public.categories (workspace_id, name, type) values ('{S}', 'Baru', 'expense')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('categories', 'update', $q$update public.categories set name = 'Ubah' where id = '{C}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('categories', 'delete', $q$delete from public.categories where id = '{CDEL}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('category_rules', 'select', $q$select 1 from public.category_rules where id = '{R}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('category_rules', 'insert', $q$insert into public.category_rules (workspace_id, match_field, pattern, category_id) values ('{S}', 'merchant', 'abc', '{C}')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('category_rules', 'update', $q$update public.category_rules set priority = 1 where id = '{R}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('category_rules', 'delete', $q$delete from public.category_rules where id = '{R}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),

  ('transactions', 'select', $q$select 1 from public.transactions where id = '{T}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('transactions', 'insert', $q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values ('{S}', '{A}', '{C}', 'expense', 1000, 'IDR', 'personal')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('transactions', 'update', $q$update public.transactions set note = 'x' where id = '{T}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('transactions', 'delete', $q$delete from public.transactions where id = '{T}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),

  ('transaction_items', 'select', $q$select 1 from public.transaction_items where id = '{I}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('transaction_items', 'insert', $q$insert into public.transaction_items (transaction_id, name, unit_price) values ('{T}', 'x', 100)$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('transaction_items', 'update', $q$update public.transaction_items set name = 'y' where id = '{I}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('transaction_items', 'delete', $q$delete from public.transaction_items where id = '{I}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),

  ('attachments', 'select', $q$select 1 from public.attachments where id = '{AT}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('attachments', 'insert', $q$insert into public.attachments (workspace_id, owner_table, owner_id, storage_path, mime, size) values ('{S}', 'transactions', '{T}', '{S}/b.png', 'image/png', 10)$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('attachments', 'update', $q$update public.attachments set size = 11 where id = '{AT}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('attachments', 'delete', $q$delete from public.attachments where id = '{AT}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),

  ('exchange_rates', 'select', $q$select 1 from public.exchange_rates$q$, 'allow', 'allow', 'allow', 'allow', 'deny'),
  ('exchange_rates', 'insert', $q$insert into public.exchange_rates (date, from_currency, to_currency, rate) values ('2026-11-02', 'USD', 'IDR', 1)$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('exchange_rates', 'update', $q$update public.exchange_rates set rate = 1$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('exchange_rates', 'delete', $q$delete from public.exchange_rates$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),

  ('audit_log', 'select', $q$select 1 from public.audit_log where workspace_id = '{S}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('audit_log', 'insert', $q$insert into public.audit_log (workspace_id, table_name, action) values ('{S}', 'x', 'insert')$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('audit_log', 'update', $q$update public.audit_log set table_name = 'y' where workspace_id = '{S}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('audit_log', 'delete', $q$delete from public.audit_log where workspace_id = '{S}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),

  ('security_events', 'select', $q$select 1 from public.security_events where user_id = '{O}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('security_events', 'insert', $q$insert into public.security_events (user_id, type) values ('{O}', 'login')$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),
  ('security_events', 'update', $q$update public.security_events set type = 'logout_all' where user_id = '{O}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),
  ('security_events', 'delete', $q$delete from public.security_events where user_id = '{O}'$q$, 'deny', 'deny', 'deny', 'deny', 'deny'),

  ('projects', 'select', $q$select 1 from public.projects where id = '{P}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('projects', 'insert', $q$insert into public.projects (workspace_id, kind, name) values ('{S}', 'pribadi', 'Baru')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('projects', 'update', $q$update public.projects set name = 'Ubah' where id = '{P}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('projects', 'delete', $q$delete from public.projects where id = '{PDEL}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('tasks', 'select', $q$select 1 from public.tasks where id = '{K}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('tasks', 'insert', $q$insert into public.tasks (workspace_id, kind, title) values ('{S}', 'pribadi', 'Baru')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('tasks', 'update', $q$update public.tasks set title = 'Ubah' where id = '{K}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('tasks', 'delete', $q$delete from public.tasks where id = '{KDEL}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('task_checklist_items', 'select', $q$select 1 from public.task_checklist_items where id = '{CI}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('task_checklist_items', 'insert', $q$insert into public.task_checklist_items (task_id, text) values ('{K}', 'x')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('task_checklist_items', 'update', $q$update public.task_checklist_items set done = true where id = '{CI}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('task_checklist_items', 'delete', $q$delete from public.task_checklist_items where id = '{CI}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),

  ('events', 'select', $q$select 1 from public.events where id = '{EV}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('events', 'insert', $q$insert into public.events (workspace_id, kind, title, starts_at, ends_at) values ('{S}', 'kuliah', 'Baru', now(), now() + interval '1 hour')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('events', 'update', $q$update public.events set title = 'Ubah' where id = '{EV}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('events', 'delete', $q$delete from public.events where id = '{EVDEL}'$q$, 'allow', 'deny', 'deny', 'deny', 'deny'),

  ('event_exceptions', 'select', $q$select 1 from public.event_exceptions where id = '{EX}'$q$, 'allow', 'allow', 'allow', 'deny', 'deny'),
  ('event_exceptions', 'insert', $q$insert into public.event_exceptions (event_id, original_date, action) values ('{EV}', '2026-11-09', 'skip')$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('event_exceptions', 'update', $q$update public.event_exceptions set original_date = '2026-11-03' where id = '{EX}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny'),
  ('event_exceptions', 'delete', $q$delete from public.event_exceptions where id = '{EX}'$q$, 'allow', 'allow', 'deny', 'deny', 'deny');

create temp table cases as
select o.tbl, o.op, r.role, o.sql, r.expected,
  case r.role
    when 'owner' then 'a0000000-0000-0000-0000-000000000001'
    when 'editor' then 'a0000000-0000-0000-0000-000000000002'
    when 'viewer' then 'a0000000-0000-0000-0000-000000000003'
    when 'outsider' then 'a0000000-0000-0000-0000-000000000004'
    else 'anon'
  end as who
from ops o
cross join lateral (values ('owner', o.owner), ('editor', o.editor), ('viewer', o.viewer), ('outsider', o.outsider), ('anon', o.anon)) as r(role, expected);

-- Matriks peran x tabel x operasi.
select is(
  pg_temp.classify(pg_temp.run_as(c.who, pg_temp.expand(c.sql))),
  c.expected,
  c.tbl || ' ' || c.op || ' sebagai ' || c.role
)
from cases c
order by c.tbl, c.op, c.role;

-- Akun privat: hanya pembuatnya yang melihat akun dan transaksinya.
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000002', pg_temp.expand($q$select 1 from public.accounts where id = '{APRIV}'$q$))), 'allow', 'akun privat terlihat oleh pembuatnya');
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', pg_temp.expand($q$select 1 from public.accounts where id = '{APRIV}'$q$))), 'deny', 'akun privat tidak terlihat oleh owner lain');
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', pg_temp.expand($q$select 1 from public.transactions where id = '{TPRIV}'$q$))), 'deny', 'transaksi akun privat tidak terlihat oleh owner');
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000002', pg_temp.expand($q$select 1 from public.transactions where id = '{TPRIV}'$q$))), 'allow', 'transaksi akun privat terlihat oleh pembuatnya');
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', pg_temp.expand($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values ('{S}', '{APRIV}', '{C}', 'expense', 1, 'IDR', 'personal')$q$))), 'deny', 'owner tidak dapat menulis ke akun privat orang lain');

-- IDOR: pengguna di luar workspace.
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.transactions where id = '{T}'$q$)), 'ok:0', 'IDOR: outsider tidak membaca transaksi workspace lain berdasarkan id');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$update public.transactions set note = 'diretas' where id = '{T}'$q$)), 'ok:0', 'IDOR: outsider tidak mengubah transaksi workspace lain');
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values ('{S}', '{A}', '{C}', 'expense', 1, 'IDR', 'personal')$q$))), 'deny', 'IDOR: outsider tidak menulis ke workspace lain');

-- IDOR: referensi lintas workspace dari dalam workspace sendiri ditolak foreign key komposit.
create temp table xws as select id as ws from public.workspaces where owner_id = 'a0000000-0000-0000-0000-000000000004' and type = 'personal';
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values (%L, %L, null, 'expense', 1, 'IDR', 'personal')$q$, (select ws from xws), 'c0000000-0000-0000-0000-000000000001')), 'err:23503', 'IDOR: akun dari workspace lain tidak dapat dirujuk');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$insert into public.transactions (workspace_id, account_id, category_id, type, amount, currency, source) values (%L, (select id from public.accounts where workspace_id = %L limit 1), %L, 'expense', 1, 'IDR', 'personal')$q$, (select ws from xws), (select ws from xws), 'd0000000-0000-0000-0000-000000000001')), 'err:23503', 'IDOR: kategori dari workspace lain tidak dapat dirujuk');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$insert into public.transactions (workspace_id, account_id, category_id, project_id, type, amount, currency, source) values (%L, (select id from public.accounts where workspace_id = %L limit 1), (select id from public.categories where workspace_id = %L and type = 'expense' limit 1), %L, 'expense', 1, 'IDR', 'personal')$q$, (select ws from xws), (select ws from xws), (select ws from xws), 'f0000000-0000-0000-0000-000000000001')), 'err:23503', 'IDOR: proyek dari workspace lain tidak dapat dirujuk');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$insert into public.tasks (workspace_id, kind, title, project_id) values (%L, 'pribadi', 'x', %L)$q$, (select ws from xws), 'f0000000-0000-0000-0000-000000000001')), 'err:23503', 'IDOR: tugas tidak dapat merujuk proyek workspace lain');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$insert into public.events (workspace_id, kind, title, starts_at, ends_at, project_id) values (%L, 'pribadi', 'x', now(), now(), %L)$q$, (select ws from xws), 'f0000000-0000-0000-0000-000000000001')), 'err:23503', 'IDOR: event tidak dapat merujuk proyek workspace lain');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$insert into public.attachments (workspace_id, owner_table, owner_id, storage_path, mime, size) values (%L, 'transactions', %L, %L, 'image/png', 10)$q$, (select ws from xws), '10000000-0000-0000-0000-000000000001', (select ws from xws)::text || '/x.png')), 'err:23503', 'IDOR: lampiran tidak dapat menempel pada baris workspace lain');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$insert into public.task_checklist_items (task_id, text) values ('{K}', 'x')$q$)), 'err:42501', 'IDOR: checklist tugas workspace lain ditolak');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$insert into public.event_exceptions (event_id, original_date, action) values ('{EV}', '2026-12-01', 'skip')$q$)), 'err:42501', 'IDOR: pengecualian event workspace lain ditolak');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.task_checklist_items where id = '{CI}'$q$)), 'ok:0', 'IDOR: checklist tidak terbaca lintas workspace');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.event_exceptions where id = '{EX}'$q$)), 'ok:0', 'IDOR: pengecualian event tidak terbaca lintas workspace');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.tasks where id = '{K}'$q$)), 'ok:0', 'IDOR: tugas tidak terbaca lintas workspace');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.events where id = '{EV}'$q$)), 'ok:0', 'IDOR: event tidak terbaca lintas workspace');

-- IDOR: memindahkan baris sendiri ke workspace lain.
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', format($q$update public.accounts set workspace_id = %L where workspace_id = %L$q$, 'b0000000-0000-0000-0000-000000000001', (select ws from xws))), 'err:42501', 'IDOR: workspace_id tidak dapat diubah');

-- Eskalasi peran.
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000003', pg_temp.expand($q$update public.workspace_members set role = 'owner' where workspace_id = '{S}' and user_id = '{V}'$q$)), 'ok:0', 'eskalasi: viewer tidak menaikkan perannya');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000002', pg_temp.expand($q$update public.workspace_members set role = 'owner' where workspace_id = '{S}' and user_id = '{E}'$q$)), 'ok:0', 'eskalasi: editor tidak menaikkan perannya');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', pg_temp.expand($q$update public.workspace_members set role = 'editor' where user_id = '{O}'$q$)), 'err:42501', 'eskalasi: peran owner hanya milik pemilik workspace');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', pg_temp.expand($q$delete from public.workspace_members where user_id = '{O}' and workspace_id = '{S}'$q$)), 'err:42501', 'pemilik workspace tidak dapat dikeluarkan');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', pg_temp.expand($q$insert into public.workspace_members (workspace_id, user_id, role) values ('{S}', '{X}', 'owner')$q$)), 'err:42501', 'eskalasi: owner kedua tidak dapat dibuat');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000002', pg_temp.expand($q$update public.workspaces set owner_id = '{E}' where id = '{S}'$q$)), 'err:42501', 'eskalasi: owner_id tidak dapat diubah (tanpa hak kolom)');

-- created_by diturunkan dari sesi, bukan dari client.
select is(
  pg_temp.run_as('a0000000-0000-0000-0000-000000000002', pg_temp.expand($q$with i as (insert into public.accounts (workspace_id, name, type, currency, created_by) values ('{S}', 'Palsu', 'bank', 'IDR', '{O}') returning created_by) select 1 from i where created_by = '{O}'$q$)),
  'ok:0',
  'created_by dari client diabaikan'
);

-- Fungsi RPC: orang luar ditolak.
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select public.fn_confirm_draft('{TDRAFT}', '{C}')$q$)), 'err:P0002', 'RPC: fn_confirm_draft menolak outsider');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000003', pg_temp.expand($q$select public.fn_confirm_draft('{TDRAFT}', '{C}')$q$)), 'err:P0002', 'RPC: fn_confirm_draft menolak viewer');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select public.fn_create_transfer('{S}', '{A}', '{ADEL}', 10)$q$)), 'err:42501', 'RPC: fn_create_transfer menolak outsider');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000003', pg_temp.expand($q$select public.fn_create_transfer('{S}', '{A}', '{ADEL}', 10)$q$)), 'err:42501', 'RPC: fn_create_transfer menolak viewer');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select public.fn_delete_transaction('{T}')$q$)), 'err:P0002', 'RPC: fn_delete_transaction menolak outsider');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select public.fn_restore_transaction('{T}')$q$)), 'err:P0002', 'RPC: fn_restore_transaction menolak outsider');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select public.fn_log_sync_conflict('{S}', 'transactions', '{T}', '{}'::jsonb)$q$)), 'err:42501', 'RPC: fn_log_sync_conflict menolak outsider');
select is(pg_temp.run_as('anon', pg_temp.expand($q$select public.fn_create_transfer('{S}', '{A}', '{ADEL}', 10)$q$)), 'err:42501', 'RPC: anon tidak dapat memanggil fn_create_transfer');
select is(pg_temp.run_as('anon', pg_temp.expand($q$select public.is_member('{S}')$q$)), 'err:42501', 'RPC: anon tidak dapat memanggil is_member');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000001', $q$select public.fn_purge_expired()$q$), 'err:42501', 'RPC: fn_purge_expired tidak dapat dipanggil pengguna');

-- Tampilan: security_invoker membuat RLS tetap berlaku.
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.v_account_balances where workspace_id = '{S}'$q$)), 'ok:0', 'view v_account_balances tidak membocorkan workspace lain');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$select 1 from public.v_monthly_summary where workspace_id = '{S}'$q$)), 'ok:0', 'view v_monthly_summary tidak membocorkan workspace lain');
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000003', pg_temp.expand($q$select 1 from public.v_account_balances where workspace_id = '{S}'$q$))), 'allow', 'view v_account_balances terbaca oleh viewer');
select is(pg_temp.run_as('anon', $q$select 1 from public.v_account_balances$q$), 'err:42501', 'view v_account_balances tidak dapat diakses anon');

-- Storage: objek lampiran mengikuti keanggotaan workspace.
insert into storage.objects (id, bucket_id, name, owner)
select 'c1000000-0000-0000-0000-000000000001', 'attachments', 'b0000000-0000-0000-0000-000000000001/a.png', 'a0000000-0000-0000-0000-000000000001'
where not exists (
  select 1 from storage.objects where bucket_id = 'attachments' and name = 'b0000000-0000-0000-0000-000000000001/a.png'
);
select is(pg_temp.classify(pg_temp.run_as('a0000000-0000-0000-0000-000000000003', $q$select 1 from storage.objects where bucket_id = 'attachments'$q$)), 'allow', 'storage: viewer membaca objek workspace sendiri');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', $q$select 1 from storage.objects where bucket_id = 'attachments'$q$), 'ok:0', 'storage: outsider tidak melihat objek workspace lain');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000003', pg_temp.expand($q$insert into storage.objects (bucket_id, name) values ('attachments', '{S}/viewer.png')$q$)), 'err:42501', 'storage: viewer tidak mengunggah');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000004', pg_temp.expand($q$insert into storage.objects (bucket_id, name) values ('attachments', '{S}/x.png')$q$)), 'err:42501', 'storage: outsider tidak mengunggah ke folder workspace lain');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000002', pg_temp.expand($q$insert into storage.objects (bucket_id, name) values ('attachments', '{S}/editor.png')$q$)), 'ok:1', 'storage: editor mengunggah ke folder workspace sendiri');
select is(pg_temp.run_as('a0000000-0000-0000-0000-000000000002', $q$insert into storage.objects (bucket_id, name) values ('attachments', 'bukan-uuid/x.png')$q$), 'err:42501', 'storage: path tanpa workspace ditolak');
select is(pg_temp.run_as('anon', $q$select 1 from storage.objects where bucket_id = 'attachments'$q$), 'ok:0', 'storage: anon tidak melihat objek');

-- Struktur keamanan (gerbang CI, PRD 9.5).
select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0::bigint, 'semua tabel di schema public memakai RLS');
select is(
  (select count(*) from pg_policies p where p.schemaname = 'public' and (p.roles @> array['anon'::name] or p.roles @> array['public'::name])),
  0::bigint, 'tidak ada kebijakan RLS untuk anon atau public di schema public');
select is(
  (select count(*) from pg_policies p where p.schemaname = 'storage' and p.policyname like 'attachments_objects_%' and p.roles = array['authenticated'::name]),
  4::bigint, 'kebijakan Storage lampiran hanya untuk authenticated');
select ok((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'storage' and c.relname = 'objects'), 'RLS aktif pada storage.objects');
select is((select public from storage.buckets where id = 'attachments'), false, 'bucket attachments privat');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) cfg where cfg like 'search_path=%')),
  0::bigint, 'semua fungsi SECURITY DEFINER mengunci search_path');
select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'v'
     and not coalesce('security_invoker=true' = any (c.reloptions), false)),
  0::bigint, 'semua view memakai security_invoker = true');
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and data_type in ('real', 'double precision')),
  0::bigint, 'tidak ada kolom float di schema public');
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public'
     and column_name in ('amount', 'amount_base', 'initial_balance', 'contract_value', 'stipend_amount', 'unit_price', 'amount_min', 'amount_max')
     and not (data_type = 'numeric' and numeric_precision = 20 and numeric_scale = 4)),
  0::bigint, 'kolom uang memakai numeric(20,4)');
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public'
     and column_name ~* '(^|_)(rrn|pan|cvv|pin|otp|password|terminal_id|account_number|card_number|virtual_account|va_number|reference_number|no_rek)($|_)'),
  0::bigint, 'tidak ada kolom untuk data terlarang (PRD M7a)');
select is(
  (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'transactions' and column_name in ('external_id_hash', 'dedupe_hash')),
  2::bigint, 'transactions hanya menyimpan hash referensi');
select ok(not has_function_privilege('anon', 'public.is_member(uuid)', 'execute'), 'anon tidak punya execute is_member');
select ok(not has_function_privilege('authenticated', 'public.fn_purge_expired()', 'execute'), 'authenticated tidak punya execute fn_purge_expired');
select ok(not has_function_privilege('authenticated', 'public.fn_seed_workspace_defaults(uuid, uuid)', 'execute'), 'authenticated tidak punya execute fn_seed_workspace_defaults');
select ok(not has_table_privilege('anon', 'public.transactions', 'select'), 'anon tidak punya hak select pada transactions');

select * from finish();
rollback;
