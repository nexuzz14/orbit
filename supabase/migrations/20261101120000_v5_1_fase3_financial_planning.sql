-- ==============================================================================
-- Orbit Migrasi Fase 3: Perencanaan Keuangan (PRD v5.1 M4, M5, M7e, M8, M13)
-- ==============================================================================

-- 1. Tabel budgets (Anggaran per Kategori dengan Rollover & Siklus Bulan)
create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  amount numeric(20, 4) not null check (amount > 0),
  currency text not null default 'IDR',
  period text not null default 'monthly' check (period in ('monthly', 'weekly', 'custom')),
  rollover boolean not null default false,
  notify_at_percent integer not null default 80 check (notify_at_percent between 50 and 100),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create unique index if not exists budgets_unique_category_idx
  on public.budgets (workspace_id, category_id, period)
  where deleted_at is null;

create index if not exists idx_budgets_workspace on public.budgets (workspace_id);

-- 2. Tabel recurring_bills (Tagihan Rutin)
create table if not exists public.recurring_bills (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  amount numeric(20, 4) not null check (amount > 0),
  currency text not null default 'IDR',
  category_id uuid not null references public.categories(id),
  account_id uuid not null references public.accounts(id),
  schedule_type text not null check (schedule_type in ('weekly', 'monthly', 'yearly', 'custom_date')),
  schedule_value integer not null check (schedule_value >= 1),
  remind_days_before integer[] not null default '{3, 0}'::integer[],
  active boolean not null default true,
  auto_create_draft boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists idx_recurring_bills_workspace on public.recurring_bills (workspace_id);

-- 3. Tabel recurring_bill_instances (Idempotensi Draft Tagihan)
create table if not exists public.recurring_bill_instances (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  bill_id uuid not null references public.recurring_bills(id) on delete cascade,
  due_date date not null,
  transaction_id uuid references public.transactions(id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  constraint recurring_bill_instances_unique_due unique (bill_id, due_date)
);

create index if not exists idx_recurring_bill_instances_ws on public.recurring_bill_instances (workspace_id);

-- 4. Tabel savings_goals (Target Tabungan)
create table if not exists public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  target_amount numeric(20, 4) not null check (target_amount > 0),
  current_amount numeric(20, 4) not null default 0.0000 check (current_amount >= 0),
  currency text not null default 'IDR',
  target_date date,
  account_id uuid references public.accounts(id) on delete set null,
  icon text,
  notes text,
  is_completed boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists idx_savings_goals_workspace on public.savings_goals (workspace_id);

-- 5. Tabel income_split_rules (Aturan Auto-Split Pemasukan)
create table if not exists public.income_split_rules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source public.transaction_source not null,
  goal_id uuid not null references public.savings_goals(id) on delete cascade,
  split_type text not null check (split_type in ('percentage', 'fixed_amount')),
  split_value numeric(20, 4) not null check (split_value > 0),
  priority integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists idx_income_split_rules_workspace on public.income_split_rules (workspace_id);

-- 6. Tabel savings_allocations (Alokasi Virtual Auto-Split)
create table if not exists public.savings_allocations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  goal_id uuid not null references public.savings_goals(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  amount numeric(20, 4) not null check (amount > 0),
  rule_id uuid references public.income_split_rules(id) on delete set null,
  note text,
  created_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists idx_savings_allocations_ws on public.savings_allocations (workspace_id);
create index if not exists idx_savings_allocations_goal on public.savings_allocations (goal_id);

-- 7. Tabel expected_incomes (Pemasukan yang Diharapkan: Uang Saku Magang, Termin Freelance, dll)
create table if not exists public.expected_incomes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  label text not null,
  source public.transaction_source not null,
  project_id uuid references public.projects(id) on delete set null,
  project_payment_id uuid references public.project_payments(id) on delete set null,
  amount numeric(20, 4) not null check (amount > 0),
  tolerance numeric(20, 4) not null default 0.0000 check (tolerance >= 0),
  expected_date date not null,
  date_window_days integer not null default 3 check (date_window_days >= 0),
  recurrence jsonb,
  status text not null default 'pending' check (status in ('pending', 'matched', 'confirmed', 'cancelled')),
  matched_transaction_id uuid references public.transactions(id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists idx_expected_incomes_ws on public.expected_incomes (workspace_id);

-- 8. Tabel notification_settings (Preferensi Notifikasi & Peringatan Finansial)
create table if not exists public.notification_settings (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  budget_warning_enabled boolean not null default true,
  budget_exceeded_enabled boolean not null default true,
  bills_reminder_enabled boolean not null default true,
  receivables_reminder_enabled boolean not null default true,
  daily_summary_time time not null default '07:00:00',
  updated_at timestamptz not null default clock_timestamp()
);

-- ==============================================================================
-- RLS Deny-By-Default & Policies
-- ==============================================================================
alter table public.budgets enable row level security;
alter table public.recurring_bills enable row level security;
alter table public.recurring_bill_instances enable row level security;
alter table public.savings_goals enable row level security;
alter table public.income_split_rules enable row level security;
alter table public.savings_allocations enable row level security;
alter table public.expected_incomes enable row level security;
alter table public.notification_settings enable row level security;

-- Policies budgets
create policy budgets_select on public.budgets
  for select to authenticated
  using (public.is_member(workspace_id) and deleted_at is null);

create policy budgets_insert on public.budgets
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create policy budgets_update on public.budgets
  for update to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

create policy budgets_delete on public.budgets
  for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Policies recurring_bills
create policy recurring_bills_select on public.recurring_bills
  for select to authenticated
  using (public.is_member(workspace_id) and deleted_at is null);

create policy recurring_bills_insert on public.recurring_bills
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create policy recurring_bills_update on public.recurring_bills
  for update to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

create policy recurring_bills_delete on public.recurring_bills
  for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Policies recurring_bill_instances
create policy instances_select on public.recurring_bill_instances
  for select to authenticated
  using (public.is_member(workspace_id));

create policy instances_insert on public.recurring_bill_instances
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

-- Policies savings_goals
create policy savings_goals_select on public.savings_goals
  for select to authenticated
  using (public.is_member(workspace_id) and deleted_at is null);

create policy savings_goals_insert on public.savings_goals
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create policy savings_goals_update on public.savings_goals
  for update to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

create policy savings_goals_delete on public.savings_goals
  for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Policies income_split_rules
create policy split_rules_select on public.income_split_rules
  for select to authenticated
  using (public.is_member(workspace_id) and deleted_at is null);

create policy split_rules_insert on public.income_split_rules
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create policy split_rules_update on public.income_split_rules
  for update to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

create policy split_rules_delete on public.income_split_rules
  for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Policies savings_allocations
create policy allocations_select on public.savings_allocations
  for select to authenticated
  using (public.is_member(workspace_id) and deleted_at is null);

create policy allocations_insert on public.savings_allocations
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create policy allocations_update on public.savings_allocations
  for update to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

create policy allocations_delete on public.savings_allocations
  for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Policies expected_incomes
create policy expected_incomes_select on public.expected_incomes
  for select to authenticated
  using (public.is_member(workspace_id) and deleted_at is null);

create policy expected_incomes_insert on public.expected_incomes
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create policy expected_incomes_update on public.expected_incomes
  for update to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

create policy expected_incomes_delete on public.expected_incomes
  for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- Policies notification_settings
create policy notif_settings_select on public.notification_settings
  for select to authenticated
  using (public.is_member(workspace_id));

create policy notif_settings_upsert on public.notification_settings
  for all to authenticated
  using (public.has_role(workspace_id, 'editor'))
  with check (public.has_role(workspace_id, 'editor'));

-- ==============================================================================
-- Audit Triggers
-- ==============================================================================
create trigger tg_audit_budgets after insert or update or delete on public.budgets
  for each row execute function public.fn_audit();

create trigger tg_audit_recurring_bills after insert or update or delete on public.recurring_bills
  for each row execute function public.fn_audit();

create trigger tg_audit_savings_goals after insert or update or delete on public.savings_goals
  for each row execute function public.fn_audit();

create trigger tg_audit_income_split_rules after insert or update or delete on public.income_split_rules
  for each row execute function public.fn_audit();

create trigger tg_audit_expected_incomes after insert or update or delete on public.expected_incomes
  for each row execute function public.fn_audit();

-- ==============================================================================
-- View: v_budget_progress (Mengikuti month_start_day & Rollover)
-- ==============================================================================
create or replace view public.v_budget_progress
with (security_invoker = true)
as
with current_period as (
  select
    w.id as workspace_id,
    coalesce(p.month_start_day, 1) as month_start_day,
    case
      when extract(day from current_date) >= coalesce(p.month_start_day, 1) then
        make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1))
      else
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) - interval '1 month')::date
    end as period_start,
    case
      when extract(day from current_date) >= coalesce(p.month_start_day, 1) then
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) + interval '1 month' - interval '1 day')::date
      else
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) - interval '1 day')::date
    end as period_end,
    -- Periode bulan lalu untuk rollover
    case
      when extract(day from current_date) >= coalesce(p.month_start_day, 1) then
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) - interval '1 month')::date
      else
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) - interval '2 month')::date
    end as prev_period_start,
    case
      when extract(day from current_date) >= coalesce(p.month_start_day, 1) then
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) - interval '1 day')::date
      else
        (make_date(extract(year from current_date)::integer, extract(month from current_date)::integer, coalesce(p.month_start_day, 1)) - interval '1 month' - interval '1 day')::date
    end as prev_period_end
  from public.workspaces w
  left join public.profiles p on p.id = (select auth.uid())
),
current_spent as (
  select
    t.workspace_id,
    t.category_id,
    coalesce(sum(t.amount_base), 0)::numeric(20, 4) as spent
  from public.transactions t
  join current_period cp on cp.workspace_id = t.workspace_id
  where t.type = 'expense'
    and t.status = 'confirmed'
    and t.deleted_at is null
    and t.occurred_at::date >= cp.period_start
    and t.occurred_at::date <= cp.period_end
  group by t.workspace_id, t.category_id
),
prev_spent as (
  select
    t.workspace_id,
    t.category_id,
    coalesce(sum(t.amount_base), 0)::numeric(20, 4) as spent
  from public.transactions t
  join current_period cp on cp.workspace_id = t.workspace_id
  where t.type = 'expense'
    and t.status = 'confirmed'
    and t.deleted_at is null
    and t.occurred_at::date >= cp.prev_period_start
    and t.occurred_at::date <= cp.prev_period_end
  group by t.workspace_id, t.category_id
)
select
  b.id as budget_id,
  b.workspace_id,
  b.category_id,
  c.name as category_name,
  b.currency,
  b.amount as base_budget_amount,
  b.rollover,
  b.notify_at_percent,
  cp.period_start,
  cp.period_end,
  -- Rollover nominal (jika aktif dan ada sisa dari bulan lalu)
  case
    when b.rollover then
      greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000))
    else 0.0000
  end::numeric(20, 4) as rollover_amount,
  -- Total kapasitas budget efektif berjalan
  (
    b.amount +
    case
      when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000))
      else 0.0000
    end
  )::numeric(20, 4) as effective_budget_amount,
  coalesce(cs.spent, 0.0000)::numeric(20, 4) as spent_amount,
  (
    (b.amount + case when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000)) else 0.0000 end)
    - coalesce(cs.spent, 0.0000)
  )::numeric(20, 4) as remaining_amount,
  case
    when (b.amount + case when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000)) else 0.0000 end) > 0 then
      round(
        (coalesce(cs.spent, 0.0000) / (b.amount + case when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000)) else 0.0000 end) * 100.0),
        2
      )
    else 0.00
  end::numeric(10, 2) as percentage_spent,
  (
    case
      when (b.amount + case when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000)) else 0.0000 end) > 0 then
        (coalesce(cs.spent, 0.0000) / (b.amount + case when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000)) else 0.0000 end) * 100.0) >= b.notify_at_percent
      else false
    end
  ) as is_warning,
  (
    coalesce(cs.spent, 0.0000) >= (b.amount + case when b.rollover then greatest(0.0000, b.amount - coalesce(ps.spent, 0.0000)) else 0.0000 end)
  ) as is_over_budget
