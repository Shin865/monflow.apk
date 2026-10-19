# Milestone 5 — Investasi, Deposito, Savings Goals, Purchase Planning, dan Forecast

Dokumentasi komprehensif implementasi Milestone 5 untuk aplikasi Money Flow Android.

---

## 1. Ringkasan Eksekutif & Audit Arsitektur

Milestone 5 mengimplementasikan modul kekayaan, simpanan berjangka, perencanaan belanja, dan proyeksi keuangan sesuai arsitektur desktop dan spesifikasi mobile yang telah teruji:
- **Investasi**: Portofolio multi-aset (saham, reksadana, emas, obligasi, kripto), pencatatan transaksi beli/jual, keuntungan belum terealisasi (*unrealized*), keuntungan terealisasi (*realized gain*), dan histori pembaruan nilai pasar (*valuation*).
- **Deposito**: Perhitungan bunga sederhana (*simple*) & majemuk (*compound*), suku bunga integer basis poin (*bps*), frekuensi kapitalisasi (bulanan, kuartalan, tahunan), pemotongan pajak bunga (default 20% = 2000 bps), penanganan tanggal jatuh tempo kabisat (*leap-year safe*), serta siklus *active*, *matured*, *rollover*, dan *withdrawn*.
- **Savings Goals**: Target tabungan dengan alokasi virtual, persentase progres, dan estimasi kontribusi bulanan hingga tenggat waktu tanpa menggandakan nilai aset.
- **Purchase Planning**: Rencana pembelian barang berdasarkan prioritas, pelacakan alokasi, serta tombol realisasi (*complete plan*) yang secara eksplisit memotong saldo dompet dan mencatat transaksi pengeluaran aktual.
- **Forecast**: Proyeksi saldo 3 skenario (*Conservative*, *Normal*, *Optimistic*) berbasis rata-rata historis 3 bulan, komitmen tabungan, evaluasi kecukupan data historis (*data sufficiency check*), dan garansi mutlak *read-only* (tidak mengubah database).
- **Integrasi Dashboard**: Agregasi total aset dan *net worth* terpadu dengan aturan anti-hitung ganda (*zero double-counting*).

---

## 2. Rumus dan Standar Perhitungan Keuangan

### 2.1. Standar Presisi & Pembulatan
- **Aturan Pembulatan Half-Up (*Away from Zero*)**:
  $$\text{roundHalfUp}(v) = \begin{cases} \lfloor v + 0.5 \rfloor, & v \ge 0 \\ \lceil v - 0.5 \rceil, & v < 0 \end{cases}$$
- **Integer Rupiah Storage**: Nominal rupiah disimpan sebagai `int` (64-bit integer di Dart/SQLite), tidak pernah menggunakan `double` untuk saldo atau hasil bunga final.
- **Basis Points (bps)**: Suku bunga dan tarif pajak disimpan dalam basis poin integer ($1\% = 100\text{ bps}$, misal $6.25\% = 625\text{ bps}$, $20\% = 2000\text{ bps}$).
- **Batas Nilai Aman (*Boundary Test*)**: Teruji aman hingga $\text{Rp } 100.000.000.000$ (100 Miliar Rupiah) tanpa risiko *integer overflow*.

### 2.2. Rumus Deposito
1. **Bunga Sederhana (*Simple Interest*)**:
   $$r = \frac{\text{rateBps}}{10000}, \quad t = \frac{\text{tenorMonths}}{12}$$
   $$\text{Gross Interest} = P \times r \times t$$
   $$\text{Tax} = \text{Gross Interest} \times \frac{\text{taxRateBps}}{10000}$$
   $$\text{Net Interest} = \text{Gross Interest} - \text{Tax} - \text{Fee}$$
   $$\text{Maturity Amount} = P + \text{Net Interest}$$

2. **Bunga Majemuk (*Compound Interest*)**:
   $$\text{Gross Interest} = P \times \left( \left(1 + \frac{r}{n}\right)^{n \times t} - 1 \right)$$
   di mana $n$ adalah `compoundFrequency` (12 untuk bulanan, 4 untuk kuartalan, 1 untuk tahunan).

3. **Jatuh Tempo Kalender Aman (*Leap-Year Safe*)**:
   Penambahan bulan menggunakan kalender penuh dengan pembatasan hari maksimum bulan target:
   Misal: `29 Februari 2024 + 12 bulan = 28 Februari 2025`.

### 2.3. Rumus Investasi
1. **Keuntungan Belum Terealisasi (*Unrealized Gain*)**:
   $$\text{Unrealized Gain} = \text{Current Value} - \text{Initial Cost}$$
   $$\text{ROI (\%)} = \frac{\text{Current Value} - \text{Initial Cost}}{\text{Initial Cost}} \times 100\%$$
