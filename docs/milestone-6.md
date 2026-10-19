# Milestone 6 — Laporan Keuangan, Keamanan, dan Backup Terenkripsi

Dokumentasi komprehensif implementasi Milestone 6 untuk aplikasi Money Flow Android.

---

## 1. Ringkasan Eksekutif & Arsitektur

Milestone 6 melengkapi aplikasi Money Flow Android dengan kapabilitas analisis keuangan mendalam, visualisasi data interaktif, ekspor data aman (CSV & PDF), sistem autentikasi lokal berlapis (PIN & Biometrik), serta mekanisme cadangan terenkripsi standar industri (*authenticated encryption*):
- **Laporan Finansial Komprehensif**: Perhitungan agregasi langsung pada SQLite database (SQL aggregations) untuk arus kas (*cash flow*), pengeluaran per kategori, pemasukan per kategori, posisi saldo akun, *net worth*, anggaran vs realisasi, utang & piutang, portofolio investasi & deposito, serta forecast multi-skenario.
- **Visualisasi Interaktif (fl_chart)**: Grafik batang arus kas bulanan (*Cash Flow BarChart*), diagram lingkaran komposisi pengeluaran (*Expense PieChart*), dan bilah progres anggaran berkode warna dengan label nominal Rupiah, indikator persentase, dan *empty state*.
- **Ekspor Aman (CSV & PDF)**:
  - **CSV**: Encoding UTF-8 dengan Byte Order Mark (BOM: `\uFEFF`) untuk kompatibilitas penuh dengan Microsoft Excel, dilengkapi sanitasi pencegahan *CSV Formula Injection* pada karakter berbahaya (`=`, `+`, `-`, `@`).
  - **PDF**: Menghasilkan dokumen laporan resmi berformat A4 dengan kartu ringkasan eksekutif, tabel rincian transaksi, tanggal cetak, rentang periode, dan mekanisme berbagi Android melalui `share_plus`.
- **PIN Aplikasi & Keamanan**:
  - Penyimpanan PIN tidak pernah berupa teks biasa (*zero plaintext storage*).
  - Derivasi hash menggunakan **PBKDF2-HMAC-SHA256** dengan salt acak 16 byte per pengguna dan 10.000 iterasi.
  - Pembatasan percobaan: 5 kali kesalahan berturut-turut memicu *lockout delay* selama 30 detik.
  - Lifecycle locking: Mengunci aplikasi saat berpindah ke latar belakang (*paused* / *hidden*) dengan proteksi proses transaksi aktif (*critical transaction guard*).
  - Penegasan: PIN adalah proteksi antarmuka lokal, bukan enkripsi database SQLite.
- **Biometrik**: Integrasi autentikasi lokal via `local_auth` dengan fallback mulus ke PIN jika biometrik dibatalkan atau perangkat tidak memiliki sensor biometrik.
- **Cadangan Terenkripsi (AES-256-GCM + PBKDF2)**:
  - Format berstandar *authenticated encryption* AES-256-GCM (`AesGcm.with256bits()`).
  - Kunci enkripsi 256-bit diturunkan dari kata sandi pengguna dengan PBKDF2-HMAC-SHA256 (salt acak 16-byte, 10.000 iterasi).
  - Nonce acak 12-byte per file backup.
  - Metadata berversi: format `money-flow-encrypted-backup`, versi 1.
  - Kata sandi tidak pernah disimpan di dalam file cadangan.
  - Prinsip atomisitas: Dekripsi dan validasi integritas tag autentikasi wajib berhasil sebelum menyentuh database SQLite; kegagalan dekripsi menjamin database aktif tidak berubah (*zero-mutation on failure*).
- **Pengingat & Manajemen Cadangan**: Menampilkan riwayat waktu backup terakhir, pembeda visual yang jelas antara cadangan biasa (JSON polos) dan cadangan terenkripsi (.enc.json), serta edukasi pengguna mengenai konsekuensi kehilangan kata sandi.

---

## 2. Laporan Finansial & Agregasi SQL

