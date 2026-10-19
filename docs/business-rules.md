# Business Rules — Money Flow

Diekstrak dari kode backend aktual pada 2026-10-12.

## 1. Aturan Saldo Akun

Sumber: `backend/app/routes/transactions.py` → `_apply_balance_change()`

```python
if txn_type == INCOME:     balance += amount
if txn_type == EXPENSE:    balance -= amount
if txn_type == REFUND:     balance += amount    # Refund mengembalikan uang
if txn_type == ADJUSTMENT: balance += amount    # Adjustment bisa +/-
```

- Saat CREATE transaksi: balance diperbarui sesuai tipe
- Saat UPDATE transaksi: balance lama di-reverse, balance baru diterapkan
- Saat DELETE transaksi: balance di-reverse

## 2. Aturan Transfer

Sumber: `backend/app/routes/transfers.py`

- `from_account.balance -= amount`
- `to_account.balance += amount`
- Transfer TIDAK mengubah net worth (total aset tetap sama)
- from_account_id ≠ to_account_id (validasi)
- amount > 0 (validasi)
- Hapus transfer: balance di-reverse

## 3. Net Worth

Sumber: `backend/app/routes/dashboard.py`

```python
total_assets = total_balance + total_investment_value + total_deposit + total_piutang
total_liabilities = total_hutang
net_worth = total_assets - total_liabilities
```

Komponen:
- `total_balance`: Sum balance dari semua akun aktif
- `total_investment_value`: Sum current_value dari investasi aktif
- `total_deposit`: Sum principal dari deposito aktif
- `total_piutang`: Sum remaining_amount dari piutang aktif
- `total_hutang`: Sum remaining_amount dari hutang aktif

## 4. Cash Flow Bulanan

Sumber: `backend/app/routes/dashboard.py`, `transactions.py`

```python
net_flow = income + refund - expense
```

- Income: sum amount WHERE type=income AND bulan/tahun cocok
- Expense: sum amount WHERE type=expense AND bulan/tahun cocok
- Refund: sum amount WHERE type=refund AND bulan/tahun cocok

## 5. Bunga Deposito

Sumber: `backend/app/models/deposit.py`

### Simple Interest
```python
gross_interest = principal * (rate/100) * (tenor_months/12)
```

### Compound Interest
```python
n = compound_frequency  # per tahun (12=bulanan, 4=kuartalan)
t = tenor_months / 12
gross_interest = principal * ((1 + (rate/100)/n) ** (n*t)) - principal
```

### Pajak dan Neto
```python
tax_amount = gross_interest * (tax_rate / 100)
net_interest = gross_interest - tax_amount
maturity_amount = principal + net_interest
```

- Default tax_rate: 20% (dari seed data settings)
- Default compound_frequency: 12 (bulanan)

## 6. Rencana Pembelian

Sumber: `backend/app/models/purchase_plan.py`

```python
remaining = max(0, target_amount - current_saving)
progress = min(100, (current_saving / target_amount) * 100) if target_amount > 0 else 0

# Monthly required
months_left = (target_year - today_year) * 12 + (target_month - today_month)
monthly_required = remaining / months_left if months_left > 0 else remaining
```

## 7. Forecast (Proyeksi)

Sumber: `backend/app/routes/forecast.py`

### Rata-rata Historis
- Ambil income dan expense 3 bulan terakhir (sebelum bulan berjalan)
- Bagi dengan jumlah bulan

### Skenario
| Skenario     | Pengali Income | Pengali Expense |
|--------------|---------------|----------------|
| Conservative | 0.9           | 1.1            |
| Normal       | 1.0           | 1.0            |
| Optimistic   | 1.1           | 0.9            |

### Proyeksi per Bulan
```python
net_flow = scenario_income - scenario_expense - monthly_purchase_savings
running_balance += net_flow
projected_balance = max(0, round(running_balance, 0))
```

## 8. Akun

- Tipe: cash, bank, ewallet, savings, other
- Hapus akun dengan transaksi → soft delete (is_active=False)
- Hapus akun tanpa transaksi → hard delete
- Saldo awal diset saat create (field `balance` di AccountCreate)

## 9. Kategori

- Tipe: income, expense
- Kategori default di-seed saat user dibuat
- Default categories tidak bisa dihapus (soft delete: is_active=False)
- Custom categories bisa hard delete
- Mendukung parent_id (hierarki)

## 10. Kategori Default (Seed Data)

### Income
Gaji 💼, Freelance 💻, Bonus 🎁, Bunga 🏦, Dividen 📈, Penjualan 🏷️, Lainnya 📥

### Expense
Makanan 🍔, Transportasi 🚗, Perumahan 🏠, Tagihan 📄, Belanja 🛍️,
Hiburan 🎬, Pendidikan 📚, Kesehatan 🏥, Investasi 📊, Lainnya 📤

## 11. Settings Default

| Key              | Value    | Deskripsi              |
|------------------|----------|------------------------|
| currency         | IDR      | Mata uang default      |
| currency_symbol  | Rp       | Simbol mata uang       |
| tax_rate_deposit | 20       | Pajak bunga deposito % |
| date_format      | DD-MM-YYYY| Format tanggal        |
| app_name         | Money Flow| Nama aplikasi         |

## 12. Backup Format

```json
{
  "version": "1.0",
  "exported_at": "ISO-8601",
  "user": { "username", "display_name", "is_guest" },
  "categories": [...],
  "accounts": [...],
  "transactions": [...],
  "transfers": [...],
  "investments": [...],
  "deposits": [...],
  "debts": [...],
  "bills": [...],
  "purchase_plans": [...],
  "settings": [...]
}
```

## 13. Temuan & Risiko

1. **Float untuk uang**: Semua nominal disimpan sebagai Float. Di Flutter akan dikonversi ke int (Rupiah).
2. **Tidak ada transfer_group_id**: Transfer menggunakan single-row, bukan dual-entry ledger.
3. **Balance dihitung secara imperatif**: Balance diperbarui langsung saat transaksi (bukan dihitung dari history).
4. **Restore tanpa FK remapping yang lengkap**: Hanya categories dan accounts yang di-remap ID-nya.
5. **Adjustment amount bisa negatif**: Kode menambahkan amount langsung, tapi schema memvalidasi `gt=0`.
   Ini inkonsisten — adjustment positif selalu menambah saldo.
