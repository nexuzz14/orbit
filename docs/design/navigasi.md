# Arsitektur Navigasi Orbit (Fase D - Langkah 2)

Dokumen ini menetapkan arsitektur navigasi standar untuk Aplikasi Mobile (`app/`) dan Aplikasi Web (`web/`) agar setiap fitur dapat dijangkau maksimal dalam **dua ketukan/klik**, konsisten lintas platform, dan mempertahankan konteks pengguna saat berpindah tab.

---

## 1. Empat Grup Utama (Taksonomi Seragam)

Seluruh fitur Orbit dikelompokkan ke dalam empat domain utama yang identik antara App dan Web:

1. **Hari Ini**
   - Fokus: Ringkasan operasional harian (jadwal hari ini, tugas hari ini & terlambat, serta ringkasan uang hari itu sesuai urutan PRD M10c).
2. **Agenda**
   - Fokus: Pengelolaan waktu dan eksekusi kerja.
   - Sub-mode: **Jadwal** (tampilan hari dan minggu) | **Tugas** (tampilan daftar dan opsi papan).
   - Filter bersama: Chip jenis kegiatan (`Semua`, `Intern`, `Freelance`, `Kuliah`, `Pribadi`).
3. **Uang**
   - Fokus: Arus kas, akun, dan perencanaan keuangan.
   - Sub-mode utama: **Transaksi** | **Akun** | **Ringkasan**.
   - Baris pintasan kontekstual di bawahnya: **Inbox** (dengan lencana jumlah draft yang menunggu konfirmasi), **Anggaran**, **Tagihan**, dan **Target**.
4. **Lainnya**
   - Fokus: Entitas induk, aturan otomatisasi, keamanan, dan preferensi.
   - Daftar menu:
     - **Kegiatan** (proyek freelance, magang/intern, mata kuliah, kegiatan pribadi)
     - **Piutang** (komitmen pembayaran dan termin klien)
     - **Kategori dan Aturan** (kategori pemasukan/pengeluaran serta aturan klasifikasi otomatis)
     - **Sumber Otomatis** (status integrasi notifikasi dan penerusan email)
     - **Keamanan** (TOTP 2FA, sesi aktif, kunci aplikasi)
     - **Pengaturan** (preferensi notifikasi, tema tampilan, profil, keluar)

---

## 2. Arsitektur Navigasi Aplikasi Mobile (`app/`)

### 2.1 Bottom NavigationBar (4 Tab)
Menggunakan komponen Material 3 `NavigationBar` dengan 4 `NavigationDestination`:

| Indeks | Label | Ikon (Tidak Aktif / Aktif) | Isi Layar Utama |
| :--- | :--- | :--- | :--- |
| `0` | **Hari Ini** | `Icons.today_outlined` / `Icons.today` | Header sapaan + tanggal, filter jenis kegiatan, jadwal hari ini, tugas hari ini & terlambat, serta ringkasan pemasukan/pengeluaran/saldo hari itu. |
| `1` | **Agenda** | `Icons.event_note_outlined` / `Icons.event_note` | `SegmentedButton` (`Jadwal` \| `Tugas`), chip filter jenis kegiatan (`Semua`, `Intern`, `Freelance`, `Kuliah`, `Pribadi`), pemilih tampilan (`Hari`/`Minggu` pada Jadwal; `Daftar`/`Papan` pada Tugas). |
| `2` | **Uang** | `Icons.account_balance_wallet_outlined` / `Icons.account_balance_wallet` | `SegmentedButton` (`Transaksi` \| `Akun` \| `Ringkasan`) di bagian atas, diikuti baris pintasan horizontal (`Inbox` + lencana draft, `Anggaran`, `Tagihan`, `Target`). |
| `3` | **Lainnya** | `Icons.grid_view_outlined` / `Icons.grid_view_rounded` | Daftar `ListTile` terstruktur menuju: `Kegiatan`, `Piutang`, `Kategori dan Aturan`, `Sumber Otomatis`, `Keamanan`, dan `Pengaturan`. |

### 2.2 Perilaku FloatingActionButton (`+`) Kontekstual
`FloatingActionButton` (`+`) selalu tampil di keempat tab utama dengan perilaku kontekstual:
- **Pada Tab Hari Ini (`0`) dan Lainnya (`3`)**: Mengetuk `FAB (+)` membuka `ModalBottomSheet` berisi tiga pilihan aksi cepat:
  1. **Tambah Transaksi** (membuka bottom sheet form transaksi mobile-first)
  2. **Tambah Tugas** (membuka form tambah tugas)
  3. **Tambah Jadwal** (membuka form tambah jadwal)