Untuk memastikan performa tinggi dan efisiensi memori pada perangkat seluler dengan puluhan ribu transaksi, perhitungan laporan dilakukan langsung pada *database engine* menggunakan SQL aggregations (`SUM()`, `COUNT()`, `GROUP BY`, `JOIN`):

### 2.1. Aturan Bisnis dan Pengecualian Transaksi
1. **Pengecualian Transfer**:
   Transfer antar-akun tidak pernah diklasifikasikan sebagai pemasukan atau pengeluaran (`WHERE type IN ('income', 'expense', 'refund')`).
2. **Perlakuan Refund (Pengembalian Dana)**:
   Refund diklasifikasikan sebagai pengurang pengeluaran bersih atau pencatatan pengembalian dana terpisah sesuai aturan domain, tidak dicatat ganda.
3. **Transaksi Terhapus / Batal**:
   Transaksi yang telah dihapus diabaikan secara konsisten.
4. **Isolasi Forecast**:
   Data forecast dihitung secara terpisah melalui `ForecastService` dan disajikan dalam kartu proyeksi independen tanpa mencemari riwayat transaksi aktual.

### 2.2. Kueri Agregasi SQL Utama (`ReportService`)

```dart
// 1. Agregasi Arus Kas Bulanan
final query = _db.selectOnly(_db.transactions)
  ..addColumns([monthCol, incomeCol, expenseCol, countCol])
  ..where(_db.transactions.type.isNotIn([TransactionType.transfer]))
  ..groupBy([monthCol])
  ..orderBy([OrderingTerm.asc(monthCol)]);

// 2. Agregasi Pengeluaran per Kategori
final query = _db.select(_db.transactions).join([
  innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
])
  ..addColumns([_db.categories.id, _db.categories.name, totalCol, countCol])
  ..where(_db.transactions.type.equalsValue(TransactionType.expense))
  ..groupBy([_db.categories.id, _db.categories.name])
  ..orderBy([OrderingTerm.desc(totalCol)]);
```

---

## 3. Visualisasi Grafik (fl_chart)

Visualisasi grafik dirancang dengan estetika modern dark theme (`#0F172A`), ramah aksesibilitas, dan tidak hanya mengandalkan warna:
1. **Tren Arus Kas (BarChart)**:
   - Sumbu Y terformat dalam Rupiah ringkas (`Rp 1,5 jt`, `Rp 10 M`).
   - Sumbu X menampilkan nama bulan Indonesia (`Jan`, `Feb`, `Mar`, dsb.).
   - Batang berdampingan: Hijau zamrud (`#10B981`) untuk pemasukan, Merah mawar (`#EF4444`) untuk pengeluaran.
2. **Distribusi Pengeluaran per Kategori (PieChart)**:
   - Sektor lingkaran proporsional dengan persentase badge jelas.
   - Legenda kategori dengan nama dan nilai Rupiah lengkap.
3. **Progres Anggaran (Linear Indicator)**:
   - Persentase realisasi terhadap batas anggaran bulanan.
   - Perubahan status visual: Normal (<80%), Waspada/Warning (80%-99%), Melebihi Batas/Exceeded (≥100%).
4. **Penanganan Data Tidak Cukup & Layar Kecil**:
   - Tampilan *empty state* informatif saat data belum tersedia.
   - Tata letak responsif (*SingleChildScrollView*, font skalabel, *wrap-friendly*).

---

## 4. Keamanan Ekspor CSV & Dokumen PDF

### 4.1. Sanitasi CSV Formula Injection (CWE-1236)
Aplikasi spreadsheet (seperti Microsoft Excel, LibreOffice Calc, Google Sheets) dapat mengeksekusi rumus atau perintah sistem operasi jika sel teks diawali dengan karakter tertentu. `ExportService.sanitizeForCsv` menetralkan bahaya ini:

```dart
static String sanitizeForCsv(String? value) {
  if (value == null) return '';
  final trimmed = value.trim();
  if (trimmed.startsWith('=') ||
      trimmed.startsWith('+') ||
      trimmed.startsWith('-') ||
      trimmed.startsWith('@')) {
    return "'$trimmed"; // Tambahkan prefix kutip tunggal untuk memaksa representasi teks murni
  }
  return value;
}
```

