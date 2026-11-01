-- Orbit Fase 1: tabel inti (workspace, akun, kategori, transaksi) dan tabel kerja yang disiapkan sejak awal.
-- Konvensi: id uuid, created_at/updated_at, deleted_at untuk soft delete, uang numeric(20,4),
-- tabel bisnis memakai workspace_id. Foreign key komposit (id, workspace_id) menjaga isolasi
-- antar workspace di level database.

-- ---------------------------------------------------------------------------
-- Pengguna dan workspace
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 100),
  base_currency public.currency_code not null default 'IDR',
  timezone text not null default 'Asia/Jakarta' check (char_length(timezone) between 1 and 64),
  month_start_day smallint not null default 1 check (month_start_day between 1 and 28),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  type public.workspace_type not null default 'personal',
  base_currency public.currency_code not null default 'IDR',
  owner_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Satu workspace pribadi per pemilik.
create unique index workspaces_one_personal_per_owner on public.workspaces (owner_id) where type = 'personal';
create index workspaces_owner_idx on public.workspaces (owner_id);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.user_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);
create index workspace_members_user_idx on public.workspace_members (user_id);

create table public.workspace_invites (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  email text not null check (email = lower(email) and char_length(email) <= 254),
  role public.user_role not null check (role in ('editor', 'viewer')),
  -- SHA-256 heksadesimal dari token undangan. Token asli tidak pernah disimpan.
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > created_at)
);
create index workspace_invites_workspace_idx on public.workspace_invites (workspace_id);

-- ---------------------------------------------------------------------------
-- Akun dan kategori
-- ---------------------------------------------------------------------------

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  type public.account_type not null,
  currency public.currency_code not null,
  initial_balance numeric(20, 4) not null default 0,
  is_liquid boolean not null default true,
  visibility public.account_visibility not null default 'shared',
  color text check (color ~ '^#[0-9a-fA-F]{6}$'),
  icon text check (char_length(icon) <= 40),
  sort_order integer not null default 0,
  archived boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, workspace_id)
);
create unique index accounts_workspace_name_uq on public.accounts (workspace_id, lower(name)) where deleted_at is null;
create index accounts_workspace_sort_idx on public.accounts (workspace_id, sort_order);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  type public.category_type not null,
  icon text check (char_length(icon) <= 40),
  color text check (color ~ '^#[0-9a-fA-F]{6}$'),
  parent_id uuid,
  -- Kunci sistem untuk kategori yang dipakai fungsi database (koreksi saldo, proyek freelance, dll).
  system_key text check (system_key in ('balance_correction', 'freelance_project', 'other_expense', 'other_income')),
  sort_order integer not null default 0,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, workspace_id),
  foreign key (parent_id, workspace_id) references public.categories (id, workspace_id),
  check (parent_id is distinct from id)
);
create unique index categories_workspace_name_uq on public.categories (
  workspace_id, type, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name)
) where deleted_at is null;
create unique index categories_system_key_uq on public.categories (workspace_id, system_key) where system_key is not null;
create index categories_workspace_idx on public.categories (workspace_id, type, sort_order);

-- ---------------------------------------------------------------------------
-- Proyek/kegiatan umum (PRD M10, versi 5)
-- ---------------------------------------------------------------------------

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  kind public.activity_kind not null,
  name text not null check (char_length(name) between 1 and 200),
  description text check (char_length(description) <= 20000),
  status public.project_status not null default 'berjalan',
  started_on date,
  deadline date,
  color text check (color ~ '^#[0-9a-fA-F]{6}$'),
  archived boolean not null default false,
  tags text[] not null default '{}' check (cardinality(tags) <= 20),
  -- Klien (freelance) atau instansi (magang).
  client_name text check (char_length(client_name) <= 200),
  -- Khusus freelance.
  contract_value numeric(20, 4) check (contract_value >= 0),
  currency public.currency_code,
  platform_fee_percent numeric(5, 2) check (platform_fee_percent between 0 and 100),
  fee_mode public.fee_mode,
  -- Khusus kuliah.
  semester smallint check (semester between 1 and 20),
  course_code text check (char_length(course_code) <= 30),
  credits smallint check (credits between 0 and 30),
  -- Khusus magang.
  stipend_amount numeric(20, 4) check (stipend_amount > 0),
  stipend_day smallint check (stipend_day between 1 and 31),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, workspace_id),
  constraint projects_freelance_fields check (
    kind = 'freelance'
    or (contract_value is null and currency is null and platform_fee_percent is null and fee_mode is null)
  ),
  constraint projects_kuliah_fields check (
    kind = 'kuliah' or (semester is null and course_code is null and credits is null)
  ),
  constraint projects_intern_fields check (
    kind = 'intern' or (stipend_amount is null and stipend_day is null)
  ),
  constraint projects_contract_currency check ((contract_value is null) = (currency is null)),
  constraint projects_fee_mode_required check (platform_fee_percent is null or fee_mode is not null),
  constraint projects_dates_order check (started_on is null or deadline is null or deadline >= started_on)
);
create index projects_workspace_idx on public.projects (workspace_id, kind, status);

