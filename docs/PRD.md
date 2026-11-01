# Orbit: PRD dan Instruksi Pembangunan (Versi 5.1)

## 0. Instruksi untuk AI Agent (baca dulu)

Peran: kamu adalah engineer yang membangun produk ini dari nol sampai siap rilis, mengikuti dokumen ini secara berurutan per fase.

Aturan kerja:
1. Kerjakan per fase (bagian 16) dan per modul. Jangan loncat fase. Jangan menambah fitur di luar dokumen ini.
2. Modul dinyatakan selesai hanya bila: migrasi SQL ada, RLS ada dan teruji, fitur jalan di web dan app (kecuali pengecualian di bagian 4), kriteria penerimaan lulus, uji otomatis ada.
3. Semua perubahan skema lewat file migrasi SQL di supabase/migrations. Jangan mengubah skema lewat dashboard.
4. Semua logika hitung (saldo, ringkasan, profit proyek, safe to spend, kurs) ada di database (view/function). Client hanya menampilkan.
5. Larangan keras: menonaktifkan RLS, memakai service role key di web/app, menaruh secret di repo, memakai float untuk uang, menyimpan kredensial atau nomor rekening/kartu, mengeksekusi apa pun berdasarkan keluaran LLM tanpa validasi, mengirim gambar bukti transaksi ke server atau penyedia LLM.
6. Jangan membuat placeholder atau data palsu di kode produksi. Seed hanya untuk kategori default dan data uji.
7. Parser untuk format notifikasi atau bukti transaksi hanya dibuat setelah sampelnya ada di docs/samples/. Jangan mengarang format yang belum ada sampelnya; format tidak dikenal masuk daftar "tidak terbaca".
8. Bila ada keputusan yang tidak tercakup dokumen, pilih opsi paling aman dan sederhana, catat di docs/decisions.md, lalu lanjut. Bertanya hanya bila benar-benar terhalang.
9. Di akhir tiap fase, hasilkan: daftar fitur selesai, hasil uji, hal yang belum, dan checklist keamanan (bagian 9.16) yang sudah dicentang.
10. Tulis kode, komentar, pesan commit, dan dokumentasi tanpa emoji. Pesan commit mengikuti Conventional Commits.

## 1. Ringkasan Produk

Orbit adalah pusat kendali pribadi berbasis web (Next.js, di-deploy ke Vercel) dan mobile (Flutter, Android dulu) dengan backend Supabase. Ditujukan untuk satu orang yang menjalani beberapa peran sekaligus (intern, freelance, kuliah) dan butuh melihat uang, tugas, dan jadwal di satu tempat. Fitur utama: layar Hari Ini, jadwal dan tugas lintas peran, pencatatan keuangan cepat, penangkapan otomatis dari notifikasi dan bukti transaksi bank (gambar, diproses lokal di HP), multi akun, multi mata uang, pelacakan proyek freelance beserta piutang, budget, tagihan rutin, target tabungan, laporan, dan (fase lanjut) berbagi workspace.

Prinsip desain:
- Mencatat harus cepat. Semua jalur otomatis menghasilkan DRAFT yang dikonfirmasi pengguna, tidak langsung masuk laporan.
- Satu sumber kebenaran: database. Web dan app konsisten.
- Sumber otomatis bersifat best-effort. Kebenaran saldo dijaga lewat rekonsiliasi (cek saldo mingguan), bukan lewat asumsi bahwa notifikasi selalu lengkap.
- Privasi: gambar bank diproses di perangkat; data yang disimpan seminimal mungkin.
- Aman secara default: data privat, akses minimum, tidak ada kepercayaan pada client.
- Satu layar Hari Ini menjawab pertanyaan "apa yang harus saya perhatikan sekarang" untuk jadwal, tugas, dan uang.

## 2. Masalah dan Tujuan

Masalah: jadwal padat sehingga arus uang tidak terpantau; uang dari beberapa arus tercampur; piutang proyek tidak tercatat; mencatat manual melelahkan; jadwal kuliah, magang, dan freelance bertumpuk sehingga tenggat dan benturan jadwal terlewat.

Tujuan terukur:
- Catat manual maksimal 10 detik.
- Minimal 50% transaksi masuk lewat jalur otomatis setelah bulan ketiga.
- Selisih saldo app dengan saldo asli = 0 saat rekonsiliasi bulanan.
- Profit bersih per proyek dan total piutang terlihat dalam satu layar.
- Layar Hari Ini menampilkan jadwal, tugas, tagihan, dan pemasukan yang menunggu dalam satu layar yang terbuka kurang dari 2 detik.
- Tidak ada tenggat tugas yang terlewat karena lupa (diukur lewat tugas terlambat per bulan, target turun dari bulan ke bulan).

## 3. Konteks Pengguna dan Keputusan Awal

- Pengguna tunggal pada fase awal (pembuatnya sendiri). Persona: mahasiswa yang juga intern dan freelancer.
- Tiga peran: mahasiswa (jadwal kuliah dan tugas kuliah), intern (jadwal magang dan tugas magang, uang saku), freelancer (proyek, tenggat, pembayaran). Keempat jenis kegiatan di aplikasi: intern, freelance, kuliah, pribadi.
- Jadwal sangat padat, sehingga deteksi benturan dan ringkasan harian lebih penting daripada fitur manajemen proyek yang kompleks.
- Perangkat: Android. Bank utama: BCA (aplikasi BCA mobile dan myBCA terpasang bersamaan). Pembayaran hampir selalu lewat QRIS atau e-wallet, jarang memakai struk kertas.
- Notifikasi pembayaran BCA ada tetapi isinya minim dan dikirim ganda oleh dua aplikasi. Layar bukti transaksi di aplikasi jauh lebih lengkap dan dapat dibagikan sebagai gambar.
- Pemasukan datang sebagai transfer masuk (uang saku/gaji intern, pembayaran proyek). Notifikasi push transfer masuk tidak membawa nama pengirim; layar detail Catatan Finansial membawa nama pengirim dan bank. Contoh notifikasi push transfer masuk belum tersedia; parsernya dibuat setelah sampel ada.
- Transaksi yang tidak tertangkap otomatis dicatat manual.
- LLM tidak dipakai pada Fase 1 sampai 6 secara default. Penyedia LLM (Gemini, opsional) hanya dipertimbangkan setelah terbukti ada kebutuhan yang tidak tertangani parser aturan dan OCR lokal.
- Web di-deploy ke Vercel; backend Supabase.
- Mode pengguna tunggal berarti sebagian kewajiban keamanan dan kepatuhan ditunda (bagian 9.0), dan fitur berbagi workspace ditunda (UI) walaupun skemanya disiapkan sejak awal.

## 4. Ruang Lingkup dan Paritas Platform

Masuk (bertahap): auth, workspace (pribadi dulu), akun, kategori dan aturan otomatis, transaksi dan transfer, Inbox draft, input kalimat dan suara, notification listener, impor bukti transaksi (gambar), impor mutasi (gambar/berkas), pengecekan saldo mingguan, pemasukan yang diharapkan, multi mata uang, proyek/tugas/pembayaran, budget, tagihan rutin, target tabungan, auto-split, laporan, safe to spend, insight mingguan (berbasis template), notifikasi, ekspor/impor data, offline-first, scan struk (opsional, OCR lokal), berbagi workspace (fase lanjut), layar Hari Ini dan agenda, tugas lintas peran (checklist, prioritas, tenggat), jadwal dan kejadian berulang (jadwal kuliah, shift magang, pertemuan), deteksi benturan jadwal, pengingat lokal, insight beban kerja.

Di luar lingkup: investasi/saham/kripto, pembayaran atau transfer uang sungguhan, pajak resmi, akuntansi perusahaan, ingest email (ditunda, tidak diperlukan untuk pola pemakaian saat ini), penarikan mutasi langsung dari bank dan agregator pihak ketiga (hanya dipertimbangkan jauh di kemudian hari), pelacak waktu/pomodoro, sinkronisasi dua arah dengan Google Calendar, kolaborasi tugas antar pengguna, manajemen proyek tim (Gantt, dependensi antar tugas), integrasi LMS kampus.

Paritas web dan app: semua fitur ada di keduanya, dengan pengecualian teknis:
- Notification listener, target "Bagikan" gambar, dan OCR ML Kit: hanya Android (app). Di web, impor gambar memakai OCR di browser (misalnya Tesseract.js, tanpa unggahan) atau ditunda; keputusan dicatat di docs/decisions.md.
- Biometrik: app. Web memakai TOTP 2FA dan passkey (opsional).
- Pengingat jadwal dan tugas di app dijadwalkan sebagai notifikasi lokal di perangkat. Web memakai push browser/email.

## 5. Panduan Gaya

Bahasa dan tulisan:
- Bahasa UI: Indonesia, netral dan jelas. Tanpa emoji di UI, notifikasi, email, pesan error, komentar kode, dan commit.
- Hindari frasa berlebihan atau terdengar seperti iklan. Kalimat pendek, aktif, spesifik. Contoh: "Transaksi disimpan." bukan "Yay! Transaksi kamu berhasil disimpan!".
- Pesan error berisi apa yang terjadi dan langkah berikutnya. Jangan menyalahkan pengguna dan jangan membocorkan detail teknis.
- Format angka Indonesia: Rp 1.250.000. Tanggal: 31 Okt 2026, jam 24 jam. Mata uang lain mengikuti ISO 4217.

