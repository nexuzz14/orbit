# Sistem Desain Orbit (Fase D - Langkah 3)

Dokumen ini merupakan sumber kebenaran tunggal (*single source of truth*) untuk design token dan komponen inti pada Aplikasi Web (`web/`) dan Aplikasi Mobile (`app/`). Seluruh layar wajib memakai token dan komponen dari sistem ini; dilarang menulis nilai warna heksadesimal atau ukuran mentah secara langsung di berkas layar.

---

## 1. Prinsip Utama
1. **Netral-Minimal dan Familiar**: Permukaan putih dan abu-abu bersih (`Slate`), satu warna aksen biru tenang (`#0284C7` pada mode terang, `#38BDF8` pada mode gelap), tanpa gradasi kosmik atau bayangan berpendar.
2. **Mode Terang dan Mode Gelap Setara**: Seluruh token memiliki pasangan nilai terang dan gelap yang memenuhi kontras minimal WCAG AA (`>= 4.5:1` untuk teks normal, `>= 3:1` untuk teks besar dan elemen antarmuka).
3. **Warna Kegiatan Selalu Disertai Label Teks**: Tidak boleh mengandalkan warna saja untuk membedakan `Intern`, `Freelance`, `Kuliah`, dan `Pribadi`.
4. **Satu Keluarga Font dan Satu Keluarga Ikon**:
   - Font: `Plus Jakarta Sans` (dengan fallback `Inter`, `system-ui`, `sans-serif`), serta `tabular-nums` wajib untuk seluruh nominal uang, jam, dan persentase.
   - Ikon: `Material Symbols` / `Icons` (Material 3) di App, `Lucide` (`lucide-react`) di Web. Tanpa emoji di seluruh antarmuka.

---

## 2. Design Token

### 2.1 Token Warna Permukaan, Teks, dan Aksen

| Token | Mode Terang | Mode Gelap | Penggunaan |
| :--- | :--- | :--- | :--- |
| `bg-canvas` / `surface` | `#F8FAFC` (Slate 50) | `#0F172A` (Slate 900) | Latar belakang utama halaman/layar |
| `bg-surface` / `surfaceContainerLow` | `#FFFFFF` (White) | `#1E293B` (Slate 800) | Kartu, sidebar, modal, bottom sheet |
| `bg-subtle` / `surfaceContainerHighest` | `#F1F5F9` (Slate 100) | `#334155` (Slate 700) | Latar kontrol segmen, chip pasif, skeleton |
| `border-default` / `outlineVariant` | `#E2E8F0` (Slate 200) | `#334155` (Slate 700) | Garis batas kartu, pemisah daftar, input |
| `text-primary` / `onSurface` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Judul, nominal utama, isi utama |
| `text-secondary` / `onSurfaceVariant` | `#475569` (Slate 600) | `#CBD5E1` (Slate 300) | Subjudul, metadata, label sekunder |
| `text-muted` | `#64748B` (Slate 500) | `#94A3B8` (Slate 400) | Keterangan waktu, placeholder |
| `accent-primary` / `primary` | `#0284C7` (Sky 600) | `#38BDF8` (Sky 400) | Satu-satunya warna aksen utama (tombol utama, tab aktif, fokus) |
| `accent-subtle` / `primaryContainer` | `#E0F2FE` (Sky 100) | `#0C4A6E` (Sky 900) | Latar elemen terpilih dan indikator tab aktif |

### 2.2 Token Warna Semantik Keuangan & Status

| Token Semantik | Teks (Terang / Gelap) | Latar Halus (Terang / Gelap) | Batas (Terang / Gelap) | Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| **Pemasukan (`income`)** | `#15803D` / `#4ADE80` | `#DCFCE7` / `#052E16` | `#BBF7D0` / `#14532D` | Nominal masuk (`+`), indikator kas positif |
| **Pengeluaran (`expense`)** | `#DC2626` / `#F87171` | `#FEE2E2` / `#450A0A` | `#FECACA` / `#7F1D1D` | Nominal keluar (`-`), lewat tenggat, benturan jadwal |
| **Peringatan (`warning`)** | `#B45309` / `#FBBF24` | `#FEF3C7` / `#451A03` | `#FDE68A` / `#78350F` | Status `Draft`, anggaran >= 80%, tagihan H-3 |