-- ---------------------------------------------------------------------------
-- Transaksi
-- ---------------------------------------------------------------------------

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  account_id uuid not null,
  category_id uuid,
  project_id uuid,
  type public.transaction_type not null,
  status public.transaction_status not null default 'confirmed',
  draft_state public.draft_state,
  amount numeric(20, 4) not null check (amount > 0),
  currency public.currency_code not null,
  fx_rate numeric(20, 8) not null default 1 check (fx_rate > 0),
  -- Dihitung trigger database. Nilai dari client diabaikan.
  amount_base numeric(20, 4) not null check (amount_base > 0),
  source public.transaction_source,
  merchant text check (char_length(merchant) <= 200),
  merchant_normalized text check (char_length(merchant_normalized) <= 200),
  location_hint text check (char_length(location_hint) <= 100),
  counterparty text check (char_length(counterparty) <= 200),
  counterparty_bank text check (char_length(counterparty_bank) <= 100),
  product_name text check (char_length(product_name) <= 200),
  txn_kind text check (char_length(txn_kind) <= 60),
  note text check (char_length(note) <= 500),
  occurred_at timestamptz not null default now(),
  transfer_group_id uuid,
  transfer_direction public.transfer_direction,
  origin public.transaction_origin not null default 'manual',
  source_package text check (char_length(source_package) <= 200),
  import_batch_id uuid,
  -- Hanya hash SHA-256 heksadesimal. Nomor referensi asli tidak boleh disimpan (PRD M7a).
  external_id_hash text check (external_id_hash ~ '^[0-9a-f]{64}$'),
  dedupe_hash text check (dedupe_hash ~ '^[0-9a-f]{64}$'),
  tags text[] not null default '{}' check (cardinality(tags) <= 20),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, workspace_id),
  foreign key (account_id, workspace_id) references public.accounts (id, workspace_id),
  foreign key (category_id, workspace_id) references public.categories (id, workspace_id),
  foreign key (project_id, workspace_id) references public.projects (id, workspace_id),
  constraint transactions_draft_state_consistent check (
    (status = 'draft' and draft_state is not null) or (status = 'confirmed' and draft_state is null)
  ),
  constraint transactions_transfer_shape check (
    (type = 'transfer') = (transfer_direction is not null)
    and (type <> 'transfer' or (transfer_group_id is not null and category_id is null))
  ),
  constraint transactions_confirmed_complete check (
    status = 'draft' or type = 'transfer' or (category_id is not null and source is not null)
  )
);
create unique index transactions_external_id_uq on public.transactions (workspace_id, external_id_hash)
  where external_id_hash is not null;
create unique index transactions_dedupe_uq on public.transactions (workspace_id, dedupe_hash)
  where dedupe_hash is not null;
create index transactions_workspace_occurred_idx on public.transactions (workspace_id, occurred_at);
create index transactions_workspace_account_idx on public.transactions (workspace_id, account_id);
create index transactions_workspace_category_idx on public.transactions (workspace_id, category_id);
create index transactions_workspace_merchant_idx on public.transactions (workspace_id, merchant_normalized);
create index transactions_workspace_status_idx on public.transactions (workspace_id, status) where deleted_at is null;
create index transactions_transfer_group_idx on public.transactions (transfer_group_id) where transfer_group_id is not null;
create index transactions_project_idx on public.transactions (workspace_id, project_id) where project_id is not null;
create index transactions_account_idx on public.transactions (account_id);

create table public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  qty numeric(12, 3) not null default 1 check (qty > 0),
  unit_price numeric(20, 4) not null check (unit_price >= 0),
  category_id uuid references public.categories (id),
  project_id uuid references public.projects (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index transaction_items_txn_idx on public.transaction_items (transaction_id);

create table public.category_rules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  match_field public.rule_match_field not null,
  pattern text check (char_length(pattern) <= 200),
  match_type public.rule_match_type not null default 'contains',
  amount_min numeric(20, 4) check (amount_min >= 0),
  amount_max numeric(20, 4) check (amount_max >= 0),
  day_of_month smallint check (day_of_month between 1 and 31),
  hour_from smallint check (hour_from between 0 and 23),
  hour_to smallint check (hour_to between 0 and 23),
  category_id uuid not null,
  account_id uuid,
  source public.transaction_source,
  project_id uuid,
  priority integer not null default 0,
  auto_apply boolean not null default false,
  confirm_count integer not null default 0 check (confirm_count >= 0),
  enabled boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (category_id, workspace_id) references public.categories (id, workspace_id),
  foreign key (account_id, workspace_id) references public.accounts (id, workspace_id),
  foreign key (project_id, workspace_id) references public.projects (id, workspace_id),
  check (amount_min is null or amount_max is null or amount_min <= amount_max),
  check (
    (match_field in ('merchant', 'product', 'counterparty') and pattern is not null)
    or (match_field = 'amount' and (amount_min is not null or amount_max is not null))
    or (match_field = 'time' and hour_from is not null and hour_to is not null)
  ),
  -- Terapkan otomatis hanya untuk aturan yang sudah dikonfirmasi minimal 3 kali (PRD M4).
  check (not auto_apply or confirm_count >= 3)
);
create index category_rules_workspace_idx on public.category_rules (workspace_id, priority desc);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  owner_table text not null check (owner_table in ('transactions', 'projects', 'tasks', 'events')),
  owner_id uuid not null,
  storage_path text not null check (char_length(storage_path) between 1 and 300),
  mime text not null check (mime in ('image/png', 'image/jpeg', 'image/webp', 'application/pdf')),
  size integer not null check (size > 0 and size <= 10485760),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (storage_path),
  -- Berkas harus berada di folder workspace sendiri.
  check (storage_path like workspace_id::text || '/%')
);
create index attachments_owner_idx on public.attachments (owner_table, owner_id);
create index attachments_workspace_idx on public.attachments (workspace_id);

