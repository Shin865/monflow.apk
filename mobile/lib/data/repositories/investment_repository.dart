import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/investment_rules.dart';

class InvestmentRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  InvestmentRepository(this._db);

  /// Watch semua investasi aktif.
  Stream<List<Investment>> watchActiveInvestments() {
    return (_db.select(_db.investments)
          ..where((i) => i.isActive.equals(true))
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .watch();
  }

  /// Get semua investasi aktif.
  Future<List<Investment>> getActiveInvestments() {
    return (_db.select(_db.investments)
          ..where((i) => i.isActive.equals(true))
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .get();
  }

  /// Ambil satu investasi berdasarkan ID.
  Future<Investment?> getById(int id) {
    return (_db.select(_db.investments)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch histori mutasi / penilaian suatu investasi.
  Stream<List<InvestmentTransaction>> watchTransactions(int investmentId) {
    return (_db.select(_db.investmentTransactions)
          ..where((t) => t.investmentId.equals(investmentId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.id)
          ]))
        .watch();
  }

  /// Watch ringkasan portofolio investasi.
  Stream<PortfolioSummary> watchPortfolioSummary() {
    return watchActiveInvestments().map((investments) {
      final items = investments
          .map((i) => InvestmentItemSummary(
                initialCost: i.initialCost,
                currentValue: i.currentValue,
                isActive: i.isActive,
              ))
          .toList();
      return InvestmentRules.summarize(items);
    });
  }

  /// Buat investasi baru.
  Future<Investment> create({
    required String name,
    required InvestmentType type,
    String? platform,
    int? accountId,
    required int initialCost,
    required int currentValue,
    double? units,
    DateTime? purchaseDate,
    String? notes,
  }) async {
    final now = DateTime.now();
    final companion = InvestmentsCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name),
      type: Value(type),
      platform: Value(platform),
      accountId: Value(accountId),
      initialCost: Value(initialCost),
      currentValue: Value(currentValue),
      units: Value(units),
      purchaseDate: Value(purchaseDate ?? now),
      notes: Value(notes),
      isActive: const Value(true),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    return _db.transaction(() async {
      final id = await _db.into(_db.investments).insert(companion);

      // Jika ada modal awal, catat juga sebagai transaksi awal (buy)
      if (initialCost > 0) {
        await _db.into(_db.investmentTransactions).insert(
              InvestmentTransactionsCompanion(
                uuid: Value(_uuid.v4()),
                investmentId: Value(id),
                type: const Value(InvestmentTxnType.buy),
                amount: Value(initialCost),
                units: Value(units),
                pricePerUnit: Value(
                    units != null && units > 0 ? initialCost / units : null),
                date: Value(purchaseDate ?? now),
                notes: const Value('Inisialisasi modal awal'),
                createdAt: Value(now),
              ),
            );
      }

      return (await getById(id))!;
    });
  }

  /// Update data investasi.
  Future<void> update(
    int id, {
    String? name,
    InvestmentType? type,
    String? platform,
    int? accountId,
    int? initialCost,
    int? currentValue,
    double? units,
    String? notes,
  }) async {
    final companion = InvestmentsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      platform: platform != null ? Value(platform) : const Value.absent(),
      accountId: accountId != null ? Value(accountId) : const Value.absent(),
      initialCost:
          initialCost != null ? Value(initialCost) : const Value.absent(),
      currentValue:
          currentValue != null ? Value(currentValue) : const Value.absent(),
      units: units != null ? Value(units) : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.investments)..where((i) => i.id.equals(id)))
        .write(companion);
  }

  /// Update nilai pasar terkini secara manual & catat histori penilaian.
  Future<void> updateValuation(
    int id, {
    required int newValue,
    String? notes,
    DateTime? date,
  }) async {
    final inv = await getById(id);
    if (inv == null) return;

    final now = DateTime.now();
    final valuationDate = date ?? now;

    await _db.transaction(() async {
      await (_db.update(_db.investments)..where((i) => i.id.equals(id))).write(
        InvestmentsCompanion(
          currentValue: Value(newValue),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.investmentTransactions).insert(
            InvestmentTransactionsCompanion(
              uuid: Value(_uuid.v4()),
              investmentId: Value(id),
              type: const Value(InvestmentTxnType.valuation),
              amount: Value(newValue),
              units: Value(inv.units),
              pricePerUnit: Value(inv.units != null && inv.units! > 0
                  ? newValue / inv.units!
                  : null),
              date: Value(valuationDate),
              notes: Value(notes ?? 'Pembaruan nilai pasar manual'),
              createdAt: Value(now),
            ),
          );
    });
  }

  /// Catat transaksi jual/beli/dividen.
  Future<void> addTransaction(
    int investmentId, {
    required InvestmentTxnType type,
    required int amount,
    double? units,
    double? pricePerUnit,
    int fee = 0,
    required DateTime date,
    String? notes,
  }) async {
    final inv = await getById(investmentId);
    if (inv == null) return;

    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.investmentTransactions).insert(
            InvestmentTransactionsCompanion(
              uuid: Value(_uuid.v4()),
              investmentId: Value(investmentId),
              type: Value(type),
              amount: Value(amount),
              units: Value(units),
              pricePerUnit: Value(pricePerUnit),
              fee: Value(fee),
              date: Value(date),
              notes: Value(notes),
              createdAt: Value(now),
            ),
          );

      if (type == InvestmentTxnType.buy) {
        final newCost = inv.initialCost + amount;
        final newUnits = (inv.units ?? 0.0) + (units ?? 0.0);
        await (_db.update(_db.investments)
              ..where((i) => i.id.equals(investmentId)))
            .write(
          InvestmentsCompanion(
            initialCost: Value(newCost),
            units: Value(newUnits > 0 ? newUnits : null),
            updatedAt: Value(now),
          ),
        );
      } else if (type == InvestmentTxnType.sell) {
        final saleCalc = InvestmentRules.calculateSale(
          totalCost: inv.initialCost,
          totalUnits: inv.units ?? 1.0,
          unitsSold: units ?? 0.0,
          sellPricePerUnit: (pricePerUnit ?? 0).round(),
          sellFee: fee,
        );

        await (_db.update(_db.investments)
              ..where((i) => i.id.equals(investmentId)))
            .write(
          InvestmentsCompanion(
            initialCost: Value(saleCalc.remainingCost),
            units: Value(
                saleCalc.remainingUnits > 0 ? saleCalc.remainingUnits : null),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Hapus investasi (soft delete).
  Future<void> delete(int id) async {
    await (_db.update(_db.investments)..where((i) => i.id.equals(id))).write(
      InvestmentsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestmentRepository(db);
});
