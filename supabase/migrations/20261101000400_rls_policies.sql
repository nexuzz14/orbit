-- Orbit Fase 1: RLS deny-by-default di semua tabel (PRD 9.5) dan hak akses minimum.
-- Matriks peran:
--   viewer: baca saja. editor: baca, tulis data kerja. owner: editor ditambah kelola anggota dan hapus permanen.
-- Tidak ada kebijakan untuk anon: anon tidak punya akses apa pun.

-- Cabut hak bawaan Supabase, lalu beri hak minimum per tabel.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from anon, public;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'workspaces', 'workspace_members', 'workspace_invites', 'accounts', 'categories',
    'category_rules', 'transactions', 'transaction_items', 'attachments', 'exchange_rates',
    'audit_log', 'security_events', 'projects', 'tasks', 'task_checklist_items', 'events', 'event_exceptions'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- profiles: hanya milik sendiri. Baris dibuat oleh trigger pendaftaran.
grant select on public.profiles to authenticated;
grant update (display_name, base_currency, timezone, month_start_day) on public.profiles to authenticated;
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- workspaces: dibuat oleh trigger (pribadi) atau fungsi (berbagi, Fase 6). Hanya owner yang mengubah nama.
grant select on public.workspaces to authenticated;
grant update (name) on public.workspaces to authenticated;
create policy workspaces_select on public.workspaces for select to authenticated
  using (public.is_member(id));
create policy workspaces_update on public.workspaces for update to authenticated
  using (public.has_role(id, 'owner')) with check (public.has_role(id, 'owner'));

-- workspace_members: anggota hanya dapat ditambah pada workspace berbagi.
grant select, insert, update, delete on public.workspace_members to authenticated;
create policy workspace_members_select on public.workspace_members for select to authenticated
  using (public.is_member(workspace_id));
create policy workspace_members_insert on public.workspace_members for insert to authenticated
  with check (
    public.has_role(workspace_id, 'owner')
    and exists (select 1 from public.workspaces w where w.id = workspace_id and w.type = 'shared')
  );
create policy workspace_members_update on public.workspace_members for update to authenticated
  using (public.has_role(workspace_id, 'owner')) with check (public.has_role(workspace_id, 'owner'));
create policy workspace_members_delete on public.workspace_members for delete to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- workspace_invites: hanya owner, hanya workspace berbagi.
grant select, insert, update, delete on public.workspace_invites to authenticated;
create policy workspace_invites_select on public.workspace_invites for select to authenticated
  using (public.has_role(workspace_id, 'owner'));
create policy workspace_invites_insert on public.workspace_invites for insert to authenticated
  with check (
    public.has_role(workspace_id, 'owner')
    and exists (select 1 from public.workspaces w where w.id = workspace_id and w.type = 'shared')
  );
create policy workspace_invites_update on public.workspace_invites for update to authenticated
  using (public.has_role(workspace_id, 'owner')) with check (public.has_role(workspace_id, 'owner'));
create policy workspace_invites_delete on public.workspace_invites for delete to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- accounts: akun privat hanya terlihat pembuatnya.
grant select, insert, update, delete on public.accounts to authenticated;
create policy accounts_select on public.accounts for select to authenticated
  using (public.is_member(workspace_id) and (visibility = 'shared' or created_by = (select auth.uid())));
create policy accounts_insert on public.accounts for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy accounts_update on public.accounts for update to authenticated
  using (public.has_role(workspace_id, 'editor') and (visibility = 'shared' or created_by = (select auth.uid())))
  with check (public.has_role(workspace_id, 'editor'));
create policy accounts_delete on public.accounts for delete to authenticated
  using (public.has_role(workspace_id, 'owner') and (visibility = 'shared' or created_by = (select auth.uid())));

-- categories
grant select, insert, update, delete on public.categories to authenticated;
create policy categories_select on public.categories for select to authenticated
  using (public.is_member(workspace_id));
create policy categories_insert on public.categories for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy categories_update on public.categories for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy categories_delete on public.categories for delete to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- category_rules
grant select, insert, update, delete on public.category_rules to authenticated;
create policy category_rules_select on public.category_rules for select to authenticated
  using (public.is_member(workspace_id));
create policy category_rules_insert on public.category_rules for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy category_rules_update on public.category_rules for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy category_rules_delete on public.category_rules for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- transactions: tanpa hapus permanen dari client (soft delete, dibersihkan job retensi 30 hari).
-- Transaksi pada akun privat mengikuti visibilitas akun lewat subquery yang tunduk pada RLS accounts.
grant select, insert, update on public.transactions to authenticated;
create policy transactions_select on public.transactions for select to authenticated
  using (public.is_member(workspace_id) and account_id in (select a.id from public.accounts a));
create policy transactions_insert on public.transactions for insert to authenticated
  with check (public.has_role(workspace_id, 'editor') and account_id in (select a.id from public.accounts a));
create policy transactions_update on public.transactions for update to authenticated
  using (public.has_role(workspace_id, 'editor') and account_id in (select a.id from public.accounts a))
  with check (public.has_role(workspace_id, 'editor') and account_id in (select a.id from public.accounts a));

-- transaction_items: lewat induk (subquery tunduk pada RLS transactions).
grant select, insert, update, delete on public.transaction_items to authenticated;
create policy transaction_items_select on public.transaction_items for select to authenticated
  using (exists (select 1 from public.transactions t where t.id = transaction_id));
