# Rencana & Fase Pengerjaan: Anak Kost (Android Client)

> **Dokumen Panduan Eksekusi Bertahap**  
> **Target Platform:** Android (Samsung Galaxy S24+ sebagai perangkat penerimaan utama)  
> **Konkurensi:** Berjalan berdampingan dengan pengembangan macOS client oleh pengguna  
> **Backend Bersama:** 1 Project Supabase (Shared Schema, Storage, RPC, & Data Contracts)  
> **Referensi Induk:** [GAMINI.md](file:///d:/Pemrograman/Aplikasi/AnakKost_Android/GAMINI.md)  
> **Tanggal Dibuat:** 10 Oktober 2026  

---

## 1. Prinsip & Pendekatan Pengerjaan

1. **Bertahap & Terukur (Incremental Slices):**
   Pengerjaan dilakukan per fase secara ketat. Kita tidak akan langsung membangun seluruh layar dengan data palsu (mock), melainkan membangun fondasi *domain*, *database lokal*, *aturan bisnis*, *UI*, dan *pengujian* pada setiap fase sebelum melangkah ke fase berikutnya.
2. **Offline-First & Local Source of Truth:**
   UI Android selalu membaca dan menulis ke database lokal (Drift / SQLite) secara reaktif. Operasi commit bersifat atomik bersama antrean *outbox*. Ketersediaan jaringan tidak pernah memblokir pencatatan.
3. **Kompatibilitas Penuh dengan macOS Client:**
   Karena Anda sedang mengembangkan versi macOS secara bersamaan, semua definisi model data, tipe data uang (`int64` rupiah), tipe data stok (`int64` milliunit), skema database, kontrak outbox/RPC Supabase, dan format enkripsi payload dibuat **identik dan 100% interoperabel**.
4. **Keamanan & Integritas:**
   Tidak ada floating point untuk uang atau stok. Tidak ada write finansial otomatis dari OCR tanpa konfirmasi pengguna. Berkas brankas dan metadata dokumen sensitif dienkripsi AES-256-GCM di sisi klien sebelum diunggah.

---

## 2. Ringkasan Peta Jalan (Roadmap) Fase

| Fase | Fokus Utama | Deliverable Kunci | Target Estimasi |
| :--- | :--- | :--- | :--- |
| **Fase 0** | Setup Proyek, Konfigurasi Platform & Kontrak Bersama | Inisialisasi Flutter, tooling, permission Android, arsitektur dasar, sinkronisasi kontrak domain & Supabase. | 15–20 jam |
| **Fase 1** | Fondasi Core Lokal: Database, Security & App Lock | Drift SQLite isolate, App Lock (PIN + Biometrik), Key Manager (Keystore + AES-256-GCM), Shell Navigasi M3. | 25–35 jam |
| **Fase 2** | Modul Keuangan & Budgeting (FIN) | Dompet & Ledger mutasi, Transaksi, Transfer, Kategori, Budget bulanan, Target tabungan, Laporan/Grafik. | 30–40 jam |
| **Fase 3** | Modul Agenda Kegiatan & Tagihan Kost (SCH & BIL) | Kalender fleksibel, Recurring event, Tasks/Deadline, Notifikasi lokal Android, Template & Pembayaran tagihan. | 30–40 jam |
| **Fase 4** | Modul Kebutuhan, Inventaris & Brankas Dokumen (STK & DOC) | Inventaris barang, Mutasi stok desimal, Daftar belanja & Checkout, Brankas Dokumen terenkripsi, PDF Viewer. | 35–45 jam |
| **Fase 5** | Kamera, OCR Struk & Scanner Dokumen (IMG) | Kamera & Picker, ML Kit Text Recognition v2 (Latin offline), Document Scanner, Parser struk deterministik, Review draf. | 25–35 jam |
| **Fase 6** | Sinkronisasi Supabase Dua Arah & Backup/Export | Supabase Auth, Device session binding, RPC `apply_operation` & `pull_changes`, Attachment sync, Conflict UI, Backup/CSV. | 40–55 jam |
| **Fase 7** | Optimasi Native Galaxy S24+ & UI Polish | 120Hz smooth scrolling, One UI adaptation (Doze/battery/split-screen), Haptic, Global search FTS5, `FLAG_SECURE`. | 20–28 jam |
| **Fase 8** | Hardening, Integrasi Lintas Platform & Uji Nyata | Pengujian 28 skenario kritis (T01–T28), uji interop dengan macOS, stress test data besar, Release APK arm64. | 20–30 jam |

---

## 3. Rincian Eksekusi Per Fase

---

### 🔹 FASE 0: Setup Proyek, Konfigurasi Platform & Kontrak Bersama
**Tujuan:** Menyiapkan repositori Flutter Android yang bersih, kompatibel dengan toolchain lokal, mengunci arsitektur Riverpod, serta menyepakati kontrak data bersama agar selaras dengan client macOS.

#### Lingkup Pekerjaan:
1. **Inisialisasi Proyek Flutter:**
   - Inisialisasi Flutter project dengan package identifier yang stabil (misal: `com.anakkost.app`).
   - Setup konfigurasi Dart SDK 3.x dan Flutter 3.44+.
   - Setup Git repository dan `.gitignore` yang tepat (termasuk mengabaikan credentials, secret keys, dan temporary media).
2. **Setup Dependency (`pubspec.yaml`):**
   - State management: `flutter_riverpod`
   - Routing: `go_router`
   - Database: `drift`, `drift_dev`, `sqlite3_flutter_libs`, `build_runner`
   - Keamanan: `cryptography`, `cryptography_flutter`, `flutter_secure_storage`, `local_auth`
   - Utility & Waktu: `uuid`, `intl`, `timezone`, `flutter_timezone`
   - Media & OCR: `camera`, `image_picker`, `google_mlkit_text_recognition`, `google_mlkit_document_scanner`
   - Notifikasi & Background: `flutter_local_notifications`, `workmanager`
   - UI / Chart: `fl_chart`, `pdfrx`
   - Backend: `supabase_flutter`
3. **Konfigurasi Platform Android (Galaxy S24+ Target):**
   - Min SDK 26 (Android 8.0) / Target SDK 34/35 (Android 14/15).
   - Pengaturan `AndroidManifest.xml`: Izin kamera, biometrik (`USE_BIOMETRIC`), notifikasi (`POST_NOTIFICATIONS`), alarm terjadwal (`SCHEDULE_EXACT_ALARM` dan fallback).
   - Konfigurasi Gradle & NDK arm64.
4. **Dokumentasi Kontrak Bersama (Shared Contracts):**
   - Pemetaan skema entitas domain dasar (UUID, `user_id`, `version`, `last_operation_id`, `origin_device_id`).
   - Format waktu: ISO-8601 UTC untuk sync, `YYYY-MM-DD` untuk local date, timezone string (default `Asia/Jakarta`).
   - Format mata uang: `int64` Rupiah murni (bukan float).
   - Format stok: `int64` milli-unit (1 unit = 1000, 1.250 kg = 1250).

#### Gate / Definition of Done Fase 0:
- [ ] Proyek Flutter berhasil di-build dan berjalan di Android tanpa error gradle/manifest.
- [ ] Analisis linter `flutter analyze` bersih (0 error, 0 warning kritis).
- [ ] Seluruh dependensi terkunci di `pubspec.lock`.
- [ ] File kontrak domain dan konstanta bersama telah didefinisikan.

---

### 🔹 FASE 1: Fondasi Core Lokal (Database Drift, Keamanan & App Lock)
**Tujuan:** Membangun lapisan data lokal yang persisten, aman, dan dapat bertahan dari restart/process death, serta mekanisme keamanan aplikasi (App Lock & Enkripsi).

#### Lingkup Pekerjaan:
1. **Drift Local Database & DAOs:**
   - Implementasi skema tabel Drift sesuai Bagian 6 GAMINI.md:
     - Profil, Dompet (`wallets`), Kategori (`categories`), Transaksi (`transactions`), Mutasi dompet (`wallet_entries`).
     - Tabel sinkronisasi lokal: `sync_outbox`, `sync_cursors`, `sync_conflicts`, `attachment_jobs`, `local_settings`.
   - Setup Drift Isolate untuk query asinkron tanpa memblokir UI thread.
   - Migrasi lokal versi 1.
2. **Keamanan Perangkat & App Lock:**
   - Layanan App Lock (`AppLockService`): Setup PIN 6-digit (salt + PBKDF2/Argon2 hashing, disimpan di `flutter_secure_storage`).
   - Integrasi biometrik (`local_auth`): Fingerprint / Face Unlock Galaxy S24+ sebagai unlock cepat.
   - Logika auto-lock: Kunci aplikasi setelah berada di background > 30 detik.
3. **Key Management & Enkripsi Dasar (`KeyManager`):**
   - Master key acak 256-bit: `media` key dan `vault` key.
   - Wrapping master key menggunakan Android Keystore / device credentials.
   - Enkripsi AES-256-GCM dengan AAD (`crypto_context_id`, ID entitas).
   - Penyimpanan direktori privat aplikasi (`path_provider`) untuk file terenkripsi.
4. **Adaptive Navigation Shell (Android Material 3):**
   - Routing via `go_router` dengan route guard (redirect ke lock screen jika aplikasi terkunci).
   - Scaffold navigasi utama Android: `NavigationBar` dengan 5 tab: **Beranda, Keuangan, Kebutuhan, Agenda, Kost**.
   - Tema Material 3 dengan dukungan Dark Mode AMOLED (pitch black background).

#### Gate / Definition of Done Fase 1:
- [ ] Database Drift terinisialisasi dan CRUD sederhana berhasil disimpan persisten.
- [ ] App Lock bekerja: PIN dapat diatur, diverifikasi, dan unlock biometrik berhasil.
- [ ] Enkripsi AES-256-GCM teruji: encrypt -> decrypt menghasilkan byte yang identik; modifikasi ciphertext menyebabkan gagal autentikasi.
- [ ] Navigasi 5 tab M3 responsif dan status tersimpan saat rotasi/perpindahan tab.

---

### 🔹 FASE 2: Modul Keuangan & Budgeting (FIN)
**Tujuan:** Mengimplementasikan pencatatan keuangan pribadi lengkap dengan model double-entry ledger, kontrol budget, dan target tabungan.

#### Lingkup Pekerjaan:
1. **Model Domain & Aturan Bisnis Uang:**
   - Aturan saldo: `saldo_dompet = SUM(wallet_entries.amount_rp)` dari transaksi `posted`. Tidak ada field saldo yang diedit bebas.
   - Tipe transaksi: `expense`, `income`, `transfer`, `opening`, `adjustment`, `refund`.
   - Transfer atomik: 1 transaksi transfer menghasilkan 2 `wallet_entries` berlawanan tanda. Biaya transfer dicatat sebagai transaksi expense terpisah dalam operasi yang sama.
   - Void transaction: pembatalan mengubah `status = 'void'`, mengeluarkan mutasi dari ledger.
2. **Budgeting & Target Tabungan:**
   - Budget per kategori pengeluaran per bulan (`month_start` tanggal 1).
   - Perhitungan penggunaan budget: `pengeluaran - refund`. Peringatan 80% dan 100%.
   - Target tabungan (`saving_goals`) dan alokasi bersih (`saving_allocations`). Tabungan tidak menggandakan pengeluaran atau mengurangi saldo real dompet.
3. **Presentation & UI Android:**
   - **Dashboard Keuangan:** Ringkasan saldo total (dengan fitur toggle sembunyikan saldo), grafik pengeluaran harian/bulanan (`fl_chart`), sisa budget bulan ini.
   - **Form Transaksi Cepat:** Input nominal dengan numeric keypad, pemformatan instan `Rp...`, pemilihan dompet & kategori, catatan, tanggal. Target pengisian ≤ 15 detik.
   - **Manajemen Dompet & Kategori:** Tambah/edit/arsip dompet (Cash, Bank, E-Wallet) dan kategori pemasukan/pengeluaran.
   - **Laporan Sederhana:** Filter berdasarkan periode bulan, dompet, dan kategori.
4. **Pencatatan Outbox Lokal:**
   - Setiap mutasi transaksi/budget otomatis menghasilkan entri di `sync_outbox` dalam transaksi DB yang sama.

#### Gate / Definition of Done Fase 2:
- [x] Test Case **T01** lolos: Transfer bank Rp1.000.000 ke e-wallet Rp200.000 dengan biaya transfer Rp2.500 menghasilkan saldo bank Rp797.500 dan e-wallet Rp200.000. Laporan hanya mencatat pengeluaran Rp2.500.
- [x] Test Case **T02** lolos: Edit dan void transaksi memutasi ledger dan sisa budget secara atomik tanpa inkonsistensi.
- [x] Saldo dompet dan sisa budget terhitung otomatis secara akurat tanpa floating point rounding error.
- [x] UI Android berfungsi offline penuh dan data tersimpan persisten setelah app di-kill.

---

### 🔹 FASE 3: Modul Agenda & Tagihan Kost (SCH & BIL)
**Tujuan:** Membantu pengelolaan jadwal harian/magang, tugas dengan deadline, pengingat lokal Android, serta tagihan rutin kost yang terintegrasi dengan modul keuangan.

#### Lingkup Pekerjaan:
1. **Kalender Fleksibel & Tugas (SCH):**
   - Entitas `activity_calendars` (tipe: magang, kuliah, pribadi, custom).
   - Entitas `activity_events`: agenda berulang mingguan (recurrence weekly) dan sekali jalan.
   - Pengecualian agenda (`activity_event_exceptions`): batalkan atau ubah satu kejadian tertentu.
   - Entitas `tasks`: status (todo, doing, done), prioritas, deadline tanggal & jam lokal. Tugas terlambat dihitung secara dinamis dari waktu saat ini.
2. **Sistem Notifikasi Lokal Android:**
   - Konfigurasi `flutter_local_notifications` dengan Android Notification Channels terpisah: Agenda, Tugas, Tagihan, Stok, Sistem.
   - Penjadwalan alarm presisi menggunakan exact alarm API Android (dengan izin runtime dan fallback inexact jika izin tidak diberikan).
   - Deduplikasi notification ID menggunakan hash stabil target entitas.
   - Fitur Snooze (30 menit untuk tugas, 1 hari untuk tagihan).
3. **Tagihan Rutin Kost (BIL):**
   - Template tagihan (`bill_templates`): frekuensi bulanan/mingguan/tahunan/sekali, tanggal anchor.
   - Penanganan khusus tanggal anchor 31 (Februari memakai hari terakhir, Maret kembali ke 31).
   - Kejadian tagihan deterministik (`bill_occurrences`) berbasis UUID template + `period_key`.
   - Logika status tagihan: dihitung dinamis dari `sisa = nominal_tagihan - sum(pembayaran)`. Status: belum bayar, sebagian, lunas, terlambat.
4. **Integrasi Pembayaran Tagihan dengan Keuangan:**
   - Tombol "Bayar" secara atomik membuat transaksi pengeluaran di dompet dan entri `bill_payments`.
   - Tombol "Tautkan Transaksi" menghubungkan pengeluaran yang sudah ada ke occurrence tagihan.
   - Pembatalan transaksi pembayaran otomatis mengembalikan sisa tagihan dan mengaktifkan kembali reminder.

#### Gate / Definition of Done Fase 3:
- [ ] Test Case **T03** lolos: Pembayaran sebagian Rp400.000 lalu Rp600.000 mengubah status menjadi lunas; membatalkan transaksi Rp600.000 mengembalikan status menjadi sebagian (sisa Rp600.000).
- [ ] Test Case **T09** lolos: Anchor tanggal 31 dievaluasi tepat di akhir bulan pendek tanpa duplikasi period key.
- [ ] Test Case **T10** lolos: Agenda berulang dan pengecualian tanggal berfungsi; perubahan jadwal membatalkan alarm notifikasi lama.
- [ ] Notifikasi lokal Android muncul tepat waktu saat aplikasi tertutup.

---

### 🔹 FASE 4: Modul Kebutuhan, Inventaris & Brankas Dokumen (STK & DOC)
**Tujuan:** Menyediakan sistem inventaris barang kebutuhan kost, daftar belanja dengan checkout terintegrasi uang/stok, serta brankas penyimpanan dokumen penting terenkripsi.

#### Lingkup Pekerjaan:
1. **Inventaris Barang & Mutasi Stok (STK):**
   - Entitas `inventory_items`: nama, kategori stok, unit dasar (`pcs`, `g`, `ml`), ambang batas minimum (`minimum_qty`).
   - Entitas `inventory_movements`: append-only ledger stok (`add`, `use`, `adjust`, `reversal`).
   - Stok dihitung dari `SUM(quantity_delta)` dalam integer milli-unit.
   - Proteksi bisnis: penggunaan stok tidak boleh menghasilkan angka negatif tanpa koreksi eksplisit.
   - Pengingat stok minimum: memicu badge / reminder saat stok ≤ ambang batas, dengan aksi cepat "Tambah ke Belanja".
2. **Daftar Belanja & Checkout Terintegrasi:**
   - Entitas `shopping_lists` dan `shopping_list_items`.
   - Alur Checkout ("Selesaikan Pembelian"): dialog konfirmasi harga & jumlah riil -> membuat transaksi pengeluaran keuangan + mutasi penambahan stok barang + riwayat harga (`price_history`) dalam 1 operasi atomik.
3. **Image & File Pipeline Android:**
   - Integrasi kamera via `camera` atau `image_picker` (Photo Picker Android modern tanpa meminta all-files permission).
   - Pre-processing gambar: kompresi JPEG kualitas 80–85, perbaikan orientasi EXIF, penghapusan metadata lokasi (privasi).
   - Pembuatan thumbnail ringan (<100 KB) untuk kartu inventaris/bukti.
4. **Brankas Dokumen Terenkripsi (DOC):**
   - Entitas `documents` dan `attachments`.
   - Metadata sensitif (nomor KTP/KTM, catatan, judul pribadi) dienkripsi AES-256-GCM sebelum disimpan ke Drift.
   - Berkas dokumen fisik dienkripsi di direktori privat aplikasi.
   - Mekanisme Vault Unlock: membuka halaman dokumen mensyaratkan autentikasi ulang (Biometrik / Device Credential).
   - Secure PDF & Image Viewer: dekripsi berkas di memori privat (menggunakan `pdfrx` / memory image), pembersihan cache memori saat aplikasi keluar dari foreground.

#### Gate / Definition of Done Fase 4:
- [ ] Test Case **T04** lolos: Checkout belanja 2 barang mencatat pengeluaran dompet, menambah stok, menyimpan histori harga, dan mencatat outbox secara atomik.
- [ ] Pencegahan stok negatif bekerja: pemakaian melebihi stok yang ada diblokir dan meminta koreksi.
- [ ] Test Case **T13** & **T14** lolos: File dokumen dan metadata tersimpan dalam bentuk ciphertext; dekripsi gagal jika kunci salah; data tidak bocor ke log atau storage publik.
- [ ] Viewer dokumen aman: keluar aplikasi segera mengunci brankas dan membersihkan memori preview.

---

### 🔹 FASE 5: Kamera, OCR Struk & Scanner Dokumen Android (IMG)
**Tujuan:** Otomatisasi draf pengeluaran dan inventaris melalui kamera ponsel Galaxy S24+ dengan pengenalan teks offline dan parser deterministik.

#### Lingkup Pekerjaan:
1. **Google ML Kit Text Recognition v2 (Android Bundled Latin):**
   - Integrasi OCR di perangkat secara offline menggunakan model bundled Latin.
   - Abstraksi interface `OcrService` (mengembalikan teks per baris, bounding box 0–1, urutan baca) sehingga kontraknya identik dengan adapter Apple Vision di macOS.
2. **Google ML Kit Document Scanner & Fallback:**
   - Pemanfaatan Document Scanner Android untuk deteksi tepi struk/dokumen.
   - Sediakan fallback pemotretan standar + crop manual jika Google Play services scanner belum terunduh atau tidak tersedia secara offline.
3. **Deterministic Receipt Parser (Dart):**
   - Parser rule-based cerdas:
     - Deteksi toko (merchant) dari header atas.
     - Deteksi tanggal dari format Indonesia (`DD/MM/YYYY`, `DD-MMM-YYYY`, dll).
     - Deteksi total belanja dari kata kunci: `TOTAL`, `GRAND TOTAL`, `JUMLAH`.
     - Pemisahan subtotal, PPN/pajak, diskon, tunai, dan kembalian (mencegah salah pilih angka kembalian sebagai total).
     - Parser item belanja (nama barang, kuantitas, harga satuan, subtotal baris).
4. **Alur Review Draf Struk:**
   - Hasil parser disajikan dalam bentuk dialog / layar **Review Draf Struk**.
   - **Aturan Mutlak:** Tidak ada transaksi finansial yang disimpan otomatis tanpa konfirmasi pengguna.
   - Pengguna memeriksa toko, tanggal, total, memilih dompet pembayaran dan kategori pengeluaran.
   - Opsi pencocokan item struk ke inventaris barang (opsional, jika disetujui pengguna).

#### Gate / Definition of Done Fase 5:
- [ ] Test Case **T11** lolos: Parser mampu memisahkan total dari subtotal, tunai, dan kembalian pada struk uji.
- [ ] OCR berjalan lancar dalam mode pesawat (offline) menggunakan model Latin bundled.
- [ ] Alur konfirmasi draf struk berhasil menghasilkan transaksi keuangan dan mutasi stok (jika dipilih) secara akurat.
- [ ] Foto struk asli tersimpan terenkripsi sebagai lampiran transaksi (`attachment`).

---

### 🔹 FASE 6: Sinkronisasi Supabase Dua Arah & Backup/Export
**Tujuan:** Menghubungkan client Android dengan project Supabase bersama agar tersinkronisasi mulus dengan client macOS, menangani konflik offline, registrasi sesi ganda, dan proteksi backup.

#### Lingkup Pekerjaan:
1. **Supabase Auth & Device Registration:**
   - Login akun pemilik via email/password. Token tersimpan aman di `flutter_secure_storage`.
   - Pendaftaran instalasi Android via RPC `register_device` (menyimpan `device_id`, session binding server, `device_generation`).
   - Mendukung multi-device session: Android dan macOS aktif bersamaan tanpa saling me-logout.
2. **Sync Push Engine (Outbox to RPC):**
   - Membaca antrean `sync_outbox` terurut berdasarkan dependensi.
   - Pemanggilan RPC privat `apply_operation` dengan payload terstruktur, operation ID idempotent, base versioning, dan dataset generation check.
   - Penerimaan acknowledgement: menandai `local_revision` yang sukses tanpa menimpa edit baru yang dibuat saat proses sync berjalan.
3. **Sync Pull Engine (Change Feed to Local):**
   - Pemanggilan RPC privat `pull_changes(after_seq, limit)` mengambil feed perubahan milik `auth.uid()`.
   - Mengaplikasikan snapshot dan tombstone secara urut ke database Drift lokal dalam 1 transaksi per halaman.
   - Update `sync_cursors` lokal per perangkat.
4. **Attachment Sync (Private Storage):**
   - Worker background / job queue untuk upload dan download ciphertext lampiran ke Supabase Private Storage (`personal-media` dan `document-vault`).
   - Verifikasi checksum SHA-256 ciphertext sebelum menandai `attachment_available`.
5. **UI Resolusi Konflik (Conflict Resolver):**
   - Jika server menolak perubahan dengan `VERSION_CONFLICT` (misal: kedua perangkat mengedit nominal transaksi yang sama saat offline), simpan di `sync_conflicts`.
   - Layanan UI menampilkan perbandingan versi lokal vs versi server dan meminta pengguna memilih/menggabungkan.
6. **Encrypted Backup & Ekspor CSV:**
   - Fitur Backup Terenkripsi: file arsip terenkripsi dengan manifest versi skema, domain data, dan recovery salt.
   - Ekspor CSV transaksi & inventaris dengan sanitasi formula injection (mencegah teks berawalan `=`, `+`, `-`, `@` dieksekusi di spreadsheet).

#### Gate / Definition of Done Fase 6:
- [ ] Test Case **T05** & **T06** lolos: Retry push idempotent menghasilkan efek tunggal; edit lokal saat push tidak tertimpa acknowledgement.
- [ ] Test Case **T07** lolos: Pull tombstone (penghapusan) tersinkronisasi sempurna ke lokal.
- [ ] Test Case **T19** – **T24** lolos: Transaksi dan tagihan yang dicatat di Android muncul di macOS (dan sebaliknya); dokumen yang diunggah dari Android dapat didekripsi di macOS.
- [ ] Konflik offline tertangani di UI tanpa kehilangan data atau salah hitung ledger keuangan.
- [ ] Ekspor CSV dan Backup terenkripsi berhasil dieksekusi.

---

### 🔹 FASE 7: Optimasi Native Galaxy S24+ & UI Polish
**Tujuan:** Memaksimalkan kenyamanan pengguna pada perangkat fisik Samsung Galaxy S24+ dengan performa tinggi, tampilan estetis, dan proteksi privasi hardware.

#### Lingkup Pekerjaan:
1. **Performa & Animasi Layar 120Hz:**
   - Verifikasi scrolling list transaksi dan inventaris pada refresh rate 120Hz (target raster & UI budget < 8.3 ms, target jank < 5%).
   - Implementasi lazy list, image caching terukur, dan pemrosesan berat di background isolate.
2. **Adaptasi One UI & Android System:**
   - Penanganan Doze Mode, Power Saving, dan batasan baterai Samsung One UI.
   - Penyesuaian layout pada font scaling sistem (hingga 200%) dan Samsung Split-Screen / Pop-up view.
   - Integrasi haptic feedback halus saat operasi simpan transaksi berhasil.
3. **Pencarian Global (FTS5):**
   - SQLite Full-Text Search (FTS5) lokal untuk pencarian cepat nama toko, kategori, catatan transaksi, barang inventaris, agenda, dan tagihan.
   - Indeks FTS5 mengecualikan dokumen brankas sensitif untuk menjaga privasi.
4. **Proteksi Layar & Privasi (`FLAG_SECURE`):**
   - Penerapan `FLAG_SECURE` pada window Android saat membuka brankas dokumen untuk mencegah screenshot dan masking di Recent Apps preview.

#### Gate / Definition of Done Fase 7:
- [ ] Cold start aplikasi lokal ≤ 3 detik (p95).
- [ ] Simpan transaksi cepat ≤ 500 ms (p95).
- [ ] List beranimasi mulus di layar 120Hz tanpa freeze / lag yang mengganggu.
- [ ] Halaman brankas terlindungi `FLAG_SECURE` di Android.

---

### 🔹 FASE 8: Hardening, Pengujian Komprehensif (T01–T28) & Release APK
**Tujuan:** Verifikasi akhir seluruh skenario bisnis, uji ketahanan offline-to-online bersama macOS, serta penyusunan build APK release mandiri.

#### Lingkup Pekerjaan:
1. **Eksekusi Uji 28 Skenario Prioritas:**
   - Memastikan seluruh skenario `T01` sampai `T28` dari GAMINI.md Bagian 9.4 teruji dan lolos verifikasi.
2. **Stress Test Data Nyata:**
   - Pengujian performa dengan database terisi 10.000 transaksi, 1.000 barang, 20.000 mutasi stok, 1.000 tugas, 100 dokumen.
   - Verifikasi query dashboard dan saldo tetap responsif (≤ 300 ms).
3. **Build APK Release Mandiri:**
   - Setup signing key Android lokal (keystore release).
   - Pengaturan ProGuard / R8 rules untuk Drift, Cryptography, dan ML Kit.
   - Pembuatan build APK release arm64 untuk instalasi mandiri di Galaxy S24+.
4. **Dokumentasi Operasional & Deployment:**
   - Petunjuk setup kredensial Supabase (`.env` / safe config).
   - Prosedur pemulihan recovery secret jika ganti perangkat.

#### Gate / Definition of Done Fase 8:
- [ ] Seluruh kriteria penerimaan MVP terpenuhi (Definition of Done Bagian 9.3 GAMINI.md).
- [ ] Tidak ada bug fatal terkait kehilangan data, double ledger, kebocoran plaintext, atau crash pada alur utama.
- [ ] APK release arm64 ter-generate dan sukses diuji di perangkat fisik Galaxy S24+.

---

## 4. Matriks Dependensi & Interoperabilitas dengan macOS Client

Untuk menjamin kelancaran sinkronisasi saat Anda mengerjakan versi macOS dan kita mengerjakan versi Android:

| Komponen | Implementasi Android (Kita) | Implementasi macOS (Anda) | Titik Temu Sinkronisasi |
| :--- | :--- | :--- | :--- |
| **Penyimpanan Lokal** | Drift (SQLite) di Android app sandbox | Drift / SQLite di macOS application support | Skema tabel, tipe kolom, dan constraint domain identik. |
| **OCR Engine** | Google ML Kit (Latin bundled) | Apple Vision via Swift bridge | Output dinormalisasi ke `OcrServiceResult` (JSON draf baris & koordinat). |
| **Kamera & Impor** | Android Camera / Photo Picker | macOS File Selector (Import gambar/PDF) | Gambar dikompresi ke JPEG dengan batas resolusi yang sama. |
| **Kunci Vault** | Master key di-wrap Android Keystore | Master key di-wrap macOS Keychain | Ciphertext file & metadata identik; dapat didekripsi dengan recovery key yang sama. |
| **Notifikasi** | Android Channels & Exact Alarm | macOS UserNotifications (Darwin) | Model data pengingat (`reminder_rules`) disinkronkan via Supabase. |
| **Sinkronisasi Server** | Push outbox via Supabase RPC | Push outbox via Supabase RPC | Idempotensi via `operation_id`, feed via `sync_changes`. |

---

## 5. Protokol Kerja Pair Programming

Untuk menjaga keteraturan dan kualitas kode:
1. **Fokus Satu Fase dalam Satu Waktu:** Kita hanya akan mengerjakan fase aktif. Tidak berpindah fase sebelum checklist Definition of Done fase tersebut terpenuhi.
2. **Domain & Invariant Dulu:** Setiap fitur dimulai dari model data, validasi, dan unit test, baru kemudian UI.
3. **Review & Konfirmasi:** Sebelum membuat perubahan arsitektural besar atau melangkah ke fase berikutnya, kita akan meninjau hasilnya bersama Anda.
4. **Kode Bersih & Terdokumentasi:** Menjaga kejelasan kode Dart dan ketersediaan komentar penjelasan untuk aturan bisnis yang rumit.