- **Pada Tab Agenda (`1`)**:
  - Jika mode aktif adalah **Jadwal**, mengetuk `FAB (+)` langsung membuka form tambah jadwal.
  - Jika mode aktif adalah **Tugas**, mengetuk `FAB (+)` langsung membuka form tambah tugas.
- **Pada Tab Uang (`2`)**:
  - Mengetuk `FAB (+)` langsung membuka bottom sheet form tambah transaksi (`TransactionFormSheet`).

### 2.3 Aturan Interaksi dan Status Navigasi Mobile
1. **Maksimal Dua Ketukan**:
   - Ketukan 1: Pilih tab utama (`Hari Ini`, `Agenda`, `Uang`, atau `Lainnya`).
   - Ketukan 2: Pilih segmen (`Jadwal`/`Tugas`, `Transaksi`/`Akun`/`Ringkasan`), pintasan (`Inbox`, `Anggaran`, `Tagihan`, `Target`), atau item pada daftar `Lainnya`.
2. **Keadaan Tiap Tab Dipertahankan**:
   - Keempat tab utama dibungkus menggunakan `IndexedStack` sehingga posisi gulir (scroll), filter jenis kegiatan, dan segmen aktif pada setiap tab tidak hilang saat pengguna berpindah tab.
3. **Layar Dalam (Inner Screens)**:
   - Setiap layar yang dibuka dari pintasan `Uang` (`Inbox`, `Anggaran`, `Tagihan`, `Target`) atau daftar `Lainnya` (`Kegiatan`, `Piutang`, `Kategori dan Aturan`, `Sumber Otomatis`, `Keamanan`, `Pengaturan`) menggunakan `AppBar` standar dengan judul jelas dan tombol kembali (`BackButton`) berukuran minimal `44x44 px`.
4. **Perilaku Tombol Kembali Sistem Android (`PopScope`)**:
   - Jika pengguna berada di layar dalam (pushed route), tombol kembali sistem menutup layar dalam tersebut.
   - Jika pengguna berada di tab `Agenda`, `Uang`, atau `Lainnya`, tombol kembali sistem mengarahkan kembali ke tab `Hari Ini` (`indeks 0`) terlebih dahulu sebelum keluar dari aplikasi.
5. **Alternatif Non-Gestur**:
   - Setiap aksi yang memiliki jalan pintas geser (swipe) wajib menyediakan tombol biasa yang terlihat jelas di layar atau di dalam kartu/baris item.

---

## 3. Arsitektur Navigasi Aplikasi Web (`web/`)

### 3.1 Sidebar Kiri Desktop (`>= 768 px`)
- **Empat Grup Seragam**: Sidebar menampilkan empat grup yang sama persis dengan struktur App (`Hari Ini`, `Agenda`, `Uang`, `Lainnya`).
- **Dapat Dilipat (Collapsible)**:
  - Keadaan terbuka (`w-64` / `256 px`): menampilkan logo + teks "Orbit", judul grup, ikon (`Lucide`), label tautan, dan lencana jumlah draft pada `Inbox`.
  - Keadaan terlipat (`w-16` / `64 px`): menampilkan logo kompak, ikon navigasi terpusat dengan atribut `title` dan `aria-label`, serta tombol pelipat sidebar (`ChevronLeft` / `ChevronRight`) berukuran minimal `44x44 px`.
- **Posisi Tetap (Fixed Viewport)**: Sidebar terkunci penuh setinggi layar (`fixed inset-y-0 left-0 h-screen`) dan tidak ikut tergulir bersama konten utama.

### 3.2 Top Bar Global
- Berada di bagian atas area konten (`sticky top-0 z-30 h-16`).
- Memuat:
  1. **Kotak Pencarian Cepat (`Search`)**: Mencari transaksi, tugas, jadwal, atau halaman secara cepat.
  2. **Menu `"+ Tambah"`**: Membuka dropdown aksi cepat (`Tambah Transaksi`, `Tambah Tugas`, `Tambah Jadwal`) dari halaman mana pun.
  3. **Pengalih Tema (`Mode Terang` / `Mode Gelap`)**: Tombol dengan target sentuh `44x44 px` dan label pembaca layar.

### 3.3 Bottom Navigation Mobile Web (`< 768 px`)
- Pada lebar layar mobile (`< 768 px`), sidebar kiri disembunyikan dan digantikan oleh **Bottom Navigation Bar 4 tab** yang identik dengan aplikasi mobile (`Hari Ini`, `Agenda`, `Uang`, `Lainnya`).
- Di dalam halaman grup (`Agenda` dan `Uang`), ditampilkan kontrol segmen (`Jadwal | Tugas` atau `Transaksi | Akun | Ringkasan`) serta baris pintasan horizontal (`Inbox`, `Anggaran`, `Tagihan`, `Target`) sehingga seluruh halaman tetap terjangkau maksimal dalam dua ketukan tanpa drawer tersembunyi.
