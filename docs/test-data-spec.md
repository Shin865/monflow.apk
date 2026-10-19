# Test Data Spec — Money Flow

## Tujuan

Menyediakan dataset sintetis yang bisa dibandingkan antara
hasil perhitungan backend Python dan aplikasi Flutter/Dart.

## Cara Menjalankan

### Python (expected values)
```bash
cd docs/
set PYTHONIOENCODING=utf-8
python test_data_spec.py
```

### Dart (actual values)
```bash
cd mobile/
flutter test test/domain/balance_rules_test.dart
flutter test test/data/database_test.dart
```

## Dataset

### 1. Saldo Akun — Income, Expense, Refund

| Langkah | Operasi | Amount | Expected Saldo |
|---|---|---|---|
| Awal | - | - | 1,000,000 |
| 1 | Income (Gaji) | 5,000,000 | 6,000,000 |
| 2 | Expense (Makan) | 150,000 | 5,850,000 |
| 3 | Expense (Transport) | 75,000 | 5,775,000 |
| 4 | Refund (Belanja) | 50,000 | 5,825,000 |

### 2. Net Flow Bulanan

```
net_flow = income + refund - expense
net_flow = 8,500,000 + 150,000 - 3,200,000 = 5,450,000
```

### 3. Transfer Netral

| Akun | Sebelum | Transfer | Sesudah |
|---|---|---|---|
| BCA | 10,000,000 | -1,000,000 | 9,000,000 |
| GoPay | 2,000,000 | +1,000,000 | 3,000,000 |
| Cash | 500,000 | 0 | 500,000 |
| **Total** | **12,500,000** | **0** | **12,500,000** |

### 4. Bunga Deposito Simple

```
Principal:     100,000,000
Rate:          4% per tahun
Tenor:         12 bulan
Gross Interest: 100,000,000 × 0.04 × 1 = 4,000,000
Tax (20%):     4,000,000 × 0.20 = 800,000
Net Interest:  4,000,000 - 800,000 = 3,200,000
Maturity:      100,000,000 + 3,200,000 = 103,200,000
```

### 5. Bunga Deposito Compound (Bulanan)

```
Principal:     100,000,000
Rate:          4% per tahun
Tenor:         12 bulan
Compound freq: 12 (bulanan)
Gross:         100,000,000 × ((1 + 0.04/12)^12 - 1) = 4,074,154.29
Tax (20%):     4,074,154.29 × 0.20 = 814,830.86
Net:           4,074,154.29 - 814,830.86 = 3,259,323.43
Maturity:      100,000,000 + 3,259,323.43 = 103,259,323.43
```

### 6. Rencana Pembelian Progress

```
Target:        15,000,000
Current:       6,000,000
Remaining:     9,000,000
Progress:      40.0%
```

### 7. Forecast Skenario

```
Base: avg_income=8,000,000  avg_expense=5,000,000  monthly_purchase=500,000

Conservative: income × 0.9 = 7,200,000  expense × 1.1 = 5,500,000  net = 1,200,000
Normal:       income × 1.0 = 8,000,000  expense × 1.0 = 5,000,000  net = 2,500,000
Optimistic:   income × 1.1 = 8,800,000  expense × 0.9 = 4,500,000  net = 3,800,000
```

### 8. Reverse Transaction

```
Balance:   10,000,000
Expense:   -500,000  → 9,500,000
Reverse:   +500,000  → 10,000,000 (kembali ke semula)
```

## Status Verifikasi

| Dataset | Python | Dart Unit Test | Dart DB Test |
|---|---|---|---|
| 1. Saldo Akun | ✅ PASS | ✅ PASS | ✅ PASS |
| 2. Net Flow | ✅ PASS | ✅ PASS | - |
| 3. Transfer | ✅ PASS | ✅ PASS | ✅ PASS |
| 4. Deposito Simple | ✅ PASS | 🔲 M6 | 🔲 M6 |
| 5. Deposito Compound | ✅ PASS | 🔲 M6 | 🔲 M6 |
| 6. Purchase Plan | ✅ PASS | 🔲 M5 | 🔲 M5 |
| 7. Forecast | ✅ PASS | 🔲 M6 | 🔲 M6 |
| 8. Reverse Txn | ✅ PASS | ✅ PASS | ✅ PASS |
