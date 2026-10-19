import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/deposit_rules.dart';

class DepositSummary {
  final int totalPrincipal;
  final int totalEstimatedNetInterest;
  final int totalMaturityAmount;
  final int count;

  const DepositSummary({
    required this.totalPrincipal,
    required this.totalEstimatedNetInterest,
    required this.totalMaturityAmount,
    required this.count,
  });
}

class DepositRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DepositRepository(this._db);

  /// Watch semua deposito (selain yang sudah dicairkan/withdrawn).
  Stream<List<Deposit>> watchDeposits() {
    return (_db.select(_db.deposits)
          ..where((d) => d.status.isNotIn([DepositStatus.withdrawn.index]))
          ..orderBy([(d) => OrderingTerm.asc(d.maturityDate)]))
        .watch()
        .map((list) {
      final today = DateTime.now();
      for (final d in list) {
        if (d.status == DepositStatus.active &&
            !d.maturityDate.isAfter(today)) {
          // Tandai matured di database
          (_db.update(_db.deposits)..where((tbl) => tbl.id.equals(d.id))).write(
            const DepositsCompanion(status: Value(DepositStatus.matured)),
          );
        }
      }
      return list;
    });
  }

  /// Get semua deposito.
  Future<List<Deposit>> getDeposits() {
    return (_db.select(_db.deposits)
          ..where((d) => d.status.isNotIn([DepositStatus.withdrawn.index]))
          ..orderBy([(d) => OrderingTerm.asc(d.maturityDate)]))
        .get();
  }

  /// Ambil satu deposito berdasarkan ID.
  Future<Deposit?> getById(int id) {
    return (_db.select(_db.deposits)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch ringkasan portofolio deposito.
  Stream<DepositSummary> watchSummary() {
    return watchDeposits().map((deposits) {
      var totalPrincipal = 0;
      var totalEstimatedInterest = 0;

      for (final dep in deposits) {
        if (dep.status == DepositStatus.active ||
            dep.status == DepositStatus.matured) {
          totalPrincipal += dep.principal;
          final calc = DepositRules.calculateDeposit(
            principal: dep.principal,
            rateBps: dep.annualRateBps,
            tenorMonths: dep.tenorMonths,
            isCompound: dep.interestType == DepositInterestType.compound,
            compoundFrequency: dep.compoundFrequency,
            taxRateBps: dep.taxRateBps,
            feeAmount: dep.feeAmount,
          );
          totalEstimatedInterest += calc.netInterest;
        }
      }

      return DepositSummary(
        totalPrincipal: totalPrincipal,
        totalEstimatedNetInterest: totalEstimatedInterest,
        totalMaturityAmount: totalPrincipal + totalEstimatedInterest,
        count:
            deposits.where((d) => d.status != DepositStatus.withdrawn).length,
      );
    });
  }

  /// Buat simpanan deposito baru.
  Future<Deposit> create({
    required String name,
    String? bankName,
    int? accountId,
    required int principal,
    required int annualRateBps,
    required int tenorMonths,
    DepositInterestType interestType = DepositInterestType.simple,
    int compoundFrequency = 12,
    int taxRateBps = 2000,
    int feeAmount = 0,
    required DateTime startDate,
    DateTime? maturityDate,
    String? notes,
  }) async {
    final now = DateTime.now();
    final computedMaturity = maturityDate ??
        DepositRules.calculateMaturityDate(startDate, tenorMonths);

    final companion = DepositsCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name),
      bankName: Value(bankName),
      accountId: Value(accountId),
      principal: Value(principal),
      annualRateBps: Value(annualRateBps),
      tenorMonths: Value(tenorMonths),
      interestType: Value(interestType),
      compoundFrequency: Value(compoundFrequency),
      taxRateBps: Value(taxRateBps),
      feeAmount: Value(feeAmount),
      startDate: Value(startDate),
      maturityDate: Value(computedMaturity),
      status: const Value(DepositStatus.active),
      notes: Value(notes),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final id = await _db.into(_db.deposits).insert(companion);
    return (await getById(id))!;
  }

  /// Perbarui data deposito.
  Future<void> update(
    int id, {
    String? name,
    String? bankName,
    int? accountId,
    int? principal,
    int? annualRateBps,
    int? tenorMonths,
    DepositInterestType? interestType,
    int? compoundFrequency,
    int? taxRateBps,
    int? feeAmount,
    DateTime? startDate,
    DateTime? maturityDate,
    String? notes,
  }) async {
    final existing = await getById(id);
    if (existing == null) return;

    final effectiveStartDate = startDate ?? existing.startDate;
    final effectiveTenor = tenorMonths ?? existing.tenorMonths;
    final effectiveMaturity = maturityDate ??
        ((startDate != null || tenorMonths != null)
            ? DepositRules.calculateMaturityDate(
                effectiveStartDate, effectiveTenor)
            : existing.maturityDate);

    final companion = DepositsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      bankName: bankName != null ? Value(bankName) : const Value.absent(),
      accountId: accountId != null ? Value(accountId) : const Value.absent(),
      principal: principal != null ? Value(principal) : const Value.absent(),
      annualRateBps:
          annualRateBps != null ? Value(annualRateBps) : const Value.absent(),
      tenorMonths:
          tenorMonths != null ? Value(tenorMonths) : const Value.absent(),
      interestType:
          interestType != null ? Value(interestType) : const Value.absent(),
      compoundFrequency: compoundFrequency != null
          ? Value(compoundFrequency)
          : const Value.absent(),
      taxRateBps: taxRateBps != null ? Value(taxRateBps) : const Value.absent(),
      feeAmount: feeAmount != null ? Value(feeAmount) : const Value.absent(),
      startDate: startDate != null ? Value(startDate) : const Value.absent(),
      maturityDate: Value(effectiveMaturity),
      notes: notes != null ? Value(notes) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.deposits)..where((d) => d.id.equals(id)))
        .write(companion);
  }

  /// Pencairan deposito (withdraw).
  ///
  /// Mengubah status deposito menjadi `withdrawn`.
  /// Jika [returnToAccountId] dipilih, pokok + bunga bersih dikembalikan ke akun tersebut.
  Future<void> withdraw(
    int id, {
    int? returnToAccountId,
    bool recordInterestIncome = true,
  }) async {
    final dep = await getById(id);
    if (dep == null) return;

    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.deposits)..where((d) => d.id.equals(id))).write(
        DepositsCompanion(
          status: const Value(DepositStatus.withdrawn),
          updatedAt: Value(now),
        ),
      );

      if (returnToAccountId != null) {
        final calc = DepositRules.calculateDeposit(
          principal: dep.principal,
          rateBps: dep.annualRateBps,
          tenorMonths: dep.tenorMonths,
          isCompound: dep.interestType == DepositInterestType.compound,
          compoundFrequency: dep.compoundFrequency,
          taxRateBps: dep.taxRateBps,
          feeAmount: dep.feeAmount,
        );

        final targetAcc = await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(returnToAccountId)))
            .getSingleOrNull();

        if (targetAcc != null) {
          // Tambahkan total dana saat jatuh tempo ke akun
          final totalReturned = calc.maturityAmount;
          await (_db.update(_db.accounts)
                ..where((a) => a.id.equals(returnToAccountId)))
              .write(
            AccountsCompanion(
              balance: Value(targetAcc.balance + totalReturned),
              updatedAt: Value(now),
            ),
          );

          // Catat transaksi pendapatan bunga jika ada bunga bersih
          if (recordInterestIncome && calc.netInterest > 0) {
            // Dapatkan kategori default atau kategori bunga
            final cat = await (_db.select(_db.categories)
                  ..where((c) => c.type.equals(CategoryType.income.index))
                  ..limit(1))
                .getSingleOrNull();

            if (cat != null) {
              await _db.into(_db.transactions).insert(
                    TransactionsCompanion(
                      uuid: Value(_uuid.v4()),
                      type: const Value(TransactionType.income),
                      accountId: Value(returnToAccountId),
                      categoryId: Value(cat.id),
                      amount: Value(calc.netInterest),
                      date: Value(now),
                      description:
                          Value('Pencairan Bunga Deposito: ${dep.name}'),
                      isActual: const Value(true),
                      createdAt: Value(now),
                      updatedAt: Value(now),
                    ),
                  );
            }
          }
        }
      }
    });
  }

  /// Perpanjang deposito (roll over).
  Future<void> rollover(
    int id, {
    int? newRateBps,
    int? newTenorMonths,
  }) async {
    final dep = await getById(id);
    if (dep == null) return;

    final now = DateTime.now();
    final effectiveStartDate =
        dep.maturityDate.isBefore(now) ? now : dep.maturityDate;
    final tenor = newTenorMonths ?? dep.tenorMonths;
    final newMaturity =
        DepositRules.calculateMaturityDate(effectiveStartDate, tenor);

    await (_db.update(_db.deposits)..where((d) => d.id.equals(id))).write(
      DepositsCompanion(
        startDate: Value(effectiveStartDate),
        maturityDate: Value(newMaturity),
        tenorMonths: Value(tenor),
        annualRateBps:
            newRateBps != null ? Value(newRateBps) : const Value.absent(),
        status: const Value(DepositStatus.active),
        updatedAt: Value(now),
      ),
    );
  }
}

final depositRepositoryProvider = Provider<DepositRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DepositRepository(db);
});