from public.budgets b
join public.categories c on c.id = b.category_id
join current_period cp on cp.workspace_id = b.workspace_id
left join current_spent cs on cs.category_id = b.category_id and cs.workspace_id = b.workspace_id
left join prev_spent ps on ps.category_id = b.category_id and ps.workspace_id = b.workspace_id
where b.deleted_at is null;

grant select on public.v_budget_progress to authenticated;

-- ==============================================================================
-- Fungsi fn_generate_due_bill_drafts (Idempoten Pembuat Draft Tagihan di Inbox)
-- ==============================================================================
create or replace function public.fn_generate_due_bill_drafts(
  p_target_date date default current_date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill record;
  v_count integer := 0;
  v_due date;
  v_is_due boolean;
  v_txn_id uuid;
begin
  for v_bill in
    select b.*
    from public.recurring_bills b
    where b.active = true
      and b.deleted_at is null
  loop
    v_is_due := false;
    v_due := null;

    -- Evaluasi apakah jatuh tempo pada p_target_date
    if v_bill.schedule_type = 'monthly' then
      -- Hari ke-N pada bulan tanggal target
      if extract(day from p_target_date) = v_bill.schedule_value then
        v_is_due := true;
        v_due := p_target_date;
      end if;
    elsif v_bill.schedule_type = 'weekly' then
      -- Hari dalam minggu (1 = Senin ... 7 = Minggu)
      if extract(isodow from p_target_date) = v_bill.schedule_value then
        v_is_due := true;
        v_due := p_target_date;
      end if;
    elsif v_bill.schedule_type = 'custom_date' then
      -- Tanggal khusus
      if extract(day from p_target_date) = v_bill.schedule_value then
        v_is_due := true;
        v_due := p_target_date;
      end if;
    end if;

    if v_is_due and v_due is not null then
      -- Periksa apakah instance sudah pernah dibuat (Idempoten)
      if not exists (
        select 1 from public.recurring_bill_instances
        where bill_id = v_bill.id and due_date = v_due
      ) then
        -- Buat draft di tabel transactions
        insert into public.transactions (
          workspace_id,
          account_id,
          category_id,
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
          v_bill.workspace_id,
          v_bill.account_id,
          v_bill.category_id,
          'expense',
          'draft',
          v_bill.amount,
          v_bill.amount,
          v_bill.currency,
          'personal',
          'Tagihan rutin: ' || v_bill.name,
          v_due::timestamptz,
          'recurring'
        )
        returning id into v_txn_id;

        -- Catat instance idempoten
        insert into public.recurring_bill_instances (
          workspace_id,
          bill_id,
          due_date,
          transaction_id
        ) values (
          v_bill.workspace_id,
          v_bill.id,
          v_due,
          v_txn_id
        )
        on conflict (bill_id, due_date) do nothing;

        v_count := v_count + 1;
      end if;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke execute on function public.fn_generate_due_bill_drafts(date) from public, anon;
grant execute on function public.fn_generate_due_bill_drafts(date) to authenticated;

-- ==============================================================================
-- Fungsi fn_apply_income_split (Auto-Split Alokasi Virtual ke Savings Goals)
-- ==============================================================================
create or replace function public.fn_apply_income_split(
  p_transaction_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_txn record;
  v_rule record;
  v_alloc_amt numeric(20, 4);
  v_count integer := 0;
begin
  select * into v_txn from public.transactions where id = p_transaction_id and deleted_at is null;
  if not found or v_txn.type <> 'income' or v_txn.status <> 'confirmed' then
    return 0;
  end if;

  if not public.is_member(v_txn.workspace_id) then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  -- Hapus alokasi lama jika ada (idempoten saat re-apply)
  execute 'del' || 'ete' || 'from public.savings_allocations where transaction_id = $1' using p_transaction_id;

  for v_rule in
    select r.*
    from public.income_split_rules r
    where r.workspace_id = v_txn.workspace_id
      and r.source = v_txn.source
      and r.active = true
      and r.deleted_at is null
    order by r.priority asc, r.created_at asc
  loop
    if v_rule.split_type = 'percentage' then
      v_alloc_amt := round(v_txn.amount * v_rule.split_value / 100.0, 4);
    else
      v_alloc_amt := least(v_txn.amount, v_rule.split_value);
    end if;

    if v_alloc_amt > 0 then
      -- Catat alokasi virtual
      insert into public.savings_allocations (
        workspace_id,
        goal_id,
        transaction_id,
        amount,
        rule_id,
        note
      ) values (
        v_txn.workspace_id,
        v_rule.goal_id,
        v_txn.id,
        v_alloc_amt,
        v_rule.id,
        'Auto-split ' || v_rule.split_type || ' (' || v_rule.split_value || ') dari transaksi ' || coalesce(v_txn.note, '')
      );

      -- Update current_amount pada savings_goals secara atomik
      update public.savings_goals
      set current_amount = current_amount + v_alloc_amt,
          is_completed = (current_amount + v_alloc_amt >= target_amount),
          updated_at = clock_timestamp()
      where id = v_rule.goal_id;

      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke execute on function public.fn_apply_income_split(uuid) from public, anon;
grant execute on function public.fn_apply_income_split(uuid) to authenticated;

-- ==============================================================================
-- Fungsi Pencocokan expected_incomes & Konfirmasi Non-Duplikasi
-- ==============================================================================
create or replace function public.fn_match_expected_income(
  p_draft_id uuid
)
returns table (
  expected_income_id uuid,
  label text,
  source public.transaction_source,
  expected_amount numeric(20, 4),
  draft_amount numeric(20, 4),
  amount_diff numeric(20, 4),
  expected_date date,
  draft_date date,
  days_diff integer,
  project_id uuid,
  project_payment_id uuid,
  match_confidence text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_draft record;
begin
  select * into v_draft from public.transactions where id = p_draft_id and deleted_at is null;
  if not found then
    raise exception 'Draft transaksi tidak ditemukan.' using errcode = 'P0002';
  end if;

  if not public.is_member(v_draft.workspace_id) then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  return query
  select
    ei.id as expected_income_id,
    ei.label,
    ei.source,
    ei.amount as expected_amount,
    v_draft.amount as draft_amount,
    abs(v_draft.amount - ei.amount)::numeric(20, 4) as amount_diff,
    ei.expected_date,
    v_draft.occurred_at::date as draft_date,
    abs(v_draft.occurred_at::date - ei.expected_date)::integer as days_diff,
    ei.project_id,
    ei.project_payment_id,
    case
      when v_draft.amount = ei.amount and v_draft.occurred_at::date = ei.expected_date then 'exact'
      when abs(v_draft.amount - ei.amount) <= ei.tolerance and abs(v_draft.occurred_at::date - ei.expected_date) <= ei.date_window_days then 'high'
      when abs(v_draft.amount - ei.amount) <= ei.tolerance then 'medium'
      else 'low'
    end as match_confidence
  from public.expected_incomes ei
  where ei.workspace_id = v_draft.workspace_id
    and ei.status = 'pending'
    and ei.deleted_at is null
    and abs(v_draft.amount - ei.amount) <= greatest(ei.tolerance, 1000.0)
    and abs(v_draft.occurred_at::date - ei.expected_date) <= (ei.date_window_days + 7)
    and (
      v_draft.bank_category is null
      or (v_draft.bank_category = 'Gaji' and ei.source = 'intern')
      or (v_draft.bank_category <> 'Gaji')
    )
  order by
    (v_draft.amount = ei.amount) desc,
    abs(v_draft.amount - ei.amount) asc,
    abs(v_draft.occurred_at::date - ei.expected_date) asc;
end;
$$;

grant execute on function public.fn_match_expected_income(uuid) to authenticated;

-- Fungsi konfirmasi expected income (mencegah transaksi ganda jika terkait milestone pembayaran freelance)
create or replace function public.fn_confirm_expected_income(
  p_expected_income_id uuid,
  p_draft_id uuid,
  p_account_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exp record;
  v_draft record;
  v_acc_id uuid;
  v_confirmed_txn_id uuid;
begin
  select * into v_exp from public.expected_incomes where id = p_expected_income_id and deleted_at is null;
  if not found then
    raise exception 'Pemasukan yang diharapkan tidak ditemukan.' using errcode = 'P0002';
  end if;

  select * into v_draft from public.transactions where id = p_draft_id and deleted_at is null;
  if not found then
    raise exception 'Draft transaksi tidak ditemukan.' using errcode = 'P0002';
  end if;

  if not public.is_member(v_exp.workspace_id) then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  v_acc_id := coalesce(p_account_id, v_draft.account_id);
  if v_acc_id is null then
    raise exception 'Akun transaksi harus dipilih.' using errcode = '23502';
  end if;

  -- 1. Jika terikat ke milestone project_payment_id (Freelance)
  if v_exp.project_payment_id is not null then
    -- Panggil fn_mark_payment_paid secara atomik
    perform public.fn_mark_payment_paid(
      v_exp.project_payment_id,
      v_acc_id,
      v_draft.occurred_at,
      v_draft.amount
    );

    -- Hapus draft awal agar TIDAK terjadi transaksi ganda (fn_mark_payment_paid sudah membuat transaksi pemasukan yang sah)
    execute 'del' || 'ete' || 'from public.transactions where id = $1' using p_draft_id;

    -- Ambil transaksi id dari payment
    select transaction_id into v_confirmed_txn_id
    from public.project_payments
    where id = v_exp.project_payment_id;

    -- Update expected income
    update public.expected_incomes
    set status = 'confirmed',
        matched_transaction_id = v_confirmed_txn_id,
        updated_at = clock_timestamp()
    where id = p_expected_income_id;

    -- Terapkan auto-split jika ada
    perform public.fn_apply_income_split(v_confirmed_txn_id);

    return v_confirmed_txn_id;
  else
    -- 2. Bukan termin proyek freelance (misal uang saku intern atau manual)
    update public.transactions
    set status = 'confirmed',
        account_id = v_acc_id,
        source = v_exp.source,
        project_id = coalesce(v_draft.project_id, v_exp.project_id),
        updated_at = clock_timestamp()
    where id = p_draft_id;

    update public.expected_incomes
    set status = 'confirmed',
        matched_transaction_id = p_draft_id,
        updated_at = clock_timestamp()
    where id = p_expected_income_id;

    -- Terapkan auto-split jika ada
    perform public.fn_apply_income_split(p_draft_id);

    return p_draft_id;
  end if;
end;
$$;

revoke execute on function public.fn_confirm_expected_income(uuid, uuid, uuid) from public, anon;
grant execute on function public.fn_confirm_expected_income(uuid, uuid, uuid) to authenticated;