Visual:
- Tampilan bersih dan padat informasi, bukan dekoratif. Satu keluarga ikon (Lucide untuk web, Material Symbols untuk Flutter dengan bobot dan gaya seragam). Ikon fungsional, tidak sebagai hiasan.
- Design token terpusat: warna (netral + satu aksen + warna semantik pemasukan, pengeluaran, peringatan), tipografi (satu keluarga sans-serif, skala 12/14/16/20/24/32), spasi grid 4/8, radius konsisten, bayangan minimal.
- Terang dan gelap, kontras minimal WCAG AA. Jangan mengandalkan warna saja untuk membedakan pemasukan dan pengeluaran (tambahkan tanda +/- dan label).
- Animasi singkat dan fungsional (maksimal 200 ms), hormati pengaturan "kurangi gerakan".
- Keadaan kosong: teks singkat dan satu aksi, tanpa ilustrasi berlebihan.
- Angka uang rata kanan, font tabular, tanda dan warna konsisten.
- Setiap jenis kegiatan punya satu warna tetap (intern, freelance, kuliah, pribadi), selalu disertai label teks atau ikon agar tidak bergantung pada warna. Label di UI mengikuti jenis: kuliah = "Mata Kuliah", intern = "Magang", freelance = "Proyek", pribadi = "Kegiatan".

Kode:
- Web: TypeScript strict, ESLint, Prettier, validasi dengan zod.
- App: Dart dengan lint ketat (very_good_analysis atau setara), satu pola state management (Riverpod).
- SQL: snake_case, nama tabel jamak, kolom waktu timestamptz, uang numeric(20,4).
- Struktur folder mengikuti fitur, bukan jenis berkas.

## 6. Fitur dan Kriteria Penerimaan

### M1. Auth dan Profil
- Daftar/login email+password dan Google. Verifikasi email wajib. Reset password lewat email.
- Pendaftaran publik dimatikan di Supabase setelah akun pembuat dibuat (atau dibatasi allowlist email).
- Biometrik di app dengan PIN cadangan. Web: TOTP 2FA, passkey opsional.
- Profil: nama, mata uang dasar, zona waktu (default Asia/Jakarta), tanggal awal siklus bulan (default 1).
- Saat daftar: dibuat workspace pribadi, kategori default, akun "Cash".
- Hapus akun: menghapus seluruh data pribadi.
Kriteria: pengguna tidak dapat membaca atau menulis data di luar workspace yang diikutinya, diuji langsung lewat API.

### M2. Workspace dan Berbagi
- Semua data berada di bawah workspace. Satu workspace pribadi dibuat otomatis dan tidak dapat dihapus; hanya itu yang dipakai pada fase awal.
- Skema workspace_members, workspace_invites, peran (owner/editor/viewer), dan visibility akun dibuat sejak Fase 1. UI dan fitur berbagi (undangan, peran, akun privat, log aktivitas anggota) dikerjakan di Fase 6 dan tidak dikerjakan sebelum Fase 1 sampai 5 selesai.
- Saat diaktifkan: undangan lewat email/tautan bertoken (7 hari, sekali pakai, dapat dicabut); akun privat hanya terlihat pembuatnya; created_by dan riwayat perubahan ditampilkan.
Kriteria (saat diaktifkan): viewer tidak bisa insert/update/delete lewat API; anggota yang dicabut langsung kehilangan akses.

### M3. Akun/Dompet
- Jenis: cash, bank, e-wallet, kartu kredit, tabungan. Field: nama, jenis, mata uang, saldo awal, warna/ikon, urutan, likuid atau tidak, privat atau dibagikan, diarsipkan, match_hints (text[]).
- accounts.match_hints (text[]) berisi label produk rekening (misalnya "TAHAPAN XPRESI") untuk menentukan akun secara otomatis pada draft dari T1 (Sumber Dana) dan T4. Nomor rekening tetap tidak disimpan.
- Saldo dihitung dari saldo awal + transaksi confirmed, tidak disimpan sebagai angka mentah.
- Rekonsiliasi: pengguna memasukkan saldo asli, sistem menunjukkan selisih dan menawarkan transaksi koreksi dengan kategori khusus "Koreksi saldo".
Kriteria: saldo selalu sama dengan hasil hitung ulang dari seluruh transaksi.

### M4. Kategori dan Aturan Otomatis
- Kategori per workspace, jenis income/expense, ikon, warna, subkategori maksimal 2 level, diarsipkan bila sudah dipakai.
- Default expense: Makan, Transport, Kos, Pulsa/Internet, Kuliah, Langganan, Hiburan, Tools Proyek, Belanja, Kesehatan, Koreksi saldo, Lainnya.
- Default income: Gaji/Uang Saku Intern, Proyek Freelance, Kiriman, Lainnya.
- Aturan otomatis (category_rules): pola pada merchant ternormalisasi, nama produk/tagihan, nama pengirim (khusus pemasukan dari layar detail), nominal persis atau rentang nominal, hari dalam bulan, dan jam. Aturan menentukan kategori, akun, sumber, proyek. Sumber yang didukung: intern, freelance, kuliah, personal.
- Saran kategori dari riwayat: untuk draft tanpa merchant, saran dihitung dari transaksi terkonfirmasi dengan nominal sama, jam berdekatan (+/- 1 jam), dan hari dalam minggu. Tampil sebagai tiga tombol kategori teratas plus "Lainnya".
- Setelah pengguna mengoreksi kategori yang sama 2 kali untuk merchant atau nominal yang sama, tawarkan membuat aturan. "Terapkan otomatis" hanya aktif bila dinyalakan pengguna untuk aturan tertentu yang sudah dikonfirmasi minimal 3 kali dengan hasil sama.
- Kategori generik dari bank (misalnya "Pembayaran") tidak dipakai sebagai kategori aplikasi.

### M5. Transaksi dan Inbox
- Field: jenis (income/expense/transfer), nominal, mata uang, akun, kategori, sumber (intern/freelance/kuliah/personal), proyek (opsional), catatan, merchant, merchant_normalized, location_hint, counterparty (pengirim/penerima), counterparty_bank, product_name, txn_kind, tanggal+jam (dengan detik bila ada), lampiran, tag, status (draft/confirmed), origin, created_by.
- Default: tanggal sekarang, akun dan kategori terakhir dipakai.
- Validasi: nominal > 0; tanggal tidak lebih dari 1 tahun ke depan; transfer wajib dua akun berbeda.
- Transfer: dua baris terkait (transfer_group_id). Beda mata uang: tiap sisi punya nominal sendiri. Biaya admin dicatat sebagai expense terpisah yang terkait.
- Split: satu transaksi dipecah ke beberapa kategori/proyek; jumlah split wajib sama dengan total.
- Filter: tanggal, akun, kategori, sumber, proyek, status, origin, rentang nominal, tag. Pencarian teks.
- Aksi massal (utama di web): ubah kategori, sumber, proyek, hapus.
- Hapus = soft delete, dapat dipulihkan 30 hari.
- Inbox: halaman draft dari semua sumber otomatis dengan status "baru", "perlu dilengkapi", atau "perlu dicek". Aksi: konfirmasi, edit, tolak, konfirmasi massal untuk draft yang sudah lengkap. Draft tidak pernah masuk saldo, laporan, atau budget sebelum dikonfirmasi.
Kriteria: tambah transaksi lewat form maksimal 4 interaksi; draft yang sudah lengkap dapat dikonfirmasi dengan satu tap.

### M6. Input Kalimat dan Suara
- Contoh: "makan siang 25rb gopay", "gaji intern 2jt bca", "kemarin bensin 30k cash", "transfer bca ke gopay 100rb".
- Nominal: 25rb, 25k, 25.000, 1,5jt, 2 juta, Rp 25.000. Tanggal relatif: hari ini, kemarin, tadi pagi, senin kemarin, tgl 20.
- Pencocokan akun dan kategori memakai nama/alias workspace dan aturan M4.
- Parser aturan berjalan di perangkat (offline). LLM tidak dipakai secara default; bila diaktifkan kelak, mengikuti bagian 11.
- Hasil selalu berupa draft yang dapat diedit, bidang tidak yakin ditandai.
- Input suara di app memakai speech-to-text perangkat lalu parser yang sama.
Kriteria: minimal 90% dari 100 kalimat uji terparse benar (nominal, jenis, akun).

### M7. Sumber Otomatis (Android)

Sumber ini bersifat best-effort. Isi, format, dan kemunculan notifikasi bergantung pada aplikasi bank dan pengaturan sistem Android, sehingga tidak boleh diasumsikan lengkap.

#### M7a. Bukti transaksi myBCA (gambar), sumber pengayaan utama
Sampel nyata menunjukkan layar bukti transaksi memuat data jauh lebih lengkap daripada notifikasi push.

Template yang didukung (parser berbasis label, bukan posisi piksel):
- T1, Pembayaran QRIS: judul "Pembayaran QRIS Berhasil"; tanggal dan jam di bawah judul (contoh "31 Okt 2026 17:39:21"); nominal besar ("IDR 13,000.00"); label Pembayaran ke (merchant, diikuti kode lokasi setelah koma), Pengakuisisi, Jenis Transaksi, Lokasi Merchant, Sumber Dana, Total Bayar, No. Referensi.
- T2, Transfer ke BCA Virtual Account: judul "Transfer Berhasil"; tanggal dan jam; nominal; label Nama (nama tagihan/produk), Nama Produk, Jenis Transaksi, Total Tagihan, Total Bayar, No. Referensi.
- T3, Detail Catatan Finansial untuk transfer masuk: header tanggal dan jam (contoh "24 Okt 2026 19:14:16"); kalimat "Transfer masuk sebesar IDR {nominal} dari {pengirim} - {bank} ke no. rekening {...} pada tanggal {tanggal}.".
- T4, Detail Catatan Finansial untuk pemasukan: header tanggal dan jam (contoh "01 Nov 2026 11:00:23"); judul "Cashflow - Pemasukan"; kalimat "Pemasukan sebesar IDR {nominal} pada kategori {kategori_bank} ke {rekening tersamar} - {produk_rekening} pada tanggal {tanggal}.". Bedakan T3 ("Transfer masuk ... dari") dan T4 ("Pemasukan ... pada kategori"). Produk rekening dicocokkan dengan accounts.match_hints untuk menentukan akun secara otomatis. Nomor rekening tetap tidak disimpan.
- Template lain (transfer keluar ke rekening, top-up e-wallet, pengeluaran dan pemasukan lain) ditambahkan setelah sampelnya dikumpulkan di docs/samples/bukti/.

