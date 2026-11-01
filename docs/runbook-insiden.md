# Runbook Penanganan Insiden Keamanan - Orbit

Dokumen ini adalah prosedur operasional standar (SOP) untuk merespons insiden keamanan, kebocoran data, atau kegagalan sistem pada aplikasi Orbit.

---

## 1. Fase Deteksi (Detection)
Insiden dapat dideteksi melalui beberapa indikator:
- **Alert Otomatis**: Lonjakan login gagal atau error 401/403 pada tabel `security_events` dan log Vercel.
- **Peringatan CI/CD**: Gitleaks mendeteksi rahasia ter-commit pada pull request/push.
- **Laporan Pengguna**: Aktivitas transaksi tidak dikenal atau sesi anomali di daftar perangkat.
- **Pemindaian Dependensi**: Dependabot/npm audit melaporkan eksploitasi zero-day kritis.

Langkah verifikasi awal:
1. Pastikan validitas insiden (bukan false positive).
2. Tentukan tingkat keparahan (SEV-1: Kritis/Bocor Kredensial, SEV-2: Tinggi/Gangguan Layanan, SEV-3: Menengah).

---

## 2. Fase Penahanan (Containment)

Tindakan cepat untuk membatasi dampak serangan:

### A. Cabut Sesi Pengguna (Revoke Sessions)
Bila diduga terjadi pengambilalihan akun:
- Jalankan RPC `fn_revoke_session(session_id)` atau hapus seluruh sesi aktif pengguna dari tabel `auth.sessions`:
  ```sql
  delete from auth.sessions where user_id = '<target_user_id>';
  insert into public.security_events (user_id, type) values ('<target_user_id>', 'logout_all');
  ```

### B. Rotasi Kunci Rahasia (Secret Rotation)
Bila API Key atau Secret Supabase/Vercel diduga bocor:
1. **Supabase JWT Secret / Anon Key / Service Key**:
   - Buka Supabase Dashboard > Project Settings > API.
   - Lakukan "Generate new JWT secret" (ini otomatis membatalkan seluruh token JWT yang beredar).
   - Perbarui env `NEXT_PUBLIC_SUPABASE_ANON_KEY` dan `SUPABASE_SERVICE_ROLE_KEY` di dashboard Vercel.
2. **Kunci Enkripsi Database Mobile**:
   - Paksa logout aplikasi mobile. Saat login berikutnya, app akan membuat ulang kunci di Keystore dan mengunci database lokal baru.
3. **Google OAuth Secret**:
   - Buka Google Cloud Console > Credentials > Reset Client Secret. Perbarui konfigurasi di Supabase Auth Provider.

### C. Nonaktifkan Fitur / Kunci Sistem (Emergency Lockdown)
Bila terdapat celah pada endpoint tertentu:
- Set maintenance mode di Vercel atau buat rewrite rule untuk memblokir endpoint yang terdampak.
- Untuk mematikan sementara pendaftaran dan invite: pastikan `enable_signup = false` pada Supabase Auth dan cabut seluruh invite aktif:
  ```sql
  update public.workspace_invites set revoked_at = now() where revoked_at is null;
  ```

---

## 3. Fase Investigasi (Investigation)
1. Periksa `public.audit_log` untuk melihat mutasi data yang dilakukan penyerang:
   ```sql
   select * from public.audit_log where actor_id = '<suspect_id>' order by at desc;
   ```
2. Analisis `public.security_events` untuk mencocokkan hash IP dan user agent.
3. Periksa log Vercel Function dan Supabase PostgREST logs untuk merekonstruksi jalur serangan.
4. Identifikasi rekaman data yang telah diakses atau dimodifikasi.

---

## 4. Fase Pemulihan (Recovery)
1. **Pemulihan Data (Data Restore)**:
   - Jika terjadi manipulasi atau penghapusan data, pulihkan dari snapshot backup harian Supabase / pg_dump.
   - Untuk transaksi yang terhapus lunak (< 30 hari), gunakan `fn_restore_transaction(id)`.
2. **Patch Celah Keamanan**:
   - Tulis regression test (misal uji pgTAP untuk celah RLS atau unit test untuk celah input).
   - Deploy hotfix migrasi SQL atau kode aplikasi.
3. **Verifikasi Sistem**:
   - Jalankan seluruh suite uji otomatis di CI (lint, tipe, pgTAP, gitleaks).
   - Pastikan metrik normal dan error rate kembali ke 0.

---

## 5. Fase Pemberitahuan (Notification)
- Berdasarkan UU PDP No. 27 Tahun 2022 (Pasal 46): jika terjadi kegagalan pelindungan data pribadi yang melibatkan pihak ketiga (saat fase multi-user aktif), pengendali data wajib menyampaikan pemberitahuan tertulis paling lambat 3 x 24 jam kepada subjek data pribadi dan lembaga terkait.
- Pada fase single-user, buat catatan insiden internal untuk dokumentasi audit.

---

## 6. Tinjauan Pasca-Insiden (Post-Mortem)
1. Buat laporan insiden dalam waktu 48 jam:
   - Garis waktu kejadian (timeline).
   - Akar masalah (root cause analysis).
   - Dampak kerugian / kebocoran.
   - Tindakan perbaikan (action items) dengan penanggung jawab dan batas waktu.
2. Perbarui `docs/threat-model.md` dan tambahkan aturan baru ke CI jika diperlukan.
