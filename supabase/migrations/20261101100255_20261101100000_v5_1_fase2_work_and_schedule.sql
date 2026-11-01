-- ==============================================================================
-- Orbit Migrasi Fase 2: Kerja, Jadwal, Tugas, & Proyek Freelance
-- ==============================================================================

-- 1. Tabel project_payments (Milestone pembayaran freelance)
create table if not exists public.project_payments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  project_id uuid not null,
  label text not null check (char_length(label) between 1 and 100),
  amount numeric(20, 4) not null check (amount > 0),
  due_date date,
  status text not null default 'pending' check (status in ('pending', 'partial', 'paid', 'overdue')),
  paid_amount numeric(20, 4) not null default 0 check (paid_amount >= 0),
  paid_at timestamptz,
  account_id uuid,
  transaction_id uuid,
  fee_transaction_id uuid,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (project_id, workspace_id) references public.projects (id, workspace_id) on delete cascade,
  foreign key (account_id, workspace_id) references public.accounts (id, workspace_id) on delete set null,
  foreign key (transaction_id, workspace_id) references public.transactions (id, workspace_id) on delete set null,
  foreign key (fee_transaction_id, workspace_id) references public.transactions (id, workspace_id) on delete set null,
  unique (id, workspace_id)
);

-- RLS deny-by-default pada project_payments
alter table public.project_payments enable row level security;
alter table public.project_payments force row level security;

grant select, insert, update, delete on public.project_payments to authenticated;

create policy project_payments_select on public.project_payments for select to authenticated
  using (public.is_member(workspace_id));
create policy project_payments_insert on public.project_payments for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy project_payments_update on public.project_payments for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy project_payments_delete on public.project_payments for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Triggers pada project_payments
create trigger trg_project_payments_updated_at before update on public.project_payments
  for each row execute function public.fn_set_updated_at();
create trigger trg_project_payments_created_by before insert on public.project_payments
  for each row execute function public.fn_set_created_by();
create trigger trg_project_payments_immutable before update on public.project_payments
  for each row execute function public.fn_protect_immutable('workspace_id', 'created_by');
create trigger trg_project_payments_audit after insert or update or delete on public.project_payments
  for each row execute function public.fn_audit();

-- 2. Sambungkan milestone_payment_id pada tasks
alter table public.tasks
  drop constraint if exists tasks_milestone_payment_id_fkey;

alter table public.tasks
  add constraint tasks_milestone_payment_id_fkey
  foreign key (milestone_payment_id) references public.project_payments (id) on delete set null;

-- 3. Fungsi fn_complete_task (toggle selesai / buka kembali)
create or replace function public.fn_complete_task(p_task_id uuid)
returns public.tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks;
  v_new_status public.task_status;
  v_new_completed timestamptz;
begin
  select * into v_task from public.tasks where id = p_task_id and deleted_at is null;
  if not found then
    raise exception 'Tugas tidak ditemukan.' using errcode = 'P0002';
  end if;

  if not public.has_role(v_task.workspace_id, 'editor') then
    raise exception 'Hak akses ditolak.' using errcode = '42501';
  end if;

  if v_task.status = 'done' then
    v_new_status := 'todo';
    v_new_completed := null;
  else
    v_new_status := 'done';
    v_new_completed := clock_timestamp();
  end if;

  update public.tasks
  set status = v_new_status,
      completed_at = v_new_completed,
      updated_at = clock_timestamp()
  where id = p_task_id
  returning * into v_task;

  return v_task;
end;
$$;
revoke execute on function public.fn_complete_task(uuid) from public, anon;
grant execute on function public.fn_complete_task(uuid) to authenticated;

