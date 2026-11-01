-- Orbit Fase 1: fungsi otorisasi, trigger validasi, audit, dan pembuatan pengguna baru.

-- ---------------------------------------------------------------------------
-- Fungsi otorisasi (PRD 9.5)
-- SECURITY DEFINER agar kebijakan RLS pada workspace_members tidak rekursif.
-- search_path dikunci dan keanggotaan selalu diturunkan dari auth.uid().
-- ---------------------------------------------------------------------------

create function public.is_member(p_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workspace_members m
    where m.workspace_id = p_workspace_id
      and m.user_id = (select auth.uid())
  );
$$;

-- Peran bertingkat: owner mencakup editor, editor mencakup viewer.
create function public.has_role(p_workspace_id uuid, p_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workspace_members m
    where m.workspace_id = p_workspace_id
      and m.user_id = (select auth.uid())
      and case m.role
            when 'owner' then 3
            when 'editor' then 2
            else 1
          end >= case p_role
            when 'owner' then 3
            when 'editor' then 2
            else 1
          end
  );
$$;

-- ---------------------------------------------------------------------------
-- Trigger umum
-- ---------------------------------------------------------------------------

-- created_by selalu diturunkan dari sesi, bukan dari client.
create function public.fn_set_created_by()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is not null then
    new.created_by := v_uid;
  end if;
  return new;
end;
$$;

-- Kolom yang tidak boleh berubah setelah baris dibuat. Nama kolom dilewatkan sebagai argumen trigger.
create function public.fn_protect_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_col text;
  v_old jsonb := to_jsonb(old);
  v_new jsonb := to_jsonb(new);
begin
  foreach v_col in array tg_argv loop
    if (v_old ->> v_col) is distinct from (v_new ->> v_col) then
      raise exception 'Kolom % tidak dapat diubah.', v_col using errcode = '42501';
    end if;
  end loop;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'workspaces', 'workspace_members', 'workspace_invites', 'accounts', 'categories',
    'projects', 'transactions', 'transaction_items', 'category_rules', 'tasks',
    'task_checklist_items', 'events', 'event_exceptions'
  ] loop
    execute format(
      'create trigger trg_%1$s_updated_at before update on public.%1$I for each row execute function public.fn_set_updated_at()',
      t
    );
  end loop;

  foreach t in array array[
    'workspace_invites', 'accounts', 'projects', 'transactions', 'category_rules', 'tasks', 'events', 'attachments'
  ] loop
    execute format(
      'create trigger trg_%1$s_created_by before insert on public.%1$I for each row execute function public.fn_set_created_by()',
      t
    );
    execute format(
      'create trigger trg_%1$s_immutable before update on public.%1$I for each row execute function public.fn_protect_immutable(%2$L, %3$L)',
      t, 'workspace_id', 'created_by'
    );
  end loop;
end;
$$;

create trigger trg_categories_immutable before update on public.categories
  for each row execute function public.fn_protect_immutable('workspace_id');
create trigger trg_workspaces_immutable before update on public.workspaces
  for each row execute function public.fn_protect_immutable('owner_id', 'type');
create trigger trg_workspace_members_immutable before update on public.workspace_members
  for each row execute function public.fn_protect_immutable('workspace_id', 'user_id');
create trigger trg_transaction_items_immutable before update on public.transaction_items
  for each row execute function public.fn_protect_immutable('transaction_id');
create trigger trg_task_checklist_items_immutable before update on public.task_checklist_items
  for each row execute function public.fn_protect_immutable('task_id');
create trigger trg_event_exceptions_immutable before update on public.event_exceptions
  for each row execute function public.fn_protect_immutable('event_id');

-- ---------------------------------------------------------------------------
-- Validasi per tabel
-- ---------------------------------------------------------------------------

create function public.fn_validate_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Menolak zona waktu yang tidak dikenal (menimbulkan error 22023).
  perform now() at time zone new.timezone;
  return new;
end;
$$;
create trigger trg_profiles_validate before insert or update on public.profiles
  for each row execute function public.fn_validate_profile();

create function public.fn_validate_event_timezone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform now() at time zone new.timezone;
  return new;