### 4.2. Karakteristik File Ekspor
- **Encoding**: UTF-8 dengan BOM bytes (`0xEF, 0xBB, 0xBF`) menjamin pembukaan langsung di Excel tanpa masalah karakter Unicode atau emoji.
- **PDF Resmi**: Berisi kop dokumen "MONEY FLOW - LAPORAN KEUANGAN", periode tanggal, kartu ringkasan eksekutif (Pemasukan, Pengeluaran, Arus Kas Bersih, Net Worth), serta tabel rincian aset & kewajiban.

---

## 5. Keamanan Aplikasi: PIN, Biometrik, dan Lifecycle

### 5.1. Algoritma Derivasi Kunci PIN (PBKDF2)
- **Fungsi KDF**: PBKDF2 dengan HMAC-SHA256 (`package:crypto`).
- **Salt**: 16 byte acak kriptografis (`Random.secure()`) unik per perangkat/pengguna, disimpan dalam setting `security.pin.salt`.
- **Iterasi**: 10.000 putaran (*work factor* seimbang untuk komputasi cepat di ponsel namun tahan terhadap serangan *offline dictionary attack*).
- **Format Hash**: Hex string 64 karakter dari 32 byte digest.

### 5.2. Pembatasan Percobaan (Rate Limiting & Lockout)
- Maksimal kegagalan berturut-turut: **5 kali**.
- Setelah 5 kali salah: Pengguna dikunci selama **30 detik** (`_lockoutUntil`).
- Countdown timer ditampilkan secara *real-time* pada layar input PIN.
- Percobaan benar mereset kegagalan menjadi 0.

### 5.3. Penanganan Lifecycle Aplikasi
- Memanfaatkan `WidgetsBindingObserver` pada `MoneyFlowApp`.
- Transisi status ke `AppLifecycleState.paused` atau `AppLifecycleState.hidden` otomatis memicu `sec.lockApp()` jika setting `security.lock_on_background` aktif.
- **Critical Transaction Guard**: Flag `isCriticalTransactionInProgress` mencegah penguncian layar di tengah proses atomik database (seperti saat pencadangan atau pemulihan data).
- Fallback transparan: Perangkat tanpa biometrik otomatis beralih ke PIN keypad.

---

## 6. Format dan Spesifikasi Backup Terenkripsi

### 6.1. Spesifikasi Kriptografi AES-256-GCM
- **Pustaka**: `package:cryptography` (implementasi teruji dan terawat).
- **Cipher**: AES-GCM 256-bit (`AesGcm.with256bits()`), menyediakan kerahasiaan (*confidentiality*) dan autentikasi integritas data (*authenticated encryption with associated data / AEAD*).
- **KDF Password**: PBKDF2-HMAC-SHA256 dengan salt acak 16 byte dan 10.000 iterasi.
- **Nonce / IV**: 12 byte acak (`Random.secure()`).
- **Mac / Tag**: 16 byte authentication tag.

### 6.2. Skema Kontainer Cadangan Berversi (`money-flow-encrypted-backup`)

```json
{
  "format": "money-flow-encrypted-backup",
  "version": 1,
  "exported_at": "2026-10-19T12:00:00.000Z",
  "cipher": "AES-256-GCM",
  "kdf": "PBKDF2-HMAC-SHA256",
  "kdf_iterations": 10000,
  "salt": "<hex-encoded-16-bytes-salt>",
  "nonce": "<hex-encoded-12-bytes-nonce>",
  "mac": "<hex-encoded-16-bytes-auth-tag>",
  "ciphertext": "<hex-encoded-encrypted-json-bytes>"
}
```

### 6.3. Garansi Integritas & Dekripsi Sebelum Mutasi Database
1. Pemeriksaan header (*header inspection*) memverifikasi format string dan versi yang didukung tanpa memerlukan kata sandi.
2. Proses dekripsi mendekode ciphertext dan memverifikasi MAC (*integrity verification*).
3. Jika kata sandi salah atau ciphertext dimanipulasi (*tampered*), algoritma AES-GCM melempar eksepsi autentikasi.
4. Database SQLite aktif **TIDAK PERNAH DISENTUH** jika tahap validasi dan dekripsi belum sukses 100%.