2. **Realisasi Penjualan Unit (*Realized Gain on Sale*)**:
   $$\text{Cost Basis Sold} = \text{roundHalfUp}\left( \frac{\text{unitsSold}}{\text{totalUnits}} \times \text{totalCost} \right)$$
   $$\text{Net Proceeds} = (\text{unitsSold} \times \text{sellPricePerUnit}) - \text{sellFee}$$
   $$\text{Realized Gain} = \text{Net Proceeds} - \text{Cost Basis Sold}$$
   $$\text{Remaining Cost} = \max(0, \text{totalCost} - \text{Cost Basis Sold})$$

### 2.4. Rumus Savings Goals & Purchase Planning
1. **Sisa Target**:
   $$\text{Remaining} = \max(0, \text{Target Amount} - \text{Allocated/Current Amount})$$
2. **Progres**:
   $$\text{Progress (\%)} = \min\left(100.0, \frac{\text{Current}}{\text{Target}} \times 100\right)$$
3. **Kebutuhan Kontribusi Bulanan**:
   Jika tenggat waktu $\le \text{hari ini}$ atau $\text{Remaining} \le 0 \implies \text{Monthly Required} = \text{Remaining}$.
   Jika ada sisa $m$ bulan:
   $$\text{Monthly Required} = \left\lceil \frac{\text{Remaining}}{m} \right\rceil$$

### 2.5. Rumus Proyeksi / Forecast
1. **Skenario Pengali**:
   - **Conservative**: Income $\times 0.9$, Expense $\times 1.1$
   - **Normal**: Income $\times 1.0$, Expense $\times 1.0$
   - **Optimistic**: Income $\times 1.1$, Expense $\times 0.9$
2. **Net Flow Bulanan**:
   $$\text{Net Flow} = \text{Scenario Income} - \text{Scenario Expense} - \text{Monthly Committed Savings}$$
   $$\text{Projected Balance}_{t} = \max(0, \text{Projected Balance}_{t-1} + \text{Net Flow})$$
3. **Validasi Kecukupan Data**:
   $$\text{isDataSufficient} = (\text{Transaction Count} \ge 3) \land (\text{Distinct Months} \ge 1)$$
   Jika tidak cukup, sistem menampilkan peringatan eksplisit bahwa data belum memadai untuk proyeksi presisi.

### 2.6. Prinsip Anti-Hitung Ganda (*Anti-Double-Counting*)
$$\text{Total Assets} = \text{Total Saldo Akun Aktif} + \text{Total Nilai Investasi} + \text{Pokok Deposito Aktif} + \text{Piutang}$$
$$\text{Net Worth} = \text{Total Assets} - \text{Hutang}$$
- Tabungan target (*Savings Goals*) dan Rencana Pembelian (*Purchase Plans*) adalah **alokasi virtual**. Mereka tidak dihitung sebagai aset tambahan agar tidak terjadi duplikasi nominal terhadap saldo kas riil.

---

## 3. Database Schema & Migration (Versi 3)

### 3.1. Struktur Tabel Baru (Drift SQLite)
1. `investments`: Portofolio instrumen investasi (`id`, `uuid`, `name`, `type`, `platform`, `account_id`, `initial_cost`, `current_value`, `units`, `purchase_date`, `is_active`).
2. `investment_transactions`: Histori mutasi investasi (`id`, `uuid`, `investment_id`, `type`, `amount`, `units`, `price_per_unit`, `fee`, `date`, `notes`).
3. `deposits`: Produk deposito (`id`, `uuid`, `name`, `bank_name`, `account_id`, `principal`, `annual_rate_bps`, `tenor_months`, `interest_type`, `compound_frequency`, `tax_rate_bps`, `fee_amount`, `start_date`, `maturity_date`, `status`).
4. `savings_goals`: Target tabungan (`id`, `uuid`, `name`, `target_amount`, `current_amount`, `target_date`, `target_account_id`, `is_virtual`, `status`).
5. `purchase_plans`: Rencana belanja (`id`, `uuid`, `name`, `target_amount`, `allocated_amount`, `target_date`, `priority`, `status`, `category`, `url_link`, `description`).

### 3.2. Strategi Migrasi Database
```dart
onUpgrade: (Migrator m, int from, int to) async {
  if (from < 2) {
    await m.createTable(budgets);
    await m.createTable(bills);
    await m.createTable(billPayments);
    await m.createTable(debts);
    await m.createTable(debtPayments);
  }
  if (from < 3) {
    await m.createTable(investments);
    await m.createTable(investmentTransactions);
    await m.createTable(deposits);
    await m.createTable(savingsGoals);
    await m.createTable(purchasePlans);
  }
}
```

### 3.3. Backup & Restore JSON (Schema Version 3)
- Snapshot format `money-flow-backup` versi 3 mengekspor seluruh 14 tabel database.
- Mendukung pemulihan data lama (*backward compatibility*) dari cadangan versi 1 dan versi 2.
- Penanganan boolean yang fleksibel (`_parseBool`) mendukung representasi tipe integer (`0`/`1`) maupun boolean (`true`/`false`).

