# Money Flow — Android Native Financial Management

Aplikasi manajemen keuangan pribadi mandiri (*standalone*), modern, andal, dan **100% Offline-First** berbasis **Flutter, Dart, Drift (SQLite), dan Riverpod** untuk Android.

Aplikasi ini berjalan sepenuhnya di perangkat Android tanpa ketergantungan pada server backend eksternal, proses desktop, Node.js, maupun koneksi internet. Seluruh data keuangan disimpan dan dienkripsi secara lokal di perangkat Anda.

---

## 1. Prasyarat Sistem & SDK

Untuk membangun dan menjalankan proyek ini, pastikan sistem Anda memenuhi persyaratan berikut:

- **Flutter SDK**: Versi `3.24.5` atau lebih baru (Channel `stable`)
- **Dart SDK**: Versi `3.5.0` hingga `< 4.0.0` (disertakan bersama Flutter SDK)
- **Java Development Kit (JDK)**: OpenJDK 17 (disyaratkan untuk Android Gradle Plugin 8+)
- **Android SDK**:
  - `compileSdkVersion`: **34** (Android 14)
  - `targetSdkVersion`: **34** (Android 14)
  - `minSdkVersion`: **23** (Android 6.0 Marshmallow ke atas — diperlukan untuk keamanan kriptografi AES-256-GCM hardware-backed dan otentikasi biometrik modern)
- **Android Studio / Command Line Tools**: Termasuk Android SDK Platform 34 dan Android SDK Build-Tools 34.0.0

---

## 2. Instalasi Dependensi & Setup

Proyek Flutter berlokasi di direktori `mobile/`. Ikuti langkah berikut untuk menginisialisasi lingkungan pengembangan:

### Di Windows (Otomatis):
Jalankan skrip pembantu di direktori root:
```cmd
setup_mobile.bat
```

### Di Linux / macOS / Manual di Windows:
Masuk ke direktori `mobile/` lalu unduh paket dependensi dan jalankan generator kode Drift:
```bash
cd mobile

# Unduh paket dependensi Flutter
flutter pub get

# Jalankan code generation Drift SQLite & Riverpod
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Menjalankan Aplikasi di Emulator / Perangkat

Pastikan emulator Android aktif atau perangkat fisik terhubung via USB Debugging (`adb devices`).

Jalankan perintah berikut dari direktori `mobile/`:
```bash
cd mobile
flutter run
```

Untuk mode rilis langsung di perangkat:
```bash
flutter run --release
```

---

## 4. Pengujian & Analisis Kualitas Kode

Seluruh fungsionalitas dan logika bisnis memiliki uji unit dan pengujian widget komprehensif (183 tes lulus 100%).

Jalankan pemeriksaan kualitas kode dari direktori `mobile/`:

```bash
cd mobile

# 1. Pemeriksaan format kode Dart
dart format --output=none --set-exit-if-changed .

# 2. Analisis statis linter (0 issues / 0 warnings)
flutter analyze

# 3. Menjalankan seluruh test suite (unit test, widget test, invariant validation)
flutter test
```

---

## 5. Konfigurasi Release Signing yang Aman

Aplikasi disiapkan untuk menggunakan penandatanganan rilis resmi Android melalui berkas `key.properties`.

> [!CAUTION]
> Jangan pernah melakukan *commit* berkas `key.properties`, file `.jks`, atau kata sandi keystore ke dalam Git repository. Berkas-berkas ini telah diabaikan secara global pada `.gitignore`.

### Langkah Konfigurasi Signing:

1. Buat keystore baru menggunakan `keytool` di direktori aman di luar repository:
   ```bash
   keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias moneyflow
   ```
2. Buat berkas `mobile/android/key.properties` (gunakan contoh `mobile/android/key.properties.example`):
   ```properties
   storePassword=GantiDenganPasswordKeystoreAnda
   keyPassword=GantiDenganPasswordAliasAnda
   keyAlias=moneyflow
   storeFile=C:/path/ke/release.jks
   ```
3. Jika `key.properties` tidak ditemukan, skrip Gradle di `mobile/android/app/build.gradle` secara otomatis melakukan fallback aman ke penandatanganan debug (*debug signing*) untuk kemudahan pengujian pengembang lokal.

---

## 6. Membangun APK Release & Lokasi Output

Jalankan perintah kompilasi rilis dari direktori `mobile/`:

### A. Universal Release APK (Kompatibel dengan semua arsitektur):
```bash
cd mobile
flutter build apk --release
```
**Lokasi Output APK:**
```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

### B. Split-per-ABI Release APK (Ukuran lebih hemat, disesuaikan per arsitektur CPU):
```bash
cd mobile
flutter build apk --release --split-per-abi
```
**Lokasi Output APK:**
- ARM 64-bit (Sebagian besar smartphone modern):
  `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- ARM 32-bit (Perangkat lama):
  `mobile/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- x86_64 (Emulator & tablet Intel/AMD):
  `mobile/build/app/outputs/flutter-apk/app-x86_64-release.apk`

