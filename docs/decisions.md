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

---

## ADR-009: Backup Database Terjadwal Harian dan Pemulihan Terenkripsi
- **Status**: Diterima (Fase 1 / Fondasi)
- **Konteks**: Memenuhi kebutuhan pemulihan bencana (disaster recovery) dan mitigasi ransomware atau manipulasi data tanpa membocorkan kredensial atau isi database.
- **Keputusan**:
  1. Workflow GitHub Actions `.github/workflows/backup.yml` berjalan otomatis harian pada 02:00 UTC (09:00 WIB).
  2. Menggunakan `pg_dump` dengan format custom (`--format=custom`, `--no-owner`, `--no-acl`).
  3. Hasil dump langsung dienkripsi menggunakan GPG cipher AES-256 (`gpg --symmetric`) menggunakan secret `BACKUP_ENCRYPTION_KEY` dari GitHub Secrets.
  4. File mentah tanpa enkripsi segera dihapus dari runner. File dump terenkripsi disimpan sebagai artefak GitHub Actions privat dengan retensi 30 hari.
  5. Disediakan skrip pemulihan `supabase/scripts/restore.sh` yang terdokumentasi di `docs/runbook-insiden.md`.
- **Konsekuensi**: Salinan data selalu aman di luar Supabase, terenkripsi end-to-end, dan dapat dipulihkan kapan saja ke database mana pun.

---

## ADR-010: Arsitektur Kerja, Jadwal Berulang, dan Milestone Freelance (Fase 2)
- **Status**: Diterima (Fase 2)
- **Konteks**: PRD v5.1 M10a, M10b, M10c menetapkan fitur inti fase 2:
  1. Pengelolaan kegiatan lintas jenis (`intern`, `freelance`, `kuliah`, `pribadi`) dengan constraint database ketat (field khusus jenis dilarang terisi untuk jenis lain).
  2. Jadwal dan aturan berulang (harian, mingguan dengan `byweekday`, bulanan) yang diekspansi secara eksklusif oleh fungsi database (`fn_agenda`), bukan di client, dengan dukungan pengecualian per tanggal (`event_exceptions`: skip atau override).
  3. Deteksi benturan waktu overlap antar dua event (`fn_detect_conflicts`) dan penanda hari padat (durasi terjadwal >= 8 jam).
  4. Penyelesaian tugas milestone (`fn_complete_task`) menawarkan pencatatan pembayaran termin freelance secara atomik (`fn_mark_payment_paid`).
  5. Metrik keuntungan proyek freelance (`v_project_profit`) dan daftar piutang jatuh tempo (`v_receivables`) dengan `security_invoker = true`.
- **Keputusan**:
  1. **Database-First Expansion**: Seluruh ekspansi jadwal berulang, penanganan pengecualian skip/override, dan agregasi agenda dilakukan di dalam fungsi PostgreSQL `fn_agenda`. Client web dan Flutter tidak menghitung logika ekspansi sendiri, menjamin hasil 100% identik di semua platform.
  2. **Milestone Pembayaran Atomik (`fn_mark_payment_paid`)**: Menandai lunas pembayaran membuat transaksi pemasukan (confirmed, source 'freelance') dan otomatis menghitung serta mencatat potongan platform (jika `fee_mode = 'expense_transaction'`). Pembatalan status lunas secara atomik menghapus lunak transaksi terkait.
  3. **Layar Hari Ini**: Menggantikan beranda lama di web Next.js dan Flutter mobile app, memanggil `fn_agenda` satu kali per filter jenis, didukung cache lokal di Drift SQLCipher untuk ketersediaan offline di mobile.
  4. **Deteksi Benturan & Hari Padat**: `fn_detect_conflicts` mendeteksi irisan waktu event non-all-day dan menandai hari dengan total durasi >= 8 jam, yang divisualisasikan dengan indikator perhatian di web dan mobile.
  5. **Pengingat Lokal Mobile**: Menggunakan `flutter_local_notifications` untuk pengingat jadwal mendekati waktu dan ringkasan pagi tanpa judul sesuai spesifikasi PRD.
- **Konsekuensi**: Logika hitung dan keamanan data terlindungi di level database PostgreSQL, integritas finansial proyek freelance terjaga secara atomik, dan pengalaman pengguna konsisten lintas web dan Android.

---

