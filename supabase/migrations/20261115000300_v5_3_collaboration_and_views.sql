-- ==============================================================================
-- Orbit Migrasi v5.3: Fitur Kolaborasi, Tampilan Tersimpan, Lampiran, Pelacak Waktu,
-- Perangkat Push/PWA, Sinkronisasi Kalender Eksternal, dan View Ringkasan v2
-- ==============================================================================

-- 1. Perluas public.attachments dengan metadata file_name & soft delete
alter table public.attachments
  add column if not exists file_name text check (char_length(file_name) <= 255),
  add column if not exists deleted_at timestamptz;

do $$
declare
  v_cname text;
begin
  select c.conname into v_cname
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'attachments'
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) ilike '%owner_table%';

  if v_cname is not null then
    execute format('alter table public.attachments drop constraint %I', v_cname);
  end if;

  alter table public.attachments
    add constraint attachments_owner_table_check
    check (owner_table in ('transactions', 'projects', 'tasks', 'events', 'bills', 'comments'));
end;
$$;

-- 2. Tabel public.comments (komentar Notion/Jira di tugas, proyek, acara, transaksi, tagihan)
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  entity_type text not null check (entity_type in ('task', 'project', 'event', 'transaction', 'bill')),
  entity_id uuid not null,
  parent_comment_id uuid references public.comments (id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 5000),
  author_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz,
  unique (id, workspace_id)
);

create index if not exists comments_entity_idx
  on public.comments (workspace_id, entity_type, entity_id, created_at)
  where deleted_at is null;

alter table public.comments enable row level security;
alter table public.comments force row level security;
revoke all on public.comments from anon, public;
grant select, insert, update, delete on public.comments to authenticated;

create policy comments_select on public.comments for select to authenticated
  using (public.is_member(workspace_id));
create policy comments_insert on public.comments for insert to authenticated
  with check (public.has_role(workspace_id, 'editor') and (author_id is null or author_id = (select auth.uid())));
create policy comments_update on public.comments for update to authenticated
  using (public.has_role(workspace_id, 'editor') and (author_id = (select auth.uid()) or public.has_role(workspace_id, 'owner')))
  with check (public.has_role(workspace_id, 'editor'));
create policy comments_delete on public.comments for delete to authenticated
  using (public.has_role(workspace_id, 'editor') and (author_id = (select auth.uid()) or public.has_role(workspace_id, 'owner')));

create or replace function public.fn_comments_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is not null then
    new.author_id := v_uid;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_comments_author on public.comments;
create trigger trg_comments_author before insert on public.comments
  for each row execute function public.fn_comments_before_insert();
drop trigger if exists trg_comments_updated_at on public.comments;
create trigger trg_comments_updated_at before update on public.comments
  for each row execute function public.fn_set_updated_at();
drop trigger if exists trg_comments_immutable on public.comments;
create trigger trg_comments_immutable before update on public.comments
  for each row execute function public.fn_protect_immutable('workspace_id', 'author_id');

