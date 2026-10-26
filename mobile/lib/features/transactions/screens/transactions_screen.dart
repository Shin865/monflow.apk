import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';

/// Layar daftar transaksi dengan filter.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionType? _filterType;
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final txnStream = ref
        .watch(transactionRepositoryProvider)
        .watchRecentTransactions(limit: 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: (_filterType != null || _selectedDateRange != null)
                  ? AppColors.primary
                  : null,
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: StreamBuilder<List<EnrichedTransaction>>(
        stream: txnStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var transactions = snapshot.data ?? [];

          // Filter lokal berdasarkan tipe
          if (_filterType != null) {
            transactions = transactions
                .where((t) => t.transaction.type == _filterType)
                .toList();
          }

          // Filter lokal berdasarkan rentang tanggal
          if (_selectedDateRange != null) {
            final start = DateTime(
              _selectedDateRange!.start.year,
              _selectedDateRange!.start.month,
              _selectedDateRange!.start.day,
            );
            final end = DateTime(
              _selectedDateRange!.end.year,
              _selectedDateRange!.end.month,
              _selectedDateRange!.end.day,
              23,
              59,
              59,
              999,
            );
            transactions = transactions.where((t) {
              final d = t.transaction.date;
              return !d.isBefore(start) && !d.isAfter(end);
            }).toList();
          }

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 80, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  const Text(
                    'Belum ada transaksi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_filterType != null || _selectedDateRange != null)
                        ? 'Tidak ada transaksi yang cocok dengan filter'
                        : 'Catat transaksi pertamamu',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  if (_filterType != null || _selectedDateRange != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _filterType = null;
                          _selectedDateRange = null;
                        });
                      },
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Reset Filter'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.pushNamed('create_transaction'),
                    icon: const Icon(Icons.add),
                    label: const Text('Catat Transaksi'),
                  ),
                ],
              ),
            );
          }

          // Group transactions by date
          final grouped = <String, List<EnrichedTransaction>>{};
          for (final etxn in transactions) {
            final dateKey = formatDate(etxn.transaction.date);
            grouped.putIfAbsent(dateKey, () => []).add(etxn);
          }

          return Column(
            children: [
              if (_filterType != null || _selectedDateRange != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.surfaceLight.withOpacity(0.5),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (_filterType != null)
                              'Tipe: ${_getTypeFilterName(_filterType!)}',
                            if (_selectedDateRange != null)
                              'Periode: ${formatDateIndo(_selectedDateRange!.start)} - ${formatDateIndo(_selectedDateRange!.end)}',
                          ].join(' • '),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _filterType = null;
                            _selectedDateRange = null;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateKey = grouped.keys.elementAt(index);
                    final items = grouped[dateKey]!;

                    // Hitung total per hari
                    int dailyNet = 0;
                    for (final item in items) {
                      final txn = item.transaction;
                      if (txn.type == TransactionType.income ||
                          txn.type == TransactionType.refund) {
                        dailyNet += txn.amount;
                      } else {
                        dailyNet -= txn.amount;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateKey,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                '${dailyNet >= 0 ? "+" : ""}${formatRupiah(dailyNet)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: dailyNet >= 0
                                      ? AppColors.income
                                      : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Transaction items
                        ...items.map((etxn) => _TransactionItem(
                              enriched: etxn,
                              onTap: () => _showTransactionOptions(etxn),
                              onDelete: () => _confirmDelete(etxn),
                            )),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('create_transaction'),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
    );
  }

  String _getTypeFilterName(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.adjustment:
        return 'Penyesuaian';
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (_filterType != null || _selectedDateRange != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterType = null;
                          _selectedDateRange = null;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tipe Transaksi',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Semua Tipe',
                    isSelected: _filterType == null,
                    onTap: () {
                      setState(() => _filterType = null);
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Pemasukan',
                    isSelected: _filterType == TransactionType.income,
                    color: AppColors.income,
                    onTap: () {
                      setState(() => _filterType = TransactionType.income);
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Pengeluaran',
                    isSelected: _filterType == TransactionType.expense,
                    color: AppColors.expense,
                    onTap: () {
                      setState(() => _filterType = TransactionType.expense);
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Refund',
                    isSelected: _filterType == TransactionType.refund,
                    color: AppColors.refund,
                    onTap: () {
                      setState(() => _filterType = TransactionType.refund);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter Tanggal',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Semua Waktu',
                    isSelected: _selectedDateRange == null,
                    onTap: () {
                      setState(() => _selectedDateRange = null);
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Hari Ini',
                    isSelected: _selectedDateRange != null &&
                        _isSameDay(_selectedDateRange!.start, DateTime.now()) &&
                        _isSameDay(_selectedDateRange!.end, DateTime.now()),
                    onTap: () {
                      final now = DateTime.now();
                      setState(() => _selectedDateRange =
                          DateTimeRange(start: now, end: now));
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Bulan Ini',
                    isSelected: _isCurrentMonthSelected(),
                    onTap: () {
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month, 1);
                      final end = DateTime(now.year, now.month + 1, 0);
                      setState(() => _selectedDateRange =
                          DateTimeRange(start: start, end: end));
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: _selectedDateRange != null &&
                            !_isCurrentMonthSelected() &&
                            !(_isSameDay(_selectedDateRange!.start,
                                    DateTime.now()) &&
                                _isSameDay(
                                    _selectedDateRange!.end, DateTime.now()))
                        ? '${formatDateIndo(_selectedDateRange!.start)} - ${formatDateIndo(_selectedDateRange!.end)}'
                        : 'Pilih Rentang...',
                    isSelected: _selectedDateRange != null &&
                        !_isCurrentMonthSelected() &&
                        !(_isSameDay(
                                _selectedDateRange!.start, DateTime.now()) &&
                            _isSameDay(
                                _selectedDateRange!.end, DateTime.now())),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        initialDateRange: _selectedDateRange,
                        locale: const Locale('id', 'ID'),
                      );
                      if (picked != null) {
                        setState(() => _selectedDateRange = picked);
                        setSheetState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Terapkan Filter'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isCurrentMonthSelected() {
    if (_selectedDateRange == null) return false;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return _isSameDay(_selectedDateRange!.start, start) &&
        _isSameDay(_selectedDateRange!.end, end);
  }

  void _showTransactionOptions(EnrichedTransaction etxn) {
    final txn = etxn.transaction;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etxn.categoryName ??
                          txn.description ??
                          'Rincian Transaksi',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatRupiah(txn.amount)} • ${formatDateIndo(txn.date)} • ${etxn.accountName ?? "Dompet"}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Ubah Transaksi'),
                subtitle:
                    const Text('Edit nominal, akun, kategori, atau tanggal'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.pushNamed('edit_transaction', extra: txn.id);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Hapus Transaksi',
                    style: TextStyle(color: AppColors.error)),
                subtitle: const Text('Hapus dan sesuaikan kembali saldo akun'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(etxn);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(EnrichedTransaction etxn) async {
    final txn = etxn.transaction;
    final itemDesc = etxn.categoryName ?? txn.description ?? 'Transaksi';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text(
          'Hapus transaksi "$itemDesc" senilai ${formatRupiah(txn.amount)}?\n\n'
          'Saldo akun "${etxn.accountName ?? 'terkait'}" akan disesuaikan kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(transactionRepositoryProvider).deleteTransaction(txn.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Transaksi dihapus & saldo dikembalikan')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.2) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? c : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? c : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final EnrichedTransaction enriched;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _TransactionItem({
    required this.enriched,
    this.onTap,
    required this.onDelete,
  });

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.adjustment:
        return 'Penyesuaian';
    }
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.refund:
        return AppColors.refund;
      case TransactionType.adjustment:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final txn = enriched.transaction;
    final isPositive = txn.type == TransactionType.income ||
        txn.type == TransactionType.refund;
    final color = _getTypeColor(txn.type);

    return Dismissible(
      key: Key('txn_${txn.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // Dialog handles actual dismissal
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  enriched.categoryIcon ?? (isPositive ? '📥' : '📤'),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enriched.categoryName ??
                          txn.description ??
                          _getTypeLabel(txn.type),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTypeLabel(txn.type),
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (enriched.accountName != null)
                          Text(
                            enriched.accountName!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                    if (txn.description != null && txn.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          txn.description!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isPositive ? "+" : "-"}${formatRupiah(txn.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