---

## 7. Hasil Pengujian Verifikasi & Quality Assurance

### 7.1. Hasil Eksekusi Unit Test & Widget Test
Pengujian dijalankan pada seluruh repositori mobile Money Flow:
- **Total Test**: 177 unit & widget tests.
- **Hasil**: **177 PASSED (100% lulus)**.
- **Waktu Eksekusi**: 10 detik.

Daftar berkas pengujian Milestone 6:
1. `test/features/milestone6_security_test.dart` (6 tests):
   - PIN setup dan verifikasi hash PBKDF2.
   - Salt acak menjamin PIN identik menghasilkan hash berbeda.
   - Kegagalan verifikasi PIN salah.
   - Pembatasan 5 kali salah memicu lockout 30 detik.
   - Reset proteksi PIN dan state lockout.
   - Pergantian PIN membutuhkan validasi PIN lama.
2. `test/features/milestone6_encrypted_backup_test.dart` (7 tests):
   - Ekspor backup terenkripsi menghasilkan header standar.
   - Verifikasi kata sandi pengguna TIDAK disimpan dalam file backup.
   - Header inspection membaca metadata tanpa dekripsi.
   - Dekripsi dengan password benar menghasilkan data utuh.
   - Dekripsi dengan password salah gagal dan melempar eksepsi.
   - Manipulasi ciphertext (*tampering*) ditolak oleh AEAD authentication.
   - Pemulihan gagal menjamin database aktif tidak berubah (*atomicity guarantee*).
3. `test/features/milestone6_reports_export_test.dart` (6 tests):
   - Perhitungan cash flow report (pemasukan, pengeluaran, net flow).
   - Breakdown pengeluaran per kategori beserta persentase pangsa.
   - Laporan komprehensif tanpa hitung ganda (*zero double-counting*).
   - Sanitasi CSV Formula Injection pada karakter `=`, `+`, `-`, `@`.
   - Ekspor CSV menghasilkan file UTF-8 BOM valid dengan Unicode & nominal besar.
   - Ekspor laporan keuangan ke format PDF resmi.

### 7.2. Hasil Analisis Kode (`flutter analyze`)
```bash
Analyzing mobile...
No issues found! (ran in 3.6s)
```
Kode bersih dari *warning*, *error*, maupun *unused imports*.

---

## 8. Panduan Penggunaan & Status Kompatibilitas

### 8.1. Mengaktifkan PIN & Biometrik
1. Masuk ke tab **Pengaturan** (`/settings`).
2. Pada bagian **Keamanan & Privasi**, aktifkan sakelar **Kunci Aplikasi dengan PIN**.
3. Masukkan 4–8 digit PIN baru dan konfirmasi ulang.
4. Aktifkan opsi **Kunci Saat Masuk Latar Belakang** untuk mengunci aplikasi otomatis saat berganti aplikasi.
5. Jika perangkat memiliki sensor sidik jari atau wajah, aktifkan **Buka Kunci dengan Biometrik**.

### 8.2. Membuat dan Memulihkan Cadangan Terenkripsi
1. Masuk ke **Pengaturan** -> **Data & Cadangan**.
2. Pilih **Cadangan Terenkripsi (AES-GCM)**.
3. Masukkan kata sandi enkripsi (minimal 6 karakter).
4. File cadangan aman berekstensi `.enc.json` siap disimpan di media eksternal (Google Drive, flashdisk, email).
5. Untuk memulihkan, pilih **Pulihkan Cadangan Terenkripsi**, pilih file cadangan, lalu masukkan kata sandi yang sesuai.

---

## 9. Catatan Arsitektur & Kesiapan Milestone 7

- **Status Database**: Skema database versi 3 tetap kompatibel penuh secara *offline-first*.
- **Enkripsi Database vs Enkripsi Cadangan**: Ditegaskan dalam dokumentasi dan antarmuka pengguna bahwa proteksi PIN mengunci antarmuka lokal, sedangkan perlindungan data cadangan eksternal menggunakan AES-256-GCM.
- Seluruh kriteria Milestone 6 telah terpenuhi secara lengkap dan siap melanjutkan ke Milestone 7.
