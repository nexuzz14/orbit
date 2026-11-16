# Sistem Desain Orbit v2 (Gaya Notion & Jira)

Dokumen ini menjadi sumber kebenaran tunggal (*single source of truth*) untuk design token, pola tata letak, dan perilaku antarmuka di Web (`web/`) dan Aplikasi Android (`app/`). Seluruh layar baru wajib memakai token dan komponen dari sistem ini; dilarang menanam nilai warna heksadesimal mentah di berkas layar.

Status: **DIKUNCI (Opsi A — Biru Tenang Orbit disetujui pengguna pada 15 Nov 2026)** — menjadi kontrak token tunggal untuk Web (`web/`) dan Aplikasi Android (`app/`).

---

## 1. Filosofi Visual (Notion + Jira)

1. **Blok dan Daftar Datar, Bukan Kartu Berwarna**:
   - Hindari kartu bertumpuk tebal dengan latar mencolok atau bayangan neon.
   - Permukaan kanvas tenang, garis batas tipis `1 px` (*hairline border*), hover lembut, dan tipografi yang memisahkan hierarki.
2. **Satu Pola per Objek (Halaman & Panel Detail)**:
   - Setiap **Tugas**, **Jadwal**, **Kegiatan/Proyek**, dan **Transaksi** memiliki pola **Halaman Detail** (gaya Notion: judul besar, tabel properti di atas, blok konten/catatan di bawah, lalu riwayat & komentar).
   - Di **Web Desktop**, item terbuka di **Panel Samping (Side Peek)** selebar `480 px` agar konteks daftar atau papan Kanban tidak hilang, dengan tombol *"Buka Penuh"* bila ingin fokus.
   - Di **Mobile Android**, item terbuka sebagai rute halaman penuh dengan tombol kembali yang jelas.
3. **Properti Inline Gaya Jira**:
   - Status (`Belum dikerjakan`, `Dikerjakan`, `Revisi`, `Selesai`), Prioritas (`Tinggi`, `Sedang`, `Rendah`), Progres (`0-100%`), Jenis Kegiatan, dan Tenggat disajikan sebagai **chip properti inline** yang ringkas dan dapat diketuk langsung untuk mengubah nilai.
4. **Satu Data, Banyak Tampilan (View Switcher)**:
   - Setiap modul mendukung perpindahan tampilan atas data yang sama (`Daftar`, `Papan`, `Kalender`, `Linimasa`), dan pilihan terakhir pengguna diingat per layar.
5. **Tipografi dan Ikon Tunggal**:
   - Font utama: `Plus Jakarta Sans` (cadangan `Inter`, `Segoe UI`, `sans-serif`) + `JetBrains Mono` untuk pintasan keyboard (`Ctrl+K`) dan kode referensi.
   - Seluruh angka uang, persentase progres, durasi, dan jam wajib memakai `tabular-nums` (`FontFeature.tabularFigures()` di Flutter).
   - Keluarga ikon: `Lucide` (`lucide-react`, `strokeWidth={1.75}`) di Web dan `Material Symbols / Icons outlined` di Mobile. **Dilarang menggunakan emoji di seluruh UI.**

---

## 2. Aksen Warna Terpilih (Opsi A — Dikunci)

Berdasarkan persetujuan mockup v2, seluruh permukaan netral Notion-Zinc dipadukan dengan aksen resmi **Opsi A — Biru Tenang Orbit** (kandidat alternatif Opsi B Monokrom Graphite diarsipkan sebagai tidak dipilih):

### Opsi A (Aktif) — Biru Tenang Orbit (`#0284C7` / `#38BDF8`)
- Dipakai pada tombol CTA utama, indikator fokus, tab aktif, progres bar utama, dan lencana navigasi aktif.
- **Mode Terang**: `accent-primary = #0284C7`, `accent-fg = #FFFFFF`, `accent-subtle = #E0F2FE`
- **Mode Gelap**: `accent-primary = #38BDF8`, `accent-fg = #0F172A`, `accent-subtle = #0C4A6E`

---

## 3. Token Warna Baku

### 3.1 Permukaan, Teks, dan Garis Batas (Netral Notion-Warm/Zinc)

| Token | Mode Terang | Mode Gelap | Penggunaan |
| :--- | :--- | :--- | :--- |
| `bg-canvas` | `#FFFFFF` | `#191919` | Latar area konten utama |
| `bg-sidebar` | `#F7F7F5` | `#202020` | Latar sidebar web, kolom papan Kanban, area sekunder |
| `bg-surface` | `#FFFFFF` | `#242424` | Kartu papan, dialog, panel detail samping (Side Peek), bottom sheet |
| `bg-subtle` | `#EFEFED` | `#2F2F2F` | Chip pasif, hover item menu, kontrol segmen latar |
| `bg-hover` | `#F4F4F2` | `#2A2A2A` | Latar baris daftar atau sel tabel saat disorot |
| `border-default` | `#E6E6E3` | `#323232` | Garis batas tipis `1 px` kartu, pemisah daftar, input |
| `border-strong` | `#D1D1CC` | `#454545` | Garis focus fallback dan pembatas kolom papan |
| `text-primary` | `#11181C` | `#F3F3F2` | Judul halaman, nama tugas, nominal utama |
| `text-secondary` | `#555550` | `#B3B3AE` | Properti metadata, subjudul, ikon tidak aktif |
| `text-muted` | `#80807A` | `#7E7E78` | Placeholder, keterangan waktu, pembatas bagian |

