# 🏠 Anak Kost — Personal Lifestyle & Expense Ecosystem (Android Client)

> **Aplikasi All-in-One Mahasiswa Kost: Keuangan Multi-Dompet, Manajemen Stok Barang, Agenda & Tagihan Rutin, Brankas Dokumen Terenkripsi (E2EE), Scanner Struk OCR Offline, dan Sinkronisasi Dua Arah Supabase.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Database](https://img.shields.io/badge/Drift-SQLite-blue?logo=sqlite)](https://drift.simonbinder.eu/)
[![State Management](https://img.shields.io/badge/Riverpod-3.x-00599C)](https://riverpod.dev)
[![Backend Sync](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![Encryption](https://img.shields.io/badge/Security-AES--256--GCM-green)](https://en.wikipedia.org/wiki/Galois/Counter_Mode)
[![Tests](https://img.shields.io/badge/Tests-48%20Passed-brightgreen)](https://github.com/Syaif05/Anak-Kost)

---

## 📖 Daftar Isi
1. [Tentang Proyek](#-tentang-proyek)
2. [Fitur Utama](#-fitur-utama)
3. [Arsitektur Sistem & Prinsip Desain](#-arsitektur-sistem--prinsip-desain)
4. [Struktur Direktori Proyek](#-struktur-direktori-proyek)
5. [Prasyarat & Persiapan Lingkungan](#-prasyarat--persiapan-lingkungan)
6. [Instalasi & Menjalankan Aplikasi](#-instalasi--menjalankan-aplikasi)
7. [Kompilasi & Build APK Release](#-kompilasi--build-apk-release)
8. [Setup Backend Supabase](#-setup-backend-supabase)
9. [Pengujian & Verifikasi Kualitas (Tests)](#-pengujian--verifikasi-kualitas-tests)
10. [Panduan Developer Selanjutnya (Maintenance Guide)](#-panduan-developer-selanjutnya-maintenance-guide)

---

## 🌟 Tentang Proyek

**Anak Kost** adalah aplikasi produktivitas dan finansial mandiri yang dirancang khusus untuk memecahkan kompleksitas kehidupan anak kost: uang saku bulanan terbatas, tagihan kosan yang berulang, stok bahan makan/kebersihan yang sering habis tanpa disadari, serta keamanan berkas identitas penting (KTP, KTM, Kontrak Sewa Kost).

Aplikasi ini dikembangkan sebagai ekosistem multi-platform yang terhubung:
- 📱 **Android Client** (*repositori ini*): Dioptimalkan untuk **Samsung Galaxy S24+** (Layar 120Hz, kamera OCR struk instan, biometrik, notifikasi lokal alarm).
- 💻 **macOS Client**: Aplikasi desktop terintegrasi untuk **MacBook Air M2**.
- ☁️ **Supabase Sync Hub**: Sinkronisasi data dua arah secara aman tanpa pernah membocorkan data privat berkat enkripsi sisi-klien (*Client-Side Encryption*).

---

## 🚀 Fitur Utama

### 1. 💰 Modul Keuangan & Ledger Multi-Dompet (FIN)
- **Multi-Dompet Dinamis**: Kas Tunai, Bank (BCA, Mandiri, dll.), Dompet Digital (GoPay, OVO, ShopeePay).
- **Akuntansi Append-Only (Double-Entry Ledger)**: Setiap transaksi (Pemasukan, Pengeluaran, Transfer antar-dompet) mencatat pergerakan debit/kredit secara atomik. Saldo selalu konsisten.
- **Anggaran Kategori Fleksibel**: Target budget per kategori pengeluaran dengan tracking bar real-time dan peringatan dini batas pengeluaran.
- **Ekspor CSV Terproteksi**: Sanitasi otomatis pencegahan *Spreadsheet Formula Injection* (Gate Test **T18**).

### 2. 📦 Modul Inventaris Kebutuhan & Daftar Belanja (STK)
- **Tracking Stok Barang**: Sabun, pasta gigi, mie instan, galon air, minyak goreng, beras, dll.
- **Append-Only Stock Ledger**: Mutasi stok tercatat rapi (`add`, `use`, `adjust`, `reversal`) dalam satuan milli-unit (`pcs`, `ml`, `g`). Proteksi nilai stok tidak bisa negatif tanpa koreksi sadar.
- **Checkout Belanja Terintegrasi**: Belanja dari *Shopping List* langsung memotong saldo dompet keuangan dan menambah stok barang inventaris dalam 1 operasi atomik.

### 3. 📅 Modul Agenda, Tugas & Tagihan Rutin (BIL / ACT)
- **Template Tagihan Kost**: Sewa kamar bulanan, listrik/token, laundry, Wi-Fi.
- **Anchor Date Cerdas**: Penanganan tanggal 31 otomatis jatuh di akhir bulan pada bulan-bulan pendek (Februari/April).
- **Notifikasi Alarm Lokal**: Menggunakan `flutter_local_notifications` dengan Notification Channels terpisah dan Android Exact Alarm.

### 4. 🔒 Brankas Dokumen Terenkripsi (DOC)
- **End-to-End Encryption (AES-256-GCM)**: File fisik dokumen (KTP, KTM, Ijazah, Kontrak Kost) dan metadata sensitif dienkripsi di perangkat sebelum disimpan.
- **App Lockout & Biometrik**: Proteksi PIN 6-digit dengan mekanisme jeda waktu bertingkat (*exponential cooldown lockout*) jika salah 5 kali berturut-turut.
- **In-Memory Secure Preview**: Menampilkan PDF dan gambar di memori privat tanpa pernah mengekstrak file dekripsi ke penyimpanan publik.

### 5. 📸 Scanner Struk & OCR Offline (IMG)
- **Google ML Kit Offline Text Recognition**: Pembacaan struk belanja secara instan di perangkat tanpa memerlukan koneksi internet.
- **Deterministic Receipt Parser**: Algoritma cerdas yang memisahkan Toko, Tanggal, Item Belanja, Subtotal, Pajak/Diskon, Tunai, Kembalian, dan Grand Total (Gate Test **T11**).
- **Review Draf Struk**: Konfirmasi pengguna sebelum struk masuk ke pencatatan keuangan.

### 6. 🔄 Sinkronisasi Supabase Dua Arah (SYNC)
- **Offline-First Outbox Engine**: Bekerja 100% saat offline, antrean perubahan dikirim secara berurutan saat perangkat kembali online (Gate Test **T05** & **T06**).
- **Pull Sequential Stream**: Menerima perubahan dan *tombstone* penghapusan secara atomik per halaman (Gate Test **T07**).
- **Layar Resolusi Konflik**: Tampilan perbandingan *side-by-side* versi lokal vs server jika terjadi konflik edit bersamaan.
- **Backup & Restore Terenkripsi Penuh**: Berkas arsip `.anakkostbackup` terenkripsi AES-256-GCM dengan derivasi kunci PBKDF2 100.000 iterasi.

---

## 🏗️ Arsitektur Sistem & Prinsip Desain

```
[ UI Layer / Presentation (Widgets & Screens) ]
                      │
[ Application / Riverpod Notifiers & Controllers ]
                      │
[ Domain / Business Logic & Services (OCR, Crypto, Parsers) ]
                      │
[ Infrastructure / Repositories & Data Sources ]
           │                                │
[ Local SQLite / Drift ]          [ Supabase Sync Service ]
 (Single Source of Truth)                 │
                                  [ Remote PostgreSQL ]
```

1. **Offline-First**: Database lokal SQLite via **Drift** adalah satu-satunya *Single Source of Truth* bagi antarmuka pengguna. Seluruh operasi CRUD berhasil seketika secara lokal tanpa menunggu respon jaringan.
2. **Privacy-First**: Server/admin Supabase hanya melihat ciphertext dokumen dan payload terenkripsi. Tidak ada kunci privat atau dokumen yang disimpan dalam bentuk plain-text di cloud.
3. **Optimistic Concurrency**: Setiap entitas memiliki nomor `version` bertingkat untuk mendeteksi konflik pengeditan antar-perangkat secara akurat.

---

## 📁 Struktur Direktori Proyek

```
AnakKost_Android/
├── android/                        # Konfigurasi native Android (Gradle, ProGuard, Keystore)
├── lib/
│   ├── app/                        # Konfigurasi tema, router (GoRouter), dan App lifecycle
│   ├── core/
│   │   ├── config/                 # Konfigurasi aplikasi (supabase_config.dart)
│   │   ├── contracts/              # Kontrak payload operasi & entity interfaces
│   │   ├── database/               # Drift SQLite schema, tables, dan migrations
│   │   ├── notifications/          # Layanan notifikasi lokal dan alarm channels
│   │   ├── providers/              # Core Riverpod providers (DB, storage, crypto)
│   │   ├── security/               # Layanan enkripsi AES-256-GCM, AppLock, PIN hasher
│   │   └── sync/                   # Sync Engine, Outbox worker, Backup/Export service
│   ├── features/
│   │   ├── activities/             # Modul Agenda kegiatan & Tasks
│   │   ├── bills/                  # Modul Template & Occurrence Tagihan kost
│   │   ├── dashboard/              # Tampilan Ringkasan Beranda (Financial summary)
│   │   ├── documents/              # Brankas Dokumen terenkripsi & Attachment viewer
│   │   ├── finance/                # Dompet, Kategori, Transaksi, Anggaran (Budget)
│   │   ├── inventory/              # Stok barang inventaris, Mutasi & Shopping list
│   │   ├── ocr/                    # Layanan OCR ML Kit & Review draf struk
│   │   ├── security/               # Layanan LockScreen & SetupPinScreen
│   │   └── sync/                   # Layanan SyncSettingsScreen & ConflictResolutionScreen
│   └── main.dart                   # Entry point aplikasi Flutter
├── supabase/
│   └── migrations/                 # Skrip migrasi PostgreSQL, RPC, dan RLS Supabase
├── test/                           # Suite pengujian unit & integrasi lengkap (T01 - T28)
├── FASE_PENGERJAAN_ANDROID.md      # Rencana & Checklist Fase Eksekusi Proyek
├── SUPABASE_SETUP_GUIDE.md         # Panduan Lengkap Instalasi & Setup Supabase
├── pubspec.yaml                    # Dependensi paket Flutter
└── README.md                       # Dokumentasi utama proyek
```

---

## ⚙️ Prasyarat & Persiapan Lingkungan

Sebelum menjalankan proyek, pastikan lingkungan pengembangan Anda telah memenuhi:
- **Flutter SDK**: Versi `^3.24.0` atau yang lebih baru ([Panduan Instalasi Flutter](https://docs.flutter.dev/get-started/install)).
- **Dart SDK**: Versi `^3.5.0` atau yang lebih baru.
- **Android Studio / VS Code** dengan ekstensi Flutter dan Dart terpasang.
- **Android SDK & Build Tools**: API level 26 minimum s.d. API 36 (Didukung penuh untuk Android 14, 15, dan 16).
- **JDK**: Java Development Kit 17 (OpenJDK 17 disarankan).

Verifikasi lingkungan Anda dengan menjalankan:
```bash
flutter doctor -v
```

---

## 💻 Instalasi & Menjalankan Aplikasi

### 1. Kloning Repositori
```bash
git clone https://github.com/Syaif05/Anak-Kost.git
cd Anak-Kost
```

### 2. Pasang Dependensi
```bash
flutter pub get
```

### 3. Konfigurasi Kredensial Supabase
Buka file [`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart):
```dart
class SupabaseConfig {
  static const String defaultUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String defaultAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```
> Kredensial default sudah disediakan di file tersebut sehingga aplikasi dapat langsung berjalan tanpa perlu menyuntikkan parameter tambahan di terminal.

### 4. Jalankan Aplikasi di Perangkat Fisik (Samsung Galaxy S24+)
Hubungkan ponsel Galaxy S24+ Anda melalui kabel USB (USB Debugging) atau Wireless ADB Debugging, lalu jalankan:

```powershell
flutter run -d "SM S926B"
```

*Atau pilih perangkat `SM S926B` di pojok kanan bawah VS Code dan tekan **F5**.*

---

## 📦 Kompilasi & Build APK Release

Untuk menghasilkan build APK rilis mandiri yang **sangat ramping (hanya ~43.5 MB)**, gunakan flag `--split-per-abi`:

```powershell
flutter build apk --release --split-per-abi
```

Hasil build APK akan tersedia di `build/app/outputs/flutter-apk/`:
- **`app-arm64-v8a-release.apk`**: Khusus untuk Samsung Galaxy S24+ dan ponsel Android modern lainnya.
- **`app-armeabi-v7a-release.apk`**: Untuk ponsel Android 32-bit lama.

### Memasang APK Langsung ke HP:
```powershell
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

---

## ☁️ Setup Backend Supabase

Skrip skema database, tabel domain, RLS, dan RPC Stored Procedures telah disediakan di:
📁 [`supabase/migrations/20261011_fase6_sync_schema.sql`](supabase/migrations/20261011_fase6_sync_schema.sql)

Untuk panduan lengkap langkah-demi-langkah (pembuatan akun, import SQL, pengaturan storage bucket privat, dan uji coba sinkronisasi dua arah), silakan baca:
👉 **[SUPABASE_SETUP_GUIDE.md](SUPABASE_SETUP_GUIDE.md)**

---

## 🧪 Pengujian & Verifikasi Kualitas (Tests)

Proyek ini dilengkapi dengan suite pengujian otomatis komprehensif yang memvalidasi integritas akuntansi, keamanan enkripsi, logika OCR, dan mesin sinkronisasi:

### Menjalankan Seluruh Tes Unit & Integrasi:
```bash
flutter test
```
*Hasil: Seluruh 48 pengujian lolos (`All tests passed!`).*

### Menjalankan Analisis Statis Kode (Linter):
```bash
flutter analyze
```
*Hasil: `No issues found!` (0 lint errors).*

### Verifikasi Skenario Prioritas (Gate Tests):
- ✅ **T01**: Transfer atomik antar dompet + pencatatan biaya admin.
- ✅ **T02**: Pembelanjaan berlebih melebihi budget memicu status warning.
- ✅ **T03**: Pembayaran sebagian tagihan kost dan pembatalan pembayaran.
- ✅ **T04**: Checkout belanja otomatis mencatat pengeluaran uang dan menambah stok inventaris secara atomik.
- ✅ **T05**: Idempotensi push retry (mencegah duplikasi data saat koneksi terputus di tengah jalan).
- ✅ **T06**: Edit lokal saat proses sinkronisasi sedang berjalan tidak tertimpa acknowledgement lama.
- ✅ **T07**: Pull tombstone (penghapusan data dari device lain) teraplikasikan atomik.
- ✅ **T11**: Parsing struk belanja OCR memisahkan subtotal, pajak, diskon, dan grand total.
- ✅ **T13 & T14**: Brankas dokumen tersimpan dalam format ciphertext AES-256-GCM.
- ✅ **T18**: Ekspor CSV memblokir eksekusi formula spreadsheet (`=`, `+`, `-`, `@`).

---

## 🧑‍💻 Panduan Developer Selanjutnya (Maintenance Guide)

Bagi developer yang akan melanjutkan atau memelihara proyek ini:

### 1. Menambah Entitas / Tabel Baru di Database
1. Buat definisi tabel baru di `lib/core/database/tables/` menggunakan syntax **Drift**.
2. Pastikan menyertakan mixin `CommonDomainColumns` untuk menjamin adanya kolom `userId`, `version`, `lastOperationId`, `originDeviceId`, `createdAt`, `updatedAt`, dan `deletedAt`.
3. Jalankan build runner untuk memperbarui kode Drift:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Tambahkan tabel yang sama ke file migrasi Supabase [`supabase/migrations/20261011_fase6_sync_schema.sql`](supabase/migrations/20261011_fase6_sync_schema.sql).

### 2. Aturan Mutlak Keuangan (Financial Ledger)
- **DILARANG** melakukan operasi `UPDATE` pada saldo dompet secara langsung!
- Seluruh mutasi saldo dompet **WAJIB** melalui pembuatan entri transaksi (`transactions`) dan entri debit/kredit (`wallet_entries`). Saldo dompet dihitung dari query aggregate `SUM(amount)`.

### 3. Aturan Mutlak Privasi & Brankas Dokumen
- Jangan pernah mencetak (*print / log*) isi plain-text dokumen sensitif, recovery key, atau master passphrase ke console/logcat!
- Berkas fisik dokumen sebelum diunggah ke storage Supabase **harus sudah berstatus ciphertext** yang dienkripsi oleh `EncryptionService`.

### 4. Menyinkronkan Kontrak dengan Klien macOS
- Payload operasi sinkronisasi menggunakan struktur seragam `SyncOperationPayload` (didefinisikan di `lib/core/contracts/operation_contracts.dart`). Pastikan klien macOS mematuhi format JSON yang identik agar sinkronisasi dua arah tetap interoperabel.

---

## 📄 Lisensi
Hak Cipta © 2026 Anak Kost App Project. Seluruh hak cipta dilindungi undang-undang.
Dilisensikan untuk penggunaan pribadi dan pengembangan edukatif.
