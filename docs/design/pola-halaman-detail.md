# Pola Halaman Detail & Panel Samping (Notion + Jira)

Setiap objek inti di Orbit (`Tugas`, `Jadwal`, `Kegiatan/Proyek`, `Transaksi`) menerapkan satu pola tampilan detail terpadu. Ini menggantikan formulir modal kaku yang sebelumnya terpisah-pisah antara mode buat dan lihat.

---

## 1. Struktur Halaman Detail

```text
+-------------------------------------------------------------------+
| [Tipe: Tugas Freelance]  [Tautan Kegiatan: Redesign Portal]  [...]|
|                                                                   |
| Implementasi API Checkout & Callback Midtrans                     |
|                                                                   |
| PROPRTI INLINE (Grid 2 Kolom Key -> Chip Interaktif)              |
|  Status      : [> Dikerjakan v]      Progres  : [========--] 75%  |
|  Prioritas   : [^ Tinggi v]          Revisi   : [1x Revisi]       |
|  Tenggat     : [17 Nov 2026 23:59]   Estimasi : [120 menit]       |
|  Penanggung  : [Nabil]               Perulang.: [Tidak berulang]  |
|  Milestone   : [Termin 2 - Rp 1.500.000]                          |
+-------------------------------------------------------------------+
| PERHATIAN AKTIF (bila ada)                                        |
|  [!] Di status Dikerjakan selama 6 hari tanpa pembaruan (Macet)   |
+-------------------------------------------------------------------+
| DESKRIPSI & CATATAN (Blok Notion / Editor Kaya di Web)            |
|  Gunakan webhook sandbox sebelum switch ke production key.        |
|  > Endpoint: /api/payments/callback                               |
+-------------------------------------------------------------------+
| SUBTUGAS & CHECKLIST (Auto Progress = selesai / total)            |
|  [x] Buat endpoint verifikasi signature                           |
|  [x] Simpan idempotency key di PostgreSQL                         |
|  [x] Uji pembayaran sukses dan kedaluwarsa                        |
|  [ ] Tangani status pending VA BCA                                |
|  [+ Tambah item checklist...]                                     |
+-------------------------------------------------------------------+
| TAUTAN ANTAR OBJEK                                                |
|  Jadwal Terkait : Review Klien Portal (Besok, 14:00)              |
|  Keuangan       : Termin 2 Proyek Redesign (Belum lunas)          |
+-------------------------------------------------------------------+
| RIWAYAT STATUS & KOMENTAR (D.2 Audit Trail)                       |
|  * 14 Nov 10:15 - Status: Dikerjakan -> Revisi (Catatan: Tambah   |
|    penanganan retry webhook saat timeout)                         |
|  * 15 Nov 09:00 - Status: Revisi -> Dikerjakan                    |
|  [Tulis komentar atau catatan perubahan...]                       |
+-------------------------------------------------------------------+
```

---

## 2. Aturan Perilaku & Interaksi (M10 / D.2)

1. **Panel Samping (Web Desktop >= 1024 px) vs Halaman Penuh (Mobile)**:
   - Di Web, mengetuk item pada Daftar, Papan Kanban, Kalender, atau Hari Ini membuka **Side Peek Sheet** selebar `480 px` - `520 px` di sisi kanan layar tanpa memindah rute. Pengguna dapat mengklik *"Buka Penuh"* untuk memperluasnya menjadi halaman modal penuh (`max-w-3xl`), atau tekan `Esc` untuk menutup.
   - Di Mobile, mengetuk item mendorong halaman detail (`Navigator.push`) dengan `AppBar` judul ringkas, tombol kembali `44x44 px`, dan tombol ubah status cepat di bagian atas.
2. **Perhitungan Progres (`progress_percent`, `0..100`)**:
   - Bila tugas memiliki **minimal 1 item checklist atau subtugas**: nilai `progress_percent` **otomatis** dihitung sebagai `round((selesai / total) * 100)`, badge menampilkan tulisan `Otomatis dari checklist`, dan slider manual dikunci (nonaktif) agar tidak saling menimpa.
   - Bila tugas **tidak memiliki checklist/subtugas**: pengguna dapat mengatur progres secara manual menggunakan slider langkah `5` (`0, 5, 10, ..., 100`), atau mengetuk cepat preset `0% | 25% | 50% | 75% | 100%`.
   - Memindahkan status ke **`Selesai` (`done`)** otomatis menetapkan `progress_percent = 100` (dengan tetap menghormati aturan checklist bila diinginkan, atau langsung menandai `100` di database sesuai D.2). Membuka kembali tugas dari `Selesai` ke `Belum dikerjakan` / `Dikerjakan` / `Revisi` **tidak mereset** `progress_percent` yang sudah dicapai.
3. **Transisi Ke Status `Revisi` dan Riwayat Status**:
   - Memilih status `Revisi` selalu membuka kotak **Catatan Revisi (opsional namun disarankan)**, baik lewat dialog kecil saat drag-drop di papan Kanban maupun inline popover di halaman detail.
   - Setiap perpindahan status mencatat baris baru (append-only) di tabel `task_status_history` (`from_status`, `to_status`, `changed_at`, `changed_by`, `note`), memperbarui `status_changed_at`, dan menambah `revision_count` sebesar `+1` setiap kali status tujuan adalah `revisi`.
4. **Papan Kanban 4 Kolom**:
   - Kolom berurutan dari kiri ke kanan: **Belum dikerjakan (`todo`)**, **Dikerjakan (`doing`)**, **Revisi (`revisi`)**, **Selesai (`done`)**.
   - Kolom **Selesai** secara bawaan hanya merender tugas yang selesai dalam **14 hari terakhir** agar papan tetap cepat dan fokus, disertai tautan **"Lihat semua selesai"** di bawah kolom.
   - Urutan dalam kolom mengikuti **prioritas (`tinggi` -> `sedang` -> `rendah`) lalu tenggat terdekat**, atau memakai `sort_order` manual bila pengguna menyeret kartu secara manual di Web.
5. **Pemasukan / Transaksi / Jadwal Detail**:
   - **Jadwal** menampilkan properti Jenis, Waktu & Zona (`WIB`), Pola Berulang, Lokasi (terlindungi di audit log), Benturan Terdeteksi, dan Pengingat (`30 menit sebelumnya`).
   - **Transaksi** menampilkan display nominal besar di atas, Akun, Kategori, Jenis Kegiatan (`Intern/Freelance/Kuliah/Pribadi`), Status (`Draft / Confirmed`), Origin (`Notifikasi / Bukti / Manual`), dan tombol konfirmasi/hapus lunak.
