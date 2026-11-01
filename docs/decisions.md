# Catatan Keputusan Teknis (Architecture Decision Records) - Orbit

Dokumen ini mencatat keputusan teknis, arsitektur, dan keamanan yang diambil selama pembangunan aplikasi Orbit, sesuai instruksi PRD Bagian 0 aturan 8.

---

## ADR-001: Skema Database Fondasi dan Tabel Kerja Dini
- **Status**: Diterima (Fase 1)
- **Konteks**: PRD v5 menetapkan bahwa skema Fase 1 mencakup modul keuangan sekaligus tabel kerja untuk jadwal dan tugas (`projects` versi umum, `tasks`, `task_checklist_items`, `events`, `event_exceptions`) agar tidak memerlukan migrasi destruktif di Fase 2.
- **Keputusan**: Seluruh tabel kerja dibuat di migrasi Fase 1 (`20261101000200_core_tables.sql`) dengan constraint CHECK yang membatasi field per jenis (`kind`: intern, freelance, kuliah, pribadi).
- **Konsekuensi**: Skema database stabil sejak awal; pengujian RLS matriks peran x tabel x operasi dan pengujian IDOR dapat mencakup seluruh tabel bisnis dari hari pertama.

---

## ADR-002: Tipe Data Numerik untuk Keuangan
- **Status**: Diterima (Fase 1)
- **Konteks**: Larangan keras PRD bagian 0: tidak memakai tipe float untuk uang karena floating-point precision error dapat merusak rekonsiliasi saldo.
- **Keputusan**: Semua kolom uang dan perhitungan finansial menggunakan `numeric(20, 4)`. Kurs menggunakan `numeric(20, 8)`.
- **Konsekuensi**: Agregasi saldo dan ringkasan bulanan di SQL presisi 100%, bebas dari pembulatan floating-point.

---

## ADR-003: Model Keamanan RLS dan Isolasi Workspace
- **Status**: Diterima (Fase 1)
- **Konteks**: Semua tabel di schema `public` harus diisolasi per workspace dengan pertahanan deny-by-default.
- **Keputusan**:
  1. Semua tabel public memiliki RLS aktif.
  2. Fungsi pembantu `is_member(workspace_id)` dan `has_role(workspace_id, role)` berstatus `SECURITY DEFINER` dengan `search_path = ''`.
  3. Relasi foreign key komposit `(id, workspace_id)` diterapkan pada tabel transaksi, kategori, akun, dan proyek untuk mencegah IDOR di level constraint database.
  4. Semua view (`v_account_balances`, `v_monthly_summary`, dll.) dideklarasikan dengan `WITH (security_invoker = true)`.
  5. Akun dengan visibilitas `private` hanya dapat dibaca oleh pembuatnya (`created_by = auth.uid()`), dan transaksi pada akun privat secara otomatis tersembunyi dari anggota lain melalui RLS subquery.
- **Konsekuensi**: Kebocoran data lintas workspace dan eskalasi hak akses tertutup rapat di level PostgreSQL engine.

---

## ADR-004: Manajemen Transfer Antar Akun
- **Status**: Diterima (Fase 1)
- **Konteks**: Transfer antar akun melibatkan dua sisi (debit dan kredit), potensi beda mata uang, dan opsional biaya admin.
- **Keputusan**: Transfer dibuat melalui fungsi database atomik `fn_create_transfer(...)` yang menghasilkan dua baris transaksi bertipe `transfer` terhubung via `transfer_group_id` dengan `transfer_direction` ('out' dan 'in'). Biaya transfer dicatat sebagai baris `expense` terkait. Trigger database melarang pembuatan atau manipulasi langsung baris transfer dari client tanpa melalui fungsi resmi.
- **Konsekuensi**: Saldo akun selalu konsisten, tidak ada transfer sepihak (setengah jadi), dan riwayat transfer dapat dihapus/dipulihkan bersama secara atomik.

---

## ADR-005: Penanganan Data Sensitif dan Konten Terlarang
- **Status**: Diterima (Fase 1)
- **Konteks**: PRD M7a dan Bagian 9 melarang keras penyimpanan data perbankan sensitif seperti nomor rekening, nomor kartu, CVV, PIN, OTP, dan RRN.
- **Keputusan**:
  1. Skema database tidak menyediakan kolom untuk nomor rekening maupun referensi asli.
  2. Nomor referensi hanya disimpan sebagai SHA-256 hash (`external_id_hash`) untuk keperluan deduplikasi.
  3. Lokasi event dikecualikan dari `audit_log` agar tidak bocor dalam jejak audit.
- **Konsekuensi**: Memenuhi asas minimisasi data dan regulasi privasi (UU PDP).

---

## ADR-006: Arsitektur Web (Next.js & @supabase/ssr)
- **Status**: Diterima (Fase 1)
- **Konteks**: Web membutuhkan SSR aman, cookie sesi HttpOnly, proteksi CSRF/XSS, dan integrasi TOTP 2FA.
- **Keputusan**:
  1. Next.js 15+ App Router dengan TypeScript strict.
  2. `@supabase/ssr` mengelola sinkronisasi cookie otentikasi secara aman antara server components, client components, dan server actions.
  3. Middleware Next.js menyematkan header keamanan (HSTS, CSP strict dengan nonce, X-Content-Type-Options, Referrer-Policy).
  4. UI hanya menampilkan fitur keuangan di Fase 1 (Sesuai batasan cakupan PRD).
- **Konsekuensi**: Keamanan tingkat perbankan tanpa bergantung pada `service_role` key di sisi frontend.

---

## ADR-007: Arsitektur Mobile App (Flutter & Drift SQLCipher)
- **Status**: Diterima (Fase 1)
- **Konteks**: Aplikasi Flutter Android harus mendukung offline-first, penyimpanan data lokal terenkripsi, dan proteksi tangkapan layar.
- **Keputusan**:
  1. Drift ORM dengan backend SQLCipher (`sqlite3_flutter_libs` terenkripsi) untuk database lokal.
  2. Kunci enkripsi database dan token sesi disimpan di Android Keystore via `flutter_secure_storage`.
  3. `FLAG_SECURE` dipasang pada window activity untuk mencegah screen scraping dan screenshot pada layar keuangan.
  4. Antrean sinkronisasi offline (Outbox) menggunakan UUID idempoten.
- **Konsekuensi**: Data terlindungi saat perangkat hilang atau dicuri.

---

## ADR-008: Deployment dan Konfigurasi Supabase Cloud
- **Status**: Diterima (Fase 1)
- **Konteks**: Lingkungan database produksi/staging dideploy ke Supabase Cloud (region `ap-southeast-1` Singapore) untuk mendukung sinkronisasi multi-klien (Web dan Flutter Mobile).
- **Keputusan**:
  1. Project di-provisioning melalui Supabase MCP pada region yang ditentukan.
  2. Seluruh 6 file migrasi diaplikasikan penuh secara berurutan.
  3. RLS deny-by-default aktif 100% di seluruh 18 tabel public dan bucket `attachments`.
  4. Parameter lingkungan disediakan melalui `.env.example` dan `.env.local` tanpa menyimpan secret di git repo.
- **Konsekuensi**: Infrastruktur cloud database siap digunakan langsung oleh aplikasi web Next.js dan Flutter mobile app.