Aturan ekstraksi:
- Cocokkan berdasarkan label dengan toleransi salah baca OCR. Abaikan watermark.
- Tanggal memakai nama bulan Indonesia singkat maupun panjang (Jan, Feb, Mar, Apr, Mei, Jun, Jul, Agu/Ags, Sep, Okt, Nov, Des). Zona waktu mengikuti pengaturan pengguna.
- Nominal berformat IDR 13,000.00 (koma = ribuan, titik = desimal).
- Merchant dinormalisasi (huruf kecil, hapus kode lokasi setelah koma, hapus tanda baca); kode lokasi disimpan terpisah sebagai petunjuk.

Data yang disimpan: nominal, mata uang, waktu kejadian (dengan detik), merchant ternormalisasi, petunjuk lokasi (kota), jenis transaksi, nama produk/tagihan, pengirim dan bank pengirim (transfer masuk), dan nomor referensi hanya dalam bentuk hash sebagai external_id.

Data yang tidak boleh disimpan di database, log, atau analitik: RRN, Customer PAN, nomor rekening (milik sendiri maupun pengirim), nomor Virtual Account, nomor rekening atau kartu sumber dana, Terminal ID, dan nomor referensi dalam bentuk asli. Merchant PAN hanya boleh dipakai sebagai kunci merchant dalam bentuk hash (opsional). Uji otomatis memeriksa skema dan log terhadap pola data tersebut.

Alur:
1. App terdaftar sebagai target "Bagikan" untuk gambar, mendukung satu atau banyak gambar (batch di akhir hari).
2. OCR di perangkat (ML Kit text recognition). Gambar tidak diunggah ke server atau penyedia LLM dan dihapus dari penyimpanan app setelah ekstraksi, kecuali pengguna memilih menyimpannya sebagai lampiran (bucket privat).
3. Klasifikasi template dari judul dan label, lalu ekstraksi.
4. Penggabungan dengan draft notifikasi (M7b): jenis dan nominal sama dengan selisih waktu kurang dari 3 menit antara waktu bukti dan waktu notifikasi diterima. Yang cocok diperkaya (merchant, jam, referensi). Tanpa pasangan menjadi draft baru.
5. Deduplikasi: external_id (hash No. Referensi) unik per workspace. Membagikan gambar yang sama dua kali tidak membuat transaksi ganda.
6. Kategori lewat category_rules (M4), tidak pernah diterapkan tanpa konfirmasi kecuali "terapkan otomatis" menyala.
7. Layar verifikasi menampilkan potongan gambar berdampingan dengan hasil parse; bidang kosong atau meragukan ditandai; tidak pernah mengonfirmasi otomatis.
Kriteria: pada set uji T1 sampai T3, nominal, waktu, dan merchant/pengirim benar di minimal 95% gambar; satu transaksi dengan notifikasi dan bukti menghasilkan satu transaksi akhir; tidak ada data terlarang di database dan log; dari berbagi gambar sampai draft terisi lengkap kurang dari 5 detik di perangkat menengah.

#### M7b. Notification listener (BCA mobile, myBCA, e-wallet)
- Daftar aplikasi yang dibaca dipilih pengguna di pengaturan; nama paket diambil dari perangkat, bukan ditulis mati. Hanya paket terpilih yang diproses. Paket di luar allowlist dibuang sebelum dibaca dan tidak pernah masuk log.
- Pola pengeluaran BCA (dari sampel): "Pengeluaran sebesar IDR {nominal} di kategori {kategori_bank}." dengan judul "Financial Diary" (BCA mobile) atau "Catatan Finansial" (myBCA). Teks tidak memuat merchant, nama akun, maupun jam. Waktu kejadian diambil dari waktu notifikasi diterima di perangkat. Kategori bank disimpan di kolom baru transactions.bank_category dan dipakai hanya sebagai petunjuk, bukan keputusan. Kategori bank generik ("Pembayaran") tidak memberi saran.
- Pola pemasukan BCA (dari sampel): "Pemasukan sebesar IDR {nominal} di kategori {kategori_bank}." (BCA mobile diawali "Financial Diary: ", myBCA dengan judul "Catatan Finansial"). Kategori bank disimpan di transactions.bank_category. category_rules mendukung match_field bank_category. Kategori bank generik tidak memberi saran.
- Abaikan notifikasi ringkasan grup (group summary / FLAG_GROUP_SUMMARY). Deduplikasi dalam satu paket berdasarkan tuple (paket, kunci notifikasi, waktu posting) karena notifikasi dapat dikirim ulang atau diperbarui. Deduplikasi lintas paket tetap berdasarkan nominal, jenis, dan jendela waktu 2 menit.
- Parser menolak teks yang tidak cocok dengan pola yang diketahui; notifikasi tidak dikenal masuk daftar "tidak terbaca" yang dapat dilaporkan untuk dibuatkan parser. Pola pemasukan (transfer masuk) dan top-up dibuat setelah sampel tersedia di docs/samples/notifications.md.
- Teks mentah diproses di perangkat dan tidak disimpan setelah diparse; yang masuk database hanya hasil terstruktur sebagai draft.
- Deduplikasi lintas aplikasi: dua notifikasi dari paket berbeda dengan jenis dan nominal sama dalam jendela 2 menit dianggap satu kejadian dan digabung menjadi satu draft. Dua notifikasi dari paket yang sama dengan nominal sama dianggap dua kejadian. Pengguna dapat memilih satu aplikasi sebagai sumber utama dan mengabaikan yang lain.
- Draft dari notifikasi memiliki merchant kosong; saran kategori memakai riwayat nominal (M4) dan bukti transaksi (M7a) melengkapinya.
- Status listener tampil di beranda. Bila mati (izin dicabut atau dibunuh penghemat baterai), tampilkan peringatan dan panduan mengecualikan app dari penghemat baterai. App tetap berfungsi penuh tanpa akses notifikasi.
- Top-up dan transfer antar akun: notifikasi top-up e-wallet dari bank menghasilkan dua draft (bank keluar, e-wallet masuk) yang digabung otomatis sebagai satu transfer berdasarkan nominal sama, selisih waktu maksimal 10 menit, dan kata kunci (top up, isi saldo). Bila hanya satu sisi terdeteksi, draft ditandai "kemungkinan transfer" dan tidak dihitung sebagai pengeluaran sebelum dikonfirmasi. Biaya admin dicatat sebagai expense terpisah yang terkait.
Kriteria: untuk format yang ada sampelnya, minimal 90% notifikasi menjadi draft dengan nominal benar; satu pembayaran yang memunculkan notifikasi di dua aplikasi menghasilkan satu draft; pola top-up tidak pernah menghasilkan pengeluaran ganda di laporan.

#### M7c. Impor mutasi (gambar atau berkas)
- Mendukung gambar PNG/JPG hasil unduhan atau tangkapan layar, serta CSV/XLSX/PDF bila tersedia.
- Untuk gambar: pilih satu atau beberapa gambar dan tentukan akun asal; OCR lokal (ML Kit); parser baris mengekstrak tanggal, keterangan, nominal, jenis (debit/kredit), dan saldo bila ada. Parser dibuat setelah sampel mutasi tersedia di docs/samples/mutasi/. Format gambar yang dihasilkan fitur unduh mutasi myBCA belum disampel (apakah daftar atau per transaksi).
- Validasi: nominal numerik, tanggal dalam rentang wajar, saldo berjalan konsisten bila kolom saldo ada, baris tidak terbaca ditandai "perlu dicek".
- Layar verifikasi menampilkan potongan gambar berdampingan dengan hasil parse; dapat diedit sebelum disimpan.
- Pencocokan dengan draft dan transaksi dari notifikasi atau bukti: jenis sama, nominal sama, tanggal sama (+/- 1 hari), dipasangkan satu-ke-satu. Yang cocok digabung (keterangan mutasi melengkapi merchant dan catatan). Baris tanpa pasangan menjadi draft baru. Draft dari notifikasi yang tidak ada di mutasi ditandai "tidak ditemukan di mutasi".
- Wizard pemetaan kolom untuk CSV/XLSX dengan template tersimpan per bank. Impor dapat dibatalkan per batch (import_batch_id).
- Impor tidak pernah mengonfirmasi otomatis. Impor ulang tidak membuat baris ganda (hash gambar dan dedupe_hash per baris).
Kriteria: pada set uji sampel mutasi, nominal dan jenis benar di minimal 95% baris dan baris yang diragukan selalu ditandai.

#### M7d. Pengecekan saldo mingguan dan koreksi
- Pengingat tiap hari yang dipilih (default Minggu malam) meminta saldo asli tiap akun bank/e-wallet. Selisih ditampilkan beserta tombol "buat transaksi koreksi" (kategori Koreksi saldo). Dapat dilewati dan tidak memblokir apa pun.
- Laporan menampilkan jumlah dan nilai koreksi per bulan sebagai indikator seberapa banyak transaksi yang terlewat.
- Cek saldo adalah sumber kebenaran saldo; selisih setelah impor harus dapat dijelaskan oleh baris yang ditandai atau transaksi koreksi.

