-- Orbit Fase 1: view dan fungsi hitung. Semua perhitungan ada di database (PRD bagian 0, aturan 4).
-- Semua view memakai security_invoker = true sehingga RLS pemanggil tetap berlaku.

-- Saldo akun = saldo awal + transaksi confirmed (tidak disimpan sebagai angka mentah).
create view public.v_account_balances
with (security_invoker = true) as
select
  a.id as account_id,
  a.workspace_id,
  a.name,
  a.type,
  a.currency,
  a.is_liquid,
  a.archived,
  a.visibility,
  a.sort_order,
  a.initial_balance,
  a.initial_balance + coalesce(sum(
    case
      when t.type = 'income' or (t.type = 'transfer' and t.transfer_direction = 'in') then t.amount
      when t.type = 'expense' or (t.type = 'transfer' and t.transfer_direction = 'out') then -t.amount
    end
  ), 0) as balance,
  count(t.id) as confirmed_txn_count,
  max(t.occurred_at) as last_txn_at
from public.accounts a
left join public.transactions t
  on t.account_id = a.id
 and t.workspace_id = a.workspace_id
 and t.status = 'confirmed'
 and t.deleted_at is null
where a.deleted_at is null
group by a.id;

-- Ringkasan per siklus bulan, mengikuti zona waktu dan tanggal awal siklus profil pemanggil.
-- Baris dengan is_total = true adalah total semua sumber; baris lain per sumber.
-- Transfer tidak dihitung. Nominal memakai amount_base yang tersimpan.
create view public.v_monthly_summary
with (security_invoker = true) as
with ctx as (
  select p.timezone, p.month_start_day
  from public.profiles p
  where p.id = (select auth.uid())
),
x as (
  select
    t.workspace_id,
    t.source,
    t.type,
    t.amount_base,
    (
      date_trunc('month', (t.occurred_at at time zone c.timezone) - make_interval(days => c.month_start_day - 1))::date
      + (c.month_start_day - 1)
    ) as month_start
  from public.transactions t
  cross join ctx c
  where t.status = 'confirmed'
    and t.deleted_at is null
    and t.type in ('income', 'expense')
),
s as (
  select
    x.workspace_id,
    x.month_start,
    x.source,
    (grouping(x.source) = 1) as is_total,
    coalesce(sum(x.amount_base) filter (where x.type = 'income'), 0)::numeric(20, 4) as income,
    coalesce(sum(x.amount_base) filter (where x.type = 'expense'), 0)::numeric(20, 4) as expense,
    count(*) as txn_count
  from x
  group by grouping sets ((x.workspace_id, x.month_start), (x.workspace_id, x.month_start, x.source))
)
select
  s.workspace_id,
  s.month_start,
  (s.month_start + interval '1 month' - interval '1 day')::date as month_end,
  s.source,
  s.is_total,
  w.base_currency as currency,
  s.income,
  s.expense,
  (s.income - s.expense)::numeric(20, 4) as net,
  s.txn_count
from s
join public.workspaces w on w.id = s.workspace_id;

-- Komposisi kategori per siklus bulan (transfer tidak dihitung).
create view public.v_monthly_category_summary
with (security_invoker = true) as
with ctx as (
  select p.timezone, p.month_start_day
  from public.profiles p
  where p.id = (select auth.uid())
)
select
  t.workspace_id,
  (
    date_trunc('month', (t.occurred_at at time zone c.timezone) - make_interval(days => c.month_start_day - 1))::date
    + (c.month_start_day - 1)
  ) as month_start,
  t.type,
  t.category_id,
  cat.name as category_name,
  sum(t.amount_base)::numeric(20, 4) as total,
  count(*) as txn_count
from public.transactions t
cross join ctx c
left join public.categories cat on cat.id = t.category_id and cat.workspace_id = t.workspace_id
where t.status = 'confirmed'
  and t.deleted_at is null
  and t.type in ('income', 'expense')
group by t.workspace_id, 2, t.type, t.category_id, cat.name;

-- Mengonfirmasi draft. Draft tidak pernah masuk saldo atau laporan sebelum dikonfirmasi.
-- Parameter opsional melengkapi bidang yang masih kosong. RLS pemanggil tetap berlaku.
create function public.fn_confirm_draft(
  p_transaction_id uuid,
  p_category_id uuid default null,
  p_account_id uuid default null,
  p_source public.transaction_source default null,
  p_project_id uuid default null
)
returns public.transactions
language plpgsql
set search_path = ''
as $$
declare
  v_txn public.transactions;