### 2.3 Token Warna Jenis Kegiatan (Wajib Disertai Label Teks)

| Jenis (`kind`) | Label Teks Baku | Teks (Terang / Gelap) | Latar Badge (Terang / Gelap) | Batas Badge (Terang / Gelap) |
| :--- | :--- | :--- | :--- | :--- |
| `intern` | **Intern** | `#0369A1` / `#7DD3FC` | `#E0F2FE` / `#0C4A6E` | `#BAE6FD` / `#075985` |
| `freelance` | **Freelance** | `#6D28D9` / `#C4B5FD` | `#EDE9FE` / `#2E1065` | `#DDD6FE` / `#4C1D95` |
| `kuliah` | **Kuliah** | `#B45309` / `#FCD34D` | `#FEF3C7` / `#451A03` | `#FDE68A` / `#78350F` |
| `pribadi` / `personal` | **Pribadi** | `#334155` / `#CBD5E1` | `#F1F5F9` / `#1E293B` | `#E2E8F0` / `#475569` |

### 2.4 Skala Tipografi Baku

| Token | Ukuran (`px` / `rem`) | Tinggi Baris (`line-height`) | Ketebalan (`font-weight`) | Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| `display-amount` | `28 px` (`1.75rem`) | `36 px` | `700` (`tabular-nums`) | Input nominal besar di atas form tambah transaksi |
| `heading-xl` | `24 px` (`1.5rem`) | `32 px` | `700` | Judul halaman / sapaan utama |
| `heading-lg` | `18 px` (`1.125rem`) | `28 px` | `600` | Judul bagian / kartu utama |
| `body-md` | `16 px` (`1rem`) | `24 px` | `400` / `500` | Teks isi standar dan input form |
| `body-sm` | `14 px` (`0.875rem`) | `20 px` | `400` / `500` | Baris daftar, tabel, dan tombol |
| `caption` | `12 px` (`0.75rem`) | `16 px` | `500` / `600` | Badge, label grup tanggal, metadata |

### 2.5 Spasi (Grid 4/8), Radius, Bayangan, dan Durasi Animasi
- **Spasi Baku (`AppTokens.spacing` / Tailwind)**:
  - `space-1`: `4 px` (jarak ikon ke teks dalam badge)
  - `space-2`: `8 px` (jarak antar-chip, jarak elemen internal rapat)
  - `space-3`: `12 px` (padding vertikal baris daftar)
  - `space-4`: `16 px` (padding kartu standar, jarak antar-kartu mobile)
  - `space-6`: `24 px` (padding halaman desktop, pemisah antar-bagian)
  - `space-8`: `32 px` (batas margin luar halaman desktop)
- **Radius Sudut**:
  - `radius-sm`: `6 px` (badge dan lencana)
  - `radius-md`: `8 px` (tombol, input, chip, kontrol segmen)
  - `radius-lg`: `12 px` (kartu, dialog, bottom sheet)
- **Bayangan Minimal**:
  - Kartu menggunakan garis batas `1 px` (`border-default`) dan bayangan sangat halus `0 1px 2px rgba(15, 23, 42, 0.04)`. Dilarang memakai bayangan berwarna/neon.
- **Animasi & Gerakan**:
  - Durasi transisi maksimal `150 ms - 200 ms` (`ease-out`).
  - Menghormati `prefers-reduced-motion: reduce` di Web dan `MediaQuery.disableAnimationsOf(context)` di App.