#### M7e. Pemasukan yang diharapkan dan transfer masuk
- Notifikasi push transfer masuk tidak membawa nama pengirim. Aplikasi tidak boleh menebak sumber atau proyek dari push, dan tidak menandai apa pun lunas otomatis. Nama pengirim dan bank tersedia dari layar detail (T3) dan dapat diambil lewat M7a.
- Draft pemasukan masuk Inbox dengan sumber dan proyek kosong, status "perlu dilengkapi", kecuali sudah diperkaya dari T3.
- Tabel expected_incomes berisi uang saku/gaji intern berulang (nominal, tanggal perkiraan, toleransi hari) dan pembayaran proyek berstatus belum lunas atau sebagian (dari project_payments). Draft dicocokkan berdasarkan nominal (persis, atau dalam toleransi untuk potongan biaya), jendela tanggal, dan nama pengirim bila ada. Kategori bank "Gaji" pada pemasukan menjadi sinyal tambahan pencocokan expected_incomes jenis uang saku/gaji. Tetap berupa saran yang membutuhkan konfirmasi.
- Hasil pencocokan hanya saran: satu kandidat tampil sebagai tombol "Konfirmasi sebagai: <nama>"; beberapa kandidat tampil sebagai daftar urut kedekatan; tanpa kandidat tampil tombol cepat sumber (Intern/Freelance/Kuliah/Personal) dan daftar proyek berstatus berjalan.
- Konfirmasi saran pembayaran proyek memanggil fn_mark_payment_paid dan menautkan draft ke pembayaran tersebut tanpa transaksi ganda. Konfirmasi saran uang saku/gaji menandai pemasukan rutin bulan itu sebagai diterima.
Kriteria: draft transfer masuk dengan nominal cocok ke satu kandidat dapat dikonfirmasi dengan satu tap; draft tanpa kandidat dapat dilengkapi dengan maksimal dua tap.

### M8. Scan Struk (opsional, Fase 7)
- Untuk struk kertas atau nota yang tidak punya bukti digital. OCR lokal (ML Kit) di app mengambil total, tanggal, dan merchant; hasil sebagai draft. Rincian item opsional dan tidak dijanjikan akurat.
- Gambar tidak diunggah ke server atau penyedia LLM. Penggunaan LLM vision (mis. Gemini) hanya bila diaktifkan sesuai bagian 11.
- Peringatan duplikat bila merchant+total+tanggal sama dengan transaksi yang ada.
Kriteria: total dan tanggal benar pada minimal 85% struk uji (minimarket, restoran, bensin).

### M9. Multi Mata Uang
- Mata uang dasar per workspace (default IDR). Akun punya mata uang sendiri. Transaksi menyimpan nominal asli, mata uang asli, kurs ke mata uang dasar, dan nominal dalam mata uang dasar.
- Kurs harian di tabel exchange_rates, diisi cron dari API kurs. Pengguna dapat mengganti kurs manual per transaksi.
- Laporan, budget, dan safe to spend memakai nominal mata uang dasar yang tersimpan, sehingga laporan lama tidak berubah saat kurs bergerak.
- Total aset menampilkan dua angka: pada kurs historis dan pada kurs hari ini (selisih = laba/rugi kurs).
- Desimal mengikuti ISO 4217. Penyimpanan numeric(20,4).
Kriteria: total laporan sama persis dengan penjumlahan transaksi, tanpa selisih pembulatan.

### M10. Proyek/Kegiatan, Tugas, dan Pembayaran
- Tabel projects menjadi wadah kegiatan per jenis (kind: intern, freelance, kuliah, pribadi). Label UI mengikuti jenis (bagian 5).
- Field umum: nama, deskripsi (Markdown), jenis, status (draft/berjalan/selesai/dibatalkan), tanggal mulai, tenggat/akhir, warna, tag, arsip.
- Field khusus freelance (hanya terisi bila kind = freelance): klien, nilai kontrak, mata uang, persen potongan platform, mode potongan.
- Field khusus kuliah (opsional): semester, kode mata kuliah, SKS.
- Field khusus magang (opsional): instansi, nominal uang saku, tanggal uang saku. Bila diisi, sistem membuat expected_incomes berulang untuk uang saku (M7e).
- Tugas (tabel tasks) tidak wajib punya proyek. Tugas lepas tetap punya jenis. Field: judul, deskripsi (Markdown), jenis, proyek (opsional), status (todo/doing/done), prioritas (rendah/sedang/tinggi), tenggat (tanggal saja atau tanggal+jam), estimasi menit (opsional), tag, checklist (item centang), milestone pembayaran (opsional), urutan.
- Tampilan tugas: daftar (filter jenis, proyek, status, prioritas, rentang tenggat, pencarian) dan papan todo/doing/done per proyek. Tugas belum selesai yang lewat tenggat berstatus "terlambat" dan tampil di atas di Hari Ini.
- Penambahan tugas cepat: field satu baris. Parser aturan untuk tenggat relatif yang sama dengan M6 ("kamis 23.59", "besok", "tgl 20") menghasilkan pratinjau yang dapat diedit sebelum disimpan (tanpa Inbox). Dikerjakan di Fase 4.
- Menyelesaikan tugas bertanda milestone menawarkan "tandai pembayaran termin X" (butuh konfirmasi, tidak otomatis) lewat fn_complete_task.
- Pembayaran proyek freelance (DP/termin/pelunasan): label, nominal, jatuh tempo, status (belum/sebagian/lunas), jumlah dibayar, tanggal bayar, akun penerima.
- Menandai lunas membuat transaksi income otomatis (confirmed) ke akun terpilih, kategori Proyek Freelance. Membatalkan status lunas membatalkan transaksinya (atomik).
- Potongan platform: transaksi expense terkait proyek, atau pengurang di profit tanpa transaksi (pilihan per proyek).
- Pengeluaran terkait proyek memakai project_id (domain, hosting, lisensi). Pengeluaran kuliah memakai sumber "kuliah".
- Metrik freelance: profit bersih = pembayaran lunas - potongan platform - pengeluaran terkait; sisa tagihan; persen tertagih; hari keterlambatan.
- Piutang: daftar pembayaran belum lunas lintas proyek, urut jatuh tempo, penanda lewat tempo. Pembayaran belum lunas otomatis menjadi kandidat expected_incomes (M7e).
- Lampiran proyek (brief, invoice) di Storage privat.
Kriteria: tugas dapat dibuat dengan maksimal 3 interaksi; tugas jatuh tempo hari ini dan tugas terlambat tampil di Hari Ini; menyelesaikan tugas milestone menawarkan pembayaran terkait tanpa mengubah data sebelum dikonfirmasi; field khusus jenis lain tidak dapat terisi (constraint database).

### M10b. Jadwal
- Event: judul, deskripsi, jenis, proyek (opsional), lokasi (teks), mulai, selesai, seharian, daftar pengingat (menit sebelum, default 30), zona waktu.
- Berulang: harian, mingguan (pilih hari), bulanan (tanggal), interval, berakhir pada tanggal atau setelah N kejadian. Contoh: jadwal kuliah mingguan sampai akhir semester, shift magang Senin sampai Rabu, pertemuan klien mingguan.
- Pengecualian per tanggal: lewati satu kejadian (libur) atau ubah satu kejadian (jam, ruang). Disimpan di event_exceptions.
- Aturan berulang disimpan sebagai data dan diekspansi oleh fungsi database (fn_agenda). Web dan app tidak menghitung ekspansi sendiri.
- Deteksi benturan: dua event atau lebih yang tumpang tindih ditandai di agenda dan Hari Ini (fn_detect_conflicts), termasuk lintas jenis (kuliah vs magang). Hari dengan jam terjadwal melebihi ambang (default 8 jam, dapat diatur) ditandai "hari padat"; tenggat tugas di hari padat mendapat peringatan.
- Tampilan: hari, minggu (grid waktu), agenda (daftar). Web menambah tampilan bulan.
- Impor/ekspor ICS bersifat opsional dan dikerjakan di Fase 7.
Kriteria: jadwal mingguan tampil benar untuk 8 minggu ke depan; kejadian yang di-skip tidak muncul; benturan terdeteksi lintas jenis; hasil identik di web dan app untuk set uji yang sama.

### M10c. Hari Ini dan Agenda
- Hari Ini (beranda). Bagian waktu: jadwal hari ini dan tugas bertenggat hari ini, urut waktu; tugas terlambat di bagian atas. Bagian perhatian: benturan jadwal, tagihan jatuh tempo dalam 3 hari, pembayaran proyek jatuh tempo atau terlambat, pemasukan yang diharapkan. Bagian uang: safe to spend, jumlah draft di Inbox, status listener. Bagian "Besok" ringkas.
- Agenda 7 hari: daftar per hari berisi jadwal, tenggat tugas, tagihan, dan pembayaran masuk, dengan indikator beban jam per hari.
- Filter chip per jenis (intern, freelance, kuliah, pribadi) di Hari Ini dan agenda.
- Satu panggilan fn_agenda(workspace_id, dari, sampai) mengembalikan semua item; client hanya menampilkan.
- Ringkasan pagi: notifikasi pada jam yang diatur (default 06.30) berisi jumlah jadwal, tugas, dan tenggat hari itu, tanpa judul.
Kriteria: Hari Ini terbuka kurang dari 2 detik dari cache lokal; semua item berasal dari fn_agenda; menyelesaikan tugas langsung memperbarui tampilan tanpa muat ulang.