begin
  select t.* into v_txn
  from public.transactions t
  where t.id = p_transaction_id and t.deleted_at is null
  for update;

  if not found then
    raise exception 'Draft tidak ditemukan.' using errcode = 'P0002';
  end if;
  if not public.has_role(v_txn.workspace_id, 'editor') then
    raise exception 'Draft tidak ditemukan.' using errcode = 'P0002';
  end if;
  if v_txn.status <> 'draft' then
    raise exception 'Transaksi ini sudah dikonfirmasi.' using errcode = '22023';
  end if;

  v_txn.category_id := coalesce(p_category_id, v_txn.category_id);
  v_txn.account_id := coalesce(p_account_id, v_txn.account_id);
  v_txn.source := coalesce(p_source, v_txn.source);
  v_txn.project_id := coalesce(p_project_id, v_txn.project_id);

  if v_txn.type = 'expense' then
    v_txn.source := coalesce(v_txn.source, 'personal');
  end if;

  if v_txn.type <> 'transfer' then
    if v_txn.category_id is null then
      raise exception 'Draft belum lengkap: pilih kategori.' using errcode = '23514';
    end if;
    if v_txn.source is null then
      raise exception 'Draft belum lengkap: pilih sumber.' using errcode = '23514';
    end if;
  end if;

  update public.transactions t
  set status = 'confirmed',
      draft_state = null,
      category_id = v_txn.category_id,
      account_id = v_txn.account_id,
      source = v_txn.source,
      project_id = v_txn.project_id
  where t.id = v_txn.id
  returning t.* into v_txn;

  return v_txn;
end;
$$;

-- Transfer antar akun: dua baris terkait (transfer_group_id). Biaya admin dicatat sebagai expense terpisah.
-- Idempoten: memanggil ulang dengan p_group_id yang sama tidak membuat baris ganda.
create function public.fn_create_transfer(
  p_workspace_id uuid,
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount_out numeric,
  p_occurred_at timestamptz default now(),
  p_note text default null,
  p_amount_in numeric default null,
  p_fee numeric default 0,
  p_group_id uuid default gen_random_uuid()
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_from public.accounts;
  v_to public.accounts;
  v_amount_in numeric(20, 4);
  v_fee_category uuid;
begin
  if not public.has_role(p_workspace_id, 'editor') then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.transactions t
    where t.transfer_group_id = p_group_id and t.workspace_id = p_workspace_id
  ) then
    return p_group_id;
  end if;

  if p_from_account_id = p_to_account_id then
    raise exception 'Transfer membutuhkan dua akun berbeda.' using errcode = '23514';
  end if;
  if p_amount_out is null or p_amount_out <= 0 then
    raise exception 'Nominal harus lebih dari 0.' using errcode = '23514';
  end if;
  if p_fee is null or p_fee < 0 then
    raise exception 'Biaya admin tidak boleh negatif.' using errcode = '23514';
  end if;

  select a.* into v_from from public.accounts a
  where a.id = p_from_account_id and a.workspace_id = p_workspace_id and a.deleted_at is null;
  select a.* into v_to from public.accounts a
  where a.id = p_to_account_id and a.workspace_id = p_workspace_id and a.deleted_at is null;
  if v_from.id is null or v_to.id is null then
    raise exception 'Akun tidak ditemukan.' using errcode = '23503';
  end if;

  if v_from.currency = v_to.currency then
    v_amount_in := coalesce(p_amount_in, p_amount_out);
    if v_amount_in <> p_amount_out then
      raise exception 'Nominal masuk harus sama bila mata uang akun sama.' using errcode = '23514';
    end if;
  else
    if p_amount_in is null or p_amount_in <= 0 then
      raise exception 'Isi nominal masuk untuk transfer beda mata uang.' using errcode = '23514';
    end if;
    v_amount_in := p_amount_in;
  end if;

  perform set_config('orbit.transfer_op', 'on', true);

  insert into public.transactions (
    workspace_id, account_id, type, status, amount, currency, source, note, occurred_at,
    transfer_group_id, transfer_direction, origin
  ) values
    (p_workspace_id, v_from.id, 'transfer', 'confirmed', p_amount_out, v_from.currency, 'personal', p_note, p_occurred_at,
     p_group_id, 'out', 'manual'),
    (p_workspace_id, v_to.id, 'transfer', 'confirmed', v_amount_in, v_to.currency, 'personal', p_note, p_occurred_at,
     p_group_id, 'in', 'manual');

  if p_fee > 0 then
    select c.id into v_fee_category
    from public.categories c
    where c.workspace_id = p_workspace_id and c.system_key = 'other_expense' and c.deleted_at is null;
    if v_fee_category is null then
      perform set_config('orbit.transfer_op', 'off', true);
      raise exception 'Kategori Lainnya tidak ditemukan.' using errcode = '23503';
    end if;
    insert into public.transactions (
      workspace_id, account_id, category_id, type, status, amount, currency, source, note, occurred_at,
      transfer_group_id, origin
    ) values (
      p_workspace_id, v_from.id, v_fee_category, 'expense', 'confirmed', p_fee, v_from.currency, 'personal',
      'Biaya admin transfer', p_occurred_at, p_group_id, 'manual'
    );
  end if;

  perform set_config('orbit.transfer_op', 'off', true);
  return p_group_id;