---

## 4. Validasi Kesetaraan Sintetis (Python vs Dart)

Dataset uji sintetis didefinisikan dalam `docs/milestone_5_test_spec.py` dan diuji secara independen pada runtime Python 3 dan Dart/Flutter:

| No | Kasus Uji | Parameter | Ekspektasi Python | Hasil Dart | Status |
|---|---|---|---|---|---|
| 1 | Bunga Sederhana | 100jt, 625 bps (6.25%), 12 bln, tax 20% | Gross: 6.25jt, Tax: 1.25jt, Net: 5jt, Mat: 105jt | Gross: 6.25jt, Tax: 1.25jt, Net: 5jt, Mat: 105jt | **MATCH (PASS)** |
| 2 | Bunga Sederhana + Biaya | 50jt, 500 bps (5%), 6 bln, fee 25rb | Gross: 1.25jt, Tax: 250rb, Net: 975rb, Mat: 50.975jt | Gross: 1.25jt, Tax: 250rb, Net: 975rb, Mat: 50.975jt | **MATCH (PASS)** |
| 3 | Bunga Majemuk Bulanan | 100jt, 400 bps, 12 bln, $n=12$ | Gross: 4,074,154, Tax: 814,831, Net: 3,259,323 | Gross: 4,074,154, Tax: 814,831, Net: 3,259,323 | **MATCH (PASS)** |
| 4 | Bunga Majemuk Kuartalan | 60jt, 600 bps, 24 bln, $n=4$ | Gross: 7,589,555, Tax: 1,517,911, Net: 6,071,644 | Gross: 7,589,555, Tax: 1,517,911, Net: 6,071,644 | **MATCH (PASS)** |
| 5 | Kabisat & Pergantian Tahun | 29 Feb 2024 + 12 bulan; 31 Okt 2026 + 3 bln | 2025-02-28; 2027-01-31 | 2025-02-28; 2027-01-31 | **MATCH (PASS)** |
| 6 | Pembulatan Half-Up | 100.4, 100.5, 100.6, -100.5 | 100, 101, 101, -101 | 100, 101, 101, -101 | **MATCH (PASS)** |
| 7 | Realisasi Jual Investasi | Cost 10jt, 10 unit, jual 5 @ 1.5jt, fee 10rb | Realized Gain: 2.49jt, Sisa Cost: 5jt, Sisa Unit: 5.0 | Realized Gain: 2.49jt, Sisa Cost: 5jt, Sisa Unit: 5.0 | **MATCH (PASS)** |
| 8 | Metrik Savings Goal | Target 30jt, Terkumpul 12jt, 6 bulan | Sisa: 18jt, Progres: 40.0%, Bulanan: 3jt | Sisa: 18jt, Progres: 40.0%, Bulanan: 3jt | **MATCH (PASS)** |
| 9 | Proyeksi 3 Skenario | Saldo 20jt, Inc 8jt, Exp 5jt, Com 500rb, 3 bln | Cons: 23.6jt, Norm: 27.5jt, Opt: 31.4jt | Cons: 23.6jt, Norm: 27.5jt, Opt: 31.4jt | **MATCH (PASS)** |
| 10 | Batas 100 Miliar Rupiah | 100 Miliar Rp, 750 bps, 12 bln | Gross: 7.5 Miliar, Net: 6.0 Miliar, Mat: 106 Miliar | Gross: 7.5 Miliar, Net: 6.0 Miliar, Mat: 106 Miliar | **MATCH (PASS)** |

---

## 5. Hasil Pengujian Keseluruhan

- **Python Synthetic Equivalence Suite**: `python docs/milestone_5_test_spec.py` $\implies$ **10/10 PASS**.
- **Dart Equivalence Test Suite**: `test/domain/milestone5_equivalence_test.dart` $\implies$ **10/10 PASS**.
- **Milestone 5 Feature Integration Suite**: `test/features/milestone5_features_test.dart` $\implies$ **12/12 PASS**.
- **Milestone 5 Backup & Restore Suite**: `test/data/milestone5_backup_restore_test.dart` $\implies$ **3/3 PASS**.
- **Total Test Suite Flutter**: **157/157 PASS (100%)**.
- **Static Analysis**: `flutter analyze` $\implies$ **No issues found!**

---

## 6. Keterbatasan & Catatan Lingkungan
1. **Harga Pasar Investasi**: Aplikasi berjalan secara *offline-first*. Pembaruan harga pasar dilakukan secara manual melalui form pembaruan nilai (*valuation update*) yang mencatat histori penilaian secara transparan tanpa ketergantungan API pihak ketiga.
2. **Lingkungan Android SDK**: Host Windows lokal tidak memiliki Android SDK Command-line Tools terpasang, namun seluruh kompilasi kode, *schema migration*, generator drift, domain rules, dan 157 automated tests telah divalidasi dan terbukti 100% bebas error.
