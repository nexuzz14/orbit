# Arsitektur Navigasi Orbit v2 (Gaya Notion & Jira)

Dokumen ini memperbarui arsitektur navigasi untuk Web (`web/`) dan Aplikasi Android (`app/`) pada rombakan total Orbit v2. Tujuannya memastikan **semua fitur — termasuk Papan Kanban, Saved Views, Kegiatan/Proyek, dan Pengaturan — dapat dijangkau paling banyak dalam dua ketukan/klik** tanpa duplikasi navigasi.

---

## 1. Catatan Temuan Audit Navigasi Sebelumnya (Kanban D.2)

Sebelum menetapkan navigasi baru, pemeriksaan kode pada versi Fase D.1/D.2 mengungkap dua alasan mengapa pengguna tidak menemukan Papan Kanban yang diklaim selesai di Fase 2:
1. **Aplikasi Mobile (`app/lib/features/tasks/tasks_screen.dart`)**: Tombol segmen `Daftar | Papan` sudah dirender, namun percabangan tampilan di dalam metode `build()` tidak pernah memeriksa nilai `_viewMode == 'papan'`. Akibatnya, saat mengetuk **"Papan"**, layar tetap menampilkan daftar vertikal yang sama. **Papan Kanban belum ada di aplikasi mobile.**
2. **Aplikasi Web (`web/src/components/navigation.tsx` & `web/src/app/(dashboard)/tugas/page.tsx`)**: Papan Kanban hanya ada di `/tugas`, tetapi di sidebar desktop hanya tercantum tautan **"Agenda"** yang mengarah ke `/jadwal`. Pengguna harus masuk ke Agenda lalu menemukan tab sekunder `Tugas`, kemudian mengganti mode `Daftar` menjadi `Papan Kanban`. Selain itu, papan web masih terbatas pada 3 kolom tanpa drag-and-drop maupun penanda D.2.

Navigasi v2 menyelesaikan kedua masalah tersebut sekaligus agar Papan Tugas, Daftar, dan Kalender langsung terlihat.

---

## 2. Navigasi Aplikasi Web (`web/`, Desktop `>= 768 px`)

Mengadopsi pola **Sidebar Workspace Notion** yang dapat dilipat (`w-60` / `240 px` terbuka, `w-14` / `56 px` terlipat):

```text
+-------------------------------------------------------------------+
| [Logo Orbit]  Orbit / Pribadi                              [<<]   |
+-------------------------------------------------------------------+
| [Q] Cari cepat atau perintah...                          [Ctrl K] |
| [+] Tambah Cepat                                                  |
+-------------------------------------------------------------------+
| UTAMA                                                             |
|  o Hari Ini                    (/hari-ini)                        |
|  o Agenda & Jadwal             (/jadwal)                          |
|  o Tugas & Papan Kanban        (/tugas)                           |
|  o Keuangan                    (/transaksi)                       |
+-------------------------------------------------------------------+
| TAMPILAN TERSIMPAN (Saved Views)                                 |
|  * Terlambat & Revisi          (/tugas?view=perhatian)            |
|  * Papan Proyek Aktif          (/tugas?view=kanban)               |
+-------------------------------------------------------------------+
| KEGIATAN (Projects Switcher)                                      |
|  # Magang Backend Engineer     [Intern]                           |
|  # Redesign Portal Klien       [Freelance]                        |
|  # Skripsi & Kuliah Sem 7      [Kuliah]                           |
|  > Lihat semua kegiatan...     (/proyek)                          |
+-------------------------------------------------------------------+
| PENGELOLAAN                                                       |
|  o Kategori & Aturan           (/kategori)                        |
|  o Sumber Otomatis & Inbox     (/inbox)           [3 draft]       |
|  o Pengaturan & Keamanan       (/pengaturan)                      |
+-------------------------------------------------------------------+
| [Terang/Gelap]  [Sinkronisasi Aktif]               [Keluar]       |
+-------------------------------------------------------------------+
```

