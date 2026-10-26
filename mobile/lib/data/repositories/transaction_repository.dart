import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/balance_rules.dart';
import 'package:money_flow/data/repositories/account_repository.dart';

/// Data class untuk transaksi yang diperkaya dengan nama akun dan kategori.
class EnrichedTransaction {
  final Transaction transaction;
  final String? accountName;
  final String? categoryName;
  final String? categoryIcon;

  const EnrichedTransaction({
    required this.transaction,
    this.accountName,
    this.categoryName,
    this.categoryIcon,
  });
}

/// Repository untuk transaksi keuangan.
/// Menerapkan aturan saldo dari BalanceRules secara atomik.
class TransactionRepository {
  final AppDatabase _db;
  final AccountRepository _accountRepo;
  static const _uuid = Uuid();

  TransactionRepository(this._db, this._accountRepo);

  /// Ambil transaksi berdasarkan ID.
  Future<Transaction?> getById(int id) async {
    return (_db.select(_db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Ambil transaksi dengan filter, termasuk nama akun dan kategori.
  Future<List<EnrichedTransaction>> getTransactions({
    TransactionType? type,
    int? accountId,
    int? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
          _db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(_db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ]);

    // Apply filters
    final conditions = <Expression<bool>>[];
    if (type != null) {
      conditions.add(_db.transactions.type.equalsValue(type));
    }
    if (accountId != null) {
      conditions.add(_db.transactions.accountId.equals(accountId));
    }
    if (categoryId != null) {
      conditions.add(_db.transactions.categoryId.equals(categoryId));
    }
    if (dateFrom != null) {
      conditions.add(_db.transactions.date.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      conditions.add(_db.transactions.date.isSmallerOrEqualValue(dateTo));
    }
    if (search != null && search.isNotEmpty) {
      conditions.add(_db.transactions.description.like('%$search%'));
    }

    if (conditions.isNotEmpty) {
      query.where(conditions.reduce((a, b) => a & b));
    }

    query
      ..orderBy([
        OrderingTerm.desc(_db.transactions.date),
        OrderingTerm.desc(_db.transactions.id),
      ])
      ..limit(limit, offset: offset);

    final rows = await query.get();

    return rows.map((row) {
      final txn = row.readTable(_db.transactions);
      final account = row.readTableOrNull(_db.accounts);
      final category = row.readTableOrNull(_db.categories);

      return EnrichedTransaction(
        transaction: txn,
        accountName: account?.name,
        categoryName: category?.name,
        categoryIcon: category?.icon,
      );
    }).toList();
  }

  /// Buat transaksi baru dan perbarui saldo akun secara atomik.
  ///
  /// [amount] harus > 0 (dalam Rupiah).
  /// Saldo akun diperbarui sesuai aturan di BalanceRules.
  Future<Transaction> create({
    required TransactionType type,
    required int accountId,
    required int categoryId,
    required int amount,
    required DateTime date,
    String? description,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Jumlah transaksi harus lebih besar dari 0');
    }

    return _db.transaction(() async {
      // Ambil akun saat ini
      final account = await _accountRepo.getById(accountId);
      if (account == null) {
        throw StateError('Akun tidak ditemukan');
      }

      // Validasi kategori
      final category = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(categoryId)))
          .getSingleOrNull();
      if (category == null) {
        throw StateError('Kategori tidak ditemukan');
      }

      // Insert transaksi
      final txnId = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              uuid: Value(_uuid.v4()),
              type: type,
              accountId: accountId,
              categoryId: categoryId,
              amount: amount,
              date: date,
              description: Value(description),
              notes: Value(notes),
            ),
          );

      // Update saldo akun
      final newBalance = BalanceRules.applyTransaction(
        currentBalance: account.balance,
        type: type,
        amount: amount,
      );
      await _accountRepo.updateBalance(accountId, newBalance);

      // Return transaksi yang baru dibuat
      return (_db.select(_db.transactions)..where((t) => t.id.equals(txnId)))
          .getSingle();
    });
  }