-- 3. Tabel public.entity_links (tautan antar objek: tugas <-> jadwal <-> transaksi <-> proyek)
create table if not exists public.entity_links (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  source_type text not null check (source_type in ('task', 'event', 'project', 'transaction', 'bill')),
  source_id uuid not null,
  target_type text not null check (target_type in ('task', 'event', 'project', 'transaction', 'bill')),
  target_id uuid not null,
  relation_type text not null default 'related'
    check (relation_type in ('related', 'blocks', 'blocked_by', 'funded_by', 'derived_from')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  check (not (source_type = target_type and source_id = target_id))
);

create unique index if not exists entity_links_unique_idx
  on public.entity_links (workspace_id, source_type, source_id, target_type, target_id, relation_type);
create index if not exists entity_links_target_idx
  on public.entity_links (workspace_id, target_type, target_id);

alter table public.entity_links enable row level security;
alter table public.entity_links force row level security;
revoke all on public.entity_links from anon, public;
grant select, insert, delete on public.entity_links to authenticated;

create policy entity_links_select on public.entity_links for select to authenticated
  using (public.is_member(workspace_id));
create policy entity_links_insert on public.entity_links for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy entity_links_delete on public.entity_links for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

drop trigger if exists trg_entity_links_created_by on public.entity_links;
create trigger trg_entity_links_created_by before insert on public.entity_links
  for each row execute function public.fn_set_created_by();

-- 4. Tabel public.saved_views (Tampilan Tersimpan gaya Notion / Jira)
create table if not exists public.saved_views (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  created_by uuid references auth.users (id) on delete set null,
  name text not null check (char_length(trim(name)) between 1 and 80),
  scope text not null check (scope in ('tasks', 'agenda', 'transactions', 'projects')),
  view_mode text not null default 'list' check (view_mode in ('list', 'board', 'calendar', 'timeline')),
  filter_json jsonb not null default '{}'::jsonb,
  sort_json jsonb not null default '{}'::jsonb,
  is_pinned boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists saved_views_workspace_idx
  on public.saved_views (workspace_id, scope, sort_order)
  where deleted_at is null;

alter table public.saved_views enable row level security;
alter table public.saved_views force row level security;
revoke all on public.saved_views from anon, public;
grant select, insert, update, delete on public.saved_views to authenticated;

create policy saved_views_select on public.saved_views for select to authenticated
  using (public.is_member(workspace_id));
create policy saved_views_insert on public.saved_views for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy saved_views_update on public.saved_views for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy saved_views_delete on public.saved_views for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

drop trigger if exists trg_saved_views_created_by on public.saved_views;
create trigger trg_saved_views_created_by before insert on public.saved_views
  for each row execute function public.fn_set_created_by();
drop trigger if exists trg_saved_views_updated_at on public.saved_views;
create trigger trg_saved_views_updated_at before update on public.saved_views
  for each row execute function public.fn_set_updated_at();
drop trigger if exists trg_saved_views_immutable on public.saved_views;
create trigger trg_saved_views_immutable before update on public.saved_views
  for each row execute function public.fn_protect_immutable('workspace_id', 'created_by');

-- 5. Tabel public.task_templates (template tugas siap pakai)
create table if not exists public.task_templates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  created_by uuid references auth.users (id) on delete set null,
  name text not null check (char_length(trim(name)) between 1 and 120),
  kind public.activity_kind not null default 'pribadi',
  default_priority public.task_priority not null default 'sedang',
  default_estimate_minutes integer check (default_estimate_minutes > 0),
  checklist_json jsonb not null default '[]'::jsonb,
  blocks_json jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz
);

create index if not exists task_templates_workspace_idx
  on public.task_templates (workspace_id, kind)
  where deleted_at is null;

alter table public.task_templates enable row level security;
alter table public.task_templates force row level security;
revoke all on public.task_templates from anon, public;
grant select, insert, update, delete on public.task_templates to authenticated;

create policy task_templates_select on public.task_templates for select to authenticated
  using (public.is_member(workspace_id));
create policy task_templates_insert on public.task_templates for insert to authenticated
  with check (public.has_role(workspace_id, 'editor'));
create policy task_templates_update on public.task_templates for update to authenticated
  using (public.has_role(workspace_id, 'editor')) with check (public.has_role(workspace_id, 'editor'));
create policy task_templates_delete on public.task_templates for delete to authenticated
  using (public.has_role(workspace_id, 'editor'));

drop trigger if exists trg_task_templates_created_by on public.task_templates;
create trigger trg_task_templates_created_by before insert on public.task_templates
  for each row execute function public.fn_set_created_by();
drop trigger if exists trg_task_templates_updated_at on public.task_templates;
create trigger trg_task_templates_updated_at before update on public.task_templates
  for each row execute function public.fn_set_updated_at();
drop trigger if exists trg_task_templates_immutable on public.task_templates;
create trigger trg_task_templates_immutable before update on public.task_templates
  for each row execute function public.fn_protect_immutable('workspace_id', 'created_by');

-- 6. Tabel public.task_time_logs (pelacak waktu & mode fokus Pomodoro/Stopwatch)
create table if not exists public.task_time_logs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  task_id uuid not null,
  user_id uuid references auth.users (id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  mode text not null default 'stopwatch' check (mode in ('stopwatch', 'pomodoro', 'manual')),
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz,
  foreign key (task_id, workspace_id) references public.tasks (id, workspace_id) on delete cascade,
  check (ended_at is null or ended_at >= started_at)
);

create index if not exists task_time_logs_task_idx
  on public.task_time_logs (task_id, started_at desc)
  where deleted_at is null;

alter table public.task_time_logs enable row level security;
alter table public.task_time_logs force row level security;
revoke all on public.task_time_logs from anon, public;
grant select, insert, update, delete on public.task_time_logs to authenticated;

create policy task_time_logs_select on public.task_time_logs for select to authenticated
  using (public.is_member(workspace_id));
create policy task_time_logs_insert on public.task_time_logs for insert to authenticated
  with check (public.has_role(workspace_id, 'editor') and (user_id is null or user_id = (select auth.uid())));
create policy task_time_logs_update on public.task_time_logs for update to authenticated
  using (public.has_role(workspace_id, 'editor') and (user_id = (select auth.uid()) or public.has_role(workspace_id, 'owner')))
  with check (public.has_role(workspace_id, 'editor'));
create policy task_time_logs_delete on public.task_time_logs for delete to authenticated
  using (public.has_role(workspace_id, 'editor') and (user_id = (select auth.uid()) or public.has_role(workspace_id, 'owner')));

create or replace function public.fn_time_logs_set_user()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is not null then
    new.user_id := v_uid;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_task_time_logs_user on public.task_time_logs;
create trigger trg_task_time_logs_user before insert on public.task_time_logs
  for each row execute function public.fn_time_logs_set_user();
drop trigger if exists trg_task_time_logs_updated_at on public.task_time_logs;
create trigger trg_task_time_logs_updated_at before update on public.task_time_logs
  for each row execute function public.fn_set_updated_at();
drop trigger if exists trg_task_time_logs_immutable on public.task_time_logs;
create trigger trg_task_time_logs_immutable before update on public.task_time_logs
  for each row execute function public.fn_protect_immutable('workspace_id', 'task_id', 'user_id');

-- 7. Tabel public.user_devices (langganan Web Push VAPID & token perangkat Android pribadi)
create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  platform text not null check (platform in ('android', 'web')),
  device_name text check (char_length(device_name) <= 120),
  fcm_token text check (char_length(fcm_token) <= 1024),
  push_subscription jsonb,
  last_seen_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index if not exists user_devices_user_idx on public.user_devices (user_id, platform);

alter table public.user_devices enable row level security;
alter table public.user_devices force row level security;
revoke all on public.user_devices from anon, public;
grant select, insert, update, delete on public.user_devices to authenticated;

create policy user_devices_self_select on public.user_devices for select to authenticated
  using (user_id = (select auth.uid()) and public.is_member(workspace_id));
create policy user_devices_self_insert on public.user_devices for insert to authenticated
  with check (user_id = (select auth.uid()) and public.is_member(workspace_id));
create policy user_devices_self_update on public.user_devices for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy user_devices_self_delete on public.user_devices for delete to authenticated
  using (user_id = (select auth.uid()));

drop trigger if exists trg_user_devices_updated_at on public.user_devices;
create trigger trg_user_devices_updated_at before update on public.user_devices
  for each row execute function public.fn_set_updated_at();

-- 8. Tabel public.calendar_connections & metadata sinkronisasi Google Calendar di events
create table if not exists public.calendar_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  provider text not null default 'google' check (provider in ('google')),
  external_calendar_id text not null default 'primary' check (char_length(external_calendar_id) between 1 and 200),
  sync_direction text not null default 'two_way' check (sync_direction in ('two_way', 'pull', 'push')),
  sync_token text check (char_length(sync_token) <= 500),
  enabled boolean not null default true,
  last_synced_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (user_id, workspace_id, provider, external_calendar_id)
);

