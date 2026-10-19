import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'database.g.dart';

// ============================================================
// ENUMS
// ============================================================

/// Tipe akun — sesuai desktop: cash, bank, ewallet, savings, other
enum AccountType {
  cash,
  bank,
  ewallet,
  savings,
  other,
}

/// Tipe kategori — sesuai desktop: income, expense
enum CategoryType {
  income,
  expense,
}

/// Tipe transaksi — sesuai desktop: income, expense, refund, adjustment
enum TransactionType {
  income,
  expense,
  refund,
  adjustment,
}

/// Status tagihan — sesuai desktop: upcoming, dueSoon, overdue, paid
enum BillStatus {
  upcoming,
  dueSoon,
  overdue,
  paid,
}

/// Frekuensi tagihan — sesuai desktop: once, monthly, quarterly, yearly
enum BillFrequency {
  once,
  monthly,
  quarterly,
  yearly,
}

/// Tipe hutang / piutang — sesuai desktop: hutang (payable), piutang (receivable)
enum DebtType {
  hutang,
  piutang,
}

/// Status hutang / piutang — sesuai desktop: active, paid, overdue
enum DebtStatus {
  active,
  paid,
  overdue,
}

/// Tipe instrumen investasi — sesuai desktop
enum InvestmentType {
  saham,
  reksadana,
  crypto,
  emas,
  obligasi,
  deposito,
  other,
}

/// Tipe transaksi investasi — sesuai desktop
enum InvestmentTxnType {
  buy,
  sell,
  dividend,
  valuation,
}

/// Tipe perhitungan bunga deposito — sesuai desktop
enum DepositInterestType {
  simple,
  compound,
}

/// Status deposito — sesuai desktop & siklus produk
enum DepositStatus {
  active,
  matured,
  rolledOver,
  withdrawn,
}

/// Status target tabungan (savings goal)
enum SavingsGoalStatus {
  active,
  achieved,
  cancelled,
}

/// Prioritas rencana pembelian — sesuai desktop
enum PlanPriority {
  low,
  medium,
  high,
  urgent,
}

/// Status rencana pembelian — sesuai desktop
enum PlanStatus {
  active,
  achieved,
  cancelled,
}

// ============================================================
// TABLE DEFINITIONS
// ============================================================

/// Tabel akun keuangan.
/// Balance disimpan sebagai INTEGER dalam satuan Rupiah.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<AccountType>()();
  IntColumn get balance => integer().withDefault(const Constant(0))();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel kategori transaksi — mendukung hierarki (parent_id).
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<CategoryType>()();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Tabel transaksi keuangan.
/// Amount disimpan sebagai INTEGER (Rupiah). is_actual untuk memisahkan aktual vs planned.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get type => intEnum<TransactionType>()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActual => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel transfer antar akun. Satu baris = satu transfer (sesuai desktop).
/// Transfer TIDAK mengubah net worth.
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get fromAccountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().references(Accounts, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel pengaturan key-value.
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().withLength(min: 1, max: 100)();
  TextColumn get value => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel anggaran bulanan per kategori.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get year => integer()();
  IntColumn get month => integer()(); // 1 - 12
  IntColumn get amount => integer()(); // Batas anggaran dalam Rupiah
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, year, month},
      ];
}