  /// Update transaksi — reverse efek lama, terapkan efek baru.
  Future<Transaction> updateTransaction({
    required int txnId,
    TransactionType? type,
    int? accountId,
    int? categoryId,
    int? amount,
    DateTime? date,
    String? description,
    String? notes,
  }) async {
    return _db.transaction(() async {
      // Ambil transaksi lama
      final oldTxn = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(txnId)))
          .getSingleOrNull();
      if (oldTxn == null) {
        throw StateError('Transaksi tidak ditemukan');
      }

      // Reverse efek lama pada akun lama
      final oldAccount = await _accountRepo.getById(oldTxn.accountId);
      if (oldAccount != null) {
        final reversedBalance = BalanceRules.applyTransaction(
          currentBalance: oldAccount.balance,
          type: oldTxn.type,
          amount: oldTxn.amount,
          reverse: true,
        );
        await _accountRepo.updateBalance(oldTxn.accountId, reversedBalance);
      }

      // Update record transaksi
      await (_db.update(_db.transactions)..where((t) => t.id.equals(txnId)))
          .write(TransactionsCompanion(
        type: type != null ? Value(type) : const Value.absent(),
        accountId: accountId != null ? Value(accountId) : const Value.absent(),
        categoryId:
            categoryId != null ? Value(categoryId) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        date: date != null ? Value(date) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));

      // Ambil transaksi yang sudah diupdate
      final newTxn = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(txnId)))
          .getSingle();

      // Terapkan efek baru pada akun (bisa berubah jika accountId berubah)
      final newAccount = await _accountRepo.getById(newTxn.accountId);
      if (newAccount != null) {
        final newBalance = BalanceRules.applyTransaction(
          currentBalance: newAccount.balance,
          type: newTxn.type,
          amount: newTxn.amount,
        );
        await _accountRepo.updateBalance(newTxn.accountId, newBalance);
      }

      return newTxn;
    });
  }

  /// Hapus transaksi dan reverse efek saldo.
  Future<void> deleteTransaction(int txnId) async {
    return _db.transaction(() async {
      final txn = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(txnId)))
          .getSingleOrNull();
      if (txn == null) {
        throw StateError('Transaksi tidak ditemukan');
      }

      // Reverse balance
      final account = await _accountRepo.getById(txn.accountId);
      if (account != null) {
        final reversedBalance = BalanceRules.applyTransaction(
          currentBalance: account.balance,
          type: txn.type,
          amount: txn.amount,
          reverse: true,
        );
        await _accountRepo.updateBalance(txn.accountId, reversedBalance);
      }

      await (_db.delete(_db.transactions)..where((t) => t.id.equals(txnId)))
          .go();
    });
  }

  /// Ringkasan cash flow bulanan.
  Future<MonthlySummary> getMonthlySummary(int year, int month) async {
    int sumByType(List<Transaction> txns, TransactionType type) {
      return txns
          .where((t) => t.type == type)
          .fold<int>(0, (sum, t) => sum + t.amount);
    }

    final allTxns = await (_db.select(_db.transactions)
          ..where((t) => t.date.year.equals(year) & t.date.month.equals(month)))
        .get();

    final income = sumByType(allTxns, TransactionType.income);
    final expense = sumByType(allTxns, TransactionType.expense);
    final refund = sumByType(allTxns, TransactionType.refund);

    return MonthlySummary(
      year: year,
      month: month,
      income: income,
      expense: expense,
      refund: refund,
      netFlow: income + refund - expense,
    );
  }

  /// Stream ringkasan cash flow bulanan secara reaktif.
  Stream<MonthlySummary> watchMonthlySummary(int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    return (_db.select(_db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startOfMonth) &
              t.date.isSmallerOrEqualValue(endOfMonth)))
        .watch()
        .map((txns) {
      int sumByType(TransactionType type) => txns
          .where((t) => t.type == type)
          .fold<int>(0, (sum, t) => sum + t.amount);

      final income = sumByType(TransactionType.income);
      final expense = sumByType(TransactionType.expense);
      final refund = sumByType(TransactionType.refund);

      return MonthlySummary(
        year: year,
        month: month,
        income: income,
        expense: expense,
        refund: refund,
        netFlow: income + refund - expense,
      );
    });
  }

  /// Stream transaksi terbaru untuk dashboard.
  Stream<List<EnrichedTransaction>> watchRecentTransactions({int limit = 10}) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
          _db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(_db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ]);

    query
      ..orderBy([
        OrderingTerm.desc(_db.transactions.date),
        OrderingTerm.desc(_db.transactions.id),
      ])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        final txn = row.readTable(_db.transactions);
        final account = row.readTableOrNull(_db.accounts);
        final category = row.readTableOrNull(_db.categories);
        return EnrichedTransaction(
          transaction: txn,
          accountName: account?.name,
          categoryName: category?.name,
          categoryIcon: category?.icon,
        );
      }).toList();
    });
  }
}

/// Ringkasan cash flow bulanan.
class MonthlySummary {
  final int year;
  final int month;
  final int income;
  final int expense;
  final int refund;
  final int netFlow;

  const MonthlySummary({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.refund,
    required this.netFlow,
  });
}

/// Provider untuk TransactionRepository.
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  return TransactionRepository(db, accountRepo);
});
