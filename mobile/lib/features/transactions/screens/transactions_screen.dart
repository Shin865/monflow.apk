import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';

/// Layar daftar transaksi dengan filter tipe dan rentang tanggal.
///
/// Desain Achromatic Ledger:
/// - Angka tabular sejajar kanan untuk pemindaian nominal yang mudah.
/// - Polarity tenang (quiet green/red).
/// - Hirarki informasi bersih: Kategori & Catatan > Dompet & Tanggal.
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
    final tokens = context.tokens;
    final txnStream = ref
        .watch(transactionRepositoryProvider)
        .watchRecentTransactions(limit: 100);

    final isFiltered = _filterType != null || _selectedDateRange != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transaksi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: isFiltered ? tokens.dataHue : tokens.textSecondary,
                  size: 22,
                ),
                if (isFiltered)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tokens.dataHue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filter Transaksi',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: StreamBuilder<List<EnrichedTransaction>>(
        stream: txnStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MfLoading(message: 'Memuat riwayat transaksi...');
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
            return MfEmptyState(
              icon: Icons.receipt_long_outlined,
              title: isFiltered
                  ? 'Tidak ada transaksi cocok'
                  : 'Belum ada transaksi',
              subtitle: isFiltered
                  ? 'Coba sesuaikan filter tipe atau tanggal transaksi Anda'
                  : 'Catat transaksi pemasukan atau pengeluaran pertama Anda',
              actionLabel: isFiltered ? 'Reset Filter' : 'Catat Transaksi',
              onAction: () {
                if (isFiltered) {
                  setState(() {
                    _filterType = null;
                    _selectedDateRange = null;
                  });
                } else {
                  context.pushNamed('create_transaction');
                }
              },
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
              if (isFiltered)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.surfaceRaised,
                    border: Border(
                      bottom: BorderSide(color: tokens.borderHairline),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt_outlined,
                          size: 14, color: tokens.dataHue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (_filterType != null)
                              'Tipe: ${_getTypeFilterName(_filterType!)}',
                            if (_selectedDateRange != null)
                              'Periode: ${formatDateIndo(_selectedDateRange!.start)} - ${formatDateIndo(_selectedDateRange!.end)}',
                          ].join(' • '),
                          style: TextStyle(
                              fontSize: 11,
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w500),
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
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: tokens.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                      horizontal: tokens.pad, vertical: 12),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateKey = grouped.keys.elementAt(index);
                    final items = grouped[dateKey]!;

                    // Hitung total net per hari
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateKey,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textMuted,
                                ),
                              ),
                              Text(
                                '${dailyNet >= 0 ? "+" : ""}${formatRupiah(dailyNet)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: dailyNet >= 0
                                      ? tokens.income
                                      : tokens.expense,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
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
                        const SizedBox(height: 6),
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
        backgroundColor: tokens.primaryButtonBg,
        foregroundColor: tokens.primaryButtonInk,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusControl),
        ),
        onPressed: () => context.pushNamed('create_transaction'),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Catat',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
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
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(tokens.radiusCard)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Transaksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
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
                      child: Text('Reset',
                          style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'TIPE TRANSAKSI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: tokens.textMuted,
                ),
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
                    color: tokens.income,
                    onTap: () {
                      setState(() => _filterType = TransactionType.income);
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Pengeluaran',
                    isSelected: _filterType == TransactionType.expense,
                    color: tokens.expense,
                    onTap: () {
                      setState(() => _filterType = TransactionType.expense);
                      setSheetState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Refund',
                    isSelected: _filterType == TransactionType.refund,
                    color: tokens.warning,
                    onTap: () {
                      setState(() => _filterType = TransactionType.refund);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'RENTANG WAKTU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: tokens.textMuted,
                ),
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
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Terapkan Filter'),
                ),
              ),
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
    final tokens = context.tokens;
    final txn = etxn.transaction;

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(tokens.radiusCard)),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatRupiah(txn.amount)} • ${formatDateIndo(txn.date)} • ${etxn.accountName ?? "Dompet"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: tokens.borderHairline),
              ListTile(
                leading: Icon(Icons.edit_outlined,
                    color: tokens.textSecondary, size: 20),
                title: Text('Ubah Transaksi',
                    style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Edit nominal, akun, kategori, atau tanggal',
                    style: TextStyle(color: tokens.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.pushNamed('edit_transaction', extra: txn.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: tokens.expense, size: 20),
                title: Text('Hapus Transaksi',
                    style: TextStyle(
                        color: tokens.expense,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                subtitle: Text('Hapus dan kembalikan penyesuaian saldo akun',
                    style: TextStyle(color: tokens.textMuted, fontSize: 11)),
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

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Transaksi',
      message:
          'Hapus transaksi "$itemDesc" senilai ${formatRupiah(txn.amount)}?\n\n'
          'Saldo dompet "${etxn.accountName ?? 'terkait'}" akan disesuaikan kembali.',
      confirmLabel: 'Hapus',
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
    final tokens = context.tokens;
    final effectiveColor = color ?? tokens.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? tokens.surfaceRaised : tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radiusChip),
          border: Border.all(
            color: isSelected ? effectiveColor : tokens.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? effectiveColor : tokens.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final txn = enriched.transaction;
    final isPositive = txn.type == TransactionType.income ||
        txn.type == TransactionType.refund;

    final amountColor = isPositive ? tokens.income : tokens.expense;

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
          color: tokens.expenseBg,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
        ),
        child: Icon(Icons.delete_outline_rounded, color: tokens.expense),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            border: Border.all(color: tokens.borderHairline),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(tokens.radiusControl),
                  border: Border.all(color: tokens.border),
                ),
                child: Text(
                  enriched.categoryIcon ?? (isPositive ? '📥' : '📤'),
                  style: const TextStyle(fontSize: 16),
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _getTypeLabel(txn.type),
                          style: TextStyle(
                            fontSize: 10,
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (enriched.accountName != null) ...[
                          Text(' • ',
                              style: TextStyle(
                                  fontSize: 10, color: tokens.textMuted)),
                          Expanded(
                            child: Text(
                              enriched.accountName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (txn.description != null &&
                        txn.description!.isNotEmpty &&
                        enriched.categoryName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          txn.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                          ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