end;
$$;
create trigger trg_events_timezone before insert or update on public.events
  for each row execute function public.fn_validate_event_timezone();

-- Peran owner hanya untuk pemilik workspace, dan keanggotaan pemilik tidak dapat dihapus.
create function public.fn_validate_member()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if tg_op = 'DELETE' then
    select w.owner_id into v_owner from public.workspaces w where w.id = old.workspace_id;
    if v_owner is not null and old.user_id = v_owner then
      raise exception 'Pemilik workspace tidak dapat dikeluarkan.' using errcode = '42501';
    end if;
    return old;
  end if;

  select w.owner_id into v_owner from public.workspaces w where w.id = new.workspace_id;
  if v_owner is null then
    raise exception 'Workspace tidak ditemukan.' using errcode = '23503';
  end if;
  if (new.role = 'owner') is distinct from (new.user_id = v_owner) then
    raise exception 'Peran owner hanya untuk pemilik workspace.' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger trg_workspace_members_validate before insert or update or delete on public.workspace_members
  for each row execute function public.fn_validate_member();

-- Subkategori maksimal 2 level dan satu jenis dengan induknya.
create function public.fn_validate_category()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent record;
begin
  if new.parent_id is not null then
    select c.parent_id, c.type into v_parent
    from public.categories c
    where c.id = new.parent_id and c.workspace_id = new.workspace_id;
    if not found then
      raise exception 'Kategori induk tidak ditemukan.' using errcode = '23503';
    end if;
    if v_parent.parent_id is not null then
      raise exception 'Subkategori maksimal 2 level.' using errcode = '23514';
    end if;
    if v_parent.type <> new.type then
      raise exception 'Jenis subkategori harus sama dengan induknya.' using errcode = '23514';
    end if;
    if tg_op = 'UPDATE' and exists (select 1 from public.categories c where c.parent_id = new.id) then
      raise exception 'Kategori yang punya subkategori tidak dapat menjadi subkategori.' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_categories_validate before insert or update on public.categories
  for each row execute function public.fn_validate_category();

-- Selesai/belum selesai menentukan completed_at.
create function public.fn_task_completed_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'done' then
    new.completed_at := coalesce(new.completed_at, now());
  else
    new.completed_at := null;
  end if;
  return new;
end;
$$;
create trigger trg_tasks_completed_at before insert or update on public.tasks
  for each row execute function public.fn_task_completed_at();

-- Nominal dalam mata uang dasar, mata uang akun, validasi tanggal, dan perlindungan baris transfer.
create function public.fn_transactions_before()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_acc_currency public.currency_code;
  v_base public.currency_code;
  v_rate numeric(20, 8);
  v_transfer_op boolean := coalesce(current_setting('orbit.transfer_op', true), '') = 'on';