### 3.2 Token Warna Status Tugas (D.2 — Jira Workflow)

| Status Kode | Label UI | Teks (Terang / Gelap) | Latar Halus (Terang / Gelap) | Garis Tepi (Terang / Gelap) | Makna |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `todo` | **Belum dikerjakan** | `#475569` / `#CBD5E1` | `#F1F5F9` / `#27272A` | `#E2E8F0` / `#3F3F46` | Baru dibuat atau dibuka kembali |
| `doing` | **Dikerjakan** | `#0369A1` / `#7DD3FC` | `#E0F2FE` / `#0C4A6E` | `#BAE6FD` / `#075985` | Sedang berjalan |
| `revisi` | **Revisi** | `#B45309` / `#FCD34D` | `#FEF3C7` / `#451A03` | `#FDE68A` / `#78350F` | Memerlukan perbaikan; mencatat `revision_count` & catatan |
| `done` | **Selesai** | `#15803D` / `#4ADE80` | `#DCFCE7` / `#052E16` | `#BBF7D0` / `#14532D` | Selesai (`progress_percent = 100`) |

### 3.3 Token Warna Semantik Keuangan & Perhatian

| Token Semantik | Teks (Terang / Gelap) | Latar Halus (Terang / Gelap) | Batas (Terang / Gelap) | Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| `income` | `#15803D` / `#4ADE80` | `#DCFCE7` / `#052E16` | `#BBF7D0` / `#14532D` | Pemasukan (`+`), saldo aman, target tercapai |
| `expense` | `#DC2626` / `#F87171` | `#FEE2E2` / `#450A0A` | `#FECACA` / `#7F1D1D` | Pengeluaran (`-`), **Terlambat**, **Benturan Jadwal**, Prioritas Tinggi |
| `warning` | `#B45309` / `#FBBF24` | `#FEF3C7` / `#451A03` | `#FDE68A` / `#78350F` | **Macet > 5 hari**, Status Draft, Anggaran >= 80%, Tagihan H-3 |

### 3.4 Token Warna Jenis Kegiatan (Wajib Disertai Label Teks)

| `kind` | Label Baku | Teks (Terang / Gelap) | Latar Badge (Terang / Gelap) | Batas (Terang / Gelap) |
| :--- | :--- | :--- | :--- | :--- |
| `intern` | **Magang** (`Intern`) | `#0369A1` / `#7DD3FC` | `#E0F2FE` / `#0C4A6E` | `#BAE6FD` / `#075985` |
| `freelance` | **Proyek** (`Freelance`) | `#6D28D9` / `#C4B5FD` | `#EDE9FE` / `#2E1065` | `#DDD6FE` / `#4C1D95` |
| `kuliah` | **Mata Kuliah** (`Kuliah`) | `#B45309` / `#FCD34D` | `#FEF3C7` / `#451A03` | `#FDE68A` / `#78350F` |
| `pribadi` / `personal` | **Kegiatan** (`Pribadi`) | `#3F3F46` / `#D4D4D8` | `#F4F4F5` / `#27272A` | `#E4E4E7` / `#3F3F46` |

---

## 4. Tipografi, Spasi, Radius, & Aksesibilitas

| Token | Ukuran / Nilai | Tinggi Baris | Ketebalan | Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| `display-amount` | `28 px` | `36 px` | `700` | Input nominal besar form transaksi |
| `page-title` | `24 px` (Mobile `22 px`) | `32 px` | `700` | Judul halaman gaya Notion dan sapaan Hari Ini |
| `heading-lg` | `18 px` | `26 px` | `600` | Judul bagian atau drawer detail |
| `heading-sm` | `15 px` | `22 px` | `600` | Judul kartu papan Kanban atau kelompok |
| `body-md` | `14 px` | `20 px` | `400` / `500` | Baris daftar, isi blok catatan, tabel properti |
| `caption` | `12 px` | `16 px` | `500` / `600` | Label kolom, properti chip, badge, metadata waktu |
| `micro` | `11 px` | `14 px` | `600` | Khusus label counter kecil atau shortcut (`Ctrl+K`) |

- **Spasi (Grid 4/8)**: `4 px` (`space-1`), `8 px` (`space-2`), `12 px` (`space-3`), `16 px` (`space-4`), `24 px` (`space-6`), `32 px` (`space-8`).
- **Radius Sudut**:
  - `radius-xs`: `4 px` (lencana status Jira inline, tag kecil)
  - `radius-sm`: `6 px` (item menu sidebar, properti chip, tombol compact)
  - `radius-md`: `8 px` (kartu papan Kanban, input, segmented switch)
  - `radius-lg`: `12 px` (modal, bottom sheet, panel detail, grup pengaturan)
- **Elevasi & Bayangan**:
  - Kartu datar hanya memakai `1 px solid border-default`.
  - Floating popover / dropdown / panel Side Peek memakai bayangan netral halus `0 4px 16px rgba(0, 0, 0, 0.08)` di mode terang dan `0 8px 24px rgba(0, 0, 0, 0.45)` di mode gelap.
- **Target Sentuh Minimum**: Seluruh tombol, chip interaktif, tab, ikon tutup, dan item checkbox memiliki area ketuk minimum `44x44 px` (di Web: tombol kompak tetap dapat memiliki tinggi visual `32 px` dengan hit-target wrapper atau `min-h-11` di kontrol utama & mobile viewport).
- **Gerakan**: Transisi maksimal `150 ms ease-out`, menghormati `prefers-reduced-motion` dan `MediaQuery.disableAnimationsOf`.
