# Panduan Konfigurasi Release Keystore & GitHub Secrets (Money Flow)

Dokumen ini menjelaskan langkah-langkah penyiapan Release Signing Key (Keystore) untuk aplikasi **Money Flow** agar APK rilis memiliki tanda tangan digital permanen, aman, dan dapat diperbarui (*in-place update*) tanpa error benturan paket (*package signature conflict*).

---

## 1. Pembuatan Keystore (Hanya Sekali)

Jalankan perintah berikut pada terminal lokal (di luar direktori repository publik atau di tempat yang aman):

```bash
keytool -genkey -v -keystore monflow.jks -keyalg RSA -keysize 2048 -validity 10000 -alias monflow
```

Saat diminta, masukkan password keystore dan password alias, serta data identitas organisasi/developer.

> [!CAUTION]
> **PERINGATAN KRUSIAL — CADANGKAN (BACKUP) KEYSTORE ANDA!**
> Simpan file `monflow.jks` dan catat password di tempat penyimpanan yang aman (seperti Password Manager / offline backup terenkripsi).
> **Jika file keystore ini hilang, aplikasi tidak akan pernah bisa di-update lagi secara in-place di perangkat pengguna!** Satu-satunya jalan adalah membuat paket baru yang mengharuskan pengguna menghapus aplikasi lama dan kehilangan data lokal bila tidak di-backup.

---

## 2. Encode Keystore ke Base64 untuk GitHub Secret

Ubah file binary `monflow.jks` menjadi format string base64 satu baris:

**Linux / macOS / Git Bash:**
```bash
base64 -w 0 monflow.jks
```
*(Pada macOS gunakan: `base64 -b 0 monflow.jks` atau `base64 -i monflow.jks | tr -d '\n'`)*

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("monflow.jks")) | Set-Clipboard
```
*(Perintah PowerShell di atas otomatis menyalin hasil string base64 ke clipboard Anda).*

---

## 3. Konfigurasi GitHub Repository Secrets

Buka repository di GitHub: **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**.

Tambahkan 4 secret wajib berikut:

| Nama Secret | Deskripsi |
| :--- | :--- |
| `KEYSTORE_BASE64` | String base64 utuh dari file `monflow.jks` (hasil langkah 2). |
| `KEYSTORE_PASSWORD` | Password keystore yang dibuat pada langkah 1. |
| `KEY_ALIAS` | Nama alias kunci (contoh: `monflow`). |
| `KEY_PASSWORD` | Password untuk alias kunci tersebut. |

> [!IMPORTANT]
> Jangan pernah meng-commit file `.jks`, `.keystore`, atau `key.properties` ke dalam git repository publik. File-file tersebut sudah dimasukkan ke `.gitignore`.

---

## 4. Catatan Migrasi untuk Pengguna yang Gagal Update

Jika pengguna sebelumnya menginstal build APK release yang tertandatangani oleh debug runner CI sementara:
1. Sistem operasi Android memblokir pembaruan dengan pesan:
   > *"App not installed as package conflicts with an existing package."*
2. **Penyebab:** Tanda tangan digital (*certificate fingerprint*) APK lama berbeda dengan APK baru ber-keystore tetap.
3. **Solusi untuk Pengguna Tersebut:**
   - Buka aplikasi Money Flow versi lama yang terpasang.
   - Buka menu **Settings / Pengaturan** -> **Backup & Export Data** -> Buat cadangan data JSON/Database ke penyimpanan perangkat.
   - Hapus (*uninstall*) aplikasi Money Flow versi lama.
   - Pasang (*install*) APK rilis baru ber-keystore tetap ini.
   - Buka menu **Settings** -> **Restore Data** untuk mengembalikan seluruh saldo, kategori, dan transaksi.
4. **Mulai dari rilis dengan keystore permanen ini dan seterusnya:** Semua pembaruan APK selanjutnya dapat dipasang langsung (*in-place update*) tanpa uninstall dan tanpa kehilangan data.