create policy transaction_items_insert on public.transaction_items for insert to authenticated
  with check (exists (
    select 1 from public.transactions t where t.id = transaction_id and public.has_role(t.workspace_id, 'editor')
  ));
create policy transaction_items_update on public.transaction_items for update to authenticated
  using (exists (
    select 1 from public.transactions t where t.id = transaction_id and public.has_role(t.workspace_id, 'editor')
  ))
  with check (exists (
    select 1 from public.transactions t where t.id = transaction_id and public.has_role(t.workspace_id, 'editor')
  ));
create policy transaction_items_delete on public.transaction_items for delete to authenticated
  using (exists (
    select 1 from public.transactions t where t.id = transaction_id and public.has_role(t.workspace_id, 'editor')
  ));

-- attachments: tanpa update (ganti = hapus lalu unggah ulang).
grant select, insert, delete on public.attachments to authenticated;
create policy attachments_select on public.attachments for select to authenticated
  using (public.is_member(workspace_id));
create policy attachments_insert on public.attachments for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy attachments_delete on public.attachments for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

-- exchange_rates: data referensi, hanya baca. Pengisian oleh service role (cron).
grant select on public.exchange_rates to authenticated;
create policy exchange_rates_select on public.exchange_rates for select to authenticated
  using (true);

-- audit_log: hanya owner yang membaca. Penulisan hanya lewat trigger/fungsi SECURITY DEFINER.
grant select on public.audit_log to authenticated;
create policy audit_log_select on public.audit_log for select to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- security_events: pengguna membaca dan menambah peristiwanya sendiri, tanpa ubah atau hapus.
grant select, insert on public.security_events to authenticated;
create policy security_events_select on public.security_events for select to authenticated
  using (user_id = (select auth.uid()));
create policy security_events_insert on public.security_events for insert to authenticated
  with check (user_id = (select auth.uid()));

-- projects
grant select, insert, update, delete on public.projects to authenticated;
create policy projects_select on public.projects for select to authenticated
  using (public.is_member(workspace_id));
create policy projects_insert on public.projects for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy projects_update on public.projects for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy projects_delete on public.projects for delete to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- tasks
grant select, insert, update, delete on public.tasks to authenticated;
create policy tasks_select on public.tasks for select to authenticated
  using (public.is_member(workspace_id));
create policy tasks_insert on public.tasks for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy tasks_update on public.tasks for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy tasks_delete on public.tasks for delete to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- task_checklist_items: lewat induk.
grant select, insert, update, delete on public.task_checklist_items to authenticated;
create policy task_checklist_items_select on public.task_checklist_items for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id));
create policy task_checklist_items_insert on public.task_checklist_items for insert to authenticated
  with check (exists (select 1 from public.tasks t where t.id = task_id and public.has_role(t.workspace_id, 'editor')));
create policy task_checklist_items_update on public.task_checklist_items for update to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and public.has_role(t.workspace_id, 'editor')))
  with check (exists (select 1 from public.tasks t where t.id = task_id and public.has_role(t.workspace_id, 'editor')));
create policy task_checklist_items_delete on public.task_checklist_items for delete to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and public.has_role(t.workspace_id, 'editor')));

-- events
grant select, insert, update, delete on public.events to authenticated;
create policy events_select on public.events for select to authenticated
  using (public.is_member(workspace_id));
create policy events_insert on public.events for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy events_update on public.events for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy events_delete on public.events for delete to authenticated
  using (public.has_role(workspace_id, 'owner'));

-- event_exceptions: lewat induk.
grant select, insert, update, delete on public.event_exceptions to authenticated;
create policy event_exceptions_select on public.event_exceptions for select to authenticated
  using (exists (select 1 from public.events e where e.id = event_id));
create policy event_exceptions_insert on public.event_exceptions for insert to authenticated
  with check (exists (select 1 from public.events e where e.id = event_id and public.has_role(e.workspace_id, 'editor')));
create policy event_exceptions_update on public.event_exceptions for update to authenticated
  using (exists (select 1 from public.events e where e.id = event_id and public.has_role(e.workspace_id, 'editor')))
  with check (exists (select 1 from public.events e where e.id = event_id and public.has_role(e.workspace_id, 'editor')));
create policy event_exceptions_delete on public.event_exceptions for delete to authenticated
  using (exists (select 1 from public.events e where e.id = event_id and public.has_role(e.workspace_id, 'editor')));

-- Hak eksekusi fungsi: anon tidak boleh memanggil apa pun; trigger dan fungsi internal tidak dipanggil client.
revoke execute on all functions in schema public from public, anon;
revoke execute on function
  public.fn_set_updated_at(), public.fn_set_created_by(), public.fn_protect_immutable(),
  public.fn_validate_profile(), public.fn_validate_event_timezone(), public.fn_validate_member(),
  public.fn_validate_category(), public.fn_task_completed_at(), public.fn_transactions_before(),
  public.fn_validate_item_scope(), public.fn_check_split_total(), public.fn_validate_attachment(),
  public.fn_audit(), public.fn_audit_log_append_only(), public.fn_handle_new_user(),
  public.fn_seed_workspace_defaults(uuid, uuid)
  from authenticated;
grant execute on function
  public.is_member(uuid), public.has_role(uuid, public.user_role),
  public.fn_normalize_merchant(text), public.fn_log_sync_conflict(uuid, text, uuid, jsonb)
  to authenticated;
