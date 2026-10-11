# Panduan Lengkap Konfigurasi Supabase untuk Anak Kost (Android & macOS)

Dokumen ini berisi panduan langkah-demi-langkah untuk menyiapkan backend **Supabase** sebagai Synchronization Hub dua arah antara perangkat **Android (Samsung Galaxy S24+)** dan **macOS (MacBook Air M2)** pada aplikasi **Anak Kost**.

---

## 📌 Ringkasan Arsitektur Sinkronisasi

Aplikasi Anak Kost mengusung filosofi **Offline-First & Privacy-First**:
1. **Local Drift / SQLite** adalah **Single Source of Truth** utama pada setiap perangkat. Aplikasi dapat digunakan 100% tanpa internet.
2. **Supabase** berfungsi sebagai **Synchronization Hub**:
   - Operasi perubahan dikirim via antrean **Append-Only Outbox** (`sync_outbox`) melalui RPC PostgreSQL yang atomik & idempotent (`apply_operation`).
   - Penerimaan perubahan dari perangkat lain ditarik secara sequential menggunakan Change Feed cursor (`pull_changes`).
   - Sesi multi-device terisolasi per user (`register_device`) sehingga Android dan macOS dapat login bersamaan tanpa saling me-logout.
3. **End-to-End Encryption (E2EE)**:
   - Berkas fisik dokumen brankas (`document-vault`) dan metadata sensitif dienkripsi secara lokal di perangkat menggunakan **AES-256-GCM**. Supabase hanya menyimpan ciphertext (`.enc`) dan checksum SHA-256. Admin/server Supabase tidak dapat membaca dokumen Anda.

---

## 🚀 Langkah 1: Membuat Proyek Supabase

Anda dapat menggunakan **Supabase Cloud** (gratis) atau **Supabase Local (Docker)**.

