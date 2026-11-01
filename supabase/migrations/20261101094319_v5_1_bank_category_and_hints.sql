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