alter table public.calendar_connections enable row level security;
alter table public.calendar_connections force row level security;
revoke all on public.calendar_connections from anon, public;
grant select, insert, update, delete on public.calendar_connections to authenticated;

create policy calendar_connections_self_select on public.calendar_connections for select to authenticated
  using (user_id = (select auth.uid()) and public.is_member(workspace_id));
create policy calendar_connections_self_insert on public.calendar_connections for insert to authenticated
  with check (user_id = (select auth.uid()) and public.has_role(workspace_id, 'editor'));
create policy calendar_connections_self_update on public.calendar_connections for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy calendar_connections_self_delete on public.calendar_connections for delete to authenticated
  using (user_id = (select auth.uid()));

drop trigger if exists trg_calendar_connections_updated_at on public.calendar_connections;
create trigger trg_calendar_connections_updated_at before update on public.calendar_connections
  for each row execute function public.fn_set_updated_at();

alter table public.events
  add column if not exists external_provider text check (external_provider in ('google')),
  add column if not exists external_event_id text check (char_length(external_event_id) <= 255),
  add column if not exists external_etag text check (char_length(external_etag) <= 255),
  add column if not exists last_synced_at timestamptz;

create unique index if not exists events_external_uq
  on public.events (workspace_id, external_provider, external_event_id)
  where external_provider is not null and external_event_id is not null and deleted_at is null;