create table public.exchange_rates (
  date date not null,
  from_currency public.currency_code not null,
  to_currency public.currency_code not null,
  rate numeric(20, 8) not null check (rate > 0),
  source text not null default 'unknown' check (char_length(source) <= 60),
  created_at timestamptz not null default now(),
  primary key (date, from_currency, to_currency),
  check (from_currency <> to_currency)
);

-- ---------------------------------------------------------------------------
-- Tabel kerja yang disiapkan sejak awal (UI dikerjakan di Fase 2)
-- ---------------------------------------------------------------------------

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  project_id uuid,
  kind public.activity_kind not null,
  title text not null check (char_length(title) between 1 and 300),
  description text check (char_length(description) <= 20000),
  status public.task_status not null default 'todo',
  priority public.task_priority not null default 'sedang',
  due_at timestamptz,
  due_is_date_only boolean not null default false,
  estimate_minutes integer check (estimate_minutes > 0),
  completed_at timestamptz,
  -- Mengacu ke project_payments; foreign key ditambahkan saat tabel itu dibuat (Fase 2).
  milestone_payment_id uuid,
  tags text[] not null default '{}' check (cardinality(tags) <= 20),
  sort_order integer not null default 0,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, workspace_id),
  foreign key (project_id, workspace_id) references public.projects (id, workspace_id),
  constraint tasks_date_only_needs_due check (not due_is_date_only or due_at is not null),
  constraint tasks_completed_consistent check ((status = 'done') = (completed_at is not null))
);
create index tasks_workspace_due_idx on public.tasks (workspace_id, due_at);
create index tasks_workspace_status_idx on public.tasks (workspace_id, status);
create index tasks_project_idx on public.tasks (project_id) where project_id is not null;

create table public.task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  text text not null check (char_length(text) between 1 and 300),
  done boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index task_checklist_items_task_idx on public.task_checklist_items (task_id, sort_order);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  project_id uuid,
  kind public.activity_kind not null,
  title text not null check (char_length(title) between 1 and 300),
  description text check (char_length(description) <= 20000),
  -- Lokasi adalah data pribadi: tidak boleh masuk log atau analitik.
  location text check (char_length(location) <= 300),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  timezone text not null default 'Asia/Jakarta' check (char_length(timezone) between 1 and 64),
  -- freq (daily/weekly/monthly), interval, byweekday (0-6), bymonthday (1-31), until, count.
  recurrence jsonb,
  reminder_minutes integer[] not null default '{30}',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, workspace_id),
  foreign key (project_id, workspace_id) references public.projects (id, workspace_id),
  constraint events_time_order check (ends_at >= starts_at),
  constraint events_reminders_valid check (
    cardinality(reminder_minutes) <= 10 and 0 <= all (reminder_minutes)
  ),
  constraint events_recurrence_shape check (
    recurrence is null
    or (
      jsonb_typeof(recurrence) = 'object'
      and recurrence ->> 'freq' in ('daily', 'weekly', 'monthly')
    )
  )
);
create index events_workspace_starts_idx on public.events (workspace_id, starts_at);

create table public.event_exceptions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  original_date date not null,
  action public.exception_action not null,
  override_starts_at timestamptz,
  override_ends_at timestamptz,
  override_title text check (char_length(override_title) <= 300),
  override_location text check (char_length(override_location) <= 300),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, original_date),
  constraint event_exceptions_skip_empty check (
    action = 'override'
    or (override_starts_at is null and override_ends_at is null and override_title is null and override_location is null)
  ),
  constraint event_exceptions_time_order check (
    override_starts_at is null or override_ends_at is null or override_ends_at >= override_starts_at
  )
);

-- ---------------------------------------------------------------------------
-- Audit dan keamanan
-- ---------------------------------------------------------------------------

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  actor_id uuid,
  table_name text not null,
  row_id uuid,
  action public.audit_action not null,
  diff jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index audit_log_workspace_at_idx on public.audit_log (workspace_id, at desc);
create index audit_log_row_idx on public.audit_log (table_name, row_id);

create table public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type public.security_event_type not null,
  -- Hash IP (HMAC dengan garam server). IP asli tidak disimpan.
  ip_hash text check (char_length(ip_hash) <= 128),
  user_agent text check (char_length(user_agent) <= 300),
  at timestamptz not null default now()
);
create index security_events_user_at_idx on public.security_events (user_id, at desc);
