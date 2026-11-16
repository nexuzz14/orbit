-- ==============================================================================
-- Orbit Migrasi v5.2 (Bagian 2): Alur Kerja Tugas D.2 & Fitur Dasar Notion/Jira
-- Mencakup: progress_percent, revision_count, latest_revision_note, status_changed_at,
-- parent_task_id (subtugas bertingkat), assignee_id, recurrence_rule, description_blocks,
-- task_status_history (append-only), fn_change_task_status, dan sinkron progres checklist.
-- ==============================================================================

-- 1. Tambah kolom D.2 dan v5.3 pada public.tasks
alter table public.tasks
  add column if not exists progress_percent smallint not null default 0
    check (progress_percent between 0 and 100),
  add column if not exists revision_count integer not null default 0
    check (revision_count >= 0),
  add column if not exists latest_revision_note text
    check (char_length(latest_revision_note) <= 1000),
  add column if not exists status_changed_at timestamptz not null default now(),
  add column if not exists parent_task_id uuid,
  add column if not exists assignee_id uuid references auth.users (id) on delete set null,
  add column if not exists description_blocks jsonb,
  add column if not exists recurrence_rule jsonb,
  add column if not exists recurrence_parent_id uuid;

-- Constraint unik komposit (id, workspace_id) sudah ada di core_tables.sql,
-- tambahkan FK swa-rujuk parent_task_id & recurrence_parent_id secara idempoten.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'tasks_parent_task_fk'
  ) then
    alter table public.tasks
      add constraint tasks_parent_task_fk
      foreign key (parent_task_id, workspace_id)
      references public.tasks (id, workspace_id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'tasks_parent_not_self'
  ) then
    alter table public.tasks
      add constraint tasks_parent_not_self
      check (parent_task_id is distinct from id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'tasks_recurrence_shape'
  ) then
    alter table public.tasks
      add constraint tasks_recurrence_shape
      check (
        recurrence_rule is null
        or (
          jsonb_typeof(recurrence_rule) = 'object'
          and recurrence_rule ->> 'freq' in ('daily', 'weekly', 'monthly')
        )
      );
  end if;
end;
$$;

-- Backfill progres tugas yang sudah berstatus 'done' sebelum migrasi
update public.tasks
set progress_percent = 100,
    status_changed_at = coalesce(completed_at, updated_at, created_at)
where status = 'done'
  and progress_percent = 0;

create index if not exists tasks_workspace_kanban_idx
  on public.tasks (workspace_id, status, sort_order)
  where deleted_at is null;

create index if not exists tasks_parent_idx
  on public.tasks (parent_task_id)
  where parent_task_id is not null and deleted_at is null;

create index if not exists tasks_assignee_idx
  on public.tasks (workspace_id, assignee_id)
  where assignee_id is not null and deleted_at is null;

-- 2. Tabel append-only task_status_history (audit transisi status D.2)
create table if not exists public.task_status_history (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  task_id uuid not null,
  from_status public.task_status,
  to_status public.task_status not null,
  note text check (char_length(note) <= 1000),
  changed_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  foreign key (task_id, workspace_id) references public.tasks (id, workspace_id) on delete cascade,
  constraint task_status_history_revisi_note_req check (
    to_status <> 'revisi' or (note is not null and char_length(trim(note)) > 0)
  )
);

create index if not exists task_status_history_task_idx
  on public.task_status_history (task_id, created_at desc);

create index if not exists task_status_history_workspace_idx
  on public.task_status_history (workspace_id, created_at desc);

alter table public.task_status_history enable row level security;
alter table public.task_status_history force row level security;

revoke all on public.task_status_history from anon, public;
grant select, insert on public.task_status_history to authenticated;

create policy task_status_history_select on public.task_status_history
  for select to authenticated
  using (public.is_member(workspace_id));

create policy task_status_history_insert on public.task_status_history
  for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));

create or replace function public.fn_task_status_history_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'task_status_history bersifat append-only dan tidak dapat diubah atau dihapus.'
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_task_status_history_no_mutate on public.task_status_history;
create trigger trg_task_status_history_no_mutate
  before update or delete on public.task_status_history
  for each row execute function public.fn_task_status_history_append_only();