- **Target Sentuh**:
  - Seluruh elemen interaktif (tombol, chip, tab, ikon aksi) wajib memiliki area ketuk minimal `44x44 px` (`min-h-11 min-w-11` di Web, `ConstrainedBox(constraints: BoxConstraints(minWidth: 44, minHeight: 44))` di App).

---

## 3. Komponen Inti yang Dipakai Ulang

### 3.1 Komponen Inti Web (`web/src/components/ui/`)
1. `Button` (`button.tsx`): Varian `primary`, `secondary`, `outline`, `ghost`, `destructive`; ukuran `default` (`min-h-11 px-4`), `sm` (`min-h-11 px-3`), `icon` (`h-11 w-11`); cincin fokus keyboard terlihat jelas (`focus-visible:ring-2`).
2. `Input` & `Select` (`input.tsx`, `select.tsx`): Tinggi standar `44 px` (`h-11`), border netral, state error dan fokus konsisten.
3. `Card` (`card.tsx`): Kontainer permukaan netral (`Card`, `CardHeader`, `CardTitle`, `CardContent`).
4. `SegmentedControl` / `Tabs` (`segmented-control.tsx`): Pemilih mode setara shadcn/ui Tabs (`Jadwal | Tugas`, `Transaksi | Akun | Ringkasan`, `Pengeluaran | Pemasukan | Transfer`).
5. `Badge` & `KindBadge` (`badge.tsx`): Lencana status (`Draft`, `Terlambat`, `Benturan`) dan lencana jenis kegiatan (`Intern`, `Freelance`, `Kuliah`, `Pribadi`) yang selalu menyertakan teks.
6. `Dialog` & `Sheet` (`sheet.tsx`): Modal/panel standar dengan dukungan tombol `Escape`, penguncian fokus, dan penutup yang memiliki `aria-label`.
7. `Skeleton` (`skeleton.tsx`): Kerangka pemuatan tanpa pergeseran tata letak.
8. `EmptyState` & `ErrorState` (`state-views.tsx`):
   - `EmptyState`: Ikon netral, judul singkat, deskripsi satu kalimat, dan tepat satu tombol aksi utama.
   - `ErrorState`: Pesan kesalahan jelas dan tombol **"Coba Lagi"**.
9. `TransactionFormModal` (`transaction-form-modal.tsx`): Form tambah transaksi *mobile-first* (nominal besar di atas, jenis segmented, chip akun dan kategori yang dapat digulir horizontal, tanggal default hari ini, tombol simpan selalu terlihat, maksimal 4 interaksi).

### 3.2 Komponen Inti App (`app/lib/core/theme/` & `app/lib/core/widgets/`)
1. `AppTheme` & `AppTokens` (`app_colors.dart`, `app_tokens.dart`): Definisi `ThemeData` Material 3 (`useMaterial3: true`, `ColorScheme.fromSeed(seedColor: Color(0xFF0284C7))` untuk terang dan gelap), skala teks, serta token warna semantik dan jenis kegiatan.
2. `OrbitCard` (`orbit_card.dart`): Pembungkus `Card` Material 3 tanpa elevasi berlebih dengan garis tepi `outlineVariant` dan padding konsisten `16 px`.
3. `OrbitKindBadge` & `OrbitStatusBadge` (`orbit_badge.dart`): Lencana jenis kegiatan dan status (`Draft`, `Benturan`) yang selalu menampilkan warna + label teks.
4. `OrbitSkeleton` (`orbit_skeleton.dart`): Kerangka loading berstruktur untuk kartu ringkasan dan daftar baris.
5. `OrbitEmptyState` & `OrbitErrorState` (`orbit_state_views.dart`): Komponen standar untuk keadaan kosong (teks singkat + 1 tombol aksi) dan keadaan error (pesan jelas + tombol "Coba Lagi" dengan tinggi minimal `44 px`).
6. `TransactionFormSheet` (`transaction_form_sheet.dart`): `ModalBottomSheet` tambah transaksi *mobile-first* yang dipakai bersama oleh `FloatingActionButton (+)` dan layar `Transaksi`.
