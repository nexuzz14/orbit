# Daftar Periksa Verifikasi Perangkat Android Fisik (Orbit v2)

Dokumen ini disiapkan khusus untuk menguji perilaku sistem Android runtime yang tidak dapat diverifikasi di environment headless Windows (seperti widget launcher, listener notifikasi lintas aplikasi, sensor biometrik, dan latar belakang OS).

## 1. Persiapan & Pemasangan APK
1. Ambil berkas hasil build release (`flutter build apk --release`):
   - `app/build/app/outputs/flutter-apk/app-release.apk`
2. Pasang ke HP Android via USB (`adb install -r build\app\outputs\flutter-apk\app-release.apk`) atau salin berkas `app-release.apk` ke HP lalu install langsung (izinkan sumber tak dikenal).
3. Login dengan akun Supabase yang sama antara Web dan Mobile, lalu pastikan migrasi `supabase/migrations/20261115000100..20261115000300` sudah diterapkan jika menguji sinkronisasi live Cloud Supabase.

## 2. Daftar Uji Fitur Runtime
1. **Sinkronisasi Lintas Platform & Realtime**:
   - Buat 1 tugas D.2 (`status = doing`, checklist) dan 1 transaksi di Web -> pastikan muncul di Mobile (`Hari Ini` / `Agenda` / `Keuangan`) dalam beberapa detik lewat Realtime atau tombol refresh.
   - Uji mode pesawat (offline): buat transaksi & ubah progres tugas di HP -> matikan mode pesawat -> verifikasi perubahan muncul di Web tanpa tertimpa data lama.
2. **Android Homescreen Widgets (`app/android/...`)**:
   - Tekan lama layar utama launcher HP -> pilih Widgets -> Orbit:
     - Pasang `Orbit Hari Ini (4x2)`, `Orbit Tugas (2x2)`, `Orbit Tambah Cepat (4x1)`, dan `Orbit Saldo (2x1)`.
   - Aktifkan **Mode Privasi** (ikon mata di app bar atau Pengaturan) -> ketuk *Perbarui Widget Sekarang* atau tunggu sinkronisasi -> pastikan widget `Orbit Saldo` menampilkan `Rp ••••••`.
   - Ketuk tombol `+ Transaksi` / `+ Tugas` / `+ Struk` pada `Orbit Tambah Cepat` -> pastikan membuka halaman/dialog cepat yang sesuai melalui deep link `io.supabase.orbit://quick-add`.
3. **Notifikasi Terjadwal & Pengingat Cerdas**:
   - Masuk ke `Lainnya > Pengaturan > Notifikasi`:
     - Berikan izin `POST_NOTIFICATIONS`.
     - Aktifkan Ringkasan Pagi, Pengingat Jadwal, Tagihan H-3, dan Ringkasan Mingguan.
     - Tekan tombol *Kirim Notifikasi Uji* -> ketuk notifikasi -> verifikasi app terbuka pada tab/rute target.
   - Verifikasi saat `Tampilkan judul di layar kunci` nonaktif, isi sensitif disamarkan.
4. **NotificationListenerService (Notifikasi Bank & E-Wallet)**:
   - Di `Lainnya > Pengaturan`, ketuk *Buka Akses Notifikasi Android* lalu beri izin khusus untuk Orbit.
   - Pilih hanya paket aplikasi bank/e-wallet yang ingin dibaca.
   - Kirim transaksi uji / tunggu notifikasi pembayaran QRIS/transfer masuk -> buka tab `Uang > Inbox` dan verifikasi draf otomatis muncul dengan status `draft` (dan label `Perlu dicek` bila nominal/merchant meragukan).
5. **Share Target Android & OCR Struk ML Kit**:
   - Dari Galeri/WhatsApp/aplikasi lain, ketuk *Bagikan (Share)* foto struk belanja atau teks mutasi ke Orbit.
   - Verifikasi teks atau hasil OCR ML Kit diparse menjadi draft di `Inbox` dan file sementara dibersihkan.
6. **Kunci Biometrik / PIN & Mode Privasi**:
   - Di Pengaturan Keamanan, pasang PIN 4-6 digit dan aktifkan Kunci Biometrik -> tutup lalu buka kembali aplikasi -> verifikasi `BiometricPrompt` muncul dan PIN fallback bekerja.

## 3. Cara Mengambil Log Jika Ada Masalah
Jalankan perintah berikut dari terminal Windows saat HP terhubung ADB (tanpa mencantumkan nominal/token pribadi saat membagikan cuplikan):

```powershell
adb logcat -c
# Reproduksi masalah di HP selama ~15 detik, lalu simpan log Flutter & Android Orbit:
adb logcat -d -s flutter OrbitWidgetProvider OrbitNotificationListener OrbitBackgroundWorker AndroidRuntime > orbit_android_log.txt
```
