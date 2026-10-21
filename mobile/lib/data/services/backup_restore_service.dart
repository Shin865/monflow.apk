import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:money_flow/core/database/database.dart';

/// Hasil operasi backup/restore.
class BackupResult {
  final bool success;
  final String message;
  final String? filePath;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// Pratinjau isi backup sebelum pengguna mengonfirmasi restore.
class BackupPreview {
  final String format;
  final int schemaVersion;
  final DateTime exportedAt;
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final int transfersCount;
  final int settingsCount;
  final int totalBalance;
  final bool isValid;
  final String? validationError;

  const BackupPreview({
    required this.format,
    required this.schemaVersion,
    required this.exportedAt,
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.transfersCount,
    required this.settingsCount,
    required this.totalBalance,
    required this.isValid,
    this.validationError,
  });
}

/// Service untuk backup dan restore data JSON yang aman dan atomik.
///
/// Memenuhi spesifikasi Milestone 3:
/// - Format: `money-flow-backup`
/// - `schema_version`: 1
/// - Snapshot konsisten & atomik (Rollback jika gagal)
/// - Validasi integritas relasi & constraint sebelum restore
/// - Pratinjau (preview) ringkasan sebelum eksekusi
/// - Mode eksplisit: Full Replace (bukan merge diam-diam)
class BackupRestoreService {
  final AppDatabase _db;
  static const String currentFormat = 'money-flow-backup';
  static const int currentSchemaVersion = 4;

  static bool _parseBool(dynamic val, {bool defaultValue = false}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is int) return val != 0;
    if (val is String) {
      final lower = val.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return defaultValue;
  }

  BackupRestoreService(this._db);