-- 9. Views Ringkasan Kanban & Beban Kerja v2 (security_invoker = true)
create or replace view public.v_task_board_summary
with (security_invoker = true) as
select
  t.workspace_id,
  count(*) filter (where t.status = 'todo')::integer as todo_count,
  count(*) filter (where t.status = 'doing')::integer as doing_count,
  count(*) filter (where t.status = 'revisi')::integer as revisi_count,
  count(*) filter (where t.status = 'done' and t.completed_at >= now() - interval '14 days')::integer as done_14d_count,
  count(*) filter (where t.status <> 'done' and t.due_at is not null and t.due_at < now())::integer as overdue_count,
  count(*) filter (where t.status <> 'done' and t.status_changed_at < now() - interval '5 days')::integer as stagnant_5d_count
from public.tasks t
where t.deleted_at is null
group by t.workspace_id;

grant select on public.v_task_board_summary to authenticated;

-- 10. Fungsi Pencarian Global terotentikasi (Ctrl+K Web & Search Mobile)
create or replace function public.fn_global_search(
  p_workspace_id uuid,
  p_query text,
  p_limit integer default 20
)
returns table (
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  status_label text,
  kind text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_q text := '%' || trim(coalesce(p_query, '')) || '%';
  v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  if not public.is_member(p_workspace_id) then
    raise exception 'Akses ditolak.' using errcode = '42501';
  end if;

  if char_length(trim(coalesce(p_query, ''))) < 1 then
    return;
  end if;

  return query
  select * from (
    (
      select
        'task'::text as entity_type,
        t.id as entity_id,
        t.title,
        coalesce(to_char(t.due_at at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI'), 'Tanpa tenggat') as subtitle,
        t.status::text as status_label,
        t.kind::text as kind
      from public.tasks t
      where t.workspace_id = p_workspace_id
        and t.deleted_at is null
        and (t.title ilike v_q or coalesce(t.description, '') ilike v_q or coalesce(t.latest_revision_note, '') ilike v_q)
      order by t.updated_at desc
      limit v_lim
    )
    union all
    (
      select
        'project'::text as entity_type,
        p.id as entity_id,
        p.name as title,
        coalesce(p.client_name, 'Kegiatan ' || p.kind::text) as subtitle,
        p.status::text as status_label,
        p.kind::text as kind
      from public.projects p
      where p.workspace_id = p_workspace_id
        and p.deleted_at is null
        and (p.name ilike v_q or coalesce(p.client_name, '') ilike v_q)
      order by p.updated_at desc
      limit v_lim
    )
    union all
    (
      select
        'event'::text as entity_type,
        e.id as entity_id,
        e.title,
        to_char(e.starts_at at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI') as subtitle,
        'scheduled'::text as status_label,
        e.kind::text as kind
      from public.events e
      where e.workspace_id = p_workspace_id
        and e.deleted_at is null
        and (e.title ilike v_q or coalesce(e.location, '') ilike v_q)
      order by e.starts_at desc
      limit v_lim
    )
    union all
    (
      select
        'transaction'::text as entity_type,
        tr.id as entity_id,
        coalesce(nullif(tr.merchant, ''), nullif(tr.note, ''), tr.type::text) as title,
        'Rp ' || to_char(tr.amount, 'FM999,999,999,990') as subtitle,
        tr.status::text as status_label,
        coalesce(tr.source::text, 'personal') as kind
      from public.transactions tr
      where tr.workspace_id = p_workspace_id
        and tr.deleted_at is null
        and (coalesce(tr.merchant, '') ilike v_q or coalesce(tr.note, '') ilike v_q or coalesce(tr.counterparty, '') ilike v_q)
      order by tr.occurred_at desc
      limit v_lim
    )
  ) res
  limit v_lim;
end;
$$;

revoke execute on function public.fn_comments_before_insert() from public, anon, authenticated;
revoke execute on function public.fn_time_logs_set_user() from public, anon, authenticated;
revoke execute on function public.fn_global_search(uuid, text, integer) from public, anon;
grant execute on function public.fn_global_search(uuid, text, integer) to authenticated;