### M11. Budget, Tagihan Rutin, Target Tabungan, Auto-split
- Budget bulanan per kategori mengikuti siklus bulan, opsi rollover. Indikator di 80% dan 100%.
- Tagihan rutin: nama, nominal (tetap/perkiraan), jadwal (mingguan/bulanan/tahunan/tanggal tertentu), akun, kategori, pengingat. Saat jatuh tempo muncul draft di Inbox.
- Target tabungan: nama, target, mata uang, tenggat, akun terkait atau kontribusi manual, progres dan estimasi tercapai.
- Auto-split: aturan persentase/nominal tetap per sumber pemasukan ke target tabungan/dana darurat/pajak, dijalankan saat income dikonfirmasi, hasilnya dapat diedit.

### M12. Laporan, Safe to Spend, Insight
- Ringkasan bulanan: pemasukan, pengeluaran, selisih; total dan per sumber.
- Perbandingan antar bulan, tren harian, komposisi kategori, top merchant, heatmap hari/jam (web).
- Laporan per proyek dan per klien. Proyeksi arus kas 30 hari dari tagihan rutin, piutang jatuh tempo, dan rata-rata pengeluaran harian.
- Laporan per jenis kegiatan.
- Insight beban kerja berbasis SQL dan template: jam terjadwal per jenis per minggu, tugas selesai vs terlambat, hari terpadat minggu depan, hari kosong terdekat.
- Safe to spend = (saldo akun likuid - tagihan rutin belum jatuh tempo di siklus ini - alokasi tabungan terjadwal) / sisa hari di siklus, dalam mata uang dasar. Rumus ditampilkan di UI.
- Insight mingguan (cron Senin pagi) berbasis SQL dan template teks, tanpa LLM: perubahan kategori, hari terboros, piutang mendekati tempo, budget yang diperkirakan jebol, jumlah koreksi saldo. Penulisan dengan LLM hanya opsional (bagian 11) dan tidak boleh menghasilkan angka.
- Ekspor: CSV, PDF, XLSX. Ekspor CSV/XLSX wajib menetralkan formula injection.
- Metrik sumber: persentase transaksi per bulan dari manual, kalimat, notifikasi, bukti, mutasi.

### M13. Notifikasi
- Kanal: push (app), email, in-app.
- Jenis: tagihan H-3 dan hari-H, pengingat catat malam (dilewati bila hari itu sudah ada pencatatan), pengingat cek saldo mingguan, budget 80%/100%, piutang jatuh tempo, draft menunggu di Inbox, status listener mati, insight mingguan, peristiwa keamanan (login baru, perubahan 2FA, perubahan email), undangan workspace (saat berbagi aktif).
- Jenis tambahan untuk jadwal dan tugas: pengingat jadwal (default 30 menit sebelum), pengingat tenggat tugas (H-1 jam 18.00 dan 1 jam sebelum untuk tenggat berjam), tugas terlambat (sekali sehari), ringkasan pagi, peringatan benturan jadwal baru.
- Pengingat jadwal dan tugas dijadwalkan sebagai notifikasi lokal di perangkat agar andal tanpa internet (tanpa izin alarm eksak bila memungkinkan; ketepatan menit tidak dijanjikan).
- Pengaturan per jenis dan jam tenang. Notifikasi keamanan tidak dapat dimatikan.
- Isi push tidak memuat nominal atau nama merchant (tampil generik di layar kunci). Isi notifikasi jadwal dan tugas di layar kunci generik (jenis dan jumlah); judul hanya tampil bila pengguna mengizinkan.

### M14. Pengaturan dan Data
- Ekspor seluruh data (JSON/CSV) dan impor ulang. Hapus data per modul atau seluruh akun.
- Daftar sesi/perangkat aktif dan tombol keluar dari semua perangkat.
- Pengaturan sumber otomatis: aplikasi yang dibaca, sumber utama saat ada duplikat, status listener.
- Tema terang/gelap/otomatis. Bahasa Indonesia, siap i18n.
- Log aktivitas.
- Jam ringkasan pagi, ambang "hari padat", warna per jenis kegiatan, pengaturan pengingat default.

## 7. Daftar Layar

App: Kunci, Login/Daftar, Beranda (safe to spend, saldo, ringkasan, badge Inbox, status listener), Tambah Transaksi (form, kalimat, suara), Inbox, Daftar Transaksi, Detail Transaksi, Akun (daftar, detail, rekonsiliasi), Cek Saldo Mingguan, Kategori+Aturan, Proyek (daftar, detail, tugas, pembayaran, profit), Piutang, Pemasukan yang Diharapkan, Budget, Tagihan Rutin, Target Tabungan, Laporan, Insight, Impor (bukti gambar, mutasi), Verifikasi Hasil OCR, Daftar "Tidak Terbaca", Sumber Otomatis (pengaturan), Notifikasi, Keamanan (sesi, 2FA, biometrik), Pengaturan. Fase lanjut: Workspace+Anggota.

Tambahan di app (mulai Fase 2): Hari Ini (menggantikan Beranda), Agenda, Jadwal (hari/minggu), Detail Event, Tugas (daftar, papan), Detail Tugas, Daftar Mata Kuliah/Magang/Proyek.

Web: semua layar di atas ditambah Dashboard lebar (arus kas, heatmap, perbandingan bulan), Tabel transaksi dengan edit massal dan pintasan keyboard, Wizard pemetaan kolom impor, Rekonsiliasi dua kolom, Papan tugas proyek.

Tambahan di web (mulai Fase 2): tampilan bulan, papan tugas lintas proyek, dan dashboard lebar yang memuat agenda dan beban kerja.

## 8. Model Data (PostgreSQL / Supabase)

Konvensi: id uuid; created_at, updated_at; deleted_at untuk soft delete; uang numeric(20,4); tabel bisnis memakai workspace_id; semua tabel di schema public wajib RLS.

- profiles: id (= auth.users.id), display_name, base_currency, timezone, month_start_day
- workspaces: id, name, type (personal/shared), base_currency, owner_id
- workspace_members: workspace_id, user_id, role
- workspace_invites: id, workspace_id, email, role, token_hash, expires_at, accepted_at, revoked_at
- accounts: id, workspace_id, name, type, currency, initial_balance, is_liquid, visibility, match_hints (text[]), created_by, archived, sort_order
- categories: id, workspace_id, name, type, icon, color, parent_id, archived
- category_rules: id, workspace_id, match_field (merchant/product/counterparty/amount/time/bank_category), pattern, match_type, amount_min, amount_max, day_of_month, category_id, account_id, source (intern/freelance/kuliah/personal), project_id, priority, auto_apply
- transactions: id, workspace_id, account_id, category_id, project_id, type, status (draft/confirmed), draft_state (baru/perlu_dilengkapi/perlu_dicek), amount, currency, fx_rate, amount_base, source (intern/freelance/kuliah/personal), bank_category, merchant, merchant_normalized, location_hint, counterparty, counterparty_bank, product_name, txn_kind, note, occurred_at, transfer_group_id, origin (manual/sentence/notification/proof_image/statement/receipt/recurring), source_package, import_batch_id, external_id_hash, dedupe_hash, created_by
- transaction_items: id, transaction_id, name, qty, unit_price, category_id, project_id
- attachments: id, workspace_id, owner_table, owner_id, storage_path, mime, size
- exchange_rates: date, from_currency, to_currency, rate, source
- projects: id, workspace_id, kind (intern/freelance/kuliah/pribadi), name, description, status, started_on, deadline, color, archived, tags, client_name (klien atau instansi), contract_value (nullable), currency (nullable), platform_fee_percent (nullable), fee_mode (nullable), semester (nullable), course_code (nullable), credits (nullable), stipend_amount (nullable), stipend_day (nullable). Constraint CHECK: field khusus freelance hanya terisi bila kind = freelance; field khusus kuliah hanya bila kind = kuliah; field uang saku hanya bila kind = intern.
- tasks: id, workspace_id, project_id (nullable), kind, title, description, status, priority, due_at, due_is_date_only, estimate_minutes, completed_at, milestone_payment_id (nullable, mengacu ke project_payments), tags, sort_order, created_by
- task_checklist_items: id, task_id, text, done, sort_order
- events: id, workspace_id, project_id (nullable), kind, title, description, location, starts_at, ends_at, all_day, timezone, recurrence (jsonb: freq, interval, byweekday, bymonthday, until, count), reminder_minutes (int[])
- event_exceptions: id, event_id, original_date, action (skip/override), override_starts_at, override_ends_at, override_title, override_location
- project_payments: id, project_id, label, amount, due_date, status, paid_amount, paid_at, account_id, transaction_id
- expected_incomes: id, workspace_id, label, source (intern/freelance/kuliah/personal), project_payment_id, amount, tolerance, expected_date, date_window_days, recurrence, status
- recurring_bills: id, workspace_id, name, amount, currency, category_id, account_id, schedule_type, schedule_value, remind_days_before, active
- budgets: id, workspace_id, category_id, period_start, limit_amount, rollover
- savings_goals: id, workspace_id, name, target_amount, currency, deadline, linked_account_id
- income_split_rules: id, workspace_id, source, goal_id, percent, fixed_amount
- source_apps: id, workspace_id, package_name, label, enabled, is_primary
- import_batches: id, workspace_id, kind (statement_image/statement_file/proof_image), image_hash, mapping, status, summary
- unreadable_notifications: id, workspace_id, source_package, received_at, reported (teks mentah tidak disimpan kecuali pengguna memilih melaporkan sampel)
- balance_checks: id, workspace_id, account_id, checked_at, reported_balance, computed_balance, difference, correction_transaction_id
- llm_usage: id, workspace_id, task, provider, day, count (hanya bila LLM diaktifkan)
- insights: id, workspace_id, week_start, payload (jsonb), generated_at
- push_tokens: id, user_id, platform, token
- notification_settings: user_id, type, channel, enabled, quiet_hours (type mencakup jadwal, tenggat tugas, tugas terlambat, ringkasan pagi, benturan)
- audit_log: id, workspace_id, actor_id, table_name, row_id, action, diff, at (append-only)
- security_events: id, user_id, type, ip_hash, user_agent, at

