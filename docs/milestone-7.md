# Milestone 7 — Final Android Release dan Distribusi

Dokumentasi komprehensif audit kesiapan rilis, signing, validasi database, CI/CD pipeline, dan panduan distribusi aplikasi Money Flow Android.

---

## 1. Audit Kesiapan Rilis

Audit menyeluruh dilakukan terhadap seluruh komponen dari Milestone 1 hingga Milestone 6 untuk memastikan aplikasi siap didistribusikan dengan andal, aman, dan tanpa ketergantungan eksternal.

| Komponen Audit | Status | Temuan & Konfigurasi |
|---|---|---|
| **Fitur Inti (M1–M6)** | Lulus | Akun, Transaksi, Anggaran, Tagihan, Hutang/Piutang, Investasi, Deposito, Savings Goals, Forecast, Laporan Keuangan, Ekspor CSV/PDF, Kunci PIN & Biometrik, Backup Biasa & Terenkripsi. |
| **Kemandirian Jaringan (Offline-First)** | Lulus | 100% mandiri di perangkat. Zero dependency pada backend localhost atau server eksternal apa pun. Izin internet `android.permission.INTERNET` **TIDAK** diminta di `AndroidManifest.xml`. |
| **Application ID** | Lulus | `com.moneyflow.app` (konsisten di `build.gradle`, `MainActivity.kt`, dan `AndroidManifest.xml`). |
| **Versi Aplikasi** | Lulus | `versionCode 1`, `versionName "1.0.0"` (`1.0.0+1` pada `pubspec.yaml`). |
| **Target SDK & Minimum SDK** | Lulus | `compileSdk = 34`, `targetSdk = 34`, `minSdk = 23` (Android 6.0 Marshmallow ke atas, disyaratkan untuk keamanan kriptografi AES-256-GCM dan otentikasi biometrik modern). |
| **Izin Android (Permissions)** | Lulus | `POST_NOTIFICATIONS` (Android 13+ untuk alarm tagihan), `RECEIVE_BOOT_COMPLETED` (menjadwalkan ulang alarm saat reboot), `USE_BIOMETRIC` & `USE_FINGERPRINT` (autentikasi biometrik lokal). Tanpa izin berbahaya (dangerous permissions) berlebih. |
| **MainActivity Kotlin** | Lulus | Mewarisi `FlutterFragmentActivity` (kebutuhan wajib `local_auth` pada platform Android). |
| **Skema Database & Migrasi** | Lulus | Skema Drift SQLite versi 3 dengan migrasi schema step-by-step dari v1 -> v2 -> v3, integritas Foreign Key aktif, dan `PRAGMA foreign_keys = ON`. |
| **Signing Release** | Lulus | Template `android/key.properties.example` disiapkan. `build.gradle` dikonfigurasi membaca `key.properties` jika tersedia dan fallback aman ke debug signing untuk development lokal. |
| **Keamanan Rahasia (Secrets)** | Lulus | `key.properties`, `*.jks`, `*.keystore` telah diabaikan pada `.gitignore` tingkat root dan subfolder `mobile/.gitignore`. |
| **Kualitas Kode & Pengujian** | Lulus | `dart format` (80 file terformat rapi), `flutter analyze` (0 issue / 0 warning), `flutter test` (182 / 182 tes lulus 100%). |

---

## 2. Validasi Data dan Integritas Database

Validasi integritas data diuji menggunakan unit dan integration test otomatis (`milestone7_release_validation_test.dart`):

### 2.1. Invarian Transfer Saldo
- **Aturan**: Transfer antar-akun tidak pernah mengubah total kekayaan bersih (*total combined assets*) atau tercatat sebagai pengeluaran/pemasukan. Saldo akun asal berkurang persis sebesar nominal transfer, dan saldo akun tujuan bertambah persis sebesar nominal yang sama.
- **Hasil Uji**: Akun Mandiri (Rp 10.000.000) mentransfer Rp 3.000.000 ke Dompet Kas (Rp 2.000.000). Total aset gabungan sebelum transfer (Rp 12.000.000) sama persis dengan setelah transfer (Rp 7.000.000 + Rp 5.000.000 = Rp 12.000.000). Status: **LULUS**.

### 2.2. Pemulihan Instalasi Bersih (Clean Installation Restore)
- **Aturan**: File cadangan terenkripsi yang diekspor dari aplikasi dengan data beragam (akun bank, e-wallet, transaksi, anggaran bulanan, tagihan, hutang/piutang, deposito, dan target tabungan) harus dapat dipulihkan secara utuh pada database baru yang masih kosong/bersih.
- **Hasil Uji**: Seluruh entitas pulih tanpa kehilangan relasi foreign key atau anomali tipe data. Status: **LULUS**.

