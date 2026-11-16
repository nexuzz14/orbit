# Spesifikasi 12 Komponen Inti Orbit v2

Seluruh layar Web (`web/src/components/ui/`) dan Mobile (`app/lib/core/widgets/`) dibangun dari 12 blok komponen bersama di bawah ini. Tidak ada lagi implementasi UI satu-per-layar yang menduplikasi logika tata letak atau warna.

| # | Nama Komponen | Web (`web/src/components/ui/`) | Mobile (`app/lib/core/widgets/`) | Peran Utama (Gaya Notion & Jira) |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **OrbitShell** | `orbit-shell.tsx` | `orbit_shell.dart` | Kerangka utama: Sidebar Notion + Ctrl+K (Web); Bottom bar 4 tab + Workspace Drawer + Search Bar (Mobile). |
| 2 | **ViewSwitcherBar** | `view-switcher.tsx` | `orbit_view_switcher.dart` | Pemilih tampilan (`Daftar \| Papan \| Kalender \| Linimasa`) + filter chip jenis kegiatan + Saved Views dropdown dengan fade scroll hint. |
| 3 | **PropertyChip & Row** | `property-chip.tsx` | `orbit_property_chip.dart` | Chip properti inline Jira (Status, Prioritas, Jenis Kegiatan, Tenggat, Estimasi, Progres) + baris key-value tabel properti Notion. |
| 4 | **TaskStatusBadge** | `status-badge.tsx` | `orbit_status_badge.dart` | Lencana 4 status D.2 (`todo`, `doing`, `revisi`, `done`), plus penanda perhatian (`Terlambat`, `Sedang Revisi`, `Macet > 5 hari`, `Benturan`, `Draft`). |
| 5 | **ProgressControl** | `progress-control.tsx` | `orbit_progress_control.dart` | Bar progres tipis + slider langkah 5 (`0..100`) saat tanpa checklist, atau mode terkunci otomatis saat checklist aktif. |
| 6 | **TaskRowItem** | `task-row.tsx` | `orbit_task_row.dart` | Baris datar daftar gaya Notion/Linear: status icon di kiri, judul tugas + tags proyek + penanda macet/revisi, metadata rata kanan (tenggat, progres %, checklist `3/4`), aksi hover/ketuk. |
| 7 | **KanbanBoard & Card** | `kanban-board.tsx` | `orbit_kanban_board.dart` | Papan 4 kolom (`Belum dikerjakan`, `Dikerjakan`, `Revisi`, `Selesai 14 hari + Lihat semua`), kartu ringkas Jira (`kind`, `title`, `progress`, `due`, `revision badge`), drag-and-drop (`@dnd-kit`) di Web + menu pindah cepat + dialog catatan revisi di Web/Mobile. |
| 8 | **DetailPeekPanel** | `detail-peek.tsx` | `orbit_detail_page.dart` | Panel detail samping `480 px` (Web Side Peek) / Halaman Detail penuh (Mobile): Header, tabel properti inline, blok deskripsi/Tiptap, checklist/subtugas, tautan objek, dan riwayat status. |
| 9 | **CommandPalette** | `command-palette.tsx` | `orbit_command_search.dart` | Pencarian global lintas objek (`Tugas`, `Jadwal`, `Transaksi`, `Proyek`) + pintasan navigasi & aksi cepat (`Ctrl+K` di Web, modal full-sheet di Mobile). |
| 10 | **AttentionBannerCard** | `attention-card.tsx` | `orbit_attention_card.dart` | Kartu Hari Ini M10c: ringkasan hitungan status per filter jenis + daftar item perlu perhatian (*terlambat*, *revisi*, *macet > 5 hari*, *benturan jadwal*, *tagihan H-3*). |
| 11 | **TransactionRow & Sheet** | `transaction-row.tsx` | `orbit_transaction_row.dart` | Pengelompokan transaksi per tanggal WIB, subtotal harian rata kanan (`tabular-nums`), tanda `+/-`, label `Draft`, serta form bottom sheet cepat <= 4 ketukan. |
| 12 | **OrbitStateViews** | `state-views.tsx` | `orbit_state_views.dart` | `SkeletonBlock`, `OrbitEmptyState` (ikon tenang + pesan singkat + 1 tombol CTA), dan `OrbitErrorState` (pesan jelas + tombol **"Coba Lagi"** >= 44 px). |

## Aturan Penggantian Bertahap
- Komponen lama (`orbit_widgets.dart`, `primitives.tsx`) akan dipecah dan digantikan bersih pada **Gelombang 0.5** dan **Gelombang 1** setelah Anda menyetujui opsi aksen warna (A atau B) dan mockup visual.
- Seluruh test unit dan widget existing (`date_timezone_boundary_test`, `format.test.ts`, `middleware_security.test.ts`) tetap dipertahankan agar kompatibilitas zona waktu WIB, keamanan middleware, dan perhitungan tetap terjaga.
