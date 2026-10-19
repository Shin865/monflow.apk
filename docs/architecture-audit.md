# Architecture Audit — Money Flow Desktop

## Tanggal Audit: 2026-10-12

## 1. Struktur Proyek

```text
money-flow/
├── frontend/          # React 18 + TypeScript + Vite + Tailwind CSS v3
│   └── src/
│       ├── pages/     # 9 page components
│       ├── components/ # Layout.tsx
│       ├── contexts/  # React contexts
│       ├── services/  # api.ts (HTTP client)
│       └── utils/     # Utility functions
├── backend/           # FastAPI + SQLAlchemy 2.0 + SQLite
│   └── app/
│       ├── routes/    # 15 route files
│       ├── models/    # 13 model files
│       ├── schemas/   # 7 schema files (Pydantic)
│       ├── database/  # connection.py, seed.py
│       ├── services/  # __init__.py only (unused)
│       ├── utils/     # __init__.py only (unused)
│       ├── auth.py    # Authentication
│       └── main.py    # FastAPI app entry
├── run.bat
└── README.md
```

## 2. Teknologi Aktual

| Layer    | Teknologi                          |
|----------|------------------------------------|
| Frontend | React 18, TypeScript, Vite         |
| UI       | Tailwind CSS v3                    |
| Backend  | FastAPI (Python)                   |
| Database | SQLite (file: money_flow.db)       |
| ORM      | SQLAlchemy 2.0 (DeclarativeBase)   |
| Validasi | Pydantic v2 (model_dump)           |
| Auth     | Custom auth (user/guest system)    |

## 3. Model Database (13 Tabel)

| Tabel                    | Kolom Utama                                                   |
|--------------------------|---------------------------------------------------------------|
| users                    | id, username, password_hash, display_name, is_guest           |
| accounts                 | id, user_id, name, type(enum), balance(FLOAT!), icon, color   |
| categories               | id, user_id, name, type(enum), parent_id, icon, color         |
| transactions             | id, user_id, type(enum), account_id, category_id, amount(FLOAT!), date |
| transfers                | id, user_id, from_account_id, to_account_id, amount(FLOAT!), date |
| investments              | id, user_id, name, type(enum), initial_cost(FLOAT!), current_value(FLOAT!) |
| investment_transactions  | id, investment_id, type(enum), amount(FLOAT!), units(FLOAT!), price_per_unit(FLOAT!) |
| deposits                 | id, user_id, name, principal(FLOAT!), rate(FLOAT!), tenor_months, tax_rate(FLOAT!) |
| debts                    | id, user_id, name, type(enum), total_amount(FLOAT!), remaining_amount(FLOAT!) |
| debt_payments            | id, debt_id, amount(FLOAT!), date, account_id               |
| bills                    | id, user_id, name, amount(FLOAT!), due_date, frequency(enum) |
| bill_payments            | id, bill_id, amount(FLOAT!), date, account_id               |
| purchase_plans           | id, user_id, name, target_amount(FLOAT!), current_saving(FLOAT!) |
| recurring_transactions   | id, user_id, name, type(enum), amount(FLOAT!), frequency(enum) |
| settings                 | id, user_id, key, value, description                         |

## 4. Temuan Kritis

### ⚠️ Semua Nominal Menggunakan Float

Semua kolom keuangan (`balance`, `amount`, `principal`, `rate`, dsb.) menggunakan `Float` di SQLAlchemy.
Ini bertentangan dengan best practice keuangan (gunakan integer Rupiah).

**Keputusan untuk Flutter:** Menyimpan semua nominal sebagai `INTEGER` (satuan Rupiah) di Drift.
Konversi dilakukan saat import data dari desktop.

### ⚠️ Transfer Bukan Dual-Entry

Transfer menggunakan satu baris di tabel `transfers`, bukan dua entry ledger.
Dari/ke akun diperbarui langsung di route handler.

### ⚠️ Backup/Restore Tanpa Versioning yang Kuat

Backup JSON menggunakan `"version": "1.0"` tapi tidak ada validasi skema yang ketat pada restore.
FK mapping pada restore sederhana (index-based).

## 5. Route API (15 files)

| File              | Endpoint Utama                | Fitur                         |
|-------------------|-------------------------------|-------------------------------|
| accounts.py       | /accounts                     | CRUD akun, summary            |
| transactions.py   | /transactions                 | CRUD + balance update         |
| transfers.py      | /transfers                    | Transfer antarakun            |
| categories.py     | /categories                   | CRUD kategori                 |
| dashboard.py      | /dashboard                    | Net worth, cash flow, overview|
| bills.py          | /bills                        | Tagihan + payments            |
| debts.py          | /debts                        | Utang/piutang + payments      |
| deposits.py       | /deposits                     | Deposito + bunga              |
| investments.py    | /investments                  | Investasi + transaksi         |
| purchase_plans.py | /purchase-plans               | Rencana pembelian             |
| forecast.py       | /forecast                     | Proyeksi 3 skenario           |
| reports.py        | /reports                      | Laporan keuangan              |
| settings.py       | /settings, /backup, /export   | Pengaturan, backup, export    |
| auth_routes.py    | /auth                         | Login, register, guest        |

## 6. Enums yang Ditemukan

```python
AccountType:   cash, bank, ewallet, savings, other
CategoryType:  income, expense
TransactionType: income, expense, refund, adjustment
DebtType:      hutang, piutang
DebtStatus:    active, paid, overdue
BillStatus:    upcoming, due_soon, overdue, paid
BillFrequency: once, monthly, quarterly, yearly
DepositStatus: active, matured, withdrawn
InterestType:  simple, compound
InvestmentType: deposito, saham, reksadana, obligasi, emas, other
InvestmentTxnType: buy, sell, dividend, valuation
PlanPriority:  low, medium, high, urgent
PlanStatus:    active, achieved, cancelled
RecurringType: income, expense
RecurringFrequency: monthly, quarterly, yearly
```