begin
  -- Baris transfer hanya dibuat dan diubah lewat fungsi database.
  if tg_op = 'INSERT' then
    if (new.type = 'transfer' or new.transfer_group_id is not null) and not v_transfer_op then
      raise exception 'Transfer dibuat lewat fn_create_transfer.' using errcode = '42501';
    end if;
  else
    if (old.type = 'transfer' or new.type = 'transfer' or old.transfer_group_id is not null) and not v_transfer_op then
      if new.type is distinct from old.type
        or new.account_id is distinct from old.account_id
        or new.amount is distinct from old.amount
        or new.currency is distinct from old.currency
        or new.occurred_at is distinct from old.occurred_at
        or new.status is distinct from old.status
        or new.deleted_at is distinct from old.deleted_at
        or new.transfer_group_id is distinct from old.transfer_group_id
        or new.transfer_direction is distinct from old.transfer_direction
        or new.category_id is distinct from old.category_id then
        raise exception 'Transfer diubah lewat fungsi database. Hapus dan buat ulang.' using errcode = '42501';
      end if;
    end if;
  end if;

  select a.currency into v_acc_currency
  from public.accounts a
  where a.id = new.account_id and a.workspace_id = new.workspace_id;
  if not found then
    raise exception 'Akun tidak ditemukan.' using errcode = '23503';
  end if;

  if new.currency is distinct from v_acc_currency then
    raise exception 'Mata uang transaksi harus sama dengan mata uang akun.' using errcode = '23514';
  end if;

  if new.occurred_at > now() + interval '1 year' then
    raise exception 'Tanggal transaksi tidak boleh lebih dari 1 tahun ke depan.' using errcode = '23514';
  end if;

  if new.status = 'draft' then
    new.draft_state := coalesce(new.draft_state, 'baru');
  else
    new.draft_state := null;
  end if;

  if new.merchant is not null then
    new.merchant_normalized := public.fn_normalize_merchant(new.merchant);
  else
    new.merchant_normalized := null;
  end if;

  -- amount_base dihitung ulang hanya bila komponennya berubah.
  if tg_op = 'UPDATE'
    and new.amount = old.amount
    and new.currency = old.currency
    and new.fx_rate = old.fx_rate
    and new.occurred_at = old.occurred_at then
    new.amount_base := old.amount_base;
    return new;
  end if;

  select w.base_currency into v_base from public.workspaces w where w.id = new.workspace_id;
  if v_base is null then
    raise exception 'Workspace tidak ditemukan.' using errcode = '23503';
  end if;

  if new.currency = v_base then
    new.fx_rate := 1;
    new.amount_base := new.amount;
  else
    if new.fx_rate = 1 then
      select r.rate into v_rate
      from public.exchange_rates r
      where r.from_currency = new.currency
        and r.to_currency = v_base
        and r.date <= (new.occurred_at at time zone 'UTC')::date
      order by r.date desc
      limit 1;
      if v_rate is null then
        raise exception 'Kurs % ke % belum tersedia. Isi kurs manual.', new.currency, v_base using errcode = '23514';
      end if;
      new.fx_rate := v_rate;
    end if;
    new.amount_base := round(new.amount * new.fx_rate, 4);
  end if;
  return new;
end;
$$;
create trigger trg_transactions_before before insert or update on public.transactions
  for each row execute function public.fn_transactions_before();

-- Item transaksi harus sewilayah dengan transaksi induknya.
create function public.fn_validate_item_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ws uuid;
begin
  select t.workspace_id into v_ws from public.transactions t where t.id = new.transaction_id;
  if v_ws is null then
    raise exception 'Transaksi tidak ditemukan.' using errcode = '23503';
  end if;
  if new.category_id is not null and not exists (
    select 1 from public.categories c where c.id = new.category_id and c.workspace_id = v_ws
  ) then
    raise exception 'Kategori tidak ditemukan.' using errcode = '23503';
  end if;
  if new.project_id is not null and not exists (
    select 1 from public.projects p where p.id = new.project_id and p.workspace_id = v_ws
  ) then
    raise exception 'Proyek tidak ditemukan.' using errcode = '23503';
  end if;
  return new;
end;
$$;
create trigger trg_transaction_items_scope before insert or update on public.transaction_items
  for each row execute function public.fn_validate_item_scope();

-- Split: jumlah item berkategori wajib sama dengan total transaksi (diperiksa saat commit).
create function public.fn_check_split_total()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_txn uuid;
  v_amount numeric(20, 4);
  v_sum numeric(20, 4);
  v_split_count integer;
begin
  if tg_table_name = 'transaction_items' then
    v_txn := coalesce(new.transaction_id, old.transaction_id);
  else
    v_txn := coalesce(new.id, old.id);
  end if;

  select t.amount into v_amount from public.transactions t where t.id = v_txn;
  if v_amount is null then
    return null;
  end if;

  select count(*) filter (where i.category_id is not null), coalesce(sum(round(i.qty * i.unit_price, 4)), 0)
    into v_split_count, v_sum
  from public.transaction_items i
  where i.transaction_id = v_txn;

  if v_split_count > 0 and v_sum <> v_amount then
    raise exception 'Jumlah split harus sama dengan total transaksi.' using errcode = '23514';
  end if;
  return null;
end;
$$;
create constraint trigger trg_items_split_total after insert or update or delete on public.transaction_items
  deferrable initially deferred for each row execute function public.fn_check_split_total();
create constraint trigger trg_transactions_split_total after update of amount on public.transactions
  deferrable initially deferred for each row execute function public.fn_check_split_total();