/// Tabel tagihan (bills) — mencakup sekali bayar & tagihan berulang.
class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get amount => integer()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get dueDay => integer().nullable()(); // 1 - 31 untuk rutin
  IntColumn get frequency =>
      intEnum<BillFrequency>().withDefault(const Constant(0))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get description => text().nullable()();
  IntColumn get status =>
      intEnum<BillStatus>().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get recurringKey => text().nullable()(); // Kunci periodik unik
  IntColumn get parentBillId => integer().nullable().references(Bills, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel riwayat pembayaran tagihan.
class BillPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get billId => integer().references(Bills, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel hutang & piutang.
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get type => intEnum<DebtType>()();
  IntColumn get totalAmount => integer()(); // Pokok awal
  IntColumn get remainingAmount => integer()(); // Sisa pokok
  TextColumn get person => text().nullable()(); // Orang / lembaga
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get tenorMonths => integer().nullable()();
  IntColumn get installmentAmount =>
      integer().nullable()(); // Cicilan per bulan
  IntColumn get installmentDay =>
      integer().nullable()(); // Tanggal jatuh tempo cicilan (1-31)
  RealColumn get interestRate => real().withDefault(const Constant(0.0))();
  IntColumn get status =>
      intEnum<DebtStatus>().withDefault(const Constant(0))();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel pembayaran / penerimaan cicilan hutang-piutang.
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get debtId => integer().references(Debts, #id)();
  IntColumn get amount => integer()(); // Total nominal transaksi
  IntColumn get principalAmount =>
      integer().withDefault(const Constant(0))(); // Pelunasan pokok
  IntColumn get interestAmount =>
      integer().withDefault(const Constant(0))(); // Bunga
  IntColumn get feeAmount =>
      integer().withDefault(const Constant(0))(); // Biaya / denda
  DateTimeColumn get date => dateTime()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel portofolio investasi — sesuai desktop & Milestone 5.
class Investments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get type => intEnum<InvestmentType>()();
  TextColumn get platform => text().nullable()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get initialCost =>
      integer().withDefault(const Constant(0))(); // Modal (Rupiah)
  IntColumn get currentValue => integer()
      .withDefault(const Constant(0))(); // Nilai pasar terkini (Rupiah)
  RealColumn get units => real().nullable()(); // Jumlah unit / lot / gram
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel histori mutasi & penilaian investasi.
class InvestmentTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get investmentId => integer().references(Investments, #id)();
  IntColumn get type => intEnum<InvestmentTxnType>()();
  IntColumn get amount => integer()(); // Nominal transaksi (Rupiah)
  RealColumn get units => real().nullable()();
  RealColumn get pricePerUnit => real().nullable()();
  IntColumn get fee =>
      integer().withDefault(const Constant(0))(); // Biaya transaksi (Rupiah)
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel deposito berjangka — suku bunga integer bps & aturan pajak/biaya.
class Deposits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get bankName => text().nullable()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get principal => integer()(); // Pokok deposito (Rupiah)
  IntColumn get annualRateBps =>
      integer()(); // Basis poin: misal 6.25% = 625 bps
  IntColumn get tenorMonths => integer()(); // Tenor dalam bulan
  IntColumn get interestType => intEnum<DepositInterestType>()
      .withDefault(const Constant(0))(); // 0 = simple, 1 = compound
  IntColumn get compoundFrequency => integer()
      .withDefault(const Constant(12))(); // 12=bulanan, 4=kuartalan, 1=tahunan
  IntColumn get taxRateBps => integer().withDefault(
      const Constant(2000))(); // Basis poin pajak: default 20% = 2000 bps
  IntColumn get feeAmount =>
      integer().withDefault(const Constant(0))(); // Biaya administrasi/lainnya
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get maturityDate => dateTime()();
  IntColumn get status =>
      intEnum<DepositStatus>().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel target tabungan (Savings Goals).
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get targetAmount => integer()(); // Target nominal (Rupiah)
  IntColumn get currentAmount =>
      integer().withDefault(const Constant(0))(); // Dana terkumpul
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get targetAccountId =>
      integer().nullable().references(Accounts, #id)();
  BoolColumn get isVirtual => boolean().withDefault(
      const Constant(true))(); // Virtual allocation vs real account
  TextColumn get notes => text().nullable()();
  IntColumn get status =>
      intEnum<SavingsGoalStatus>().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tabel rencana pembelian (Purchase Planning) — sesuai model desktop.
class PurchasePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get targetAmount => integer()(); // Target nominal (Rupiah)
  IntColumn get allocatedAmount => integer()
      .withDefault(const Constant(0))(); // Dana yang sudah dialokasikan
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get priority => intEnum<PlanPriority>()
      .withDefault(const Constant(1))(); // default 1 = medium
  IntColumn get status => intEnum<PlanStatus>()
      .withDefault(const Constant(0))(); // default 0 = active
  TextColumn get category => text().nullable()(); // Kategori barang
  TextColumn get urlLink => text().nullable()(); // Link produk
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================
// DATABASE
// ============================================================

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  Transfers,
  Settings,
  Budgets,
  Bills,
  BillPayments,
  Debts,
  DebtPayments,
  Investments,
  InvestmentTransactions,
  Deposits,
  SavingsGoals,
  PurchasePlans,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing — accepts any QueryExecutor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
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
        },
      );

  // ============================================================
  // SEED DATA
  // ============================================================

  /// Seed default categories jika belum ada.
  Future<void> seedDefaultCategories() async {
    final count = await (select(categories)..limit(1)).get();
    if (count.isNotEmpty) return;

    const uuid = Uuid();

    final incomeCategories = [
      {'name': 'Gaji', 'icon': '💼', 'color': '#10B981'},
      {'name': 'Freelance', 'icon': '💻', 'color': '#3B82F6'},
      {'name': 'Bonus', 'icon': '🎁', 'color': '#F59E0B'},
      {'name': 'Bunga', 'icon': '🏦', 'color': '#6366F1'},
      {'name': 'Dividen', 'icon': '📈', 'color': '#8B5CF6'},
      {'name': 'Penjualan', 'icon': '🏷️', 'color': '#EC4899'},
      {'name': 'Lainnya', 'icon': '📥', 'color': '#6B7280'},
    ];

    final expenseCategories = [
      {'name': 'Makanan', 'icon': '🍔', 'color': '#EF4444'},
      {'name': 'Transportasi', 'icon': '🚗', 'color': '#F97316'},
      {'name': 'Perumahan', 'icon': '🏠', 'color': '#8B5CF6'},
      {'name': 'Tagihan', 'icon': '📄', 'color': '#EC4899'},
      {'name': 'Belanja', 'icon': '🛍️', 'color': '#F59E0B'},
      {'name': 'Hiburan', 'icon': '🎬', 'color': '#3B82F6'},
      {'name': 'Pendidikan', 'icon': '📚', 'color': '#10B981'},
      {'name': 'Kesehatan', 'icon': '🏥', 'color': '#EF4444'},
      {'name': 'Investasi', 'icon': '📊', 'color': '#6366F1'},
      {'name': 'Lainnya', 'icon': '📤', 'color': '#6B7280'},
    ];

    await batch((batch) {
      for (final cat in incomeCategories) {
        batch.insert(
            categories,
            CategoriesCompanion.insert(
              uuid: Value(uuid.v4()),
              name: cat['name']!,
              type: CategoryType.income,
              icon: Value(cat['icon']),
              color: Value(cat['color']),
              isDefault: const Value(true),
            ));
      }
      for (final cat in expenseCategories) {
        batch.insert(
            categories,
            CategoriesCompanion.insert(
              uuid: Value(uuid.v4()),
              name: cat['name']!,
              type: CategoryType.expense,
              icon: Value(cat['icon']),
              color: Value(cat['color']),
              isDefault: const Value(true),
            ));
      }
    });
  }

  /// Seed default settings jika belum ada.
  Future<void> seedDefaultSettings() async {
    final count = await (select(settings)..limit(1)).get();
    if (count.isNotEmpty) return;

    final defaultSettings = [
      {'key': 'currency', 'value': 'IDR', 'description': 'Mata uang default'},
      {
        'key': 'currency_symbol',
        'value': 'Rp',
        'description': 'Simbol mata uang'
      },
      {
        'key': 'tax_rate_deposit',
        'value': '20',
        'description': 'Pajak bunga deposito (%)'
      },
      {
        'key': 'date_format',
        'value': 'DD-MM-YYYY',
        'description': 'Format tanggal'
      },
      {
        'key': 'app_name',
        'value': 'Money Flow',
        'description': 'Nama aplikasi'
      },
    ];

    await batch((batch) {
      for (final s in defaultSettings) {
        batch.insert(
            settings,
            SettingsCompanion.insert(
              key: s['key']!,
              value: Value(s['value']),
              description: Value(s['description']),
            ));
      }
    });
  }
}

/// Provider for AppDatabase — overridden in main.dart.
final databaseProvider = Provider<AppDatabase>((ref) {
  // Di produksi, di-override dengan database SQLite dokumen di main.dart.
  // Fallback in-memory database untuk testing / widget preview tanpa override.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  ref.onDispose(() => db.close());
  return db;
});

/// Opens the SQLite connection.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'money_flow.db'));
    return NativeDatabase.createInBackground(file);
  });
}