### C. Android App Bundle (AAB) untuk Google Play Store:
```bash
cd mobile
flutter build appbundle --release
```
**Lokasi Output AAB:**
```text
mobile/build/app/outputs/bundle/release/app-release.aab
```

---

## 7. Format Cadangan (Backup) & Prosedur Restore

Aplikasi menyediakan dua mekanisme pencadangan lokal berstandar tinggi:

### 7.1. Format Cadangan JSON Berversi (`money-flow-backup`)
- Format berkas: JSON snapshot berstruktur dengan `format: "money-flow-backup"` dan `schema_version: 3`.
- Mencakup metadata ringkasan, seluruh tabel akun, kategori, transaksi, transfer dua-entri, anggaran, tagihan, hutang/piutang, investasi, deposito, target tabungan, rencana pembelian, dan preferensi pengaturan.
- Presisi angka Rupiah menggunakan integer murni.
- Disimpan secara lokal di direktori dokumen aplikasi perangkat:
  ```text
  /data/user/0/com.moneyflow.app/app_flutter/money_flow_backups/
  ```

### 7.2. Cadangan Terenkripsi Kuat (Encrypted Backup)
- Menggunakan standar enkripsi militer **AES-256-GCM** dengan derivasi kunci sandi **PBKDF2** (100.000 iterasi SHA-256) dan salt acak 16-byte kriptografis.
- Otentikasi integritas data diverifikasi sebelum dekripsi menyentuh database aktif (*zero corruption on wrong password*).

### 7.3. Prosedur Restore Data
1. Buka menu **Pengaturan (Settings) > Cadangan & Pemulihan (Backup & Restore)**.
2. Pilih file cadangan `.json` (atau `.enc` jika terenkripsi).
3. Aplikasi akan menampilkan **Pratinjau (Preview)** ringkasan data (jumlah akun, transaksi, total saldo).
4. Masukkan password jika file terenkripsi.
5. Konfirmasi pemulihan. Operasi pemulihan berjalan dalam SQLite Database Transaction yang atomik (*atomic full replace*): jika terjadi kegagalan format di tengah proses, seluruh perubahan dibatalkan (*rollback*) dan database aktif tetap 100% utuh.
6. Data riil dari aplikasi versi desktop lama juga telah diekspor dan diverifikasi siap dipulihkan melalui:
   `mobile/assets/backup/desktop_migrated_backup.json` (juga didokumentasikan di `docs/desktop_migrated_backup.json`).

---

## 8. Kebijakan Database & Skema Migrasi

Penyimpanan lokal dikelola oleh **Drift** (wrapper SQLite berkemampuan tinggi untuk Flutter):
- **Foreign Key Enforcement**: `PRAGMA foreign_keys = ON;` selalu aktif untuk menjaga integritas relasi antar tabel.
- **Skema Bertingkat (Step-by-Step Migration)**:
  - **Skema v1**: Tabel Akun, Kategori, Transaksi, Transfer, Pengaturan.
  - **Skema v2**: Penambahan Anggaran (*Budgets*), Tagihan (*Bills*), Pembayaran Tagihan (*Bill Payments*), Hutang/Piutang (*Debts*), dan Pembayaran Hutang (*Debt Payments*).
  - **Skema v3**: Penambahan Investasi (*Investments*), Transaksi Investasi (*Investment Transactions*), Deposito Berjangka (*Deposits*), Target Tabungan (*Savings Goals*), dan Rencana Pembelian (*Purchase Plans*).
- Setiap pembaruan versi skema di masa depan wajib mengimplementasikan fungsi migrasi eksplisit di `mobile/lib/core/database/database.dart` tanpa menghapus data tabel yang sudah ada (*zero data loss on upgrade*).

---

## 9. Fitur Aplikasi & Status Implementasi

