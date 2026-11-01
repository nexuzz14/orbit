# Model Ancaman Orbit (STRIDE) - Versi 1 (Fase 1)

Model ancaman ini disusun berdasarkan metodologi STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege) untuk mengidentifikasi ancaman keamanan pada setiap komponen sistem Orbit dan kontrol mitigasi yang diterapkan.

## 1. Aktor Ancaman (Threat Actors)
1. **Penyerang Eksternal**: Penyerang di internet tanpa kredensial sah yang mencoba membobol auth, API Supabase, atau web app.
2. **Akun yang Diambil Alih (Account Takeover)**: Kredensial pengguna dicuri melalui phishing atau kebocoran kata sandi eksternal.
3. **Perangkat Hilang / Dicuri**: Ponsel fisik pengguna jatuh ke tangan pihak ketiga.
4. **Aplikasi Lain di Perangkat (Malicious / Nosy App)**: Aplikasi Android lain yang mencoba membaca berkas lokal, memori, atau tangkapan layar.
5. **Konten Tidak Tepercaya (Untrusted Content)**: Notifikasi palsu, berkas CSV/XLSX/PDF berbahaya, gambar bukti manipulatif, formula injection.
6. **Orang Dalam / Insider Workspace**: Anggota workspace dengan peran viewer/editor yang mencoba mengakses atau memanipulasi data di luar haknya (IDOR, privilege escalation).

## 2. Analisis STRIDE per Komponen

### 2.1 Web Application (Next.js, Vercel)
- **Spoofing**:
  - *Ancaman*: Penyerang memalsukan sesi login atau melakukan session hijacking.
  - *Mitigasi*: Cookie sesi `HttpOnly`, `Secure`, `SameSite=Lax` dikelola oleh `@supabase/ssr`. TOTP 2FA wajib untuk akun pembuat. Access token berumur pendek (15 menit) dan rotasi refresh token aktif.
- **Tampering**:
  - *Ancaman*: Manipulasi request form / parameter client-side, CSRF, XSS.
  - *Mitigasi*: Validasi skema otoritatif dengan Zod di server actions/route handlers. Origin header checking. Sanitasi ketat output, pelarangan `dangerouslySetInnerHTML`. CSP ketat dengan script-src tanpa `'unsafe-inline'`.
- **Repudiation**:
  - *Ancaman*: Pengguna menyangkal telah melakukan transaksi atau perubahan konfigurasi.
  - *Mitigasi*: Trigger database mencatat seluruh mutasi data ke `audit_log` (append-only) beserta `actor_id` dan diff. `security_events` mencatat peristiwa autentikasi.
- **Information Disclosure**:
  - *Ancaman*: Data transaksi atau saldo bocor ke pengguna lain, error trace bocor di produksi, kebocoran secret.
  - *Mitigasi*: RLS deny-by-default di database; web hanya memegang Anon Key (tidak pernah Service Role Key); source maps dimatikan di production build; error message generik ke user.
- **Denial of Service**:
  - *Ancaman*: DoS pada route form atau auth.
  - *Mitigasi*: Rate limiting bawaan Supabase Auth dan edge network protection Vercel. Pendaftaran publik dimatikan.
- **Elevation of Privilege**:
  - *Ancaman*: Pengguna mengubah peran dari viewer menjadi owner atau memanipulasi workspace_id.
  - *Mitigasi*: `workspace_id`, `user_id`, dan `role` diturunkan dari token JWT di database, client input diabaikan. Trigger `fn_protect_immutable` memblokir pengubahan kolom sensitif.

### 2.2 Mobile App (Flutter Android)
- **Spoofing**:
  - *Ancaman*: Bypass biometrik atau akses app oleh penemu HP yang hilang.
  - *Mitigasi*: Token sesi dan encryption key disimpan di Android Keystore via `flutter_secure_storage`. App lock dengan biometrik/PIN.
- **Tampering**:
  - *Ancaman*: Modifikasi database lokal SQLite, modifikasi APK (repackaging).
  - *Mitigasi*: Basis data lokal Drift dienkripsi penuh menggunakan SQLCipher. Build release dengan obfusikasi (`--obfuscate --split-debug-info`) dan R8/ProGuard.
