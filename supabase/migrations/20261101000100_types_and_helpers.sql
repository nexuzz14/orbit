-- Orbit Fase 1: tipe dasar, domain, dan fungsi pembantu umum.
-- Semua perubahan skema lewat migrasi (PRD bagian 0, aturan 3).

create domain public.currency_code as text
  constraint currency_code_format check (value ~ '^[A-Z]{3}$');

create type public.user_role as enum ('owner', 'editor', 'viewer');
create type public.workspace_type as enum ('personal', 'shared');
create type public.account_type as enum ('cash', 'bank', 'e_wallet', 'credit_card', 'savings');
create type public.account_visibility as enum ('shared', 'private');
create type public.category_type as enum ('income', 'expense');
create type public.transaction_type as enum ('income', 'expense', 'transfer');
create type public.transaction_status as enum ('draft', 'confirmed');
create type public.draft_state as enum ('baru', 'perlu_dilengkapi', 'perlu_dicek');
-- Nilai sumber transaksi (PRD v5): intern, freelance, kuliah, personal.
create type public.transaction_source as enum ('intern', 'freelance', 'kuliah', 'personal');
create type public.transaction_origin as enum (
  'manual', 'sentence', 'notification', 'proof_image', 'statement', 'receipt', 'recurring'
);
create type public.transfer_direction as enum ('out', 'in');
-- Jenis kegiatan untuk projects, tasks, dan events.
create type public.activity_kind as enum ('intern', 'freelance', 'kuliah', 'pribadi');
create type public.project_status as enum ('draft', 'berjalan', 'selesai', 'dibatalkan');
create type public.fee_mode as enum ('expense_transaction', 'profit_deduction');
create type public.task_status as enum ('todo', 'doing', 'done');
create type public.task_priority as enum ('rendah', 'sedang', 'tinggi');
create type public.exception_action as enum ('skip', 'override');
create type public.rule_match_field as enum ('merchant', 'product', 'counterparty', 'amount', 'time');
create type public.rule_match_type as enum ('exact', 'contains', 'prefix');
create type public.audit_action as enum ('insert', 'update', 'delete', 'conflict');
create type public.security_event_type as enum (
  'login', 'login_failed', 'logout_all', 'session_revoked', 'password_changed',
  'password_reset_requested', 'mfa_enrolled', 'mfa_removed', 'mfa_verified',
  'email_changed', 'data_export', 'account_deleted'
);

create function public.fn_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Menormalkan nama merchant: huruf kecil, buang kode lokasi setelah koma, buang tanda baca.
create function public.fn_normalize_merchant(p_merchant text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    trim(
      regexp_replace(
        regexp_replace(lower(split_part(coalesce(p_merchant, ''), ',', 1)), '[^[:alnum:][:space:]]', ' ', 'g'),
        '\s+', ' ', 'g'
      )
    ),
    ''
  );
$$;
