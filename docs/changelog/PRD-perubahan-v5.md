# Perubahan PRD: Versi 4 ke Versi 5 (Orbit)

Instruksi menerapkan: terapkan semua perubahan di bawah ke docs/PRD.md. Bagian yang berjudul "Ganti" diganti utuh. Bagian "Tambahkan" disisipkan di bagian yang disebut. Setelah selesai, pastikan: tidak ada kata "FinTrack" tersisa, nomor fase dan semua referensi fase konsisten (lihat bagian R), dan judul dokumen menjadi "Orbit: PRD dan Instruksi Pembangunan (Versi 5)".

## A. Penamaan
- Nama produk: Orbit. Folder repo: orbit/. Package Flutter: orbit_app. Android applicationId: id.my.nabilcf.orbit. Ganti semua kemunculan "FinTrack".

## B. Bagian 1 (Ringkasan Produk): ganti paragraf pertama dengan
Orbit adalah pusat kendali pribadi berbasis web (Next.js, di-deploy ke Vercel) dan mobile (Flutter, Android dulu) dengan backend Supabase. Ditujukan untuk satu orang yang menjalani beberapa peran sekaligus (intern, freelance, kuliah) dan butuh melihat uang, tugas, dan jadwal di satu tempat. Fitur utama: layar Hari Ini, jadwal dan tugas lintas peran, pencatatan keuangan cepat, penangkapan otomatis dari notifikasi dan bukti transaksi bank (gambar, diproses lokal di HP), multi akun, multi mata uang, pelacakan proyek freelance beserta piutang, budget, tagihan rutin, target tabungan, laporan, dan (fase lanjut) berbagi workspace.

Prinsip desain, tambahkan: "Satu layar Hari Ini menjawab pertanyaan 'apa yang harus saya perhatikan sekarang' untuk jadwal, tugas, dan uang."

## C. Bagian 2 (Masalah dan Tujuan)
Tambahkan masalah: "Jadwal kuliah, magang, dan freelance bertumpuk sehingga tenggat dan benturan jadwal terlewat."
Tambahkan tujuan terukur:
- Layar Hari Ini menampilkan jadwal, tugas, tagihan, dan pemasukan yang menunggu dalam satu layar yang terbuka kurang dari 2 detik.
- Tidak ada tenggat tugas yang terlewat karena lupa (diukur lewat tugas terlambat per bulan, target turun dari bulan ke bulan).

## D. Bagian 3 (Konteks Pengguna)
Tambahkan butir:
- Tiga peran: mahasiswa (jadwal kuliah dan tugas kuliah), intern (jadwal magang dan tugas magang, uang saku), freelancer (proyek, tenggat, pembayaran). Keempat jenis kegiatan di aplikasi: intern, freelance, kuliah, pribadi.
- Jadwal sangat padat, sehingga deteksi benturan dan ringkasan harian lebih penting daripada fitur manajemen proyek yang kompleks.

## E. Bagian 4 (Ruang Lingkup)
Tambahkan ke "Masuk": layar Hari Ini dan agenda, tugas lintas peran (checklist, prioritas, tenggat), jadwal dan kejadian berulang (jadwal kuliah, shift magang, pertemuan), deteksi benturan jadwal, pengingat lokal, insight beban kerja.
Tambahkan ke "Di luar lingkup": pelacak waktu/pomodoro, sinkronisasi dua arah dengan Google Calendar, kolaborasi tugas antar pengguna, manajemen proyek tim (Gantt, dependensi antar tugas), integrasi LMS kampus.
Tambahkan ke pengecualian paritas: "Pengingat jadwal dan tugas di app dijadwalkan sebagai notifikasi lokal di perangkat. Web memakai push browser/email."

## F. Bagian 5 (Panduan Gaya)
Tambahkan: setiap jenis kegiatan punya satu warna tetap (intern, freelance, kuliah, pribadi), selalu disertai label teks atau ikon agar tidak bergantung pada warna. Label di UI mengikuti jenis: kuliah = "Mata Kuliah", intern = "Magang", freelance = "Proyek", pribadi = "Kegiatan".

## G. Bagian 6: Ganti M10 seluruhnya dengan M10, M10b, M10c berikut

### M10. Proyek/Kegiatan, Tugas, dan Pembayaran
- Tabel projects menjadi wadah kegiatan per jenis (kind: intern, freelance, kuliah, pribadi). Label UI mengikuti jenis (bagian F).
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

