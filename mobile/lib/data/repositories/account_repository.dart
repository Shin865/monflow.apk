import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';

/// Repository untuk operasi akun keuangan.
class AccountRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  AccountRepository(this._db);

  /// Ambil semua akun aktif, diurutkan berdasarkan tipe dan nama.
  Future<List<Account>> getActiveAccounts() {
    return (_db.select(_db.accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .get();
  }

  /// Ambil semua akun termasuk yang tidak aktif.
  Future<List<Account>> getAllAccounts() {
    return (_db.select(_db.accounts)
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .get();
  }

  /// Ambil satu akun berdasarkan ID.
  Future<Account?> getById(int id) {
    return (_db.select(_db.accounts)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Buat akun baru.
  /// [initialBalance] dalam satuan Rupiah (integer).
  Future<Account> create({
    required String name,
    required AccountType type,
    int initialBalance = 0,
    String? icon,
    String? color,
    String? description,
  }) async {
    final id = await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            uuid: Value(_uuid.v4()),
            name: name,
            type: type,
            balance: Value(initialBalance),
            icon: Value(icon),
            color: Value(color),
            description: Value(description),
          ),
        );

    return (await getById(id))!;
  }

  /// Update informasi akun (bukan saldo — saldo diubah via transaksi).
  Future<Account> update({
    required int id,
    String? name,
    AccountType? type,
    String? icon,
    String? color,
    String? description,
    bool? isActive,
  }) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return (await getById(id))!;
  }

  /// Update saldo akun (dipanggil secara internal oleh TransactionRepository).
  Future<void> updateBalance(int id, int newBalance) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        balance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hapus akun. Soft delete jika ada transaksi terkait.
  Future<String> delete(int id) async {
    final txnCount = await (_db.select(_db.transactions)
          ..where((t) => t.accountId.equals(id)))
        .get();

    if (txnCount.isNotEmpty) {
      await update(id: id, isActive: false);
      return 'Akun dinonaktifkan (memiliki ${txnCount.length} transaksi)';
    } else {
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
      return 'Akun dihapus';
    }
  }

  /// Hitung total saldo semua akun aktif.
  Future<int> getTotalBalance() async {
    final accounts = await getActiveAccounts();
    return accounts.fold<int>(0, (sum, a) => sum + a.balance);
  }

  /// Stream semua akun aktif (untuk reactive UI).
  Stream<List<Account>> watchActiveAccounts() {
    return (_db.select(_db.accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .watch();
  }

  /// Stream total saldo.
  Stream<int> watchTotalBalance() {
    return watchActiveAccounts().map(
      (accounts) => accounts.fold<int>(0, (sum, a) => sum + a.balance),
    );
  }
}

/// Provider untuk AccountRepository.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepository(db);
});