View/function di database: v_account_balances, v_monthly_summary, v_project_profit, v_receivables, v_budget_progress, v_cashflow_forecast, v_source_mix; fn_safe_to_spend, fn_confirm_draft, fn_merge_drafts, fn_mark_payment_paid, fn_apply_income_split, fn_match_expected_income, fn_suggest_category, fn_accept_invite, fn_agenda, fn_detect_conflicts, fn_complete_task, v_workload_weekly, fn_expand_recurrence (internal). Semua view memakai security_invoker = true.

Constraint wajib: CHECK nominal > 0, mata uang valid, role/status/type sebagai enum, foreign key lengkap, unique (workspace_id, external_id_hash) bila tidak null, unique (workspace_id, dedupe_hash) untuk impor, index pada (workspace_id, occurred_at), (workspace_id, account_id), (workspace_id, category_id), (workspace_id, merchant_normalized); index tasks (workspace_id, due_at), tasks (workspace_id, status), events (workspace_id, starts_at).

RLS untuk tasks, task_checklist_items, events, event_exceptions mengikuti pola yang sama (workspace; tabel anak lewat induk).

## 9. Standar Keamanan

### 9.0 Mode pengguna tunggal: yang ditunda dan yang wajib
Ditunda sampai aplikasi dibuka untuk orang lain: CAPTCHA, kebijakan privasi dan syarat layanan, mekanisme hak subjek data, DAST baseline, SBOM, pentest mandiri penuh ASVS L2/MASTG, dokumen kepatuhan UU PDP, security.txt. Pemakaian pribadi diperkirakan di luar cakupan UU PDP, tetapi ditinjau ulang oleh ahli hukum sebelum dibuka untuk orang lain.
Tetap wajib sejak Fase 1: RLS di semua tabel dan Storage dengan uji pgTAP di CI; 2FA TOTP untuk akun pembuat, sesi berumur pendek, daftar sesi aktif; secret hanya di secret manager Vercel dan Supabase dengan pemindaian secret (gitleaks) dan audit dependensi; header keamanan dan CSP di web, preview deployment dilindungi dan memakai project Supabase dev; di app: secure storage, basis data lokal terenkripsi, FLAG_SECURE, build obfuscated, tanpa data sensitif di log; perlakuan "konten tidak tepercaya" pada seluruh pipeline OCR/notifikasi/impor; backup harian dan uji restore sebelum data nyata dimasukkan; ekspor CSV/XLSX menetralkan formula injection; pendaftaran publik dimatikan.

### 9.1 Acuan standar
- OWASP ASVS (v4.0.3 atau terbaru) Level 2 untuk web dan API.
- OWASP MASVS v2 dengan MASTG untuk app, target L1 dan sebagian L2.
- OWASP Top 10 dan OWASP API Security Top 10 sebagai checklist review tiap rilis.
- NIST SP 800-63B untuk kata sandi dan sesi.
- ISO/IEC 27001 Annex A sebagai acuan kontrol (tanpa sertifikasi).
- UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.
- PCI DSS tidak berlaku selama aplikasi tidak menyimpan data kartu. Aturan internal: nomor kartu penuh, CVV, PIN, OTP, kredensial bank, nomor rekening, dan nomor virtual account tidak boleh disimpan atau dicatat di log.

### 9.2 Klasifikasi data
- Sangat sensitif: token sesi, refresh token, secret, token undangan, gambar bukti/mutasi/struk.
- Sensitif: data transaksi, saldo, akun, proyek, klien, nama pengirim transfer, tugas, jadwal. Lokasi event termasuk data pribadi dan tidak masuk log atau analitik.
- Internal: konfigurasi, log tanpa data pengguna.
- Publik: halaman pemasaran, kebijakan privasi.
Data sangat sensitif tidak pernah masuk log, analitik, atau pesan error. Data sensitif hanya diakses lewat RLS dan tidak dikirim ke pihak ketiga.

### 9.3 Model ancaman
docs/threat-model.md dibuat di Fase 1 memakai STRIDE per komponen (web, app, database, Storage, Edge Function, notification listener, pipeline OCR, penyedia LLM bila ada, CI/CD). Aktor: penyerang eksternal, akun yang diambil alih, perangkat hilang, aplikasi lain di perangkat, konten tidak tepercaya (notifikasi, gambar, CSV, PDF). Diperbarui tiap ada fitur besar baru.

### 9.4 Autentikasi dan sesi
- Kata sandi minimal 10 karakter, tanpa aturan komposisi kaku, cek terhadap daftar bocor bila tersedia.
- Verifikasi email wajib. Rate limit di Supabase Auth dan Edge Function. Pesan login/reset generik.
- MFA TOTP; kode pemulihan dibuat sekali dan disimpan pengguna.
- Access token berumur pendek, refresh token dirotasi dengan deteksi pemakaian ulang, daftar sesi aktif, keluar dari semua perangkat.
- Autentikasi ulang untuk aksi sensitif: ubah email/password, hapus akun, ekspor seluruh data, ubah peran, hapus workspace.
- Cookie sesi web: HttpOnly, Secure, SameSite=Lax (lewat @supabase/ssr).
- App lock biometrik dengan batas waktu tidak aktif yang dapat diatur.

### 9.5 Otorisasi dan isolasi data
- Deny by default. RLS aktif di semua tabel dan Storage. CI gagal bila ada tabel di schema public tanpa RLS.
- Fungsi bantu is_member(workspace_id) dan has_role(workspace_id, role). Tabel anak memeriksa lewat induknya.
- Fungsi SECURITY DEFINER wajib set search_path tetap dan memeriksa keanggotaan di dalam fungsi.
- Client tidak dipercaya untuk workspace_id, role, atau user_id; semuanya diturunkan dari auth.uid() dan tabel keanggotaan.
- Uji IDOR otomatis untuk semua tabel dan endpoint. Uji RLS dan IDOR mencakup tasks, events, dan tabel anaknya.
- Edge Function memakai service role hanya bila perlu dan tetap memeriksa keanggotaan sendiri.

### 9.6 Validasi input dan pencegahan injeksi
- Semua input divalidasi di client (UX), di server/Edge Function (zod), dan di database (CHECK, FK, enum). Validasi server adalah yang otoritatif.
- Tidak ada SQL dinamis dari input.
- XSS: tidak memakai dangerouslySetInnerHTML. Deskripsi proyek, tugas, dan event disimpan sebagai Markdown tanpa HTML mentah dan dirender dengan sanitizer ketat. CSP tanpa unsafe-inline untuk script.
- Formula injection: nilai sel ekspor yang diawali =, +, -, @ diberi awalan tanda kutip tunggal.
- Parser berkas (CSV, XLSX, PDF) berjalan dengan batas ukuran, jumlah baris, dan waktu; tolak berkas terkompresi berlapis.
- SSRF: Edge Function tidak mengambil URL dari input pengguna.

### 9.7 Kriptografi dan manajemen rahasia
- TLS 1.2 atau lebih baru di mana-mana, HSTS aktif. Enkripsi at-rest oleh Supabase.
- Token undangan dan referensi transaksi disimpan sebagai hash (SHA-256).
- Secret hanya di secret manager Vercel dan Supabase. Dilarang di repo, log, atau bundle client. gitleaks sebagai pre-commit dan di CI.
- Rotasi kunci terjadwal dan segera setelah dugaan kebocoran (runbook di docs/runbook-insiden.md).
- App: flutter_secure_storage untuk token dan kunci basis data lokal; basis data lokal dienkripsi (SQLCipher); tidak ada kunci API pihak ketiga di app.

### 9.8 Keamanan web (Next.js di Vercel)
- Header: Strict-Transport-Security, Content-Security-Policy (nonce per request), X-Content-Type-Options: nosniff, Referrer-Policy: strict-origin-when-cross-origin, Permissions-Policy minimal, frame-ancestors 'none'.
- CSRF: server action dan route handler memeriksa Origin; cookie SameSite. CORS ketat.
- Source map tidak dipublikasikan di produksi. Error ke pengguna generik, detail ke log.
- Preview deployment dilindungi (Vercel Authentication) dan memakai project Supabase dev.
- Tanpa skrip pihak ketiga yang tidak perlu. Lockfile di-commit, versi dipin, Dependabot/Renovate aktif.

### 9.9 Keamanan mobile (MASVS)
- Token dan kunci di secure storage; tidak ada data sensitif di SharedPreferences, log, atau cache tanpa enkripsi.
- Layar keuangan memakai FLAG_SECURE agar tangkapan layar dan pratinjau aplikasi terakhir tidak terbuka.
- Android: cleartext traffic dilarang, allowBackup=false untuk data sensitif, deep link divalidasi, komponen yang tidak perlu tidak di-export. Target "Bagikan" hanya menerima gambar dan memvalidasi tipe.
- Build rilis: --obfuscate --split-debug-info, R8/ProGuard aktif.
- Deteksi root: peringatan, bukan pemblokiran. Certificate pinning opsional dengan rencana rotasi.
- Izin minimal dan diminta saat fitur dipakai. Akses notifikasi dijelaskan dan dapat dicabut kapan saja.
- Judul tugas dan event tidak masuk push yang dikirim melalui server; pengingat jadwal dan tugas memakai notifikasi lokal.
- Notification listener: hanya paket terpilih; teks mentah tidak dikirim ke server dan tidak disimpan setelah diparse; nama paket dan teks tidak masuk log.
- Gambar bukti dan mutasi diproses di perangkat dan dihapus dari penyimpanan app setelah ekstraksi.