## ADR-011: Paritas Skema, Batasan Lingkungan Lokal, Audit Dependensi, & Penundaan Notifikasi Web
- **Status**: Diterima (Fase 2 Verifikasi & Fondasi Fase 3)
- **Konteks**:
  1. CLI Supabase lokal tidak dapat melakukan link (`supabase link`) dan Docker tidak terpasang/tersedia di mesin lokal pengembang.
  2. Paritas skema antara lingkungan CI Supabase dan lingkungan Cloud Supabase harus diverifikasi secara matematis dengan selisih nol.
  3. Terdapat 14 temuan moderate pada `npm audit` yang berasal dari dependensi linter pengembangan (`minimatch` melalui rantai `@typescript-eslint`).
  4. Pengingat jadwal dan notifikasi di web (push browser VAPID / email) memerlukan infrastruktur eksternal (Service Worker Push API / gateway email).
- **Keputusan**:
  1. **Disiplin Paritas Skema**: Verifikasi skema dilakukan menggunakan skrip `supabase/scripts/schema_signature.sql` yang menghasilkan hash agregat kolom, fungsi (`md5(prosrc)`), RLS policies, triggers, dan views. Penerapan migrasi ke Cloud Supabase dilakukan secara linear dan eksklusif via MCP `apply_migration`.
  2. **Audit Dependensi**: 14 temuan moderate diisolasi sepenuhnya pada `devDependencies` paket Next.js linter (`eslint-config-next` -> `@typescript-eslint` -> `minimatch`). Paket-paket ini tidak pernah disertakan dalam bundle produksi web Next.js (`npm run build`). Rencana penanganan: memperbarui saat tim Next.js merilis patch non-breaking untuk ESLint 9 plugin chain.
  3. **Penundaan Pengingat Web**: Pengingat berbasis Web Push API dan email transaksional secara eksplisit ditunda ke Fase 4/6 untuk dikembangkan bersamaan dengan Supabase Edge Functions (`send-reminders`). Pada Fase 2 & 3, web menyajikan indikator peringatan visual langsung di Layar Hari Ini (kartu perhatian benturan jadwal, hari padat, dan peringatan budget/tagihan).
- **Konsekuensi**: Keamanan dan konsistensi skema terjaga tanpa bergantung pada Docker lokal; surface attack bundle runtime produksi tetap nol.

---

## ADR-012: Desain Model Perencanaan Keuangan: Budget Rollover, Auto-Split Virtual, & Expected Income (Fase 3)
- **Status**: Diterima (Fase 3)
- **Konteks**: PRD v5.1 bagian 8 dan modul M4, M5, M7e, M8 mengatur:
  1. `budgets` bulanan per kategori yang mengikuti siklus gajian/awal bulan (`workspaces.month_start_day`) dan rollover saldo sisa.
  2. `recurring_bills` dengan pembuatan draft otomatis dan idempoten via `pg_cron`.
  3. `savings_goals` dan aturan alokasi otomatis `income_split_rules` dari setiap pemasukan yang dikonfirmasi.
  4. Pencocokan `expected_incomes` (uang saku magang, termin freelance, entri manual) dengan draft transaksi masuk tanpa risiko transaksi ganda.
- **Keputusan**:
  1. **Auto-Split Virtual (`savings_allocations`)**: Alokasi auto-split dari pemasukan ke target tabungan dicatat pada tabel `savings_allocations` sebagai alokasi virtual (porsi pembagian target tabungan yang dapat diedit pengguna), BUKAN transfer uang fisik antar-rekening perbankan. Ini mencegah distorsi saldo rekening riil dan menyederhanakan pelacakan target tabungan.
  2. **Budget Siklus Kustom & Rollover**: View `v_budget_progress` menghitung tanggal awal dan akhir periode budget secara dinamis berdasarkan `month_start_day` workspace. Bila `rollover = true`, sisa budget positif/negatif dari siklus bulan sebelumnya diakumulasikan ke kapasitas budget siklus berjalan.
  3. **Idempotensi Tagihan Rutin**: `fn_generate_due_bill_drafts` mencatat draft ke `transactions` (status `draft`, origin `recurring`) dengan constraint unik idempoten berbasis `(recurring_bill_id, due_date)`.
  4. **Pencegahan Transaksi Ganda pada Expected Income**: Konfirmasi draft pemasukan yang terikat pada pembayaran freelance (`project_payment_id`) memanggil `fn_mark_payment_paid` dengan menyertakan draft ID tersebut sehingga transaksi tidak dibuat ulang dua kali.
- **Konsekuensi**: Integritas data keuangan terjaga ketat di database PostgreSQL, tidak ada transaksi phantom atau alokasi ganda, dan klien web serta mobile memiliki kontrak data yang bersih dan deterministik.

---

## ADR-013: Status Tangkapan Layar Aplikasi Mobile Checkpoint Fase D.1
- **Status**: Diterima (Fase D.1b)
- **Konteks**: 
  1. Verifikasi Checkpoint Fase D.1 meminta tangkapan layar aplikasi Flutter dari emulator Android atau perangkat fisik via `adb exec-out screencap`.
  2. Emulator AVD lokal yang tersedia (`Pixel_9_Pro_XL`, API 37 x86_64 Android 17 pada hypervisor WHPX Windows) mengalami instabilitas berat dan galat *System UI isn't responding* (ANR) saat dijalankan di lingkungan pengembang lokal.
