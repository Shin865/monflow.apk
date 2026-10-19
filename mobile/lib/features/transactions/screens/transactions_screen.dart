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
            icon: const Icon(Icons.filter_list_rounded),
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
                    _filterType != null
                        ? 'Tidak ada transaksi dengan filter ini'
                        : 'Catat transaksi pertamamu',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
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

          return ListView.builder(
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
                        onDelete: () => _confirmDelete(etxn.transaction),
                      )),
                  const SizedBox(height: 8),
                ],
              );
            },
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Transaksi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Semua',
                  isSelected: _filterType == null,
                  onTap: () {
                    setState(() => _filterType = null);
                    Navigator.pop(ctx);
                  },
                ),
                _FilterChip(
                  label: 'Pemasukan',
                  isSelected: _filterType == TransactionType.income,
                  color: AppColors.income,
                  onTap: () {
                    setState(() => _filterType = TransactionType.income);
                    Navigator.pop(ctx);
                  },
                ),
                _FilterChip(
                  label: 'Pengeluaran',
                  isSelected: _filterType == TransactionType.expense,
                  color: AppColors.expense,
                  onTap: () {
                    setState(() => _filterType = TransactionType.expense);
                    Navigator.pop(ctx);
                  },
                ),
                _FilterChip(
                  label: 'Refund',
                  isSelected: _filterType == TransactionType.refund,
                  color: AppColors.refund,
                  onTap: () {
                    setState(() => _filterType = TransactionType.refund);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Transaction txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text(
          'Hapus transaksi ${formatRupiah(txn.amount)}?\n'
          'Saldo akun akan disesuaikan kembali.',
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
  final VoidCallback onDelete;

  const _TransactionItem({
    required this.enriched,
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
    );
  }
}
