# Migration Plan — Money Flow Desktop → Android

## Prinsip

1. **Aplikasi desktop tetap utuh** — tidak ada file yang dihapus atau dimodifikasi
2. **Flutter di folder `mobile/` terpisah** — tidak mengganggu frontend/backend
3. **Semua nominal uang sebagai INTEGER Rupiah** — mengoreksi Float dari desktop
4. **Offline-first** — tidak memerlukan server, internet, atau backend
5. **Vertical slices** — selesaikan 1 alur end-to-end sebelum menambah fitur

## Milestone 0 — Audit ✅

| Deliverable | Status |
|---|---|
| architecture-audit.md | ✅ |
| database-mapping.md | ✅ |
| business-rules.md | ✅ |
| feature-mapping.md | ✅ |
| migration-plan.md | ✅ (ini) |
| test_data_spec.py | ✅ (semua test PASS) |

## Milestone 1 — Fondasi Flutter ✅

| Deliverable | Status |
|---|---|
| Proyek Flutter `mobile/` | ✅ Dibuat |
| pubspec.yaml dengan dependensi | ✅ |
| Drift database definition | ✅ |
| Riverpod configured | ✅ |
| go_router navigation | ✅ |
| Format Rupiah & tanggal Indonesia | ✅ |
| Dark theme premium | ✅ |
| Seed data (kategori + settings) | ✅ |

## Milestone 2 — Irisan Transaksi Pertama ⏳

| Deliverable | Status |
|---|---|
| Create account | ✅ UI + Repository |
| List accounts grouped | ✅ Stream-based |
| Total balance | ✅ Reactive |
| Record income transaction | ✅ + balance update |
| Record expense transaction | ✅ + balance update |
| Record refund | ✅ + balance update |
| Transaction list + filter | ✅ |
| Delete transaction + reverse | ✅ |
| Dashboard overview | ✅ |
| Balance rules unit test | ✅ |
| Formatter unit test | ✅ |
| Python test parity | ✅ ALL PASS |
| `flutter create` + build | ⏳ Menunggu Flutter SDK |
| APK debug | ⏳ Menunggu Flutter SDK |

## Risiko & Pertanyaan Terbuka

1. **Float → Integer**: Konversi nominal desktop yang sudah tersimpan sebagai float
   perlu pembulatan. Apakah `round()` cukup atau perlu aturan khusus?

2. **Adjustment type**: Di schema Pydantic, amount > 0 (validasi),
   tapi di code adjustment `balance += amount`. Ini berarti adjustment
   selalu positif. Apakah perlu adjustment negatif juga?

3. **Transfer tanpa transfer_group_id**: Desktop menggunakan single-row transfer.
   Apakah perlu migrasi ke dual-entry ledger di Android?

4. **Backup compatibility**: Format backup JSON desktop apakah perlu bisa
   diimpor langsung ke Android? Perlu konversi FK dan tipe data.

5. **Offline encryption**: Database SQLite belum terenkripsi. Apakah perlu
   SQLCipher untuk M7?