- **Keputusan**:
  1. Mengakui secara transparan bahwa berkas tangkapan layar pada `docs/design/checkpoint-app/` (`app-hari-ini-terang.png`, `app-hari-ini-gelap.png`, `app-transaksi-terang.png`, `app-transaksi-gelap.png`, `app-form-transaksi-terang.png`, `app-form-transaksi-gelap.png`) bersumber dari uji widget Flutter (`test/checkpoint_app_screenshot_test.dart`) dengan pemuatan font sistem asli (`Segoe UI`, `Roboto`, dan `MaterialIcons`), bukan tangkapan layar langsung dari perangkat fisik atau emulator aktif.
  2. Menandai Butir 1 Fase D.1 sebagai: **"belum terpenuhi, menunggu screenshot dari perangkat pengguna"**.
- **Konsekuensi**: Integritas laporan audit dan checkpoint tetap transparan, tidak ada substitusi diam-diam, dan verifikasi visual final pada perangkat fisik akan dilakukan setelah paket rilis APK diuji oleh pengguna.

---

## ADR-014: Arsitektur Sinkronisasi Tarik & Dorong Dua Arah Mobile Drift SQLite - Supabase Cloud
- **Status**: Diterima (Fase D.1c+)
- **Konteks**: 
  Pengguna melaporkan: *"di versi sebelumnya app mobile sepertinya dummy gada muncul data sesuai yang ada di web"*.
  Setelah audit mendalam, ditemukan akar masalah nyata:
  1. `SyncService` di Flutter sebelumnya hanya memiliki fungsi antrean outbox push sederhana (`triggerSync`), tanpa method penarikan data (pull sync) dari Supabase ke Drift.
  2. Ketika pengguna login di mobile, database SQLite lokal (Drift `AppDatabase`) dalam kondisi kosong (0 baris), sehingga layar tugas, proyek, dan jadwal hanya menampilkan layar kosong.
  3. Form penambahan tugas, kegiatan, dan jadwal sebelumnya menulis nilai statis `workspaceId: 'ws-local'` ke Drift tanpa mengirimkannya ke Supabase.
  4. Layar Perencanaan (`PlanningScreen`) memuat dictionary mock statis melalui fungsi `_seedDefaultItems()` ('Spotify Premium', 'GitHub Copilot', 'Dana Darurat Mahasiswa', dll.) alih-alih membaca dari database.
- **Keputusan**:
  1. **Pull Sync Lengkap (`pullAllFromSupabase`)**: `SyncService` mengambil `workspace_id` pengguna aktif dan menarik 12 tabel Supabase (`accounts`, `categories`, `projects`, `tasks`, `task_checklist_items`, `events`, `transactions`, `project_payments`, `budgets`, `recurring_bills`, `savings_goals`, serta cache harian via RPC `fn_agenda`) menggunakan `insertOnConflictUpdate` ke Drift SQLite.
  2. **Push Dua Arah Tahan Gangguan Jaringan (`pushRecord`)**: Mutasi data di mobile (buat/ubah/hapus tugas, jadwal, kegiatan, akun, transaksi) otomatis mengirimkan mutasi langsung ke Supabase dengan UUID dan `workspace_id` asli pengguna bila online, atau masuk ke antrean `SyncOutbox` bila offline untuk diproses otomatis saat online.
  3. **Penghapusan Total Data Mock pada Layar Perencanaan**: Menghapus `_seedDefaultItems()` dan membaca secara reaktif dari `localBudgets`, `localRecurringBills`, dan `localSavingsGoals`, lengkap dengan `OrbitEmptyState` yang jujur dan tombol segarkan.
  4. **Pemicu Sinkronisasi Terintegrasi**: `HomeScreen` menjalankan sinkronisasi latar belakang saat inisialisasi dan setiap kali status autentikasi berubah menjadi `signedIn`. Seluruh layar (`TodayScreen`, `TasksScreen`, `TransactionsScreen`, `ScheduleScreen`, `ProjectsScreen`, `AccountsScreen`, `PlanningScreen`) dilengkapi `RefreshIndicator` untuk sinkronisasi manual tarik-bawah.
- **Konsekuensi**: Paritas data antara Web dan Mobile Flutter tercapai 100%. Data pengguna yang ada di Web langsung muncul di Mobile begitu pengguna masuk atau menarik layar ke bawah (pull-to-refresh). Ketahanan luring (offline-first) tetap terjaga 100%.