### 2.3. Jaminan Atomisitas (Failure Safety)
- **Aturan**: Jika pengguna memasukkan kata sandi yang salah atau berkas cadangan rusak (tampered/corrupted ciphertext), proses dekripsi AES-256-GCM akan gagal validasi integritas tag autentikasi sebelum menyentuh database SQLite aktif. Database aktif tidak boleh mengalami mutasi parsial sedikit pun (*zero database corruption*).
- **Hasil Uji**: Injeksi payload rusak dengan MAC invalid menghasilkan `result.success == false` dan data akun pada database aktif tetap 100% utuh. Status: **LULUS**.

### 2.4. Konsistensi Agregasi Laporan Keuangan
- **Aturan**: Seluruh pilar aset (saldo kas, nilai investasi, pokok deposito, piutang) dikurangi liabilitas (hutang) dihitung serempak melalui SQL aggregations tanpa drift desimal.
- **Hasil Uji**: Kas Rp 20.000.000 + Deposito Rp 10.000.000 - Hutang Rp 5.000.000 = Net Worth Rp 25.000.000. Status: **LULUS**.

---

## 3. Konfigurasi Signing Release

Aplikasi Android release membutuhkan tanda tangan digital (keystore) yang konsisten agar pengguna dapat melakukan update aplikasi di masa mendatang tanpa konflik tanda tangan (*signature mismatch*).

### 3.1. Prosedur Pembuatan Keystore (One-Time Setup)

Jalankan perintah berikut di terminal aman (misalnya direktori pribadi pengguna di luar repositori Git):

```bash
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias moneyflow
```

Simpan kata sandi keystore dan kata sandi alias di tempat yang aman (misalnya password manager).

### 3.2. Konfigurasi `key.properties`

Buat file `mobile/android/key.properties` berdasarkan template `mobile/android/key.properties.example`:

```properties
storePassword=GantiDenganPasswordKeystoreAnda
keyPassword=GantiDenganPasswordAliasAnda
keyAlias=moneyflow
storeFile=release.jks
```

> [!WARNING]
> Jangan pernah melakukan *commit* atau memasukkan berkas `key.properties` maupun berkas `.jks` ke dalam Git repository. File-file ini sudah masuk dalam `.gitignore`.

### 3.3. Rencana Cadangan Keystore
1. Buat salinan berkas `release.jks` terenkripsi dan simpan di setidaknya dua media terpisah (misalnya flashdisk terenkripsi offline dan cold cloud storage aman).
2. Catat alias, tanggal pembuatan, dan sidik jari SHA-256 keystore.
3. Kehilangan keystore akan menyebabkan aplikasi tidak dapat diperbarui di perangkat pengguna yang sudah terpasang tanpa menghapus aplikasi terlebih dahulu (yang dapat menyebabkan kehilangan database lokal jika belum dibackup).

---

## 4. Status Lingkungan Build & Automasi CI

### 4.1. Audit Lingkungan Host Saat Ini
- **Flutter SDK**: v3.35.3 (Dart v3.9.0) terpasang di host lokal.
- **Java / Android SDK**: Tidak terpasang di lingkungan Windows host saat ini (`Unable to locate Android SDK`, `java is not recognized`).
- **Pemberitahuan Transparansi**: Sesuai instruksi Milestone 7 ("*Jangan mengarang lokasi APK, hasil pengujian, atau keberhasilan build jika SDK tidak tersedia*"), kompilasi biner `.apk` final di host lokal tertahan oleh ketiadaan Android SDK & Java.
- **Solusi yang Disediakan**: Telah disiapkan alur kerja otomatisasi **GitHub Actions CI** (`.github/workflows/mobile_ci.yml`) yang berjalan di runner Ubuntu resmi dengan Java 17 dan Android SDK 34 yang telah terkonfigurasi lengkap.

### 4.2. Alur Kerja GitHub Actions CI (`.github/workflows/mobile_ci.yml`)

Pipeline CI menjalankan:
1. **Pemeriksaan Format**: `dart format --output=none --set-exit-if-changed .`
2. **Analisis Statis**: `flutter analyze`
3. **Pengujian Unit & Widget**: `flutter test` (182 tests)
4. **Build APK Release**:
   - Universal APK: `flutter build apk --release`
   - Split-per-ABI APK (opsional ukuran hemat): `flutter build apk --release --split-per-abi`
5. **Penyimpanan Artefak**: Mengunggah APK ke GitHub Actions Artifacts sehingga dapat langsung diunduh oleh pengguna.

