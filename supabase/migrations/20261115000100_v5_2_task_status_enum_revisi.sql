-- ==============================================================================
-- Orbit Migrasi v5.2 (Bagian 1): Tambah nilai enum 'revisi' ke public.task_status
-- Catatan PostgreSQL: ALTER TYPE ADD VALUE harus berada di transaksi terpisah
-- sebelum nilai enum baru direferensikan dalam CHECK/trigger/fungsi.
-- ==============================================================================

alter type public.task_status add value if not exists 'revisi' after 'doing';
