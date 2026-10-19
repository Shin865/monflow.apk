import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/budget_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';

/// Layar Detail Anggaran Kategori
class CategoryBudgetDetailScreen extends ConsumerStatefulWidget {
  final int categoryId;
  final int year;
  final int month;

  const CategoryBudgetDetailScreen({
    super.key,
    required this.categoryId,
    required this.year,
    required this.month,
  });

  @override
  ConsumerState<CategoryBudgetDetailScreen> createState() =>
      _CategoryBudgetDetailScreenState();
}

class _CategoryBudgetDetailScreenState
    extends ConsumerState<CategoryBudgetDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetRepo = ref.watch(budgetRepositoryProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);

    final periodDate = DateTime(widget.year, widget.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Anggaran Kategori'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          categoryRepo.getById(widget.categoryId),
          budgetRepo.getMonthlyBudgetSummary(widget.year, widget.month),
          budgetRepo.getCategoryTransactions(
              widget.categoryId, widget.year, widget.month),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final category = snapshot.data![0] as Category?;
          final summary = snapshot.data![1] as MonthlyBudgetSummary;
          final transactions = snapshot.data![2] as List<Transaction>;

          if (category == null) {
            return const Center(child: Text('Kategori tidak ditemukan.'));
          }

          final item = summary.items.firstWhere(
            (i) => i.category.id == widget.categoryId,
            orElse: () => CategoryBudgetSummary(
              budget: null,
              category: category,
              budgetAmount: 0,
              actualSpent: 0,
              remaining: 0,
              percentage: 0.0,
              alertStatus: BudgetAlertStatus.safe,
            ),
          );

          Color badgeColor;
          String badgeText;
          switch (item.alertStatus) {
            case BudgetAlertStatus.safe:
              badgeColor = AppColors.income;
              badgeText = 'Aman';
              break;
            case BudgetAlertStatus.nearLimit:
              badgeColor = AppColors.warning;
              badgeText = 'Mendekati Batas';
              break;
            case BudgetAlertStatus.exceeded:
              badgeColor = AppColors.expense;
              badgeText = 'Lewat Batas';
              break;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(category.icon ?? '📁',
                              style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(category.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                DateFormat('MMMM yyyy', 'id_ID')
                                    .format(periodDate),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (item.hasBudget)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatColumn(
                          label: 'Anggaran',
                          value: formatRupiah(item.budgetAmount),
                          color: AppColors.primary,
                        ),
                        _StatColumn(
                          label: 'Realisasi',
                          value: formatRupiah(item.actualSpent),
                          color: AppColors.expense,
                        ),
                        _StatColumn(
                          label: 'Sisa',
                          value: formatRupiah(item.remaining),
                          color: item.remaining >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ],
                    ),
                    if (item.hasBudget) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (item.actualSpent / item.budgetAmount)
                              .clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaksi Terkait',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${transactions.length} transaksi',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),

              if (transactions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Belum ada transaksi pada periode ini.'),
                  ),
                )
              else
                ...transactions.map((tx) {
                  final isRefund = tx.type == TransactionType.refund;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isRefund
                            ? AppColors.income.withOpacity(0.15)
                            : AppColors.expense.withOpacity(0.15),
                        child: Icon(
                          isRefund
                              ? Icons.undo_rounded
                              : Icons.arrow_upward_rounded,
                          color:
                              isRefund ? AppColors.income : AppColors.expense,
                          size: 18,
                        ),
                      ),
                      title: Text(tx.description ??
                          (isRefund ? 'Pengembalian Dana' : 'Pengeluaran')),
                      subtitle: Text(formatDate(tx.date)),
                      trailing: Text(
                        '${isRefund ? '+' : '-'}${formatRupiah(tx.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isRefund ? AppColors.income : AppColors.expense,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