| Modul | Fitur & Deskripsi | Status |
|---|---|---|
| 📊 **Dashboard** | Total Net Worth, Arus Kas Bulanan, Ringkasan Akun, Tagihan Mendatang, Aset vs Liabilitas | ✅ Lengkap & Mandiri |
| 💸 **Cash Flow** | Pemasukan, Pengeluaran, Transfer Antarakun (dua entri atomik), dan Refund | ✅ Lengkap & Mandiri |
| 🏦 **Accounts** | Manajemen Uang Tunai, Bank, E-Wallet, Tabungan dengan tracking saldo real-time | ✅ Lengkap & Mandiri |
| 🗂️ **Categories** | Master data kategori pemasukan & pengeluaran dengan ikon dan palet warna | ✅ Lengkap & Mandiri |
| 🎯 **Budgets** | Anggaran bulanan per kategori, visual progress bar, dan peringatan batas penggunaan | ✅ Lengkap & Mandiri |
| 📑 **Bills** | Tagihan rutin/berulang, status jatuh tempo (upcoming, due soon, overdue, paid), pengingat lokal | ✅ Lengkap & Mandiri |
| 🤝 **Debts** | Manajemen Hutang & Piutang, tenor, cicilan berkala, dan pencatatan pembayaran | ✅ Lengkap & Mandiri |
| 📈 **Investments** | Portofolio investasi (Saham, Reksadana, Kripto, Emas, Obligasi), modal, nilai pasar, laba/rugi | ✅ Lengkap & Mandiri |
| 🏦 **Deposits** | Deposito berjangka, kalkulasi bunga *Simple* & *Compound*, tenor, dan simulasi pajak (default 20%) | ✅ Lengkap & Mandiri |
| 🛡️ **Savings Goals**| Target dana darurat & tabungan tujuan khusus dengan visual progress bar | ✅ Lengkap & Mandiri |
| 🛒 **Purchase Plans**| Rencana pembelian barang, target dana, prioritas, estimasi waktu, dan tautan produk | ✅ Lengkap & Mandiri |
| 🔮 **Forecast** | Proyeksi arus kas masa depan (Skenario Konservatif, Normal, Optimis) | ✅ Lengkap & Mandiri |
| 📉 **Reports** | Laporan grafis arus kas, pengeluaran per kategori, saldo per akun, net worth, ekspor CSV & PDF | ✅ Lengkap & Mandiri |
| 🔒 **Security** | Proteksi Kunci PIN (PBKDF2 hash), Kunci Biometrik sidik jari, dan proteksi salah PIN (lockout) | ✅ Lengkap & Mandiri |
| 💾 **Backup & Restore**| Ekspor/impor cadangan JSON berversi dan cadangan terenkripsi kuat AES-256-GCM | ✅ Lengkap & Mandiri |

### Batasan Aplikasi Saat Ini:
1. **Pembaruan Nilai Pasar Investasi**: Karena aplikasi 100% offline tanpa koneksi server eksternal, pembaruan harga pasar instrumen investasi (*current valuation*) dilakukan secara manual oleh pengguna melalui menu portofolio investasi.
2. **Notifikasi Alarm Tagihan**: Notifikasi tagihan menggunakan penjadwalan lokal Android (`flutter_local_notifications`). Pada perangkat Android dengan optimasi baterai agresif (seperti Xiaomi MIUI/HyperOS atau Vivo), pengguna disarankan mengaktifkan izin *Autostart* dan menonaktifkan *Battery Saver* untuk aplikasi Money Flow agar alarm tetap berdering tepat waktu.

---

## 10. Struktur Proyek

```text
MONEY_FLOW_APK/
├── .github/
│   └── workflows/
│       └── mobile_ci.yml         # Otomasi pengujian & build release APK via GitHub Actions
├── docs/                         # Dokumentasi arsitektur, aturan bisnis, dan spesifikasi pengujian
│   ├── architecture-audit.md
│   ├── business-rules.md
│   ├── database-mapping.md
│   ├── desktop_migrated_backup.json # Data riil pengguna dari desktop yang telah dimigrasi
│   ├── feature-mapping.md
│   ├── migration-plan.md
│   ├── milestone-4.md
│   ├── milestone-5.md
│   ├── milestone-6.md
│   └── milestone-7.md
├── mobile/                       # Proyek Flutter Android Mandiri
│   ├── android/                  # Android native runner, Gradle 8, Kotlin, dan konfigurasi rilis
│   ├── assets/                   # Asset statis & cadangan data migrasi desktop
│   │   └── backup/
│   │       └── desktop_migrated_backup.json
│   ├── lib/
│   │   ├── app.dart              # Root widget & routing MaterialApp
│   │   ├── core/                 # Drift SQLite database, theme, enums, & utilities
│   │   ├── data/                 # Repositori data & service offline (backup, report, security)
│   │   ├── domain/               # Aturan bisnis, kalkulator bunga/pajak, & model
│   │   ├── features/             # Layar UI & widget Flutter per modul fitur
│   │   └── main.dart             # Entry point aplikasi Android
│   ├── test/                     # 183 unit test, widget test, & validasi rilis
│   ├── analysis_options.yaml     # Aturan linter resmi Flutter
│   ├── build.yaml                # Konfigurasi code generator Drift
│   ├── pubspec.yaml              # Dependensi Flutter & pustaka Android
│   └── pubspec.lock              # Lockfile dependensi teruji
├── .gitignore                    # Aturan pengabaian berkas rahasia & build
├── README.md                     # Dokumentasi resmi aplikasi Android
└── setup_mobile.bat              # Skrip otomasi persiapan & verifikasi Flutter di Windows
```

---

## 11. Lisensi & Privasi

Aplikasi Money Flow menghormati privasi data Anda 100%. Tidak ada analitik, tidak ada pelacakan data, dan tidak ada data keuangan yang dikirimkan ke server mana pun di internet. Seluruh data adalah milik Anda seutuhnya di perangkat Android Anda.