-- 3. Validasi & pembaruan status tugas D.2 pada BEFORE INSERT/UPDATE tasks
create or replace function public.fn_tasks_d2_before()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_session_note text := nullif(trim(coalesce(current_setting('orbit.status_note', true), '')), '');
begin
  if tg_op = 'INSERT' then
    if new.status = 'done' then
      new.progress_percent := 100;
    end if;
    if new.status = 'revisi' then
      new.latest_revision_note := coalesce(nullif(trim(coalesce(new.latest_revision_note, '')), ''), v_session_note);
      if new.latest_revision_note is null then
        raise exception 'Catatan alasan wajib diisi saat tugas masuk status Revisi.'
          using errcode = '23514';
      end if;
      if new.revision_count = 0 then
        new.revision_count := 1;
      end if;
    end if;
    return new;
  end if;

  -- tg_op = 'UPDATE'
  if new.status is distinct from old.status then
    new.status_changed_at := clock_timestamp();
    if new.status = 'done' then
      new.progress_percent := 100;
    elsif new.status = 'revisi' then
      new.latest_revision_note := coalesce(
        v_session_note,
        nullif(trim(coalesce(new.latest_revision_note, '')), '')
      );
      if new.latest_revision_note is null or new.latest_revision_note is not distinct from old.latest_revision_note and v_session_note is null then
        -- Wajib ada catatan alasan eksplisit jika masuk Revisi
        if new.latest_revision_note is null then
          raise exception 'Catatan alasan wajib diisi saat status berpindah ke Revisi.'
            using errcode = '23514';
        end if;
      end if;
      if coalesce(current_setting('orbit.revision_already_counted', true), '') <> 'on' then
        new.revision_count := old.revision_count + 1;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_tasks_d2_before on public.tasks;
create trigger trg_tasks_d2_before
  before insert or update on public.tasks
  for each row execute function public.fn_tasks_d2_before();

-- 4. Catat riwayat status ke task_status_history saat status berubah atau baris baru dibuat
create or replace function public.fn_tasks_d2_after_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_managed boolean := coalesce(current_setting('orbit.status_trigger_managed', true), '') = 'on';
  v_actor uuid := coalesce(auth.uid(), new.created_by);
  v_note text;
