# Panduan Tindakan Manual Dashboard Supabase - Orbit

Dokumen ini berisi daftar langkah manual yang **wajib dilakukan oleh pemilik proyek** di Dashboard Supabase untuk mengamankan dan mengonfigurasi proyek Orbit sebelum masuk ke tahap produksi (atau setelah pembuatan akun pertama).

---

## 1. Nonaktifkan Pendaftaran Publik (Public Signups)
Setelah Anda membuat akun pertama Anda (sebagai pemilik/administrator utama):
1. Buka [Supabase Dashboard](https://supabase.com/dashboard).
2. Pilih project Anda (`kpsfdqswoerzkicocvre` untuk dev/prod).
3. Navigasi ke **Authentication** > **Providers** > **Email**.
4. Cari opsi **"Enable Signups"** dan ubah menjadi **OFF (Nonaktif)**.
5. Klik **Save**.
> **Tujuan**: Mencegah pihak luar mendaftar akun baru ke instance Orbit pribadi Anda. Seluruh penambahan anggota berikutnya hanya dapat dilakukan melalui mekanisme undangan workspace (`workspace_invites`).

---

## 2. Aktifkan Multi-Factor Authentication (MFA / TOTP)
1. Di Dashboard, buka menu **Authentication** > **Multi-Factor Authentication (MFA)**.
2. Pastikan **Time-based One-Time Password (TOTP)** berstatus **Enabled**.
3. Di tab **Security**, pastikan tingkat jaminan autentikasi (AAL) disetel untuk mewajibkan 2FA saat sesi meminta hak akses sensitif.
4. Pada web Orbit, masuk ke menu **Pengaturan Keamanan** (`/pengaturan`) lalu scan QR code menggunakan aplikasi Google Authenticator, Aegis, atau 1Password untuk mendaftarkan faktor TOTP pertama Anda.

---

## 3. Konfigurasi Site URL dan Redirect URLs
1. Buka menu **Authentication** > **URL Configuration**.
2. Pada kolom **Site URL**:
   - Untuk lingkungan lokal: `http://localhost:3000` (atau `http://127.0.0.1:3000`)
   - Untuk lingkungan produksi: Masukkan URL domain web Anda (misal `https://orbit.yourdomain.com`).
3. Pada bagian **Redirect URLs**, tambahkan URL callback berikut:
   - `http://localhost:3000/**`
   - `http://localhost:3000/auth/callback`
   - `http://127.0.0.1:3000/**`
   - `https://your-production-domain.vercel.app/**`
   - `https://your-production-domain.vercel.app/auth/callback`
   - Skema callback mobile: `io.supabase.orbit://login-callback/`
4. Klik **Save**.

---

## 4. Konfigurasi Google OAuth (Opsional untuk Single Sign-On)
1. Buat project di [Google Cloud Console](https://console.cloud.google.com/).
2. Masuk ke **APIs & Services** > **Credentials**.
3. Buat **OAuth 2.0 Client IDs** bertipe **Web application**.
4. Di bagian **Authorized redirect URIs**, masukkan URL dari Supabase:
   `https://<project-ref>.supabase.co/auth/v1/callback`
   *(Contoh: `https://kpsfdqswoerzkicocvre.supabase.co/auth/v1/callback`)*.
5. Simpan Client ID dan Client Secret yang dihasilkan.
6. Buka Supabase Dashboard > **Authentication** > **Providers** > **Google**.
7. Masukkan **Client ID** dan **Client Secret**, aktifkan toggle **Enable Google provider**, lalu klik **Save**.

---

## 5. Pemisahan Lingkungan: Project Dev dan Prod Terpisah
Untuk menjaga isolasi dan stabilitas data:
1. **Jangan mencampur data pengujian dengan data riil/produksi.**
2. Buat dua project terpisah di Supabase Dashboard:
   - **Orbit Dev / Staging**: untuk eksperimen fitur, uji integrasi, dan reset database sesering mungkin.
   - **Orbit Production**: untuk data riil harian Anda.
3. Terapkan seluruh migrasi ke project produksi melalui perintah:
   ```bash
   npx supabase db push --linked
   # atau melalui MCP Supabase tool apply_migration
   ```
4. Salin Anon Key dan URL masing-masing project ke konfigurasi environment yang sesuai (`.env.local` untuk dev, Vercel Environment Variables untuk prod).

---

## 6. Konfigurasi GitHub Secrets untuk Backup Harian
Untuk mengaktifkan workflow backup database otomatis `.github/workflows/backup.yml`:
1. Buka repository GitHub Anda di browser (`nexuzz14/orbit`).
2. Masuk ke **Settings** > **Secrets and variables** > **Actions**.
3. Tambahkan dua Secret baru:
   - `DATABASE_URL`: Connection string PostgreSQL Supabase Anda (ambil dari Dashboard > Project Settings > Database > Connection string > URI). Format: `postgres://postgres:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?sslmode=require`.
   - `BACKUP_ENCRYPTION_KEY`: Kunci sandi acak yang panjang (minimal 32 karakter) untuk enkripsi GPG AES-256. Simpan kunci ini juga di password manager pribadi Anda agar backup dapat didekripsi jika terjadi insiden.

4. **Instruksi Menjalankan Backup Manual Pertama Kali**:
   - Buka tab **Actions** di repositori GitHub `nexuzz14/orbit`.
   - Pada daftar workflow di sebelah kiri, pilih **Database Backup (Daily Encrypted)**.
   - Klik tombol dropdown **Run workflow**, pilih branch `main`, lalu klik tombol hijau **Run workflow**.
   - Atau jalankan lewat GitHub CLI di terminal Anda:
     ```bash
     gh workflow run backup.yml --ref main
     ```
   - Tunggu run selesai hingga hijau dan periksa artefak `orbit-db-backup-*.dump.gpg` yang dihasilkan.

> **Catatan Status Checklist Keamanan PRD 9.16**: Item backup di checklist gerbang rilis keamanan berstatus **"Menunggu secret dari pengguna"** hingga Anda selesai menyetel kedua secret di atas dan workflow berhasil dijalankan.