### Opsi A: Supabase Cloud (Paling Direkomendasikan)
1. Buka [https://supabase.com](https://supabase.com) dan buat akun / login.
2. Klik tombol **"New Project"**.
3. Isi informasi proyek:
   - **Name**: `AnakKost-Sync`
   - **Database Password**: Buat password yang kuat (simpan di password manager Anda).
   - **Region**: Pilih region terdekat (misalnya: `Singapore (ap-southeast-1)` untuk latensi terbaik dari Indonesia).
   - **Pricing Plan**: Free Tier.
4. Klik **"Create new project"** dan tunggu sekitar 1–2 menit hingga database selesai di-provisioning.

### Opsi B: Supabase Local (Self-Hosted / Docker)
Jika Anda ingin menjalankan Supabase secara lokal di Mac atau PC:
```bash
# Di terminal macOS atau Windows
npx supabase init
npx supabase start
```
Catat `API URL` (biasanya `http://127.0.0.1:54321`) dan `anon key`.

---

## 🗄️ Langkah 2: Menjalankan Migrasi Skema Database

File migrasi lengkap telah disediakan di repositori:
📁 `supabase/migrations/20261011_fase6_sync_schema.sql`

File ini mencakup:
- Ekstensi `uuid-ossp` dan `pgcrypto`.
- Tabel sesi perangkat: `devices`.
- Tabel state sequence: `sync_user_state`.
- Tabel log operasi & feed perubahan: `sync_operations`, `sync_changes`.
- Tabel domain: `wallets`, `transactions`, `budgets`, `categories`, `bills`, `inventory_items`, `inventory_movements`, `shopping_lists`, `documents`, `attachments`.
- Row-Level Security (RLS) di seluruh tabel (`auth.uid() = user_id`).
- Stored Procedures / RPC:
  - `register_device`
  - `apply_operation` (Idempotent & Optimistic Concurrency Check)
  - `pull_changes`
  - `revoke_device`
- Storage bucket initialization & RLS policies untuk storage.

### Cara Menjalankan Migrasi di Supabase Cloud:
1. Di Dashboard Supabase, buka menu **SQL Editor** (ikon terminal/query di sidebar kiri).
2. Klik tombol **"New Query"**.
3. Buka file `supabase/migrations/20261011_fase6_sync_schema.sql` di editor kode Anda, copy seluruh isinya, lalu paste ke SQL Editor Supabase.
4. Klik tombol **"Run"** (atau tekan `Ctrl+Enter` / `Cmd+Enter`).
5. Pastikan muncul pesan sukses: **`Success. No rows returned`**.

---

## 📦 Langkah 3: Konfigurasi Storage Buckets (Private)

Script migrasi otomatis mendaftarkan 2 bucket, namun Anda dapat memverifikasinya melalui menu **Storage** di dashboard Supabase:

1. Buka menu **Storage** di sidebar kiri.
2. Periksa apakah bucket berikut sudah ada:
   - `personal-media` (Public: **OFF / Private**)
   - `document-vault` (Public: **OFF / Private**)
3. *Jika belum ada*, Anda dapat membuatnya manual:
   - Klik **"New Bucket"**.
   - Masukkan nama `personal-media`, pastikan toggle **"Public bucket"** dalam posisi **OFF (Nonaktif)**.
   - Ulangi untuk `document-vault` (juga **Private**).
4. **Verifikasi Kebijakan Akses (RLS):**
   - Bucket ini dilindungi RLS sehingga pengguna hanya bisa mengunduh/mengunggah berkas yang berada di dalam folder ID mereka sendiri (`auth.uid()/*`).
   - Kebijakan RLS sudah dibuat otomatis oleh file migrasi SQL pada skema `storage.objects`.

---

## 🔐 Langkah 4: Konfigurasi Supabase Auth

1. Buka menu **Authentication** -> **Providers** di sidebar Supabase.
2. Pastikan provider **Email** berstatus **Enabled**.
3. **Pengaturan Konfirmasi Email:**
   - Untuk kemudahan pengujian pertama kali: Buka **Authentication** -> **URL Configuration** / **Sign Up**.
   - Matikan opsi **"Confirm email"** jika Anda ingin langsung login tanpa harus klik link verifikasi email.
   - Atau biarkan aktif jika ingin verifikasi email resmi.
4. **Multi-Session:**
   - Supabase Auth secara default mendukung multi-session token per user. Anda bisa login menggunakan akun email yang sama di Samsung Galaxy S24+ dan MacBook Air M2 tanpa saling menimpa token login.

---

## 🔑 Langkah 5: Mendapatkan API Keys & Konfigurasi Client

1. Di Dashboard Supabase, buka menu **Project Settings** (ikon gear di pojok kiri bawah) -> **API**.
2. Salin nilai berikut:
   - **Project URL**: contoh `https://abcdefghijklm.supabase.co`
   - **Project API Keys** -> `anon` / `public`: contoh `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

> ⚠️ **Catatan Keamanan:**
> Kunci `anon` / `public` aman ditanam di aplikasi client (Android & macOS) karena seluruh data dilindungi oleh **Row-Level Security (RLS)** dan fungsi RPC hanya mengizinkan manipulasi data milik `auth.uid()` yang sedang login. **JANGAN PERNAH** menanam kunci `service_role` di aplikasi client!

---

## 📱 Langkah 6: Menghubungkan Client Android & macOS

Di proyek Flutter Android (dan client macOS yang sedang Anda bangun):

### 1. Inisialisasi Supabase di `main.dart`
Tambahkan inisialisasi Supabase sebelum `runApp`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://YOUR_PROJECT_ID.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_SUPABASE_ANON_KEY',
    ),
  );

  runApp(
    const ProviderScope(
      child: AnakKostApp(),
    ),
  );
}
```

### 2. Menjalankan Aplikasi dengan Environment Variables
Anda dapat menyuntikkan kredensial saat build atau run:

```bash
flutter run --dart-define=SUPABASE_URL="https://YOUR_PROJECT_ID.supabase.co" --dart-define=SUPABASE_ANON_KEY="YOUR_KEY"
```

Atau menggunakan file `.env` dengan package `flutter_dotenv`.

---

## 🔄 Langkah 7: Verifikasi Uji Coba Sinkronisasi Dua Arah

Setelah kedua perangkat (Android & macOS) terhubung ke project Supabase yang sama:

### Skenario Uji 1: Sinkronisasi Transaksi & Saldo Dompet
1. Buka aplikasi **Anak Kost** di **Galaxy S24+**.
2. Masuk ke halaman **Pengaturan Sinkronisasi** (`/sync-settings`), login dengan akun Anda.
3. Catat transaksi pengeluaran baru di Galaxy S24+ (misal: "Beli Makan Siang Rp 25.000").
4. Di Galaxy S24+, klik tombol **"Sinkronkan Sekarang"**.
5. Buka aplikasi di **MacBook Air M2**, pastikan login dengan akun yang sama.
6. Klik **"Sinkronkan Sekarang"** di macOS.
7. ✅ **Hasil:** Transaksi "Beli Makan Siang Rp 25.000" dan pengurangan saldo dompet muncul secara identik di MacBook Air M2!

### Skenario Uji 2: Pengujian Mode Offline
1. Aktifkan **Mode Pesawat (Airplane Mode)** di Galaxy S24+.
2. Buat 3 transaksi baru dan ubah stok barang di inventaris.
3. Matikan Mode Pesawat (kembali online).
4. Klik **"Sinkronkan Sekarang"**.
5. ✅ **Hasil:** Seluruh transaksi lokal dalam antrean outbox terkirim ke server secara berurutan dan tanpa duplikasi (Gate Test **T05** & **T06**).

### Skenario Uji 3: Resolusi Konflik (Optimistic Concurrency)
1. Matikan koneksi internet pada kedua perangkat.
2. Di Galaxy S24+, edit nominal transaksi A dari `Rp 50.000` menjadi `Rp 55.000`.
3. Di MacBook Air M2, edit transaksi A yang sama dari `Rp 50.000` menjadi `Rp 60.000`.
4. Sambungkan internet di Galaxy S24+ dan sinkronkan (berhasil menjadi versi 2).
5. Sambungkan internet di MacBook Air M2 dan sinkronkan.
6. ✅ **Hasil:** Server menolak perubahan macOS dengan kode `VERSION_CONFLICT`. Aplikasi macOS mendeteksi konflik dan membuka layar **Resolusi Konflik** (`/conflicts`), menampilkan perbandingan side-by-side versi lokal vs server, memungkinkan pengguna memilih versi yang benar tanpa merusak ledger.

### Skenario Uji 4: Brankas Dokumen Terenkripsi (E2EE)
1. Di Galaxy S24+, simpan foto KTP atau sertifikat kost ke **Brankas Dokumen**.
2. Sinkronkan ke Supabase.
3. Buka dashboard Supabase -> Storage -> bucket `document-vault`.
4. Unduh file fisik yang terunggah.
5. ✅ **Hasil:** File yang terunduh dari Supabase adalah binary terenkripsi AES-256-GCM (`.enc`). Isi dokumen sama sekali tidak bisa dibuka tanpa Master Recovery Key yang hanya ada di perangkat Anda.
6. Buka MacBook Air M2, lakukan pull sync, masukkan Master Key brankas di macOS -> Dokumen terbuka dengan sempurna.

---

## 🛠️ Pemeliharaan & Troubleshooting

| Gejala Masalah | Penyebab Umum | Solusi |
|---|---|---|
| `JWT expired` atau `401 Unauthorized` | Sesi Supabase kadaluarsa | Buka halaman Sync Settings dan lakukan login ulang. |
| `VERSION_CONFLICT` | Data diedit di dua perangkat saat offline | Buka menu `/conflicts` di aplikasi untuk memilih versi yang ingin dipertahankan. |
| Upload storage gagal (`403 Forbidden`) | Belum login atau RLS storage belum aktif | Pastikan user sudah terautentikasi dan path berkas diawali dengan UID user (`<uid>/<filename>.enc`). |
| Data tidak masuk ke Supabase saat sync | RPC `apply_operation` belum di-deploy | Jalankan kembali script `20261011_fase6_sync_schema.sql` di Supabase SQL Editor. |

---

## 📋 Checklist Kesiapan Produksi (Fase 6 Selesai)
- [x] Migrasi Skema PostgreSQL lengkap (`20261011_fase6_sync_schema.sql`).
- [x] RPC `apply_operation` dengan jaminan Idempotent (Gate **T05**).
- [x] Sync Engine dengan perlindungan edit lokal saat in-flight (Gate **T06**).
- [x] Pull Engine dengan pemrosesan Tombstone dan update cursor per-device (Gate **T07**).
- [x] Sanitasi Formula Injection pada Ekspor CSV (Gate **T18**).
- [x] Backup & Restore Terenkripsi (AES-256-GCM + PBKDF2).
- [x] Layar Pengaturan Sinkronisasi (`SyncSettingsScreen`) & Resolusi Konflik (`ConflictResolutionScreen`).