begin
  if v_managed then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_note := case when new.status = 'revisi' then new.latest_revision_note else null end;
    insert into public.task_status_history (
      workspace_id, task_id, from_status, to_status, note, changed_by
    ) values (
      new.workspace_id, new.id, null, new.status, v_note, v_actor
    );
    return new;
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    v_note := case
      when new.status = 'revisi' then new.latest_revision_note
      else nullif(trim(coalesce(current_setting('orbit.status_note', true), '')), '')
    end;
    insert into public.task_status_history (
      workspace_id, task_id, from_status, to_status, note, changed_by
    ) values (
      new.workspace_id, new.id, old.status, new.status, v_note, v_actor
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_tasks_d2_after_history on public.tasks;
create trigger trg_tasks_d2_after_history
  after insert or update on public.tasks
  for each row execute function public.fn_tasks_d2_after_history();

-- 5. Sinkronisasi otomatis progress_percent dari checklist item dan subtugas
create or replace function public.fn_recompute_task_progress(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks;
  v_cl_total integer;
  v_cl_done integer;
  v_sub_total integer;
  v_sub_done integer;
  v_next_progress smallint;
begin
  select * into v_task from public.tasks where id = p_task_id and deleted_at is null;
  if not found then
    return;
  end if;

  if v_task.status = 'done' then
    if v_task.progress_percent <> 100 then
      update public.tasks set progress_percent = 100 where id = p_task_id;
    end if;
    return;
  end if;

  select count(*)::integer, count(*) filter (where done)::integer
  into v_cl_total, v_cl_done
  from public.task_checklist_items
  where task_id = p_task_id;

  if v_cl_total > 0 then
    v_next_progress := round((v_cl_done::numeric * 100.0) / v_cl_total::numeric)::smallint;
    if v_next_progress is distinct from v_task.progress_percent then
      update public.tasks set progress_percent = v_next_progress where id = p_task_id;
    end if;
    return;
  end if;

  select count(*)::integer, count(*) filter (where status = 'done')::integer
  into v_sub_total, v_sub_done
  from public.tasks
  where parent_task_id = p_task_id and deleted_at is null;

  if v_sub_total > 0 then
    v_next_progress := round((v_sub_done::numeric * 100.0) / v_sub_total::numeric)::smallint;
    if v_next_progress is distinct from v_task.progress_percent then
      update public.tasks set progress_percent = v_next_progress where id = p_task_id;
    end if;
  end if;
end;
$$;

create or replace function public.fn_trg_checklist_progress()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 3 then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    perform public.fn_recompute_task_progress(old.task_id);
    return old;
  end if;

  perform public.fn_recompute_task_progress(new.task_id);
  return new;
end;
$$;

drop trigger if exists trg_task_checklist_progress on public.task_checklist_items;
create trigger trg_task_checklist_progress
  after insert or update or delete on public.task_checklist_items
  for each row execute function public.fn_trg_checklist_progress();

create or replace function public.fn_trg_subtask_progress()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 3 then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    if old.parent_task_id is not null then
      perform public.fn_recompute_task_progress(old.parent_task_id);
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.parent_task_id is distinct from new.parent_task_id and old.parent_task_id is not null then
    perform public.fn_recompute_task_progress(old.parent_task_id);
  end if;

  if new.parent_task_id is not null then
    perform public.fn_recompute_task_progress(new.parent_task_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tasks_subtask_progress on public.tasks;
create trigger trg_tasks_subtask_progress
  after insert or update or delete on public.tasks
  for each row execute function public.fn_trg_subtask_progress();

-- 6. RPC fn_change_task_status (Kanban drag-drop & transisi status beraturan D.2)
create or replace function public.fn_change_task_status(
  p_task_id uuid,
  p_to_status public.task_status,
  p_note text default null,
  p_sort_order integer default null
)
returns public.tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks;
  v_old_status public.task_status;
  v_clean_note text := nullif(trim(coalesce(p_note, '')), '');
  v_cl_total integer;
  v_cl_done integer;
  v_sub_total integer;
  v_sub_done integer;
  v_next_progress smallint;
  v_next_completed timestamptz;
begin
  select * into v_task
  from public.tasks
  where id = p_task_id and deleted_at is null;

  if not found then
    raise exception 'Tugas tidak ditemukan.' using errcode = 'P0002';
  end if;

  if not public.has_role(v_task.workspace_id, 'editor') then
    raise exception 'Hak akses ditolak.' using errcode = '42501';
  end if;

  v_old_status := v_task.status;

  if p_to_status = 'revisi' and v_old_status is distinct from 'revisi' and v_clean_note is null then
    raise exception 'Catatan alasan wajib diisi saat memindahkan tugas ke Revisi.'
      using errcode = '23514';
  end if;

  v_next_progress := v_task.progress_percent;
  if p_to_status = 'done' then
    v_next_progress := 100;
    v_next_completed := coalesce(v_task.completed_at, clock_timestamp());
  else
    v_next_completed := null;
    if v_old_status = 'done' then
      select count(*)::integer, count(*) filter (where done)::integer
      into v_cl_total, v_cl_done
      from public.task_checklist_items
      where task_id = p_task_id;

      if v_cl_total > 0 then
        v_next_progress := round((v_cl_done::numeric * 100.0) / v_cl_total::numeric)::smallint;
      else
        select count(*)::integer, count(*) filter (where status = 'done')::integer
        into v_sub_total, v_sub_done
        from public.tasks
        where parent_task_id = p_task_id and deleted_at is null;
        if v_sub_total > 0 then
          v_next_progress := round((v_sub_done::numeric * 100.0) / v_sub_total::numeric)::smallint;
        else
          v_next_progress := 0;
        end if;
      end if;
    end if;
  end if;

  perform set_config('orbit.status_trigger_managed', 'on', true);
  perform set_config('orbit.revision_already_counted', 'on', true);
  perform set_config('orbit.status_note', coalesce(v_clean_note, ''), true);

  update public.tasks
  set status = p_to_status,
      completed_at = v_next_completed,
      progress_percent = v_next_progress,
      revision_count = case
        when p_to_status = 'revisi' and v_old_status is distinct from 'revisi'
          then v_task.revision_count + 1
        else v_task.revision_count
      end,
      latest_revision_note = case
        when p_to_status = 'revisi' and v_clean_note is not null then v_clean_note
        else v_task.latest_revision_note
      end,
      sort_order = coalesce(p_sort_order, v_task.sort_order),
      status_changed_at = case
        when p_to_status is distinct from v_old_status then clock_timestamp()
        else v_task.status_changed_at
      end,
      updated_at = clock_timestamp()
  where id = p_task_id
  returning * into v_task;

  if p_to_status is distinct from v_old_status then
    insert into public.task_status_history (
      workspace_id, task_id, from_status, to_status, note, changed_by
    ) values (
      v_task.workspace_id, v_task.id, v_old_status, p_to_status, v_clean_note, auth.uid()
    );
  end if;

  return v_task;
end;
$$;

-- 7. Perbarui fn_complete_task agar memakai alur D.2 dan mencatat riwayat
create or replace function public.fn_complete_task(p_task_id uuid)
returns public.tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks;
  v_target public.task_status;
begin
  select * into v_task from public.tasks where id = p_task_id and deleted_at is null;
  if not found then
    raise exception 'Tugas tidak ditemukan.' using errcode = 'P0002';
  end if;

  v_target := case when v_task.status = 'done' then 'todo'::public.task_status else 'done'::public.task_status end;
  return public.fn_change_task_status(p_task_id, v_target, null, null);
end;
$$;

revoke execute on function public.fn_task_status_history_append_only() from public, anon, authenticated;
revoke execute on function public.fn_tasks_d2_before() from public, anon, authenticated;
revoke execute on function public.fn_tasks_d2_after_history() from public, anon, authenticated;
revoke execute on function public.fn_recompute_task_progress(uuid) from public, anon, authenticated;
revoke execute on function public.fn_trg_checklist_progress() from public, anon, authenticated;
revoke execute on function public.fn_trg_subtask_progress() from public, anon, authenticated;

revoke execute on function public.fn_change_task_status(uuid, public.task_status, text, integer) from public, anon;
grant execute on function public.fn_change_task_status(uuid, public.task_status, text, integer) to authenticated;

revoke execute on function public.fn_complete_task(uuid) from public, anon;
grant execute on function public.fn_complete_task(uuid) to authenticated;