## H. Bagian 6 lainnya
- M12 (Laporan dan Insight), tambahkan: laporan per jenis kegiatan; insight beban kerja berbasis SQL dan template: jam terjadwal per jenis per minggu, tugas selesai vs terlambat, hari terpadat minggu depan, hari kosong terdekat.
- M13 (Notifikasi), tambahkan jenis: pengingat jadwal (default 30 menit sebelum), pengingat tenggat tugas (H-1 jam 18.00 dan 1 jam sebelum untuk tenggat berjam), tugas terlambat (sekali sehari), ringkasan pagi, peringatan benturan jadwal baru. Pengingat jadwal dan tugas dijadwalkan sebagai notifikasi lokal di perangkat agar andal tanpa internet (tanpa izin alarm eksak bila memungkinkan; ketepatan menit tidak dijanjikan). Isi notifikasi di layar kunci generik (jenis dan jumlah); judul hanya tampil bila pengguna mengizinkan.
- M14 (Pengaturan), tambahkan: jam ringkasan pagi, ambang "hari padat", warna per jenis, pengaturan pengingat default.
- M5 dan M7e: nilai sumber transaksi menjadi intern, freelance, kuliah, personal. Aturan kategori otomatis (M4) mendukung sumber "kuliah".

## I. Bagian 7 (Daftar Layar)
Tambahkan di app: Hari Ini (menggantikan Beranda), Agenda, Jadwal (hari/minggu), Detail Event, Tugas (daftar, papan), Detail Tugas, Daftar Mata Kuliah/Magang/Proyek. Tambahkan di web: tampilan bulan, papan tugas lintas proyek, dan dashboard lebar yang memuat agenda dan beban kerja.

## J. Bagian 8 (Model Data)
- Ganti tabel projects dengan: id, workspace_id, kind (intern/freelance/kuliah/pribadi), name, description, status, started_on, deadline, color, archived, tags, client_name (klien atau instansi), contract_value (nullable), currency (nullable), platform_fee_percent (nullable), fee_mode (nullable), semester (nullable), course_code (nullable), credits (nullable), stipend_amount (nullable), stipend_day (nullable). Constraint CHECK: field khusus freelance hanya terisi bila kind = freelance; field khusus kuliah hanya bila kind = kuliah; field uang saku hanya bila kind = intern.
- Hapus tabel project_tasks. Tambahkan:
  - tasks: id, workspace_id, project_id (nullable), kind, title, description, status, priority, due_at, due_is_date_only, estimate_minutes, completed_at, milestone_payment_id (nullable, mengacu ke project_payments), tags, sort_order, created_by
  - task_checklist_items: id, task_id, text, done, sort_order
  - events: id, workspace_id, project_id (nullable), kind, title, description, location, starts_at, ends_at, all_day, timezone, recurrence (jsonb: freq, interval, byweekday, bymonthday, until, count), reminder_minutes (int[])
  - event_exceptions: id, event_id, original_date, action (skip/override), override_starts_at, override_ends_at, override_title, override_location
- Nilai enum source pada transactions, expected_incomes, dan category_rules ditambah "kuliah".
- Fungsi/view baru: fn_agenda, fn_detect_conflicts, fn_complete_task, v_workload_weekly, fn_expand_recurrence (internal). View memakai security_invoker = true.
- Index: tasks (workspace_id, due_at), tasks (workspace_id, status), events (workspace_id, starts_at).
- notification_settings: tambah jenis jadwal, tenggat tugas, tugas terlambat, ringkasan pagi, benturan.
- RLS untuk tasks, task_checklist_items, events, event_exceptions mengikuti pola yang sama (workspace; tabel anak lewat induk).

## K. Bagian 9 (Keamanan)
Tambahkan: deskripsi tugas/proyek/event disanitasi (Markdown tanpa HTML mentah); lokasi event termasuk data pribadi dan tidak masuk log atau analitik; uji RLS dan IDOR mencakup tasks, events, dan tabel anaknya; judul tugas dan event tidak masuk push yang dikirim melalui server.

## L. Bagian 10 (Arsitektur)
Tambahkan: ekspansi kejadian berulang dan penggabungan agenda hanya di fn_agenda (database). App: flutter_local_notifications (atau setara) untuk pengingat lokal; jadwal pengingat dihitung ulang saat data berubah atau perangkat restart.

## M. Bagian 12 (Sinkronisasi Offline)
Tambahkan: tugas, event, dan pengecualian disinkronkan lewat outbox yang sama. Agenda dapat dilihat dari cache lokal tanpa internet; ekspansi kejadian berulang untuk tampilan offline memakai implementasi lokal yang diuji dengan kasus uji yang sama dengan fn_agenda.