-- Lampiran harus menempel pada baris yang terlihat dan satu workspace.
create function public.fn_validate_attachment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ok boolean;
begin
  v_ok := case new.owner_table
    when 'transactions' then exists (select 1 from public.transactions o where o.id = new.owner_id and o.workspace_id = new.workspace_id)
    when 'projects' then exists (select 1 from public.projects o where o.id = new.owner_id and o.workspace_id = new.workspace_id)
    when 'tasks' then exists (select 1 from public.tasks o where o.id = new.owner_id and o.workspace_id = new.workspace_id)
    when 'events' then exists (select 1 from public.events o where o.id = new.owner_id and o.workspace_id = new.workspace_id)
    else false
  end;
  if not v_ok then
    raise exception 'Induk lampiran tidak ditemukan.' using errcode = '23503';
  end if;
  return new;
end;
$$;
create trigger trg_attachments_validate before insert on public.attachments
  for each row execute function public.fn_validate_attachment();

-- ---------------------------------------------------------------------------
-- Audit log (append-only) dan keamanan
-- ---------------------------------------------------------------------------

create function public.fn_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb;
  v_ws uuid;
  v_diff jsonb;
  v_action public.audit_action;
  v_id uuid;
  v_skip text[] := array['token_hash', 'location', 'override_location'];
begin
  -- Penghapusan berantai dan trigger bersarang tidak dicatat.
  if pg_trigger_depth() > 1 then
    return null;
  end if;

  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
    v_action := 'delete';
  else
    v_row := to_jsonb(new);
    v_action := case tg_op when 'INSERT' then 'insert'::public.audit_action else 'update'::public.audit_action end;
  end if;

  v_id := nullif(v_row ->> 'id', '')::uuid;

  v_ws := case tg_table_name
    when 'workspaces' then v_id
    when 'task_checklist_items' then (select t.workspace_id from public.tasks t where t.id = (v_row ->> 'task_id')::uuid)
    when 'event_exceptions' then (select e.workspace_id from public.events e where e.id = (v_row ->> 'event_id')::uuid)
    when 'transaction_items' then (select x.workspace_id from public.transactions x where x.id = (v_row ->> 'transaction_id')::uuid)
    else nullif(v_row ->> 'workspace_id', '')::uuid
  end;
  if v_ws is null then
    return null;
  end if;

  if tg_op = 'INSERT' then
    v_diff := jsonb_build_object('new', v_row - v_skip);
  elsif tg_op = 'DELETE' then
    v_diff := jsonb_build_object('old', v_row - v_skip);
  else
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('old', o.value, 'new', n.value)), '{}'::jsonb)
      into v_diff
    from jsonb_each(to_jsonb(new)) n
    join jsonb_each(to_jsonb(old)) o on o.key = n.key
    where n.value is distinct from o.value
      and n.key <> 'updated_at'
      and n.key <> all (v_skip);
    if v_diff = '{}'::jsonb then
      return null;
    end if;
  end if;

  insert into public.audit_log (workspace_id, actor_id, table_name, row_id, action, diff)
  values (v_ws, (select auth.uid()), tg_table_name, v_id, v_action, v_diff);
  return null;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'workspaces', 'workspace_members', 'workspace_invites', 'accounts', 'categories', 'category_rules',
    'transactions', 'transaction_items', 'attachments', 'projects', 'tasks', 'task_checklist_items',
    'events', 'event_exceptions'
  ] loop
    execute format(
      'create trigger trg_%1$s_audit after insert or update or delete on public.%1$I for each row execute function public.fn_audit()',
      t
    );
  end loop;
end;
$$;

-- audit_log hanya boleh ditambah. Penghapusan hanya lewat penghapusan berantai (hapus workspace/akun)
-- atau fungsi retensi yang menyetel orbit.audit_purge.
create function public.fn_audit_log_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and (
    pg_trigger_depth() > 1 or coalesce(current_setting('orbit.audit_purge', true), '') = 'on'
  ) then
    return old;
  end if;
  raise exception 'audit_log bersifat append-only.' using errcode = '42501';
end;
$$;
create trigger trg_audit_log_append_only before update or delete on public.audit_log
  for each row execute function public.fn_audit_log_append_only();

