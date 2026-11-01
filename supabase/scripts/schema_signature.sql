-- Skrip Pemeriksaan Paritas Skema Orbit (PRD 9.16 & Langkah 0.3)
with
columns_meta as (
  select
    c.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default
  from information_schema.columns c
  where c.table_schema = 'public'
  order by c.table_name, c.column_name
),
functions_meta as (
  select
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as args,
    md5(p.prosrc) as src_hash
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
  order by p.proname, args
),
policies_meta as (
  select
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
  from pg_policies
  where schemaname = 'public'
  order by tablename, policyname
),
triggers_meta as (
  select
    event_object_table as table_name,
    trigger_name,
    action_timing,
    event_manipulation
  from information_schema.triggers
  where trigger_schema = 'public'
  order by event_object_table, trigger_name
),
views_meta as (
  select
    table_name,
    md5(view_definition) as view_hash
  from information_schema.views
  where table_schema = 'public'
  order by table_name
)
select json_build_object(
  'columns_hash', md5((select json_agg(c)::text from columns_meta c)),
  'columns_count', (select count(*) from columns_meta),
  'functions_hash', md5((select json_agg(f)::text from functions_meta f)),
  'functions_count', (select count(*) from functions_meta),
  'policies_hash', md5((select json_agg(p)::text from policies_meta p)),
  'policies_count', (select count(*) from policies_meta),
  'triggers_hash', md5((select json_agg(t)::text from triggers_meta t)),
  'triggers_count', (select count(*) from triggers_meta),
  'views_hash', md5((select json_agg(v)::text from views_meta v)),
  'views_count', (select count(*) from views_meta)
) as schema_signature;
