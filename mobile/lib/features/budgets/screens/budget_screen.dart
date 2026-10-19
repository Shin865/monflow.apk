import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/budget_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';

/// Layar Anggaran (Budget) Bulanan per Kategori
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late DateTime _selectedPeriod;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedPeriod = DateTime(now.year, now.month);
  }

  void _previousMonth() {
    setState(() {
      _selectedPeriod =
          DateTime(_selectedPeriod.year, _selectedPeriod.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedPeriod =
          DateTime(_selectedPeriod.year, _selectedPeriod.month + 1);
    });
  }

  void _showSetBudgetDialog(BuildContext context,
      {Category? initialCategory, Budget? currentBudget}) {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final budgetRepo = ref.read(budgetRepositoryProvider);

    final amountController = TextEditingController(
      text: currentBudget != null ? currentBudget.amount.toString() : '',
    );
    int? selectedCatId = initialCategory?.id ?? currentBudget?.categoryId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(currentBudget != null
              ? 'Edit Anggaran'
              : 'Atur Anggaran Kategori'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (initialCategory == null && currentBudget == null) ...[
                  const Text('Pilih Kategori Pengeluaran',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  FutureBuilder<List<Category>>(
                    future: categoryRepo.getByType(CategoryType.expense),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final categories = snapshot.data!;
                      if (selectedCatId == null && categories.isNotEmpty) {
                        selectedCatId = categories.first.id;
                      }
                      return DropdownButtonFormField<int>(
                        value: selectedCatId,
                        dropdownColor: AppColors.surface,
                        items: categories.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Row(
                              children: [
                                Text(c.icon ?? '📁',
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedCatId = val),
                        decoration:
                            const InputDecoration(labelText: 'Kategori'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(initialCategory?.icon ?? '📁',
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            initialCategory?.name ?? 'Kategori',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Anggaran (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Periode: ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedPeriod)}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            if (currentBudget != null)
              TextButton(
                onPressed: () async {
                  await budgetRepo.deleteBudget(currentBudget.id);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  setState(() {});
                },
                child: const Text('Hapus',
                    style: TextStyle(color: AppColors.expense)),
              ),
            FilledButton(
              onPressed: () async {
                final amount = int.tryParse(amountController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (amount <= 0 || selectedCatId == null) return;

                await budgetRepo.setBudget(
                  categoryId: selectedCatId!,
                  year: _selectedPeriod.year,
                  month: _selectedPeriod.month,
                  amount: amount,
                );

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(() {});
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetRepo = ref.watch(budgetRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran (Budget)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Anggaran',
            onPressed: () => _showSetBudgetDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Periode Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _previousMonth,
                  tooltip: 'Bulan Sebelumnya',
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM yyyy', 'id_ID').format(_selectedPeriod),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                  tooltip: 'Bulan Berikutnya',
                ),
              ],
            ),
          ),

          // Konten Utama Anggaran
          Expanded(
            child: FutureBuilder<MonthlyBudgetSummary>(
              future: budgetRepo.getMonthlyBudgetSummary(
                  _selectedPeriod.year, _selectedPeriod.month),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.expense, size: 48),
                          const SizedBox(height: 12),
                          Text('Gagal memuat anggaran: ${snapshot.error}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Coba Lagi')),
                        ],
                      ),
                    ),
                  );
                }

                final summary = snapshot.data!;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Kartu Ringkasan Total
                    _TotalBudgetCard(summary: summary),
                    const SizedBox(height: 20),

                    // Header Daftar Kategori
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Anggaran per Kategori',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${summary.items.where((i) => i.hasBudget).length} diatur',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (summary.items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child:
                              Text('Belum ada kategori pengeluaran tersedia.'),
                        ),
                      )
                    else
                      ...summary.items.map((item) => _CategoryBudgetCard(
                            item: item,
                            onTap: () {
                              context.pushNamed(
                                'category_budget_detail',
                                extra: {
                                  'categoryId': item.category.id,
                                  'year': _selectedPeriod.year,
                                  'month': _selectedPeriod.month,
                                },
                              ).then((_) => setState(() {}));
                            },
                            onEdit: () {
                              _showSetBudgetDialog(
                                context,
                                initialCategory: item.category,
                                currentBudget: item.budget,
                              );
                            },
                          )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBudgetCard extends StatelessWidget {
  final MonthlyBudgetSummary summary;

  const _TotalBudgetCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    Color progressColor;
    if (summary.totalPercentage > 100) {
      progressColor = AppColors.expense;
    } else if (summary.totalPercentage >= 80) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.income;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceLight.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pengeluaran vs Anggaran',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary.totalPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatRupiah(summary.totalSpent),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                'dari ${formatRupiah(summary.totalBudgeted)}',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.totalBudgeted > 0
                  ? (summary.totalSpent / summary.totalBudgeted).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 8,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summary.totalRemaining >= 0
                    ? 'Sisa Anggaran: ${formatRupiah(summary.totalRemaining)}'
                    : 'Over Budget: ${formatRupiah(summary.totalRemaining.abs())}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: summary.totalRemaining >= 0
                      ? AppColors.textMuted
                      : AppColors.expense,
                ),
              ),
              if (summary.totalRemaining < 0)
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppColors.expense),
                    SizedBox(width: 4),
                    Text('Melewati Batas',
                        style:
                            TextStyle(color: AppColors.expense, fontSize: 11)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  final CategoryBudgetSummary item;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CategoryBudgetCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.alertStatus == BudgetAlertStatus.exceeded
              ? AppColors.expense.withOpacity(0.5)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(item.category.icon ?? '📁',
                        style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          item.hasBudget
                              ? 'Anggaran: ${formatRupiah(item.budgetAmount)}'
                              : 'Belum ada anggaran',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (item.hasBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.textMuted),
                    onPressed: onEdit,
                    tooltip: 'Atur Anggaran',
                  ),
                ],
              ),
              if (item.hasBudget) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        (item.actualSpent / item.budgetAmount).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terpakai: ${formatRupiah(item.actualSpent)} (${item.percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      item.remaining >= 0
                          ? 'Sisa: ${formatRupiah(item.remaining)}'
                          : 'Lebih: ${formatRupiah(item.remaining.abs())}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.remaining >= 0
                            ? AppColors.textPrimary
                            : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ] else if (item.actualSpent > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Pengeluaran aktual: ${formatRupiah(item.actualSpent)}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.expense),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