-- 4. Fungsi fn_mark_payment_paid (atomik: lunas/batal lunas & kelola transaksi)
create or replace function public.fn_mark_payment_paid(
  p_payment_id uuid,
  p_account_id uuid default null,
  p_paid_at timestamptz default null,
  p_fee numeric default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.project_payments;
  v_project public.projects;
  v_acc public.accounts;
  v_txn_id uuid;
  v_fee_txn_id uuid := null;
  v_fee_amt numeric(20, 4) := coalesce(p_fee, 0);
  v_paid_time timestamptz := coalesce(p_paid_at, clock_timestamp());
  v_category_id uuid;
  v_exp_category_id uuid;
begin
  select * into v_payment from public.project_payments where id = p_payment_id and deleted_at is null;
  if not found then
    raise exception 'Pembayaran tidak ditemukan.' using errcode = 'P0002';
  end if;

  if not public.has_role(v_payment.workspace_id, 'editor') then
    raise exception 'Hak akses ditolak.' using errcode = '42501';
  end if;

  -- Operasi batalkan status lunas jika p_account_id null dan status sudah paid
  if v_payment.status = 'paid' then
    if p_account_id is null then
      if v_payment.transaction_id is not null then
        update public.transactions set deleted_at = clock_timestamp() where id = v_payment.transaction_id;
      end if;
      if v_payment.fee_transaction_id is not null then
        update public.transactions set deleted_at = clock_timestamp() where id = v_payment.fee_transaction_id;
      end if;
      update public.project_payments
      set status = 'pending',
          paid_amount = 0,
          paid_at = null,
          account_id = null,
          transaction_id = null,
          fee_transaction_id = null,
          updated_at = clock_timestamp()
      where id = p_payment_id;
      return null;
    else
      raise exception 'Pembayaran ini sudah berstatus lunas. Batalkan terlebih dahulu untuk mengubah.' using errcode = '22000';
    end if;
  end if;

  -- Menandai lunas
  if p_account_id is null then
    raise exception 'Akun penerima harus dipilih.' using errcode = '23502';
  end if;

  select * into v_project from public.projects where id = v_payment.project_id;
  select * into v_acc from public.accounts where id = p_account_id and workspace_id = v_payment.workspace_id and deleted_at is null;
  if not found then
    raise exception 'Akun tidak valid di workspace ini.' using errcode = '23503';
  end if;

  -- Kategori pemasukan proyek
  select id into v_category_id
  from public.categories
  where workspace_id = v_payment.workspace_id
    and type = 'income'
    and name in ('Proyek Freelance', 'Gaji/Uang Saku Intern')
  order by (name = 'Proyek Freelance') desc
  limit 1;

  if v_category_id is null then
    select id into v_category_id
    from public.categories
    where workspace_id = v_payment.workspace_id and type = 'income' and deleted_at is null
    limit 1;
  end if;

  -- Buat transaksi pemasukan lunas
  insert into public.transactions (
    workspace_id,
    account_id,
    category_id,
    project_id,
    type,
    status,
    amount,
    amount_base,
    currency,
    source,
    note,
    occurred_at,
    origin
  ) values (
    v_payment.workspace_id,
    p_account_id,
    v_category_id,
    v_payment.project_id,
    'income',
    'confirmed',
    v_payment.amount,
    v_payment.amount,
    v_acc.currency,
    'freelance',
    'Pelunasan milestone: ' || v_payment.label || ' (' || v_project.name || ')',
    v_paid_time,
    'manual'
  )
  returning id into v_txn_id;

  -- Periksa apakah perlu transaksi expense potongan platform
  if v_fee_amt = 0 and v_project.platform_fee_percent is not null and v_project.platform_fee_percent > 0 and v_project.fee_mode = 'expense_transaction' then
    v_fee_amt := round(v_payment.amount * v_project.platform_fee_percent / 100.0, 4);
  end if;

  if v_fee_amt > 0 and v_project.fee_mode = 'expense_transaction' then
    select id into v_exp_category_id
    from public.categories
    where workspace_id = v_payment.workspace_id and type = 'expense' and deleted_at is null
    limit 1;

    insert into public.transactions (
      workspace_id,
      account_id,
      category_id,
      project_id,
      type,
      status,
      amount,
      amount_base,
      currency,
      source,
      note,
      occurred_at,
      origin
    ) values (
      v_payment.workspace_id,
      p_account_id,
      v_exp_category_id,
      v_payment.project_id,
      'expense',
      'confirmed',
      v_fee_amt,
      v_fee_amt,
      v_acc.currency,
      'freelance',
      'Potongan platform: ' || v_payment.label || ' (' || v_project.name || ')',
      v_paid_time,
      'manual'
    )
    returning id into v_fee_txn_id;
  end if;

  -- Perbarui status payment menjadi paid
  update public.project_payments
  set status = 'paid',
      paid_amount = v_payment.amount,
      paid_at = v_paid_time,
      account_id = p_account_id,
      transaction_id = v_txn_id,
      fee_transaction_id = v_fee_txn_id,
      updated_at = clock_timestamp()
  where id = p_payment_id;

  return v_txn_id;
end;
$$;
revoke execute on function public.fn_mark_payment_paid(uuid, uuid, timestamptz, numeric) from public, anon;
grant execute on function public.fn_mark_payment_paid(uuid, uuid, timestamptz, numeric) to authenticated;

-- 5. Views: v_project_profit & v_receivables (security_invoker = true)
create or replace view public.v_project_profit
with (security_invoker = true)
as
with payments as (
  select
    project_id,
    coalesce(sum(amount), 0) as total_invoiced,
    coalesce(sum(paid_amount), 0) as total_paid
  from public.project_payments
  where deleted_at is null
  group by project_id
),
expenses as (
  select
    project_id,
    coalesce(sum(amount_base), 0) as total_expense
  from public.transactions
  where type = 'expense'
    and status = 'confirmed'
    and deleted_at is null
    and project_id is not null
  group by project_id
)
select
  p.workspace_id,
  p.id as project_id,
  p.name as project_name,
  p.kind,
  p.client_name,
  p.status,
  p.contract_value,
  p.currency,
  coalesce(pm.total_invoiced, 0)::numeric(20, 4) as total_invoiced,
  coalesce(pm.total_paid, 0)::numeric(20, 4) as total_paid,
  coalesce(ex.total_expense, 0)::numeric(20, 4) as total_expense,
  case
    when p.platform_fee_percent is not null and p.platform_fee_percent > 0 and (p.fee_mode = 'profit_deduction' or p.fee_mode is null) then
      round((coalesce(pm.total_paid, 0) * p.platform_fee_percent / 100.0), 4)
    else 0.0000
  end::numeric(20, 4) as platform_fee_deducted,
  (
    coalesce(pm.total_paid, 0) - coalesce(ex.total_expense, 0) -
    case
      when p.platform_fee_percent is not null and p.platform_fee_percent > 0 and (p.fee_mode = 'profit_deduction' or p.fee_mode is null) then
        round((coalesce(pm.total_paid, 0) * p.platform_fee_percent / 100.0), 4)
      else 0.0000
    end
  )::numeric(20, 4) as net_profit,
  case
    when coalesce(pm.total_paid, 0) > 0 then
      round(
        ((coalesce(pm.total_paid, 0) - coalesce(ex.total_expense, 0) -
          case
            when p.platform_fee_percent is not null and p.platform_fee_percent > 0 and (p.fee_mode = 'profit_deduction' or p.fee_mode is null) then
              round((coalesce(pm.total_paid, 0) * p.platform_fee_percent / 100.0), 4)
            else 0.0000
          end
        ) / pm.total_paid * 100.0),
        2
      )
    else 0.00
  end::numeric(10, 2) as margin_percent,
  (coalesce(p.contract_value, pm.total_invoiced, 0) - coalesce(pm.total_paid, 0))::numeric(20, 4) as remaining_invoiced
from public.projects p
left join payments pm on pm.project_id = p.id
left join expenses ex on ex.project_id = p.id
where p.deleted_at is null;

grant select on public.v_project_profit to authenticated;

create or replace view public.v_receivables
with (security_invoker = true)
as
select
  p.workspace_id,
  p.id as project_id,
  p.name as project_name,
  p.client_name,
  pm.id as payment_id,
  pm.label,
  pm.amount,
  pm.paid_amount,
  (pm.amount - pm.paid_amount)::numeric(20, 4) as remaining_amount,
  pm.due_date,
  case
    when pm.status = 'paid' then 'paid'
    when pm.due_date is not null and pm.due_date < current_date then 'overdue'
    when pm.paid_amount > 0 then 'partial'
    else 'pending'
  end as status,
  (pm.due_date is not null and pm.due_date < current_date and pm.status <> 'paid') as is_overdue,
  case
    when pm.due_date is not null and pm.due_date < current_date and pm.status <> 'paid' then
      (current_date - pm.due_date)::integer
    else 0
  end as days_overdue
from public.project_payments pm
join public.projects p on p.id = pm.project_id
where pm.deleted_at is null
  and pm.status <> 'paid'
order by pm.due_date asc nulls last;

grant select on public.v_receivables to authenticated;

-- 6. Fungsi fn_agenda (menggabungkan event, jadwal berulang, dan tugas jatuh tempo)
create or replace function public.fn_agenda(
  p_workspace_id uuid,
  p_start_date date,
  p_end_date date default null,
  p_kind text default null
)
returns table (
  id uuid,
  item_type text,
  kind public.activity_kind,
  title text,
  description text,
  project_id uuid,
  project_name text,
  project_color text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean,
  location text,
  status text,
  priority text,
  due_at timestamptz,
  due_is_date_only boolean,
  is_overdue boolean,
  checklist_total integer,
  checklist_done integer,
  event_id uuid,
  is_recurring boolean,
  milestone_payment_id uuid
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_end date := coalesce(p_end_date, p_start_date);
begin
  if not public.is_member(p_workspace_id) then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  return query
  -- 1. Non-recurring events
  select
    e.id,
    'event'::text as item_type,
    e.kind,
    e.title,
    e.description,
    e.project_id,
    p.name as project_name,
    p.color as project_color,
    e.starts_at,
    e.ends_at,
    e.all_day,
    e.location,
    'scheduled'::text as status,
    null::text as priority,
    null::timestamptz as due_at,
    false as due_is_date_only,
    false as is_overdue,
    0::integer as checklist_total,
    0::integer as checklist_done,
    e.id as event_id,
    false as is_recurring,
    null::uuid as milestone_payment_id
  from public.events e
  left join public.projects p on p.id = e.project_id
  where e.workspace_id = p_workspace_id
    and e.deleted_at is null
    and e.recurrence is null
    and e.starts_at::date <= v_end
    and e.ends_at::date >= p_start_date
    and (p_kind is null or e.kind::text = p_kind)

  union all

  -- 2. Recurring events
  select
    gen_random_uuid() as id,
    'event'::text as item_type,
    e.kind,
    coalesce(exc.override_title, e.title) as title,
    e.description,
    e.project_id,
    p.name as project_name,
    p.color as project_color,
    coalesce(
      exc.override_starts_at,
      timezone(e.timezone, (d.series_date + timezone(e.timezone, e.starts_at)::time))
    ) as starts_at,
    coalesce(
      exc.override_ends_at,
      timezone(e.timezone, (d.series_date + timezone(e.timezone, e.starts_at)::time)) + (e.ends_at - e.starts_at)
    ) as ends_at,
    e.all_day,
    coalesce(exc.override_location, e.location) as location,
    'scheduled'::text as status,
    null::text as priority,
    null::timestamptz as due_at,
    false as due_is_date_only,
    false as is_overdue,
    0::integer as checklist_total,
    0::integer as checklist_done,
    e.id as event_id,
    true as is_recurring,
    null::uuid as milestone_payment_id
  from public.events e
  left join public.projects p on p.id = e.project_id
  cross join generate_series(p_start_date::timestamp, v_end::timestamp, interval '1 day') as d(series_date)
  left join public.event_exceptions exc on exc.event_id = e.id and exc.original_date = d.series_date::date
  where e.workspace_id = p_workspace_id
    and e.deleted_at is null
    and e.recurrence is not null
    and (p_kind is null or e.kind::text = p_kind)
    and (exc.action is null or exc.action <> 'skip')
    and d.series_date::date >= (timezone(e.timezone, e.starts_at))::date
    and (
      (e.recurrence ->> 'freq' = 'daily')
      or
      (
        e.recurrence ->> 'freq' = 'weekly'
        and (
          (e.recurrence -> 'byweekday') is null
          or (e.recurrence -> 'byweekday') @> to_jsonb(extract(isodow from d.series_date)::integer)
          or (e.recurrence -> 'byweekday') @> to_jsonb(extract(dow from d.series_date)::integer)
        )
      )
      or
      (
        e.recurrence ->> 'freq' = 'monthly'
        and extract(day from d.series_date) = extract(day from e.starts_at)
      )
    )
    and (
      (e.recurrence ->> 'until') is null
      or d.series_date::date <= (e.recurrence ->> 'until')::date
    )

  union all

  -- 3. Tasks due in range or overdue
  select
    t.id,
    'task'::text as item_type,
    t.kind,
    t.title,
    t.description,
    t.project_id,
    p.name as project_name,
    p.color as project_color,
    null::timestamptz as starts_at,
    null::timestamptz as ends_at,
    false as all_day,
    null::text as location,
    t.status::text as status,
    t.priority::text as priority,
    t.due_at,
    t.due_is_date_only,
    (t.due_at is not null and t.due_at < clock_timestamp() and t.status <> 'done') as is_overdue,
    coalesce(ci.total, 0)::integer as checklist_total,
    coalesce(ci.done, 0)::integer as checklist_done,
    null::uuid as event_id,
    false as is_recurring,
    t.milestone_payment_id
  from public.tasks t
  left join public.projects p on p.id = t.project_id
  left join (
    select
      task_id,
      count(*) as total,
      count(*) filter (where done) as done
    from public.task_checklist_items
    group by task_id
  ) ci on ci.task_id = t.id
  where t.workspace_id = p_workspace_id
    and t.deleted_at is null
    and (p_kind is null or t.kind::text = p_kind)
    and (
      (t.due_at::date between p_start_date and v_end)
      or (p_start_date <= current_date and t.due_at < clock_timestamp() and t.status <> 'done')
    )
  order by starts_at nulls last, due_at nulls last, priority desc;
end;
$$;
revoke execute on function public.fn_agenda(uuid, date, date, text) from public, anon;
grant execute on function public.fn_agenda(uuid, date, date, text) to authenticated;

-- 7. Fungsi fn_detect_conflicts (mendeteksi benturan event dan penanda hari padat)
create or replace function public.fn_detect_conflicts(
  p_workspace_id uuid,
  p_start_date date,
  p_end_date date default null
)
returns table (
  conflict_date date,
  event1_id uuid,
  event1_title text,
  event1_starts_at timestamptz,
  event1_ends_at timestamptz,
  event2_id uuid,
  event2_title text,
  event2_starts_at timestamptz,
  event2_ends_at timestamptz,
  is_heavy_day boolean
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_end date := coalesce(p_end_date, p_start_date);
begin
  if not public.is_member(p_workspace_id) then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  return query
  with agenda_events as (
    select
      a.id as item_id,
      a.event_id,
      a.title,
      a.starts_at,
      a.ends_at,
      a.starts_at::date as event_date,
      extract(epoch from (a.ends_at - a.starts_at)) / 3600.0 as duration_hours
    from public.fn_agenda(p_workspace_id, p_start_date, v_end) a
    where a.item_type = 'event' and not a.all_day
  ),
  day_stats as (
    select
      event_date,
      count(*) as daily_event_count,
      sum(duration_hours) as total_duration_hours
    from agenda_events
    group by event_date
  ),
  conflicts as (
    select
      e1.event_date as conflict_date,
      e1.event_id as event1_id,
      e1.title as event1_title,
      e1.starts_at as event1_starts_at,
      e1.ends_at as event1_ends_at,
      e2.event_id as event2_id,
      e2.title as event2_title,
      e2.starts_at as event2_starts_at,
      e2.ends_at as event2_ends_at,
      coalesce(ds.daily_event_count >= 5 or ds.total_duration_hours >= 8.0, false) as is_heavy_day
    from agenda_events e1
    join agenda_events e2 on e1.event_date = e2.event_date
      and e1.item_id < e2.item_id
      and e1.starts_at < e2.ends_at
      and e1.ends_at > e2.starts_at
    left join day_stats ds on ds.event_date = e1.event_date
  ),
  heavy_days_only as (
    select
      ds.event_date as conflict_date,
      null::uuid as event1_id,
      null::text as event1_title,
      null::timestamptz as event1_starts_at,
      null::timestamptz as event1_ends_at,
      null::uuid as event2_id,
      null::text as event2_title,
      null::timestamptz as event2_starts_at,
      null::timestamptz as event2_ends_at,
      true as is_heavy_day
    from day_stats ds
    where (ds.daily_event_count >= 5 or ds.total_duration_hours >= 8.0)
      and not exists (
        select 1 from conflicts c where c.conflict_date = ds.event_date
      )
  )
  select * from conflicts
  union all
  select * from heavy_days_only
  order by conflict_date, event1_starts_at nulls last;
end;
$$;
revoke execute on function public.fn_detect_conflicts(uuid, date, date) from public, anon;
grant execute on function public.fn_detect_conflicts(uuid, date, date) to authenticated;