## N. Bagian 15 (Pengujian)
Tambahkan: uji ekspansi kejadian berulang (mingguan, bulanan, pengecualian, batas akhir), uji deteksi benturan dan hari padat, uji fn_agenda (jadwal, tugas, tagihan, pembayaran), uji fn_complete_task (milestone), kecocokan hasil agenda lokal (app) dengan hasil database untuk set uji yang sama, uji pengingat lokal setelah restart perangkat.

## O. Bagian 17 (Metrik Keberhasilan)
Tambahkan: Hari Ini dibuka hampir setiap hari; persentase tugas selesai sebelum tenggat naik dari bulan ke bulan; tidak ada benturan jadwal yang tidak terdeteksi pada set uji.

## P. Bagian 18 (Risiko)
Tambahkan: "Cakupan yang membesar (uang + tugas + jadwal) untuk satu orang dengan jadwal padat: Fase 2 dibatasi pada fitur inti (area, tugas, event, Hari Ini); tampilan bulan, ICS, parser tugas cepat, dan insight beban kerja ditunda ke fase berikutnya sampai fitur inti terbukti dipakai harian."

## Q. Bagian 16 (Fase Pengerjaan): ganti seluruhnya dengan

Fase 1, fondasi: repo dan CI, threat model awal, skema + RLS + seed (termasuk tabel projects umum, tasks, task_checklist_items, events, event_exceptions agar tidak perlu migrasi besar nanti), auth (2FA, rate limit, pendaftaran publik dimatikan), workspace pribadi, akun, kategori, transaksi, transfer, ringkasan bulanan, kerangka Inbox, header keamanan, uji RLS di CI, outbox sinkron dasar. UI Fase 1 hanya keuangan.
Fase 2, kerja dan jadwal: projects/kegiatan lintas jenis, tugas (daftar, papan, checklist, prioritas, tenggat), event dan jadwal berulang (hari/minggu/agenda), fn_agenda, deteksi benturan, layar Hari Ini, pengingat lokal dan ringkasan pagi, pembayaran proyek freelance, piutang, dan profit.
Fase 3, perencanaan keuangan: budget, tagihan rutin, target tabungan, auto-split, expected_incomes (termasuk uang saku magang), notifikasi keuangan.
Fase 4, pencatatan cerdas tanpa LLM: input kalimat dan suara, tugas cepat, category_rules (merchant, produk, nominal, jam), saran kategori dari riwayat, safe to spend, insight mingguan berbasis template (keuangan dan beban kerja), pengecekan saldo mingguan dan koreksi.
Fase 5, sumber otomatis Android: (1) impor bukti transaksi gambar, (2) impor mutasi dan pencocokan, (3) notification listener dengan deduplikasi lintas aplikasi, (4) pencocokan pemasukan yang diharapkan dan pasangan top-up/transfer. Parser tiap format dibuat hanya setelah sampelnya ada.
Fase 6, skala: multi mata uang penuh, berbagi workspace dan peran (UI), akun privat, log aktivitas, daftar sesi.
Fase 7, penyelesaian: offline-first matang, biometrik, ekspor/impor data (termasuk ICS), tampilan bulan di app, scan struk opsional, LLM opsional bila terbukti perlu, performa, aksesibilitas, pentest mandiri, gerbang rilis keamanan (9.16), rilis.

Fase 1 sampai 3 harus sudah dipakai harian oleh pembuatnya sebelum Fase 4 dimulai. Tiap fase selesai bila kriteria penerimaan lulus (web dan app, kecuali pengecualian Android), uji RLS hijau, dan checklist keamanan fase tersebut terisi.

## R. Penyesuaian referensi fase di bagian lain
- Bagian 0 aturan 1 dan bagian 16: tetap merujuk "bagian 16".
- M2 (Workspace dan Berbagi): UI berbagi dikerjakan di Fase 6 (sebelumnya Fase 5).
- M8 (Scan Struk): opsional di Fase 7 (sebelumnya Fase 6).
- Bagian 3 dan bagian 11: "LLM tidak dipakai pada Fase 1 sampai 5" menjadi "Fase 1 sampai 6".
- Bagian 9.0: tidak ada perubahan selain konsistensi nomor fase.
- Bagian 19: tambahkan butir "Contoh jadwal kuliah dan magang (hari, jam, pola berulang) untuk set uji agenda."