### 4.3. Perintah Build Mandiri (Saat Android SDK Tersedia di Host)

Jika Android SDK dan Java JDK 17 telah dipasang di komputer lokal, build APK dapat dijalankan dengan:

```bash
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --release
```

Output berkas APK berada di:
- Universal: `mobile/build/app/outputs/flutter-apk/app-release.apk`
- Per-ABI: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, dll.

---

## 5. Panduan Distribusi Pribadi (Sideloading)

Untuk distribusi langsung kepada keluarga, tim, atau penggunaan pribadi:

### 5.1. Spesifikasi Perangkat Minimum
- **Sistem Operasi**: Android 6.0 (Marshmallow, API level 23) atau lebih tinggi.
- **Arsitektur CPU**: ARM64 (aarch64), ARMv7 (armeabi-v7a), atau x86_64.
- **Penyimpanan Bebas**: Minimal 50 MB untuk instalasi aplikasi dan basis data lokal.
- **Biometrik**: Opsional (sensor sidik jari atau pengenalan wajah perangkat).

### 5.2. Langkah Instalasi APK Bersih
1. Salin berkas `app-release.apk` ke penyimpanan perangkat Android.
2. Buka berkas APK melalui File Manager di perangkat Android.
3. Jika muncul peringatan *"Install unknown apps"* (Pasang aplikasi dari sumber tidak dikenal), pilih **Settings** dan aktifkan izin untuk File Manager yang bersangkutan.
4. Lanjutkan proses pemasangan hingga selesai.
5. Buka aplikasi **Money Flow**.
6. Setujui permintaan izin notifikasi jika ingin mengaktifkan pengingat tagihan.

### 5.3. Prosedur Pembaruan (Upgrade APK)
> [!IMPORTANT]
> **Selalu lakukan Ekspor Cadangan Data sebelum memperbarui APK!**

1. Di aplikasi lama: Buka menu **Pengaturan** -> **Cadangan & Pemulihan** -> **Ekspor Cadangan Terenkripsi**.
2. Simpan file cadangan (`.enc.json`) ke folder aman di luar perangkat (misalnya Google Drive, email pribadi, atau komputer).
3. Unduh berkas APK versi baru.
4. Pasang APK versi baru **tanpa mencopot (uninstall)** aplikasi versi lama.
5. Android Package Installer akan memperbarui biner secara otomatis sambil mempertahankan basis data SQLite yang ada.
6. Buka aplikasi dan periksa bahwa seluruh data akun dan transaksi tetap utuh.

---

## 6. Daftar Keterbatasan yang Diketahui (Known Limitations)

1. **Jadwal Pengingat Setelah Reboot**:
   - Pengingat tagihan menggunakan alarm sistem lokal. Beberapa vendor perangkat (seperti Xiaomi MIUI/HyperOS, OPPO ColorOS, Vivo Funtouch) memiliki manajemen baterai agresif yang dapat membatasi proses latar belakang. Pengguna disarankan mengatur aplikasi ke status *No Restrictions* pada pengaturan baterai perangkat jika pengingat tidak muncul tepat waktu.
2. **Ketergantungan Keystore Signing**:
   - Jika APK rilis berikutnya ditandatangani dengan keystore berbeda dari APK yang terpasang, Android akan menolak instalasi dengan galat `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Dalam kondisi ini, pengguna harus mengekspor backup, menghapus aplikasi lama, memasang APK baru, dan mengimpor kembali file cadangan.
3. **Penyimpanan Lokal Penuh**:
   - Karena aplikasi bersifat *offline-first*, jika penyimpanan perangkat pengguna benar-benar habis (0 byte tersisa), SQLite dapat melempar galat `disk I/O error` saat mencoba menulis transaksi baru.

---

## 7. Ringkasan Kriteria Milestone 7

- [x] Semua 182 tes lulus 100% tanpa kegagalan.
- [x] Zero warnings pada `flutter analyze` dan formatting standar Dart bersih.
- [x] Application ID `com.moneyflow.app` konsisten.
- [x] Versioning `1.0.0+1` (v1.0.0 release) terkonfigurasi.
- [x] Konfigurasi signing release aman dengan pemisahan rahasia dari Git (`key.properties.example`, `.gitignore`).
- [x] Validasi data: Invarian transfer saldo, atomisitas backup restore, dan integritas laporan komprehensif teruji.
- [x] Alur kerja otomatisasi CI GitHub Actions (`mobile_ci.yml`) aktif untuk build dan pengujian mandiri.
- [x] Panduan distribusi APK, persyaratan minimum, dan prosedur pembaruan data terdokumentasi lengkap.