- **Repudiation**:
  - *Ancaman*: Manipulasi outbox sinkronisasi offline.
  - *Mitigasi*: Outbox menggunakan idempotent client-generated UUIDs. Server menyelesaikan konflik dengan audit log versi yang kalah.
- **Information Disclosure**:
  - *Ancaman*: Pengintipan layar keuangan via recent apps / spyware, bocoran log cat.
  - *Mitigasi*: `FLAG_SECURE` diaktifkan pada semua activity/window berlayar keuangan. Data sensitif (nominal, merchant, token, lokasi) tidak pernah dicetak ke log console.
- **Denial of Service**:
  - *Ancaman*: Database lokal crash akibat file corrupt.
  - *Mitigasi*: Transaksi database lokal ACID, integritas SQLCipher.
- **Elevation of Privilege**:
  - *Ancaman*: Akses data workspace lain lewat manipulasi sync request.
  - *Mitigasi*: Sinkronisasi online tunduk penuh pada RLS database; token JWT membatasi akses hanya ke workspace terdaftar.

### 2.3 Database (PostgreSQL / Supabase)
- **Spoofing**: Penyerang mengaku sebagai user lain via query langsung -> Dimusnahkan dengan JWT verification Supabase Auth dan `auth.uid()`.
- **Tampering**:
  - *Ancaman*: SQL Injection atau modifikasi data sepihak.
  - *Mitigasi*: Parameterized queries di semua layer. Trigger database mengunci field immutable (`workspace_id`, `created_by`, `transfer_group_id`). Tidak ada raw SQL dinamis dari user input.
- **Repudiation**: Modifikasi data tanpa jejak -> Dimusnahkan dengan tabel `public.audit_log` yang berstatus `append-only` (dilindungi trigger anti-delete/update).
- **Information Disclosure**: IDOR lintas workspace -> Dimusnahkan dengan RLS wajib di semua tabel public dan foreign key komposit `(id, workspace_id)`.
- **Denial of Service**: Query berat menghabiskan CPU -> Index komposit lengkap pada kolom filter `(workspace_id, occurred_at)`, `(workspace_id, account_id)`, dsb.
- **Elevation of Privilege**: Pengguna menaikkan role sendiri -> Trigger `fn_validate_member` dan policy `workspace_members` melarang mutasi non-owner.

### 2.4 Supabase Storage
- **Spoofing & Elevation**: Akses bucket lampiran -> Bucket `attachments` disetel `public = false`. RLS pada `storage.objects` memverifikasi folder prefix `<workspace_id>/...` harus merupakan workspace di mana pengguna adalah anggota.
- **Tampering**: Upload file berbahaya (executable, script web) -> Whitelist MIME (`image/png`, `image/jpeg`, `image/webp`, `application/pdf`), batas ukuran 10 MB.
- **Information Disclosure**: Direct link leakage -> Objek hanya dapat diakses melalui signed URL berumur pendek atau sesi terautentikasi.

### 2.5 Pipeline Notifikasi, Bukti Transaksi, dan OCR (Fase Lanjut & Desain Fondasi)
- **Untrusted Input**: Gambar bank, teks notifikasi, file mutasi diperlakukan sebagai konten tidak tepercaya.
- **Privasi**: Nomor kartu penuh, CVV, PIN, OTP, nomor rekening/rekening tujuan, nomor Virtual Account, dan RRN **dilarang keras** disimpan di database maupun log. Nomor referensi hanya disimpan dalam bentuk hash SHA-256 (`external_id_hash`).
- **Processing**: Seluruh OCR dan parser notifikasi berjalan lokal di perangkat, tidak ada gambar yang dikirim ke cloud/LLM tanpa otorisasi tegas.
- **Formula Injection**: Ekspor spreadsheet (CSV/XLSX) menetralkan karakter diawali `=`, `+`, `-`, `@` dengan prefix tanda kutip tunggal `'`.

### 2.6 CI/CD Pipeline
- **Secret Leaks**: Gitleaks memindai secret pada pre-commit dan pull request di GitHub Actions.
- **Vulnerabilities**: Dependabot dan audit dependensi (`npm audit`, `dart pub audit`) otomatis memeriksa CVE tinggi/kritis.
- **Regression**: Uji pgTAP memverifikasi matriks peran x tabel x operasi dan uji IDOR pada setiap build.