### Aturan Kunci Web v2
1. **Tanpa Navigasi Ganda Menjebak**: Setiap rute utama punya tepat satu tempat jelas (`Hari Ini`, `Agenda & Jadwal`, `Tugas & Papan`, `Keuangan`), dengan sub-tab internal hanya untuk sub-halaman di domain tersebut (`Transaksi | Akun | Anggaran | Tagihan | Target | Ringkasan` di Keuangan; `Daftar | Papan | Kalender | Linimasa` di Tugas & Agenda).
2. **Scroll Internal Mandiri + Footer Sticky**: Area tengah sidebar (`UTAMA`, `TAMPILAN TERSIMPAN`, `KEGIATAN`, `PENGELOLAAN`) memiliki `overflow-y-auto`, sementara header workspace di atas dan footer tema/keluar di bawah tetap terkunci pada viewport setinggi `>= 700 px`.
3. **Command Palette (`Ctrl+K`)**: Tersedia di seluruh rute dashboard untuk melompat ke halaman, mencari tugas/jadwal/transaksi/kegiatan, atau menjalankan aksi cepat (`Buat Tugas Baru`, `Catat Pengeluaran`, `Buka Papan Kanban`).
4. **Panel Detail Samping (Side Peek, Jira/Notion Pattern)**: Mengklik baris atau kartu tugas/kegiatan membuka panel detail `480 px` di kanan layar tanpa meninggalkan halaman aktif.

---

## 3. Navigasi Aplikasi Mobile (`app/` & Web Mobile `< 768 px`)

Tetap memakai **4 Tab Bottom Navigation Bar** agar nyaman dijangkau satu tangan, ditambah **Workspace Drawer Notion** dan **Pencarian Global**:

### 3.1 Empat Tab Bawah
| Indeks | Label | Ikon | Isi Utama |
| :--- | :--- | :--- | :--- |
| `0` | **Hari Ini** | `today_outlined` / `today` | Sapaan waktu WIB + tanggal, kartu ringkas progres & perhatian D.2 (ketuk langsung buka papan/tugas terkait), jadwal hari ini, tugas prioritas/terlambat, saldo & arus kas hari ini. |
| `1` | **Agenda** | `event_note_outlined` / `event_note` | Segmen atas: **Tugas** \| **Jadwal**. Di mode **Tugas**: view switcher **Daftar \| Papan (Kanban 4 Kolom) \| Kalender**, filter jenis & saved views. Di mode **Jadwal**: **Hari \| Minggu \| Linimasa**. |
| `2` | **Uang** | `account_balance_wallet_outlined` | Segmen utama: **Transaksi \| Akun \| Ringkasan**. Baris pintasan horizontal dengan efek fade tepi (*scroll hint*): **Inbox** (lencana jumlah draft), **Anggaran**, **Tagihan**, **Target**. |
| `3` | **Lainnya** | `grid_view_outlined` | Daftar terstruktur: **Kegiatan & Proyek**, **Piutang Termin**, **Kategori & Aturan**, **Sumber Otomatis & Notifikasi**, **Keamanan & Privasi**, **Pengaturan & Sinkronisasi**. |

### 3.2 App Bar Global & Workspace Drawer (Notion Style)
- Kiri atas di App Bar pada keempat tab: tombol ikon panel/menu untuk membuka **Workspace Drawer** berisi daftar cepat **Tampilan Tersimpan** (seperti *Papan Kanban*, *Tugas Revisi & Terlambat*) dan daftar **Kegiatan Aktif**.
- Kanan atas di App Bar: tombol **Cari (`Search`)** (membuka Command Search lintas tugas, jadwal, transaksi, proyek) dan tombol **Tambah (`+`)** atau FAB kontekstual.
- **PopScope Android**: Tombol kembali menutup panel/drawer -> menutup modal/halaman dalam -> kembali ke tab `Hari Ini` (`0`) -> baru keluar app.
- **Alternatif Gestur**: Memindahkan kartu di Kanban mobile memakai tombol menu cepat atau drag-handle sekaligus dialog/bottom-sheet pindah status (dan isi catatan bila ke `Revisi`) sehingga tetap dapat diakses penuh tanpa ketergantungan pada gestur seret layar kecil.