### 9.10 Keamanan pipeline OCR, notifikasi, impor, dan LLM
- Anggap semua konten dari notifikasi, gambar, CSV, dan PDF tidak tepercaya.
- Hasil OCR dan parse divalidasi (nominal > 0, mata uang valid, tanggal wajar); nilai yang tidak lolos dikosongkan dan ditandai "perlu dicek". Hasil selalu berstatus draft.
- Jika LLM diaktifkan: LLM tidak diberi akses tool, database, atau secret; keluaran hanya data dan wajib lolos skema (zod); aturan lengkap di bagian 11.
- Upload (lampiran): validasi tipe lewat magic bytes, batas ukuran, nama berkas diacak, metadata EXIF/GPS dihapus, bucket privat, signed URL berumur pendek.
- Data pihak ketiga (nama pengirim) diperlakukan sebagai data pribadi: disimpan seminimal mungkin dan dapat dihapus.

### 9.11 Privasi
- Pengumpulan data seminimal mungkin; daftar data yang tidak boleh disimpan ada di M7a.
- Retensi: soft delete 30 hari lalu hard delete; audit log 12 bulan; backup 30 hari.
- Sebelum dibuka untuk pengguna lain (9.0): kebijakan privasi dan syarat layanan, daftar pemroses data (Supabase, Vercel, layanan push, penyedia LLM bila ada), lokasi pemrosesan, prosedur pelanggaran data sesuai batas waktu UU PDP yang berlaku, dan tinjauan hukum.

### 9.12 Logging, pemantauan, audit
- audit_log append-only. security_events mencatat login berhasil/gagal, reset password, perubahan MFA, sesi baru, ekspor data, hapus akun. IP disimpan dalam bentuk hash.
- Peringatan otomatis: lonjakan login gagal, ekspor besar, pemakaian kuota LLM tidak wajar (bila aktif).
- Log aplikasi tidak memuat nominal, merchant, token, isi notifikasi, lokasi event, atau isi dokumen. Pelacak error dengan scrubbing data pribadi.

### 9.13 Backup dan pemulihan
- Backup harian (di paket gratis Supabase, gunakan pg_dump terjadwal lewat CI bila backup otomatis tidak tersedia; periksa halaman pricing). Target RPO 24 jam, RTO 4 jam.
- Uji restore sebelum data nyata dimasukkan, tiap kuartal, dan sebelum rilis besar. Pengguna dapat mengekspor datanya kapan saja.

### 9.14 Respons insiden
- Runbook di docs/runbook-insiden.md: deteksi, penahanan (cabut sesi, rotasi kunci, nonaktifkan fitur), investigasi, pemberitahuan, pemulihan, tinjauan pasca-insiden.

### 9.15 Siklus pengembangan aman
- Review ancaman untuk setiap fitur besar sebelum implementasi.
- CI: lint, tipe, uji, SAST (CodeQL atau Semgrep), audit dependensi, pemindaian secret, uji RLS (pgTAP).
- Branch protection dan review wajib untuk perubahan skema dan kode keamanan.
- 2FA aktif di GitHub, Vercel, Supabase, Google Cloud, dan penyedia email/domain. Akses layanan dengan hak minimum.

### 9.16 Gerbang rilis keamanan (wajib lulus per fase)
- RLS aktif di semua tabel dan Storage; matriks uji peran x tabel x operasi hijau.
- Tidak ada secret di repo atau bundle; pemindaian secret bersih.
- Tidak ada kerentanan dependensi tingkat tinggi/kritis yang belum ditangani.
- Header keamanan terverifikasi di staging; CSP tanpa unsafe-inline untuk script.
- Uji IDOR dan eskalasi peran lulus (termasuk tasks, events, dan tabel anaknya).
- Uji skema dan log: tidak ada data terlarang (M7a) yang tersimpan.
- Pipeline OCR/notifikasi/impor lulus uji dengan masukan berbahaya (teks tidak dikenal, gambar rusak, berkas terlalu besar, formula injection).
- Build app memakai obfuscation; FLAG_SECURE aktif; tidak ada data sensitif di log.
- Backup dan restore teruji. Threat model terbaru.
- Sebelum dibuka untuk pengguna lain: semua item yang ditunda di 9.0 dikembalikan dan lulus.

## 10. Arsitektur dan Deployment

Struktur repo (monorepo): supabase/ (migrations, seed, functions, tests), web/ (Next.js App Router, TypeScript, Tailwind), app/ (Flutter), packages/ (kontrak bersama dan set uji parser), docs/ (threat-model.md, decisions.md, runbook-insiden.md, samples/notifications.md, samples/bukti/, samples/mutasi/).

Backend: Supabase (Postgres, Auth, RLS, Storage, Edge Functions, pg_cron, Realtime). Edge Functions: fx-refresh (cron), weekly-insights (cron, template SQL), send-reminders (cron), llm-gateway (hanya bila LLM diaktifkan), accept-invite (saat berbagi aktif). Parser kalimat, notifikasi, bukti, dan mutasi berjalan di perangkat dan menulis draft lewat API biasa; tidak ada Edge Function yang menerima gambar atau teks notifikasi mentah.

Web (Vercel):
- Root Directory = web. Region fungsi dekat region Supabase (Singapore).
- Env publik hanya NEXT_PUBLIC_SUPABASE_URL dan NEXT_PUBLIC_SUPABASE_ANON_KEY. Service role key tidak dipakai di web.
- Pisahkan env Production dan Preview. Dua project Supabase: dev dan prod. Preview deployment memakai dev dan dilindungi Vercel Authentication.
- Auth: Site URL = domain produksi; Redirect URLs = domain produksi + pola preview. Redirect URI Google OAuth disesuaikan.
- Cron dan tugas terjadwal ada di Supabase (pg_cron, Edge Function), bukan Vercel Cron.
- Lampiran diunggah langsung dari client ke Supabase Storage lewat signed upload URL (batas body fungsi Vercel kecil).
- Domain kustom dipasang di Vercel. Paket Hobby hanya untuk pemakaian non-komersial; periksa syarat terbaru sebelum dipakai publik.

App (Flutter, Android dulu): supabase_flutter, drift dengan SQLCipher, outbox sinkronisasi idempoten, Riverpod, google_mlkit_text_recognition, penerima intent "Bagikan" gambar, notification listener service. Build rilis di-obfuscate. Pengingat lokal memakai flutter_local_notifications (atau setara); jadwal pengingat dihitung ulang saat data berubah atau perangkat restart.

Ekspansi kejadian berulang dan penggabungan agenda hanya di fn_agenda (database).

Parser kalimat dan parser aturan lain diuji dengan set kasus uji bersama (JSON input/output) agar hasil identik di web dan app bila diimplementasikan di keduanya.

## 11. Penyedia LLM dan OCR

Keputusan: LLM tidak dipakai pada Fase 1 sampai 6. OCR memakai ML Kit lokal. Penyedia LLM hanya dipertimbangkan setelah ada kebutuhan terbukti yang tidak tertangani parser aturan.

Bila diaktifkan kelak:
- Semua pemanggilan lewat satu antarmuka LlmProvider dan Edge Function llm-gateway. API key hanya di Supabase secrets.
- Konfigurasi per tugas lewat env: LLM_PROVIDER_PARSE_SENTENCE, LLM_PROVIDER_SCAN_RECEIPT, LLM_PROVIDER_INSIGHT. Nilai: gemini, deepseek, none. Default semuanya none. Nama model lewat env (GEMINI_MODEL_TEXT, GEMINI_MODEL_VISION), tidak ditulis mati; pilih seri Flash/Flash-Lite yang stabil dan hindari model preview untuk jalur produksi.
- Gemini: tier berbayar (billing aktif) wajib sebelum data nyata dikirim, karena tier gratis dan AI Studio dapat memakai konten untuk pengembangan produk. Tier gratis hanya untuk uji dengan data palsu. Pasang budget alert di Google Cloud. Rate limit berlaku per project, bukan per key.
- DeepSeek: hanya untuk teks transaksi pendek yang sudah diredaksi (tanpa nama orang, nomor rekening/kartu, alamat). Tidak boleh untuk gambar, lampiran, atau ringkasan keuangan, karena kebijakan privasinya menyimpan data di Tiongkok dan tidak memberi jaminan tertulis setara tier berbayar penyedia lain.
- Gambar bukti transaksi, mutasi, dan struk tidak boleh dikirim ke penyedia LLM tanpa persetujuan eksplisit yang dicatat di docs/decisions.md.
- Keluaran memakai structured output (JSON schema) dan divalidasi ulang dengan zod; nilai tidak valid dikosongkan dan ditandai; hasil selalu draft. Isi konten diperlakukan sebagai data, bukan instruksi (prompt injection).
- Kuota harian dan bulanan di llm_usage; melebihi kuota jatuh ke parser aturan. Cache hasil berdasarkan hash, timeout, dan retry terbatas dengan backoff.
- Log hanya mencatat jenis permintaan, durasi, jumlah token, dan status; tidak menyimpan isi prompt, gambar, atau respons.
- Sebelum menambah penyedia baru, catat di docs/decisions.md lokasi pemrosesan, kebijakan pelatihan data, retensi, dan hasil uji dengan data palsu.

