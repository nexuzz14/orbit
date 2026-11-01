-- Orbit Fase 1: Storage privat dan jadwal retensi.

-- Bucket privat untuk lampiran. Berkas disimpan di folder <workspace_id>/... dan hanya gambar/PDF.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,
  10485760,
  array['image/png', 'image/jpeg', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Mengambil workspace_id dari awal path objek. Mengembalikan null bila bukan uuid.
create function public.fn_storage_workspace(p_name text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return split_part(p_name, '/', 1)::uuid;
exception
  when others then
    return null;
end;
$$;
revoke execute on function public.fn_storage_workspace(text) from public, anon;
grant execute on function public.fn_storage_workspace(text) to authenticated;

-- RLS pada storage.objects aktif secara bawaan Supabase; tanpa kebijakan berarti ditolak.
create policy attachments_objects_select on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and public.is_member(public.fn_storage_workspace(name)));
create policy attachments_objects_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and public.has_role(public.fn_storage_workspace(name), 'editor'));
create policy attachments_objects_update on storage.objects for update to authenticated
  using (bucket_id = 'attachments' and public.has_role(public.fn_storage_workspace(name), 'editor'))
  with check (bucket_id = 'attachments' and public.has_role(public.fn_storage_workspace(name), 'editor'));
create policy attachments_objects_delete on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and public.has_role(public.fn_storage_workspace(name), 'editor'));

-- Jadwal retensi harian (03:00 UTC) bila pg_cron tersedia.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('orbit-purge-expired', '0 3 * * *', 'select public.fn_purge_expired()');
  else
    raise notice 'pg_cron tidak tersedia. Jadwalkan public.fn_purge_expired() secara manual.';
  end if;
exception
  when others then
    raise notice 'Penjadwalan pg_cron dilewati: %', sqlerrm;
end;
$$;
