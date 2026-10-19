# Feature Mapping — Desktop → Android

## Pemetaan Halaman React → Layar Flutter

| Halaman Desktop (React) | Layar Android (Flutter) | Milestone | Status |
|---|---|---|---|
| Dashboard.tsx | DashboardScreen | M2 | ✅ Implementasi awal |
| Accounts.tsx | AccountsScreen, CreateAccountScreen | M2 | ✅ CRUD |
| Transactions.tsx | TransactionsScreen, CreateTransactionScreen | M2 | ✅ CRUD + balance |
| BillsAndDebts.tsx | BillsScreen, DebtsScreen | M5 | 🔲 |
| Investments.tsx | InvestmentScreen, DepositScreen | M6 | 🔲 |
| PurchasePlans.tsx | PurchasePlanScreen | M5 | 🔲 |
| Reports.tsx | ReportsScreen | M6 | 🔲 |
| Settings.tsx | SettingsScreen, BackupScreen | M4 | 🔲 |
| LoginPage.tsx | - (tidak diperlukan) | - | ❌ Dihilangkan |

## Pemetaan Fitur per Milestone

### Milestone 2 (Sekarang) ✅
- [x] Buat akun/dompet (nama, tipe, saldo awal, warna)
- [x] Daftar akun dikelompokkan per tipe
- [x] Total saldo semua akun
- [x] Catat pemasukan
- [x] Catat pengeluaran
- [x] Catat refund
- [x] Saldo otomatis diperbarui
- [x] Daftar transaksi dikelompokkan per tanggal
- [x] Filter transaksi berdasarkan tipe
- [x] Hapus transaksi + reverse saldo
- [x] Dashboard: saldo total, daftar akun, transaksi terakhir
- [x] Format Rupiah (Rp 1.500.000)
- [x] Format tanggal Indonesia
- [x] Unit test saldo
- [x] Unit test formatter

### Milestone 3 (Selanjutnya) 🔲
- [ ] Transfer antarakun
- [ ] Edit transaksi (reverse lama, apply baru)
- [ ] Riwayat transfer
- [ ] Hapus transfer + reverse
- [ ] Paginasi daftar transaksi

### Milestone 4 🔲
- [ ] Dashboard: cash flow bulanan (chart)
- [ ] Kategori: CRUD custom
- [ ] Backup database ke JSON
- [ ] Restore dari JSON
- [ ] APK release signing

### Milestone 5 🔲
- [ ] Anggaran bulanan per kategori
- [ ] Tagihan + tagihan berulang
- [ ] Utang (hutang/piutang)
- [ ] Cicilan + pembayaran utang
- [ ] Rencana pembelian
- [ ] Target tabungan

### Milestone 6 🔲
- [ ] Deposito + bunga sederhana/majemuk
- [ ] Pajak deposito
- [ ] Investasi + portofolio
- [ ] Laporan keuangan
- [ ] Forecast 3 skenario
- [ ] Export CSV

## Komponen UI yang Dibuat

| Komponen | File | Deskripsi |
|---|---|---|
| ShellScreen | shell_screen.dart | Bottom navigation bar |
| DashboardScreen | dashboard_screen.dart | Ringkasan keuangan |
| AccountsScreen | accounts_screen.dart | Daftar akun + grouped |
| CreateAccountScreen | create_account_screen.dart | Form buat akun |
| TransactionsScreen | transactions_screen.dart | Daftar transaksi + filter |
| CreateTransactionScreen | create_transaction_screen.dart | Form catat transaksi |