## 12. Sinkronisasi Offline (App)
- Tulis lokal dulu, masuk outbox dengan client_generated_id (uuid) agar retry aman.
- Konflik: last-write-wins per baris berdasarkan updated_at server; versi yang kalah disimpan di audit_log.
- Hapus berupa soft delete agar tersinkron. Data referensi (akun, kategori, aturan, sumber_apps) di-cache.
- Penangkapan notifikasi dan OCR berjalan offline dan menghasilkan draft lokal yang disinkronkan saat online.
- Indikator status sinkron selalu terlihat.
- Tugas, event, dan pengecualian disinkronkan lewat outbox yang sama. Agenda dapat dilihat dari cache lokal tanpa internet; ekspansi kejadian berulang untuk tampilan offline memakai implementasi lokal yang diuji dengan kasus uji yang sama dengan fn_agenda.

## 13. Non-Fungsional
- Performa: form tambah transaksi siap < 2 detik dari buka app; daftar 10.000 transaksi tetap lancar (paginasi + indeks); uji dengan 50.000 transaksi.
- Akurasi: tidak ada float untuk uang; semua agregasi di SQL.
- Offline: pencatatan, notifikasi, dan OCR tetap berfungsi tanpa internet.
- Aksesibilitas: kontras AA, target sentuh minimal 44 px, label pembaca layar, navigasi keyboard di web.
- Observabilitas: log error Edge Function, pelacak error di web dan app. Pantau biaya LLM bila diaktifkan.
- Responsif: mobile, tablet, desktop; tema terang dan gelap.

## 14. Analitik Produk (tanpa data keuangan)
Event anonim: jalur pembuatan transaksi (manual/kalimat/notifikasi/bukti/mutasi), waktu dari buka form ke simpan, rasio draft dikonfirmasi vs ditolak, tingkat koreksi hasil parse, jumlah notifikasi tidak terbaca, uptime listener. Tidak ada nominal, merchant, nama pengirim, atau teks catatan dalam event.

## 15. Pengujian
- Database: pgTAP untuk RLS, saldo, profit proyek, safe to spend, konversi kurs, pencocokan expected_income, atomisitas fn_mark_payment_paid, dan fn_merge_drafts.
- Parser: set uji kalimat; notifikasi (dari docs/samples/notifications.md); bukti T1 sampai T3 dan template lanjutan (gambar nyata yang sudah disamarkan); mutasi.
- Uji duplikasi: satu pembayaran dengan notifikasi dari dua aplikasi + bukti + mutasi harus menghasilkan satu transaksi.
- Uji data terlarang: skema dan log tidak memuat RRN, nomor rekening, atau nomor referensi asli.
- Web: Playwright untuk alur utama. App: integration test alur offline ke online dan alur berbagi gambar.
- Agenda dan tugas: uji ekspansi kejadian berulang (mingguan, bulanan, pengecualian, batas akhir), uji deteksi benturan dan hari padat, uji fn_agenda (jadwal, tugas, tagihan, pembayaran), uji fn_complete_task (milestone), kecocokan hasil agenda lokal (app) dengan hasil database untuk set uji yang sama, uji pengingat lokal setelah restart perangkat.
- Uji paritas fitur web dan app (sesuai pengecualian bagian 4).
- Uji keamanan sesuai 9.15 dan 9.16.

## 16. Fase Pengerjaan

Fase 1, fondasi: repo dan CI, threat model awal, skema + RLS + seed (termasuk tabel projects umum, tasks, task_checklist_items, events, event_exceptions agar tidak perlu migrasi besar nanti), auth (2FA, rate limit, pendaftaran publik dimatikan), workspace pribadi, akun, kategori, transaksi, transfer, ringkasan bulanan, kerangka Inbox, header keamanan, uji RLS di CI, outbox sinkron dasar. UI Fase 1 hanya keuangan.
Fase 2, kerja dan jadwal: projects/kegiatan lintas jenis, tugas (daftar, papan, checklist, prioritas, tenggat), event dan jadwal berulang (hari/minggu/agenda), fn_agenda, deteksi benturan, layar Hari Ini, pengingat lokal dan ringkasan pagi, pembayaran proyek freelance, piutang, dan profit.
Fase 3, perencanaan keuangan: budget, tagihan rutin, target tabungan, auto-split, expected_incomes (termasuk uang saku magang), notifikasi keuangan.
Fase 4, pencatatan cerdas tanpa LLM: input kalimat dan suara, tugas cepat, category_rules (merchant, produk, nominal, jam), saran kategori dari riwayat, safe to spend, insight mingguan berbasis template (keuangan dan beban kerja), pengecekan saldo mingguan dan koreksi.
Fase 5, sumber otomatis Android: (1) impor bukti transaksi gambar, (2) impor mutasi dan pencocokan, (3) notification listener dengan deduplikasi lintas aplikasi, (4) pencocokan pemasukan yang diharapkan dan pasangan top-up/transfer. Parser tiap format dibuat hanya setelah sampelnya ada.
Fase 6, skala: multi mata uang penuh, berbagi workspace dan peran (UI), akun privat, log aktivitas, daftar sesi.
Fase 7, penyelesaian: offline-first matang, biometrik, ekspor/impor data (termasuk ICS), tampilan bulan di app, scan struk opsional, LLM opsional bila terbukti perlu, performa, aksesibilitas, pentest mandiri, gerbang rilis keamanan (9.16), rilis.

Fase 1 sampai 3 harus sudah dipakai harian oleh pembuatnya sebelum Fase 4 dimulai. Tiap fase selesai bila kriteria penerimaan lulus (web dan app, kecuali pengecualian Android), uji RLS hijau, dan checklist keamanan fase tersebut terisi.

## 17. Metrik Keberhasilan
- 30 hari pemakaian berturut-turut oleh pembuatnya.
- Median waktu catat manual < 10 detik; draft lengkap dapat dikonfirmasi dengan satu tap.
- Minimal 50% transaksi dari jalur otomatis setelah bulan ketiga (v_source_mix).
- Akurasi: bukti transaksi >= 95% (nominal, waktu, merchant/pengirim), notifikasi format dikenal >= 90%, parse kalimat >= 90%.
- Selisih rekonsiliasi bulanan = 0 setelah penyesuaian; jumlah transaksi koreksi per bulan turun seiring waktu.
- Nol data terlarang di database dan log. Nol kebocoran data antar workspace pada uji RLS dan IDOR.
- Hari Ini dibuka hampir setiap hari; persentase tugas selesai sebelum tenggat naik dari bulan ke bulan; tidak ada benturan jadwal yang tidak terdeteksi pada set uji.

## 18. Risiko dan Mitigasi
- Dua frontend sekaligus menggandakan beban: logika di database, kontrak uji bersama, kerjakan per modul.
- Notifikasi bank tidak konsisten (isi minim, kadang tidak muncul, format bisa berubah): dianggap best-effort; bukti transaksi, mutasi, dan cek saldo mingguan menjaga kebenaran; daftar "tidak terbaca" dan sampel baru untuk pembaruan parser.
- Notifikasi ganda dari dua aplikasi BCA: dedupe lintas paket, pilihan sumber utama.
- OCR salah membaca angka: validasi, layar verifikasi dengan potongan gambar, tidak pernah konfirmasi otomatis, cek saldo mingguan.
- Layar bukti bank berubah tampilan: parser berbasis label, uji dengan sampel, pembaruan template terpisah.
- Notification listener dimatikan sistem hemat baterai: indikator status, panduan pengecualian, input manual tetap jalur cadangan.
- Kebijakan toko aplikasi terhadap izin notifikasi/SMS: SMS tidak dipakai; akses notifikasi dijelaskan dan opsional.
- Data pribadi pihak ketiga (nama pengirim): disimpan minimal, dapat dihapus, tidak masuk log atau analitik.
- Kebocoran data antar workspace: RLS deny by default, uji otomatis di CI.
- Biaya dan privasi LLM: default tidak dipakai; bila aktif, ikuti bagian 11.
- Beban kerja besar untuk satu orang dengan jadwal padat: Fase 1 sampai 3 harus berguna dipakai harian sebelum Fase 4; fitur lanjutan dikerjakan hanya bila terbukti dibutuhkan.
- Cakupan yang membesar (uang + tugas + jadwal) untuk satu orang dengan jadwal padat: Fase 2 dibatasi pada fitur inti (area, tugas, event, Hari Ini); tampilan bulan, ICS, parser tugas cepat, dan insight beban kerja ditunda ke fase berikutnya sampai fitur inti terbukti dipakai harian.

## 19. Asumsi, Keputusan Terbuka, dan Sampel yang Diperlukan
- Perangkat Android; bank utama BCA (BCA mobile dan myBCA).
- Notifikasi push transfer masuk belum disampel (contoh sudah terhapus); dikumpulkan saat ada transfer masuk berikutnya.
- Sampel yang masih diperlukan (nama, nomor rekening, RRN, dan nomor referensi disamarkan): bukti transfer keluar ke rekening, bukti top-up e-wallet, satu contoh hasil unduhan mutasi (apakah daftar atau per transaksi), notifikasi top-up, dan notifikasi pemasukan.
- Apakah impor gambar di web memakai OCR di browser atau khusus app.
- Sumber kurs untuk cron fx-refresh.
- Distribusi app (Play Store atau sideload).
- Apakah iOS masuk rilis kelak; bila ya, fitur khusus Android didokumentasikan sebagai tidak tersedia di iOS.
- Tinjauan hukum atas kebijakan privasi dan kewajiban UU PDP sebelum aplikasi dibuka untuk pengguna lain.
- Contoh jadwal kuliah dan magang (hari, jam, pola berulang) untuk set uji agenda.