-- Mencatat versi yang kalah pada konflik sinkronisasi (PRD bagian 12).
create function public.fn_log_sync_conflict(
  p_workspace_id uuid,
  p_table_name text,
  p_row_id uuid,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_role(p_workspace_id, 'editor') then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;
  if p_table_name not in ('accounts', 'categories', 'transactions', 'tasks', 'events', 'task_checklist_items', 'event_exceptions') then
    raise exception 'Tabel tidak didukung.' using errcode = '22023';
  end if;
  if pg_column_size(p_payload) > 20000 then
    raise exception 'Muatan terlalu besar.' using errcode = '22023';
  end if;
  insert into public.audit_log (workspace_id, actor_id, table_name, row_id, action, diff)
  values (p_workspace_id, (select auth.uid()), p_table_name, p_row_id, 'conflict',
          jsonb_build_object('losing_version', coalesce(p_payload, '{}'::jsonb) - 'location' - 'override_location'));
end;
$$;

-- ---------------------------------------------------------------------------
-- Pengguna baru: profil, workspace pribadi, kategori default, akun Cash
-- ---------------------------------------------------------------------------

create function public.fn_seed_workspace_defaults(p_workspace_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_currency public.currency_code;
begin
  select w.base_currency into v_currency from public.workspaces w where w.id = p_workspace_id;
  if v_currency is null then
    raise exception 'Workspace tidak ditemukan.' using errcode = '23503';
  end if;

  -- Kategori default pengeluaran (PRD M4).
  insert into public.categories (workspace_id, name, type, icon, color, system_key, sort_order)
  values
    (p_workspace_id, 'Makan', 'expense', 'utensils', '#c2410c', null, 10),
    (p_workspace_id, 'Transport', 'expense', 'bus', '#0369a1', null, 20),
    (p_workspace_id, 'Kos', 'expense', 'home', '#7c3aed', null, 30),
    (p_workspace_id, 'Pulsa/Internet', 'expense', 'wifi', '#0f766e', null, 40),
    (p_workspace_id, 'Kuliah', 'expense', 'graduation-cap', '#4338ca', null, 50),
    (p_workspace_id, 'Langganan', 'expense', 'repeat', '#be185d', null, 60),
    (p_workspace_id, 'Hiburan', 'expense', 'gamepad-2', '#a21caf', null, 70),
    (p_workspace_id, 'Tools Proyek', 'expense', 'wrench', '#475569', null, 80),
    (p_workspace_id, 'Belanja', 'expense', 'shopping-bag', '#b45309', null, 90),
    (p_workspace_id, 'Kesehatan', 'expense', 'heart-pulse', '#dc2626', null, 100),
    (p_workspace_id, 'Koreksi saldo', 'expense', 'scale', '#64748b', 'balance_correction', 110),
    (p_workspace_id, 'Lainnya', 'expense', 'ellipsis', '#6b7280', 'other_expense', 120);

  -- Kategori default pemasukan (PRD M4).
  insert into public.categories (workspace_id, name, type, icon, color, system_key, sort_order)
  values
    (p_workspace_id, 'Gaji/Uang Saku Intern', 'income', 'wallet', '#15803d', null, 10),
    (p_workspace_id, 'Proyek Freelance', 'income', 'briefcase', '#0e7490', 'freelance_project', 20),
    (p_workspace_id, 'Kiriman', 'income', 'send', '#4d7c0f', null, 30),
    (p_workspace_id, 'Lainnya', 'income', 'ellipsis', '#6b7280', 'other_income', 40);

  insert into public.accounts (workspace_id, name, type, currency, initial_balance, is_liquid, visibility, icon, color, sort_order, created_by)
  values (p_workspace_id, 'Cash', 'cash', v_currency, 0, true, 'shared', 'banknote', '#15803d', 0, p_user_id);
end;
$$;

create function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ws uuid;
  v_name text;
begin
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    ''
  );

  insert into public.profiles (id, display_name) values (new.id, left(v_name, 100));

  insert into public.workspaces (name, type, owner_id)
  values ('Pribadi', 'personal', new.id)
  returning id into v_ws;

  insert into public.workspace_members (workspace_id, user_id, role) values (v_ws, new.id, 'owner');

  perform public.fn_seed_workspace_defaults(v_ws, new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_user();