exception
  when others then
    perform set_config('orbit.transfer_op', 'off', true);
    raise;
end;
$$;

-- Hapus lunak. Transfer dihapus bersama pasangannya dan biaya admin terkait.
create function public.fn_delete_transaction(p_transaction_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_txn public.transactions;
begin
  select t.* into v_txn from public.transactions t where t.id = p_transaction_id;
  if not found or not public.has_role(v_txn.workspace_id, 'editor') then
    raise exception 'Transaksi tidak ditemukan.' using errcode = 'P0002';
  end if;

  perform set_config('orbit.transfer_op', 'on', true);
  if v_txn.transfer_group_id is not null then
    update public.transactions t
    set deleted_at = coalesce(t.deleted_at, now())
    where t.transfer_group_id = v_txn.transfer_group_id and t.workspace_id = v_txn.workspace_id;
  else
    update public.transactions t
    set deleted_at = coalesce(t.deleted_at, now())
    where t.id = v_txn.id;
  end if;
  perform set_config('orbit.transfer_op', 'off', true);
exception
  when others then
    perform set_config('orbit.transfer_op', 'off', true);
    raise;
end;
$$;

-- Pulihkan dalam 30 hari setelah dihapus.
create function public.fn_restore_transaction(p_transaction_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_txn public.transactions;
begin
  select t.* into v_txn from public.transactions t where t.id = p_transaction_id;
  if not found or not public.has_role(v_txn.workspace_id, 'editor') then
    raise exception 'Transaksi tidak ditemukan.' using errcode = 'P0002';
  end if;
  if v_txn.deleted_at is null then
    return;
  end if;
  if v_txn.deleted_at < now() - interval '30 days' then
    raise exception 'Masa pemulihan 30 hari sudah lewat.' using errcode = '22023';
  end if;

  perform set_config('orbit.transfer_op', 'on', true);
  if v_txn.transfer_group_id is not null then
    update public.transactions t set deleted_at = null
    where t.transfer_group_id = v_txn.transfer_group_id and t.workspace_id = v_txn.workspace_id;
  else
    update public.transactions t set deleted_at = null where t.id = v_txn.id;
  end if;
  perform set_config('orbit.transfer_op', 'off', true);
exception
  when others then
    perform set_config('orbit.transfer_op', 'off', true);
    raise;
end;
$$;

-- Daftar sesi aktif pemanggil (PRD 9.4). IP tidak dikembalikan.
create function public.fn_my_sessions()
returns table (
  id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  user_agent text,
  aal text,
  is_current boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_current uuid := nullif((select auth.jwt()) ->> 'session_id', '')::uuid;
begin
  if v_uid is null then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;
  return query
    select s.id, s.created_at, s.updated_at, s.user_agent, s.aal::text, (s.id = v_current)
    from auth.sessions s
    where s.user_id = v_uid
      and (s.not_after is null or s.not_after > now())
    order by s.updated_at desc nulls last;
end;
$$;

create function public.fn_revoke_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;
  delete from auth.sessions s where s.id = p_session_id and s.user_id = v_uid;
  get diagnostics v_count = row_count;
  if v_count > 0 then
    insert into public.security_events (user_id, type) values (v_uid, 'session_revoked');
  end if;
  return v_count > 0;
end;
$$;

-- Retensi: hapus permanen data yang dihapus lunak lebih dari 30 hari dan audit log lebih dari 12 bulan.
-- Hanya untuk pg_cron/service role.
create function public.fn_purge_expired()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.transactions where deleted_at < now() - interval '30 days';
  delete from public.tasks where deleted_at < now() - interval '30 days';
  delete from public.events where deleted_at < now() - interval '30 days';
  delete from public.category_rules where deleted_at < now() - interval '30 days';

  perform set_config('orbit.audit_purge', 'on', true);
  delete from public.audit_log where at < now() - interval '12 months';
  perform set_config('orbit.audit_purge', 'off', true);
end;
$$;

revoke execute on function public.fn_purge_expired() from public, anon, authenticated;
revoke execute on function
  public.fn_confirm_draft(uuid, uuid, uuid, public.transaction_source, uuid),
  public.fn_create_transfer(uuid, uuid, uuid, numeric, timestamptz, text, numeric, numeric, uuid),
  public.fn_delete_transaction(uuid), public.fn_restore_transaction(uuid),
  public.fn_my_sessions(), public.fn_revoke_session(uuid)
  from public, anon;
grant execute on function
  public.fn_confirm_draft(uuid, uuid, uuid, public.transaction_source, uuid),
  public.fn_create_transfer(uuid, uuid, uuid, numeric, timestamptz, text, numeric, numeric, uuid),
  public.fn_delete_transaction(uuid), public.fn_restore_transaction(uuid),
  public.fn_my_sessions(), public.fn_revoke_session(uuid)
  to authenticated;

grant select on public.v_account_balances, public.v_monthly_summary, public.v_monthly_category_summary to authenticated;