  /// Export semua tabel database ke format JSON snapshot yang konsisten.
  Future<String> exportToJson() async {
    final accounts = await (_db.select(_db.accounts)
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .get();
    final categories = await (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
    final transactions = await (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final transfers = await (_db.select(_db.transfers)
          ..orderBy([(tr) => OrderingTerm.asc(tr.id)]))
        .get();
    final settings = await (_db.select(_db.settings)
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .get();
    final budgets = await (_db.select(_db.budgets)
          ..orderBy([(b) => OrderingTerm.asc(b.id)]))
        .get();
    final bills = await (_db.select(_db.bills)
          ..orderBy([(bl) => OrderingTerm.asc(bl.id)]))
        .get();
    final billPayments = await (_db.select(_db.billPayments)
          ..orderBy([(bp) => OrderingTerm.asc(bp.id)]))
        .get();
    final debts = await (_db.select(_db.debts)
          ..orderBy([(d) => OrderingTerm.asc(d.id)]))
        .get();
    final debtPayments = await (_db.select(_db.debtPayments)
          ..orderBy([(dp) => OrderingTerm.asc(dp.id)]))
        .get();
    final investments = await (_db.select(_db.investments)
          ..orderBy([(i) => OrderingTerm.asc(i.id)]))
        .get();
    final investmentTransactions = await (_db.select(_db.investmentTransactions)
          ..orderBy([(it) => OrderingTerm.asc(it.id)]))
        .get();
    final deposits = await (_db.select(_db.deposits)
          ..orderBy([(dp) => OrderingTerm.asc(dp.id)]))
        .get();
    final savingsGoals = await (_db.select(_db.savingsGoals)
          ..orderBy([(sg) => OrderingTerm.asc(sg.id)]))
        .get();
    final purchasePlans = await (_db.select(_db.purchasePlans)
          ..orderBy([(pp) => OrderingTerm.asc(pp.id)]))
        .get();
    final purchasePlanHistories = await (_db.select(_db.purchasePlanHistories)
          ..orderBy([(h) => OrderingTerm.asc(h.id)]))
        .get();

    final now = DateTime.now();
    final backupData = {
      'format': currentFormat,
      'schema_version': currentSchemaVersion,
      'app': 'money_flow',
      'app_version': '1.0.0+1',
      'exported_at': now.toIso8601String(),
      'metadata': {
        'total_accounts': accounts.length,
        'total_categories': categories.length,
        'total_transactions': transactions.length,
        'total_transfers': transfers.length,
        'total_settings': settings.length,
        'total_budgets': budgets.length,
        'total_bills': bills.length,
        'total_debts': debts.length,
        'total_investments': investments.length,
        'total_deposits': deposits.length,
        'total_savings_goals': savingsGoals.length,
        'total_purchase_plans': purchasePlans.length,
        'total_balance': accounts.fold<int>(
            0, (sum, a) => sum + (a.isActive ? a.balance : 0)),
      },
      'data': {
        'accounts': accounts
            .map((a) => {
                  'id': a.id,
                  'uuid': a.uuid,
                  'name': a.name,
                  'type': a.type.index,
                  'balance': a.balance,
                  'icon': a.icon,
                  'color': a.color,
                  'description': a.description,
                  'is_active': a.isActive,
                  'created_at': a.createdAt.toIso8601String(),
                  'updated_at': a.updatedAt.toIso8601String(),
                })
            .toList(),
        'categories': categories
            .map((c) => {
                  'id': c.id,
                  'uuid': c.uuid,
                  'name': c.name,
                  'type': c.type.index,
                  'parent_id': c.parentId,
                  'icon': c.icon,
                  'color': c.color,
                  'is_default': c.isDefault,
                  'is_active': c.isActive,
                })
            .toList(),
        'transactions': transactions
            .map((t) => {
                  'id': t.id,
                  'uuid': t.uuid,
                  'type': t.type.index,
                  'account_id': t.accountId,
                  'category_id': t.categoryId,
                  'amount': t.amount,
                  'date': t.date.toIso8601String(),
                  'description': t.description,
                  'notes': t.notes,
                  'is_actual': t.isActual,
                  'created_at': t.createdAt.toIso8601String(),
                  'updated_at': t.updatedAt.toIso8601String(),
                })
            .toList(),
        'transfers': transfers
            .map((tr) => {
                  'id': tr.id,
                  'uuid': tr.uuid,
                  'from_account_id': tr.fromAccountId,
                  'to_account_id': tr.toAccountId,
                  'amount': tr.amount,
                  'date': tr.date.toIso8601String(),
                  'description': tr.description,
                  'created_at': tr.createdAt.toIso8601String(),
                })
            .toList(),
        'settings': settings
            .map((s) => {
                  'id': s.id,
                  'key': s.key,
                  'value': s.value,
                  'description': s.description,
                  'updated_at': s.updatedAt.toIso8601String(),
                })
            .toList(),
        'budgets': budgets
            .map((b) => {
                  'id': b.id,
                  'uuid': b.uuid,
                  'category_id': b.categoryId,
                  'year': b.year,
                  'month': b.month,
                  'amount': b.amount,
                  'created_at': b.createdAt.toIso8601String(),
                  'updated_at': b.updatedAt.toIso8601String(),
                })
            .toList(),
        'bills': bills
            .map((bl) => {
                  'id': bl.id,
                  'uuid': bl.uuid,
                  'name': bl.name,
                  'amount': bl.amount,
                  'due_date': bl.dueDate.toIso8601String(),
                  'due_day': bl.dueDay,
                  'frequency': bl.frequency.index,
                  'is_recurring': bl.isRecurring,
                  'category_id': bl.categoryId,
                  'description': bl.description,
                  'status': bl.status.index,
                  'is_active': bl.isActive,
                  'recurring_key': bl.recurringKey,
                  'parent_bill_id': bl.parentBillId,
                  'created_at': bl.createdAt.toIso8601String(),
                  'updated_at': bl.updatedAt.toIso8601String(),
                })
            .toList(),
        'bill_payments': billPayments
            .map((bp) => {
                  'id': bp.id,
                  'uuid': bp.uuid,
                  'bill_id': bp.billId,
                  'amount': bp.amount,
                  'date': bp.date.toIso8601String(),
                  'account_id': bp.accountId,
                  'notes': bp.notes,
                  'created_at': bp.createdAt.toIso8601String(),
                })
            .toList(),
        'debts': debts
            .map((d) => {
                  'id': d.id,
                  'uuid': d.uuid,
                  'name': d.name,
                  'type': d.type.index,
                  'total_amount': d.totalAmount,
                  'remaining_amount': d.remainingAmount,
                  'person': d.person,
                  'description': d.description,
                  'due_date': d.dueDate?.toIso8601String(),
                  'tenor_months': d.tenorMonths,
                  'installment_amount': d.installmentAmount,
                  'installment_day': d.installmentDay,
                  'interest_rate': d.interestRate,
                  'status': d.status.index,
                  'account_id': d.accountId,
                  'created_at': d.createdAt.toIso8601String(),
                  'updated_at': d.updatedAt.toIso8601String(),
                })
            .toList(),
        'debt_payments': debtPayments
            .map((dp) => {
                  'id': dp.id,
                  'uuid': dp.uuid,
                  'debt_id': dp.debtId,
                  'amount': dp.amount,
                  'principal_amount': dp.principalAmount,
                  'interest_amount': dp.interestAmount,
                  'fee_amount': dp.feeAmount,
                  'date': dp.date.toIso8601String(),
                  'account_id': dp.accountId,
                  'notes': dp.notes,
                  'created_at': dp.createdAt.toIso8601String(),
                })
            .toList(),
        'investments': investments
            .map((i) => {
                  'id': i.id,
                  'uuid': i.uuid,
                  'name': i.name,
                  'type': i.type.index,
                  'platform': i.platform,
                  'account_id': i.accountId,
                  'initial_cost': i.initialCost,
                  'current_value': i.currentValue,
                  'units': i.units,
                  'purchase_date': i.purchaseDate?.toIso8601String(),
                  'notes': i.notes,
                  'is_active': i.isActive,
                  'created_at': i.createdAt.toIso8601String(),
                  'updated_at': i.updatedAt.toIso8601String(),
                })
            .toList(),
        'investment_transactions': investmentTransactions
            .map((it) => {
                  'id': it.id,
                  'uuid': it.uuid,
                  'investment_id': it.investmentId,
                  'type': it.type.index,
                  'amount': it.amount,
                  'units': it.units,
                  'price_per_unit': it.pricePerUnit,
                  'fee': it.fee,
                  'date': it.date.toIso8601String(),
                  'notes': it.notes,
                  'created_at': it.createdAt.toIso8601String(),
                })
            .toList(),
        'deposits': deposits
            .map((d) => {
                  'id': d.id,
                  'uuid': d.uuid,
                  'name': d.name,
                  'bank_name': d.bankName,
                  'account_id': d.accountId,
                  'principal': d.principal,
                  'annual_rate_bps': d.annualRateBps,
                  'tenor_months': d.tenorMonths,
                  'interest_type': d.interestType.index,
                  'compound_frequency': d.compoundFrequency,
                  'tax_rate_bps': d.taxRateBps,
                  'fee_amount': d.feeAmount,
                  'start_date': d.startDate.toIso8601String(),
                  'maturity_date': d.maturityDate.toIso8601String(),
                  'status': d.status.index,
                  'notes': d.notes,
                  'created_at': d.createdAt.toIso8601String(),
                  'updated_at': d.updatedAt.toIso8601String(),
                })
            .toList(),
        'savings_goals': savingsGoals
            .map((sg) => {
                  'id': sg.id,
                  'uuid': sg.uuid,
                  'name': sg.name,
                  'target_amount': sg.targetAmount,
                  'current_amount': sg.currentAmount,
                  'target_date': sg.targetDate?.toIso8601String(),
                  'target_account_id': sg.targetAccountId,
                  'is_virtual': sg.isVirtual,
                  'notes': sg.notes,
                  'status': sg.status.index,
                  'created_at': sg.createdAt.toIso8601String(),
                  'updated_at': sg.updatedAt.toIso8601String(),
                })
            .toList(),
        'purchase_plans': purchasePlans
            .map((pp) => {
                  'id': pp.id,
                  'uuid': pp.uuid,
                  'name': pp.name,
                  'target_amount': pp.targetAmount,
                  'allocated_amount': pp.allocatedAmount,
                  'target_date': pp.targetDate?.toIso8601String(),
                  'priority': pp.priority.index,
                  'status': pp.status.index,
                  'category': pp.category,
                  'url_link': pp.urlLink,
                  'description': pp.description,
                  'transaction_id': pp.transactionId,
                  'created_at': pp.createdAt.toIso8601String(),
                  'updated_at': pp.updatedAt.toIso8601String(),
                })
            .toList(),
        'purchase_plan_histories': purchasePlanHistories
            .map((h) => {
                  'id': h.id,
                  'plan_id': h.planId,
                  'action': h.action,
                  'timestamp': h.timestamp.toIso8601String(),
                  'details': h.details,
                  'notes': h.notes,
                })
            .toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Simpan backup snapshot ke direktori dokumen lokal aplikasi.
  Future<BackupResult> backupToFile() async {
    try {
      final json = await exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dir.path, 'money_flow_backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'money-flow-backup-$timestamp.json';
      final file = File(p.join(backupDir.path, fileName));
      await file.writeAsString(json);

      return BackupResult(
        success: true,
        message: 'Cadangan data berhasil disimpan: $fileName',
        filePath: file.path,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Gagal membuat cadangan data: $e',
      );
    }
  }

  /// Validasi menyeluruh terhadap konten JSON sebelum dilakukan pemulihan.
  /// Mengembalikan error pesan jika tidak valid, atau `null` jika valid.
  static String? validateBackupJson(String jsonString) {
    try {
      final parsed = jsonDecode(jsonString);
      if (parsed is! Map<String, dynamic>) {
        return 'Format file harus berupa JSON objek.';
      }

      // Validasi format name (dukung 'money-flow-backup' dan legacy 'app' == 'money_flow')
      final format = parsed['format'] ?? parsed['app'];
      if (format != currentFormat && format != 'money_flow') {
        return 'Format cadangan tidak dikenali. Diharapkan "$currentFormat".';
      }

      // Validasi skema
      final schemaVer = parsed['schema_version'] ?? parsed['version'];
      if (schemaVer == null || schemaVer is! int) {
        return 'Versi skema (schema_version) tidak ditemukan atau tidak valid.';
      }
      if (schemaVer < 1 || schemaVer > currentSchemaVersion) {
        return 'Versi skema cadangan ($schemaVer) tidak didukung oleh versi aplikasi ini (v1..v$currentSchemaVersion).';
      }

      // Validasi data container
      if (parsed['data'] == null || parsed['data'] is! Map<String, dynamic>) {
        return 'Objek "data" tidak ditemukan dalam cadangan.';
      }

      final inner = parsed['data'] as Map<String, dynamic>;
      final requiredTables = [
        'accounts',
        'categories',
        'transactions',
        'transfers'
      ];
      for (final table in requiredTables) {
        if (!inner.containsKey(table) || inner[table] is! List) {
          return 'Tabel "$table" tidak ditemukan atau bukan daftar data yang valid.';
        }
      }

      // Validasi relasi & constraint
      final rawAccounts = inner['accounts'] as List;
      final rawCategories = inner['categories'] as List;
      final rawTransactions = inner['transactions'] as List;
      final rawTransfers = inner['transfers'] as List;

      final accountIds = <int>{};
      for (final a in rawAccounts) {
        if (a is! Map<String, dynamic>) return 'Format entri akun tidak valid.';
        final id = a['id'];
        if (id == null || id is! int) return 'ID akun tidak valid.';
        if (accountIds.contains(id)) return 'Duplikasi ID akun: $id';
        accountIds.add(id);

        if (a['name'] == null || (a['name'] as String).trim().isEmpty) {
          return 'Nama akun tidak boleh kosong.';
        }
      }

      final categoryIds = <int>{};
      for (final c in rawCategories) {
        if (c is! Map<String, dynamic>) {
          return 'Format entri kategori tidak valid.';
        }
        final id = c['id'];
        if (id == null || id is! int) return 'ID kategori tidak valid.';
        if (categoryIds.contains(id)) return 'Duplikasi ID kategori: $id';
        categoryIds.add(id);

        if (c['name'] == null || (c['name'] as String).trim().isEmpty) {
          return 'Nama kategori tidak boleh kosong.';
        }
      }

      for (final t in rawTransactions) {
        if (t is! Map<String, dynamic>) {
          return 'Format entri transaksi tidak valid.';
        }
        final accId = t['account_id'];
        final catId = t['category_id'];
        final amount = t['amount'];

        if (accId is! int || !accountIds.contains(accId)) {
          return 'Relasi rusak: Transaksi mengacu pada Akun ID $accId yang tidak ada dalam cadangan.';
        }
        if (catId is! int || !categoryIds.contains(catId)) {
          return 'Relasi rusak: Transaksi mengacu pada Kategori ID $catId yang tidak ada dalam cadangan.';
        }
        if (amount is! int || amount <= 0) {
          return 'Constraint dilanggar: Nominal transaksi harus bernilai integer > 0.';
        }
      }

      for (final tr in rawTransfers) {
        if (tr is! Map<String, dynamic>) {
          return 'Format entri transfer tidak valid.';
        }
        final fromId = tr['from_account_id'];
        final toId = tr['to_account_id'];
        final amount = tr['amount'];

        if (fromId is! int || !accountIds.contains(fromId)) {
          return 'Relasi rusak: Akun asal transfer ID $fromId tidak ditemukan.';
        }
        if (toId is! int || !accountIds.contains(toId)) {
          return 'Relasi rusak: Akun tujuan transfer ID $toId tidak ditemukan.';
        }
        if (fromId == toId) {
          return 'Constraint dilanggar: Akun asal dan tujuan transfer tidak boleh sama.';
        }
        if (amount is! int || amount <= 0) {
          return 'Constraint dilanggar: Nominal transfer harus > 0.';
        }
      }

      return null; // Validasi sukses
    } on FormatException {
      return 'File bukan merupakan format JSON yang valid.';
    } catch (e) {
      return 'Validasi cadangan gagal: $e';
    }
  }

  /// Dapatkan pratinjau ringkasan dari file/konten cadangan sebelum restore.
  BackupPreview inspectBackup(String jsonString) {
    final error = validateBackupJson(jsonString);
    if (error != null) {
      return BackupPreview(
        format: 'unknown',
        schemaVersion: 0,
        exportedAt: DateTime.now(),
        accountsCount: 0,
        categoriesCount: 0,
        transactionsCount: 0,
        transfersCount: 0,
        settingsCount: 0,
        totalBalance: 0,
        isValid: false,
        validationError: error,
      );
    }

    try {
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      final inner = parsed['data'] as Map<String, dynamic>;

      final rawAccounts = inner['accounts'] as List;
      final rawCategories = inner['categories'] as List;
      final rawTransactions = inner['transactions'] as List;
      final rawTransfers = inner['transfers'] as List;
      final rawSettings = (inner['settings'] as List?) ?? [];

      int totalBalance = 0;
      for (final a in rawAccounts) {
        final balance = a['balance'] as int? ?? 0;
        final isActive = _parseBool(a['is_active'], defaultValue: true);
        if (isActive) {
          totalBalance += balance;
        }
      }

      return BackupPreview(
        format: (parsed['format'] ?? parsed['app'] ?? currentFormat) as String,
        schemaVersion:
            (parsed['schema_version'] ?? parsed['version'] ?? 1) as int,
        exportedAt: DateTime.tryParse(parsed['exported_at'] as String? ?? '') ??
            DateTime.now(),
        accountsCount: rawAccounts.length,
        categoriesCount: rawCategories.length,
        transactionsCount: rawTransactions.length,
        transfersCount: rawTransfers.length,
        settingsCount: rawSettings.length,
        totalBalance: totalBalance,
        isValid: true,
      );
    } catch (e) {
      return BackupPreview(
        format: 'unknown',
        schemaVersion: 0,
        exportedAt: DateTime.now(),
        accountsCount: 0,
        categoriesCount: 0,
        transactionsCount: 0,
        transfersCount: 0,
        settingsCount: 0,
        totalBalance: 0,
        isValid: false,
        validationError: 'Gagal membaca isi ringkasan cadangan: $e',
      );
    }
  }

  /// Pulihkan data dari JSON string dengan mode FULL REPLACE secara atomik.
  ///
  /// Jaminan atomisitas:
  /// Dijalankan di dalam SQLite transaction (`_db.transaction`). Jika terjadi exception atau kegagalan
  /// di langkah mana pun, seluruh perubahan otomatis di-ROLLBACK dan database aktif tetap utuh tanpa korupsi.
  Future<BackupResult> restoreFromJson(String jsonString) async {
    final validationError = validateBackupJson(jsonString);
    if (validationError != null) {
      return BackupResult(success: false, message: validationError);
    }

    try {
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      final inner = parsed['data'] as Map<String, dynamic>;

      final rawAccounts = inner['accounts'] as List;
      final rawCategories = inner['categories'] as List;
      final rawTransactions = inner['transactions'] as List;
      final rawTransfers = inner['transfers'] as List;
      final rawSettings = (inner['settings'] as List?) ?? [];
      final rawBudgets = (inner['budgets'] as List?) ?? [];
      final rawBills = (inner['bills'] as List?) ?? [];
      final rawBillPayments = (inner['bill_payments'] as List?) ?? [];
      final rawDebts = (inner['debts'] as List?) ?? [];
      final rawDebtPayments = (inner['debt_payments'] as List?) ?? [];
      final rawInvestments = (inner['investments'] as List?) ?? [];
      final rawInvestmentTransactions =
          (inner['investment_transactions'] as List?) ?? [];
      final rawDeposits = (inner['deposits'] as List?) ?? [];
      final rawSavingsGoals = (inner['savings_goals'] as List?) ?? [];
      final rawPurchasePlans = (inner['purchase_plans'] as List?) ?? [];
      final rawPurchasePlanHistories =
          (inner['purchase_plan_histories'] as List?) ?? [];

      await _db.transaction(() async {
        // 1. Bersihkan seluruh data aktif secara berurutan sesuai relasi Foreign Key
        await _db.delete(_db.investmentTransactions).go();
        await _db.delete(_db.investments).go();
        await _db.delete(_db.deposits).go();
        await _db.delete(_db.savingsGoals).go();
        await _db.delete(_db.purchasePlanHistories).go();
        await _db.delete(_db.purchasePlans).go();
        await _db.delete(_db.billPayments).go();
        await _db.delete(_db.debtPayments).go();
        await _db.delete(_db.bills).go();
        await _db.delete(_db.debts).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.transfers).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.accounts).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.settings).go();

        // 2. Pulihkan Categories (mempertahankan exact Primary Key ID)
        for (final item in rawCategories) {
          final c = item as Map<String, dynamic>;
          await _db.into(_db.categories).insert(
                CategoriesCompanion.insert(
                  id: Value(c['id'] as int),
                  uuid: Value(c['uuid'] as String? ?? ''),
                  name: c['name'] as String,
                  type: CategoryType.values[c['type'] as int],
                  parentId: Value(c['parent_id'] as int?),
                  icon: Value(c['icon'] as String?),
                  color: Value(c['color'] as String?),
                  isDefault:
                      Value(_parseBool(c['is_default'], defaultValue: false)),
                  isActive:
                      Value(_parseBool(c['is_active'], defaultValue: true)),
                ),
              );
        }

        // 3. Pulihkan Accounts (mempertahankan exact Primary Key ID)
        for (final item in rawAccounts) {
          final a = item as Map<String, dynamic>;
          await _db.into(_db.accounts).insert(
                AccountsCompanion.insert(
                  id: Value(a['id'] as int),
                  uuid: Value(a['uuid'] as String? ?? ''),
                  name: a['name'] as String,
                  type: AccountType.values[a['type'] as int],
                  balance: Value(a['balance'] as int? ?? 0),
                  icon: Value(a['icon'] as String?),
                  color: Value(a['color'] as String?),
                  description: Value(a['description'] as String?),
                  isActive:
                      Value(_parseBool(a['is_active'], defaultValue: true)),
                  createdAt: Value(DateTime.parse(a['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(a['updated_at'] as String)),
                ),
              );
        }

        // 4. Pulihkan Transactions (mempertahankan exact Primary Key ID & relasi FK)
        for (final item in rawTransactions) {
          final t = item as Map<String, dynamic>;
          await _db.into(_db.transactions).insert(
                TransactionsCompanion.insert(
                  id: Value(t['id'] as int),
                  uuid: Value(t['uuid'] as String? ?? ''),
                  type: TransactionType.values[t['type'] as int],
                  accountId: t['account_id'] as int,
                  categoryId: t['category_id'] as int,
                  amount: t['amount'] as int,
                  date: DateTime.parse(t['date'] as String),
                  description: Value(t['description'] as String?),
                  notes: Value(t['notes'] as String?),
                  isActual:
                      Value(_parseBool(t['is_actual'], defaultValue: true)),
                  createdAt: Value(DateTime.parse(t['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(t['updated_at'] as String)),
                ),
              );
        }

        // 5. Pulihkan Transfers (mempertahankan exact Primary Key ID)
        for (final item in rawTransfers) {
          final tr = item as Map<String, dynamic>;
          await _db.into(_db.transfers).insert(
                TransfersCompanion.insert(
                  id: Value(tr['id'] as int),
                  uuid: Value(tr['uuid'] as String? ?? ''),
                  fromAccountId: tr['from_account_id'] as int,
                  toAccountId: tr['to_account_id'] as int,
                  amount: tr['amount'] as int,
                  date: DateTime.parse(tr['date'] as String),
                  description: Value(tr['description'] as String?),
                  createdAt: Value(DateTime.parse(tr['created_at'] as String)),
                ),
              );
        }

        // 6. Pulihkan Settings jika ada
        for (final item in rawSettings) {
          final s = item as Map<String, dynamic>;
          await _db.into(_db.settings).insert(
                SettingsCompanion.insert(
                  id: Value(s['id'] as int),
                  key: s['key'] as String,
                  value: Value(s['value'] as String?),
                  description: Value(s['description'] as String?),
                  updatedAt: Value(DateTime.parse(s['updated_at'] as String)),
                ),
              );
        }

        // 7. Pulihkan Budgets
        for (final item in rawBudgets) {
          final b = item as Map<String, dynamic>;
          await _db.into(_db.budgets).insert(
                BudgetsCompanion.insert(
                  id: Value(b['id'] as int),
                  uuid: Value(b['uuid'] as String? ?? ''),
                  categoryId: b['category_id'] as int,
                  year: b['year'] as int,
                  month: b['month'] as int,
                  amount: b['amount'] as int,
                  createdAt: Value(DateTime.parse(b['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(b['updated_at'] as String)),
                ),
              );
        }

        // 8. Pulihkan Debts
        for (final item in rawDebts) {
          final d = item as Map<String, dynamic>;
          await _db.into(_db.debts).insert(
                DebtsCompanion.insert(
                  id: Value(d['id'] as int),
                  uuid: Value(d['uuid'] as String? ?? ''),
                  name: d['name'] as String,
                  type: DebtType.values[d['type'] as int],
                  totalAmount: d['total_amount'] as int,
                  remainingAmount: d['remaining_amount'] as int,
                  person: Value(d['person'] as String?),
                  description: Value(d['description'] as String?),
                  dueDate: Value(d['due_date'] != null
                      ? DateTime.parse(d['due_date'] as String)
                      : null),
                  tenorMonths: Value(d['tenor_months'] as int?),
                  installmentAmount: Value(d['installment_amount'] as int?),
                  installmentDay: Value(d['installment_day'] as int?),
                  interestRate:
                      Value((d['interest_rate'] as num?)?.toDouble() ?? 0.0),
                  status: Value(DebtStatus.values[d['status'] as int]),
                  accountId: Value(d['account_id'] as int?),
                  createdAt: Value(DateTime.parse(d['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(d['updated_at'] as String)),
                ),
              );
        }

        // 9. Pulihkan Debt Payments
        for (final item in rawDebtPayments) {
          final dp = item as Map<String, dynamic>;
          await _db.into(_db.debtPayments).insert(
                DebtPaymentsCompanion.insert(
                  id: Value(dp['id'] as int),
                  uuid: Value(dp['uuid'] as String? ?? ''),
                  debtId: dp['debt_id'] as int,
                  amount: dp['amount'] as int,
                  principalAmount: Value(dp['principal_amount'] as int? ?? 0),
                  interestAmount: Value(dp['interest_amount'] as int? ?? 0),
                  feeAmount: Value(dp['fee_amount'] as int? ?? 0),
                  date: DateTime.parse(dp['date'] as String),
                  accountId: Value(dp['account_id'] as int?),
                  notes: Value(dp['notes'] as String?),
                  createdAt: Value(DateTime.parse(dp['created_at'] as String)),
                ),
              );
        }

        // 10. Pulihkan Bills
        for (final item in rawBills) {
          final bl = item as Map<String, dynamic>;
          await _db.into(_db.bills).insert(
                BillsCompanion.insert(
                  id: Value(bl['id'] as int),
                  uuid: Value(bl['uuid'] as String? ?? ''),
                  name: bl['name'] as String,
                  amount: bl['amount'] as int,
                  dueDate: DateTime.parse(bl['due_date'] as String),
                  dueDay: Value(bl['due_day'] as int?),
                  frequency:
                      Value(BillFrequency.values[bl['frequency'] as int]),
                  isRecurring: Value(
                      _parseBool(bl['is_recurring'], defaultValue: false)),
                  categoryId: Value(bl['category_id'] as int?),
                  description: Value(bl['description'] as String?),
                  status: Value(BillStatus.values[bl['status'] as int]),
                  isActive:
                      Value(_parseBool(bl['is_active'], defaultValue: true)),
                  recurringKey: Value(bl['recurring_key'] as String?),
                  parentBillId: Value(bl['parent_bill_id'] as int?),
                  createdAt: Value(DateTime.parse(bl['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(bl['updated_at'] as String)),
                ),
              );
        }

        // 11. Pulihkan Bill Payments
        for (final item in rawBillPayments) {
          final bp = item as Map<String, dynamic>;
          await _db.into(_db.billPayments).insert(
                BillPaymentsCompanion.insert(
                  id: Value(bp['id'] as int),
                  uuid: Value(bp['uuid'] as String? ?? ''),
                  billId: bp['bill_id'] as int,
                  amount: bp['amount'] as int,
                  date: DateTime.parse(bp['date'] as String),
                  accountId: bp['account_id'] as int,
                  notes: Value(bp['notes'] as String?),
                  createdAt: Value(DateTime.parse(bp['created_at'] as String)),
                ),
              );
        }

        // 12. Pulihkan Investments
        for (final item in rawInvestments) {
          final i = item as Map<String, dynamic>;
          await _db.into(_db.investments).insert(
                InvestmentsCompanion.insert(
                  id: Value(i['id'] as int),
                  uuid: Value(i['uuid'] as String? ?? ''),
                  name: i['name'] as String,
                  type: InvestmentType.values[i['type'] as int],
                  platform: Value(i['platform'] as String?),
                  accountId: Value(i['account_id'] as int?),
                  initialCost: Value(i['initial_cost'] as int? ?? 0),
                  currentValue: Value(i['current_value'] as int? ?? 0),
                  units: Value((i['units'] as num?)?.toDouble()),
                  purchaseDate: Value(i['purchase_date'] != null
                      ? DateTime.parse(i['purchase_date'] as String)
                      : null),
                  notes: Value(i['notes'] as String?),
                  isActive:
                      Value(_parseBool(i['is_active'], defaultValue: true)),
                  createdAt: Value(DateTime.parse(i['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(i['updated_at'] as String)),
                ),
              );
        }

        // 13. Pulihkan Investment Transactions
        for (final item in rawInvestmentTransactions) {
          final it = item as Map<String, dynamic>;
          await _db.into(_db.investmentTransactions).insert(
                InvestmentTransactionsCompanion.insert(
                  id: Value(it['id'] as int),
                  uuid: Value(it['uuid'] as String? ?? ''),
                  investmentId: it['investment_id'] as int,
                  type: InvestmentTxnType.values[it['type'] as int],
                  amount: it['amount'] as int,
                  units: Value((it['units'] as num?)?.toDouble()),
                  pricePerUnit:
                      Value((it['price_per_unit'] as num?)?.toDouble()),
                  fee: Value(it['fee'] as int? ?? 0),
                  date: DateTime.parse(it['date'] as String),
                  notes: Value(it['notes'] as String?),
                  createdAt: Value(DateTime.parse(it['created_at'] as String)),
                ),
              );
        }

        // 14. Pulihkan Deposits
        for (final item in rawDeposits) {
          final d = item as Map<String, dynamic>;
          await _db.into(_db.deposits).insert(
                DepositsCompanion.insert(
                  id: Value(d['id'] as int),
                  uuid: Value(d['uuid'] as String? ?? ''),
                  name: d['name'] as String,
                  bankName: Value(d['bank_name'] as String?),
                  accountId: Value(d['account_id'] as int?),
                  principal: d['principal'] as int,
                  annualRateBps: d['annual_rate_bps'] as int,
                  tenorMonths: d['tenor_months'] as int,
                  interestType: Value(DepositInterestType
                      .values[d['interest_type'] as int? ?? 0]),
                  compoundFrequency:
                      Value(d['compound_frequency'] as int? ?? 12),
                  taxRateBps: Value(d['tax_rate_bps'] as int? ?? 2000),
                  feeAmount: Value(d['fee_amount'] as int? ?? 0),
                  startDate: DateTime.parse(d['start_date'] as String),
                  maturityDate: DateTime.parse(d['maturity_date'] as String),
                  status: Value(DepositStatus.values[d['status'] as int? ?? 0]),
                  notes: Value(d['notes'] as String?),
                  createdAt: Value(DateTime.parse(d['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(d['updated_at'] as String)),
                ),
              );
        }

        // 15. Pulihkan Savings Goals
        for (final item in rawSavingsGoals) {
          final sg = item as Map<String, dynamic>;
          await _db.into(_db.savingsGoals).insert(
                SavingsGoalsCompanion.insert(
                  id: Value(sg['id'] as int),
                  uuid: Value(sg['uuid'] as String? ?? ''),
                  name: sg['name'] as String,
                  targetAmount: sg['target_amount'] as int,
                  currentAmount: Value(sg['current_amount'] as int? ?? 0),
                  targetDate: Value(sg['target_date'] != null
                      ? DateTime.parse(sg['target_date'] as String)
                      : null),
                  targetAccountId: Value(sg['target_account_id'] as int?),
                  isVirtual:
                      Value(_parseBool(sg['is_virtual'], defaultValue: true)),
                  notes: Value(sg['notes'] as String?),
                  status: Value(
                      SavingsGoalStatus.values[sg['status'] as int? ?? 0]),
                  createdAt: Value(DateTime.parse(sg['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(sg['updated_at'] as String)),
                ),
              );
        }

        // 16. Pulihkan Purchase Plans
        for (final item in rawPurchasePlans) {
          final pp = item as Map<String, dynamic>;
          await _db.into(_db.purchasePlans).insert(
                PurchasePlansCompanion.insert(
                  id: Value(pp['id'] as int),
                  uuid: Value(pp['uuid'] as String? ?? ''),
                  name: pp['name'] as String,
                  targetAmount: pp['target_amount'] as int,
                  allocatedAmount: Value(pp['allocated_amount'] as int? ?? 0),
                  targetDate: Value(pp['target_date'] != null
                      ? DateTime.parse(pp['target_date'] as String)
                      : null),
                  priority:
                      Value(PlanPriority.values[pp['priority'] as int? ?? 1]),
                  status: Value(PlanStatus.values[pp['status'] as int? ?? 0]),
                  category: Value(pp['category'] as String?),
                  urlLink: Value(pp['url_link'] as String?),
                  description: Value(pp['description'] as String?),
                  transactionId: Value(pp['transaction_id'] as int?),
                  createdAt: Value(DateTime.parse(pp['created_at'] as String)),
                  updatedAt: Value(DateTime.parse(pp['updated_at'] as String)),
                ),
              );
        }

        // 17. Pulihkan Purchase Plan Histories
        for (final item in rawPurchasePlanHistories) {
          final h = item as Map<String, dynamic>;
          await _db.into(_db.purchasePlanHistories).insert(
                PurchasePlanHistoriesCompanion.insert(
                  id: Value(h['id'] as int),
                  planId: h['plan_id'] as int,
                  action: h['action'] as String,
                  timestamp: Value(DateTime.parse(h['timestamp'] as String)),
                  details: Value(h['details'] as String?),
                  notes: Value(h['notes'] as String?),
                ),
              );
        }
      });

      return BackupResult(
        success: true,
        message:
            'Pemulihan data berhasil! Dipulihkan ${rawAccounts.length} akun, ${rawCategories.length} kategori, ${rawTransactions.length} transaksi, ${rawTransfers.length} transfer.',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message:
            'Gagal melakukan pemulihan data: $e. Database aktif tetap utuh.',
      );
    }
  }

  /// Restore dari file lokal.
  Future<BackupResult> restoreFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BackupResult(
          success: false,
          message: 'File cadangan tidak ditemukan.',
        );
      }

      final jsonString = await file.readAsString();
      return restoreFromJson(jsonString);
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Gagal membaca file cadangan: $e',
      );
    }
  }

  /// Dapatkan daftar file backup yang tersimpan di direktori dokumen aplikasi.
  Future<List<File>> listBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'money_flow_backups'));
    if (!await backupDir.exists()) return [];

    final entities = await backupDir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    files
        .sort((a, b) => b.path.compareTo(a.path)); // Urutkan terbaru lebih dulu
    return files;
  }
}

/// Provider untuk BackupRestoreService.
final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupRestoreService(db);
});
