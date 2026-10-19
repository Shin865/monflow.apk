# Database Mapping — Desktop → Android

## Konversi Tipe Data

| Kolom Desktop (SQLAlchemy) | Tipe Desktop | Tipe Android (Drift) | Alasan |
|---|---|---|---|
| account.balance | Float | INTEGER (Rupiah) | Menghindari floating-point error |
| transaction.amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| transfer.amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| debt.total_amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| debt.remaining_amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| debt.installment_amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| debt.interest_rate | Float | REAL (persen) | Rate bukan nominal uang |
| deposit.principal | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| deposit.rate | Float | REAL (persen) | Rate bukan nominal uang |
| deposit.tax_rate | Float | REAL (persen) | Rate bukan nominal uang |
| bill.amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| investment.initial_cost | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| investment.current_value | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| purchase_plan.target_amount | Float | INTEGER (Rupiah) | Konsistensi keuangan |
| purchase_plan.current_saving | Float | INTEGER (Rupiah) | Konsistensi keuangan |

## Pemetaan Tabel

| Tabel Desktop | Status di Milestone 1-2 | Catatan |
|---|---|---|
| accounts | ✅ Diimplementasi | + uuid, tanpa user_id |
| categories | ✅ Diimplementasi | + uuid, seed data |
| transactions | ✅ Diimplementasi | + uuid, date sebagai DateTime |
| transfers | ✅ Diimplementasi (skema) | Belum UI (Milestone 3) |
| settings | ✅ Diimplementasi | Seed data default |
| users | ❌ Tidak diperlukan | Single-user app di Android |
| investments | 🔲 Milestone 6 | |
| investment_transactions | 🔲 Milestone 6 | |
| deposits | 🔲 Milestone 6 | |
| debts | 🔲 Milestone 5 | |
| debt_payments | 🔲 Milestone 5 | |
| bills | 🔲 Milestone 5 | |
| bill_payments | 🔲 Milestone 5 | |
| purchase_plans | 🔲 Milestone 5 | |
| recurring_transactions | 🔲 Milestone 5 | |

## Perubahan Arsitektur

| Aspek | Desktop | Android |
|---|---|---|
| Multi-user | Ya (user_id FK) | Tidak (single-user) |
| Auth | Username/password + guest | Tidak diperlukan |
| ID | Integer auto-increment | Integer auto-increment + UUID |
| Enum storage | SQLAlchemy Enum (string) | Drift intEnum (integer) |
| Date storage | Date/DateTime | DateTime (ISO via Drift) |
| Balance update | Langsung di route handler | Atomik dalam DB transaction |
| Reactive UI | Polling via API | Stream langsung dari Drift |

## Konversi saat Import Data Desktop

Jika nantinya data desktop diimpor ke Android:
1. Semua nominal Float dikalikan 1 dan dibulatkan ke integer (round)
2. user_id dihilangkan (single-user)
3. Enum string dikonversi ke integer sesuai posisi di Dart enum
4. ID diremap untuk menghindari konflik
5. UUID baru di-generate untuk setiap entitas
