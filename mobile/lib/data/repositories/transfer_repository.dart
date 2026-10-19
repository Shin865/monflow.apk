import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/balance_rules.dart';
import 'package:money_flow/data/repositories/account_repository.dart';

/// Data class untuk transfer yang diperkaya dengan nama akun.
class EnrichedTransfer {
  final Transfer transfer;
  final String? fromAccountName;
  final String? toAccountName;

  const EnrichedTransfer({
    required this.transfer,
    this.fromAccountName,
    this.toAccountName,
  });
}

/// Repository untuk transfer antar akun.
/// Transfer TIDAK mengubah net worth — hanya memindahkan saldo.
class TransferRepository {
  final AppDatabase _db;
  final AccountRepository _accountRepo;
  static const _uuid = Uuid();

  TransferRepository(this._db, this._accountRepo);

  /// Buat transfer baru dan perbarui saldo kedua akun secara atomik.
  Future<Transfer> create({
    required int fromAccountId,
    required int toAccountId,
    required int amount,
    required DateTime date,
    String? description,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Jumlah transfer harus lebih besar dari 0');
    }
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Tidak bisa transfer ke akun yang sama');
    }

    return _db.transaction(() async {
      final fromAccount = await _accountRepo.getById(fromAccountId);
      final toAccount = await _accountRepo.getById(toAccountId);

      if (fromAccount == null) {
        throw StateError('Akun asal tidak ditemukan');
      }
      if (toAccount == null) {
        throw StateError('Akun tujuan tidak ditemukan');
      }

      // Insert transfer record
      final transferId = await _db.into(_db.transfers).insert(
            TransfersCompanion.insert(
              uuid: Value(_uuid.v4()),
              fromAccountId: fromAccountId,
              toAccountId: toAccountId,
              amount: amount,
              date: date,
              description: Value(description),
            ),
          );

      // Update saldo kedua akun
      final newFromBalance = BalanceRules.applyTransferFrom(
        currentBalance: fromAccount.balance,
        amount: amount,
      );
      final newToBalance = BalanceRules.applyTransferTo(
        currentBalance: toAccount.balance,
        amount: amount,
      );

      await _accountRepo.updateBalance(fromAccountId, newFromBalance);
      await _accountRepo.updateBalance(toAccountId, newToBalance);

      // Verifikasi net worth neutral
      assert(BalanceRules.verifyTransferNeutral(
        fromBefore: fromAccount.balance,
        toBefore: toAccount.balance,
        fromAfter: newFromBalance,
        toAfter: newToBalance,
      ));

      return (_db.select(_db.transfers)..where((t) => t.id.equals(transferId)))
          .getSingle();
    });
  }

  /// Hapus transfer dan reverse efek saldo.
  Future<void> deleteTransfer(int transferId) async {
    return _db.transaction(() async {
      final transfer = await (_db.select(_db.transfers)
            ..where((t) => t.id.equals(transferId)))
          .getSingleOrNull();

      if (transfer == null) {
        throw StateError('Transfer tidak ditemukan');
      }

      // Reverse saldo
      final fromAccount = await _accountRepo.getById(transfer.fromAccountId);
      final toAccount = await _accountRepo.getById(transfer.toAccountId);

      if (fromAccount != null) {
        final reversed = BalanceRules.applyTransferFrom(
          currentBalance: fromAccount.balance,
          amount: transfer.amount,
          reverse: true,
        );
        await _accountRepo.updateBalance(transfer.fromAccountId, reversed);
      }

      if (toAccount != null) {
        final reversed = BalanceRules.applyTransferTo(
          currentBalance: toAccount.balance,
          amount: transfer.amount,
          reverse: true,
        );
        await _accountRepo.updateBalance(transfer.toAccountId, reversed);
      }

      await (_db.delete(_db.transfers)..where((t) => t.id.equals(transferId)))
          .go();
    });
  }

  /// Stream transfer terbaru dengan nama akun.
  Stream<List<EnrichedTransfer>> watchRecentTransfers({int limit = 20}) {
    final query = _db.select(_db.transfers).join([
      innerJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.transfers.fromAccountId),
        useColumns: false,
      ),
    ]);

    query
      ..orderBy([
        OrderingTerm.desc(_db.transfers.date),
        OrderingTerm.desc(_db.transfers.id),
      ])
      ..limit(limit);

    // Use custom select for enriched data
    return _db
        .customSelect(
          'SELECT t.*, '
          'a1.name AS from_name, '
          'a2.name AS to_name '
          'FROM transfers t '
          'INNER JOIN accounts a1 ON a1.id = t.from_account_id '
          'INNER JOIN accounts a2 ON a2.id = t.to_account_id '
          'ORDER BY t.date DESC, t.id DESC '
          'LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.transfers, _db.accounts},
        )
        .watch()
        .map((rows) {
          return rows.map((row) {
            return EnrichedTransfer(
              transfer: Transfer(
                id: row.read<int>('id'),
                uuid: row.read<String>('uuid'),
                fromAccountId: row.read<int>('from_account_id'),
                toAccountId: row.read<int>('to_account_id'),
                amount: row.read<int>('amount'),
                date: row.read<DateTime>('date'),
                description: row.readNullable<String>('description'),
                createdAt: row.read<DateTime>('created_at'),
              ),
              fromAccountName: row.read<String>('from_name'),
              toAccountName: row.read<String>('to_name'),
            );
          }).toList();
        });
  }

  /// Ambil semua transfer.
  Future<List<Transfer>> getAllTransfers() {
    return (_db.select(_db.transfers)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }
}

/// Provider untuk TransferRepository.
final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  return TransferRepository(db, accountRepo);
});
