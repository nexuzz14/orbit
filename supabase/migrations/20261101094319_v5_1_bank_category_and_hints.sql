-- ==============================================================================
-- Orbit Migrasi v5.1: Bank Category, Account Match Hints, & Cascade Protection
-- ==============================================================================

-- 1. Tambah kolom match_hints pada tabel accounts untuk pencocokan produk rekening (M3 & M7a/T4)
alter table public.accounts
  add column if not exists match_hints text[] not null default '{}'::text[];

-- 2. Tambah kolom bank_category pada tabel transactions (M7b)
alter table public.transactions
  add column if not exists bank_category text;

-- 3. Tambah nilai 'bank_category' ke enum rule_match_field
alter type public.rule_match_field add value if not exists 'bank_category';

-- Perbarui constraint category_rules_check1 agar mendukung 'bank_category'
alter table public.category_rules
  drop constraint if exists category_rules_check1;

alter table public.category_rules
  add constraint category_rules_check1
  check (
    (match_field in ('merchant', 'product', 'counterparty', 'bank_category') and pattern is not null)
    or (match_field = 'amount' and (amount_min is not null or amount_max is not null))
    or (match_field = 'time' and hour_from is not null and hour_to is not null)
  );

-- 4. Perbarui fn_protect_immutable untuk mengizinkan ON DELETE SET NULL dari auth.users
create or replace function public.fn_protect_immutable()
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
      -- Izinkan ON DELETE SET NULL yang dipicu cascade referensi PostgreSQL (trigger depth > 1)
      if v_col = 'created_by' and (v_new ->> v_col) is null and pg_trigger_depth() > 1 then
        continue;
      end if;
      raise exception 'Kolom % tidak dapat diubah.', v_col using errcode = '42501';
    end if;
  end loop;
  return new;
end;
$$;

-- 5. Perbarui fn_audit agar tidak menyisipkan audit log jika workspace sudah/sedang dihapus
create or replace function public.fn_audit()
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

  -- Jika workspace null atau sudah tidak ada di tabel workspaces (misal cascading delete), abaikan audit log.
  if v_ws is null or not exists (select 1 from public.workspaces w where w.id = v_ws) then
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
