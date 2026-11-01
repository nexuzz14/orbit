# Sampel Notifikasi dan Tangkapan Layar Transaksi Perbankan (Android)

Dokumen ini berisi sampel notifikasi push dan teks layar detail transaksi dari aplikasi perbankan (BCA mobile dan myBCA) untuk keperluan parsing otomatis (modul M7a & M7b). Seluruh data pribadi, nomor rekening, dan identitas telah disamarkan.

---

## 1. Sampel Notifikasi Push (M7b)

### Sampel 1: Push Pengeluaran - BCA mobile
- **Paket Sumber**: `com.bca`
- **Judul Notifikasi**: `BCA mobile`
- **Isi Notifikasi**: `Financial Diary: Pengeluaran sebesar IDR 12,000.00 di kategori Pembayaran.`
- **Karakteristik**:
  - Diawali prefix `Financial Diary: `
  - Mengandung tipe `Pengeluaran`
  - Nominal berformat `IDR 12,000.00`
  - Kategori bank: `Pembayaran` (kategori generik, tidak memberikan saran kategori otomatis).

### Sampel 2: Push Pengeluaran - myBCA
- **Paket Sumber**: `com.bca.mybca`
- **Judul Notifikasi**: `Catatan Finansial`
- **Isi Notifikasi**: `Pengeluaran sebesar IDR 7,000.00 di kategori Pembayaran.`
- **Karakteristik**:
  - Tanpa prefix `Financial Diary:`
  - Mengandung tipe `Pengeluaran`
  - Nominal berformat `IDR 7,000.00`
  - Kategori bank: `Pembayaran`.

### Sampel 3: Push Pemasukan - BCA mobile
- **Paket Sumber**: `com.bca`
- **Judul Notifikasi**: `BCA mobile`
- **Isi Notifikasi**: `Financial Diary: Pemasukan sebesar IDR 800,000.00 di kategori Gaji.`
- **Karakteristik**:
  - Diawali prefix `Financial Diary: `
  - Mengandung tipe `Pemasukan`
  - Nominal berformat `IDR 800,000.00`
  - Kategori bank: `Gaji` (menjadi petunjuk pencocokan kategori pemasukan atau piutang/gaji).

### Sampel 4: Push Pemasukan - myBCA
- **Paket Sumber**: `com.bca.mybca`
- **Judul Notifikasi**: `Catatan Finansial`
- **Isi Notifikasi**: `Pemasukan sebesar IDR 800,000.00 di kategori Gaji.`
- **Karakteristik**:
  - Judul `Catatan Finansial`
  - Tipe `Pemasukan`
  - Nominal berformat `IDR 800,000.00`
  - Kategori bank: `Gaji`.

### Kasus Khusus: Deduplikasi Lintas Paket dan Tumpukan Notifikasi
- Kejadian transaksi yang sama dapat memicu dua notifikasi sekaligus dari BCA mobile (`com.bca`) dan myBCA (`com.bca.mybca`) dalam menit yang sama.
- Notifikasi bertumpuk di shade Android (Notification Shade).
- **Aturan Deduplikasi**:
  - Intra-paket: deduplikasi berdasarkan tuple `(paket, kunci_notifikasi, waktu_posting)`.
  - Group Summary: abaikan notifikasi yang ditandai sebagai group summary oleh sistem Android (`FLAG_GROUP_SUMMARY`).
  - Lintas-paket: deduplikasi berdasarkan `(nominal, jendela_waktu_5_menit, tipe)`. Paket di luar allowlist segera dibuang sebelum dibaca dan tidak dicatat di log.

---

## 2. Sampel Layar Detail Transaksi (Teks Hasil OCR / Aksesibilitas - M7a)

### Layar Detail Pemasukan (Template T4)
- **Header**: `01 Nov 2026 11:00:23`
- **Judul Layar**: `Cashflow - Pemasukan`
- **Isi Teks**:
  `Pemasukan sebesar IDR 800,000.00 pada kategori Gaji ke {rekening tersamar} - TAHAPAN XPRESI pada tanggal 01 November 2026.`
- **Ekstraksi Entitas**:
  - Tanggal & Waktu: `01 Nov 2026 11:00:23` (diambil dari header transaksi).
  - Nominal: `800000.00`
  - Mata Uang: `IDR`
  - Kategori Bank: `Gaji`
  - Produk Rekening: `TAHAPAN XPRESI` (dicocokkan dengan `accounts.match_hints` untuk memilih akun tujuan secara otomatis).
  - Nomor rekening disamarkan dan TIDAK disimpan.

### Layar Detail Transfer Masuk (Template T3)
- **Header**: `24 Okt 2026 19:14:16`
- **Isi Teks**:
  `Transfer masuk sebesar IDR 150,000.00 dari {pengirim tersamar} - BANK MANDIRI ke no. rekening {tersamar} pada tanggal 24 Oktober 2026.`
- **Ekstraksi Entitas**:
  - Tanggal & Waktu: `24 Okt 2026 19:14:16`
  - Nominal: `150000.00`
  - Pengirim: Disamarkan
  - Bank Pengirim: `BANK MANDIRI`
  - Tipe Transaksi: `income` (transfer masuk).
  - Pembeda utama dengan T4: T3 menggunakan pola `"Transfer masuk ... dari"`, sedangkan T4 menggunakan pola `"Pemasukan ... pada kategori"`.
