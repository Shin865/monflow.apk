import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';
import 'package:money_flow/data/repositories/savings_goal_repository.dart';
import 'package:money_flow/domain/rules/purchase_plan_rules.dart';
import 'package:money_flow/domain/rules/savings_goal_rules.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Target & Perencanaan'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.flag_rounded), text: 'Target Tabungan'),
            Tab(
                icon: Icon(Icons.shopping_bag_rounded),
                text: 'Rencana Pembelian'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SavingsGoalsTab(),
          _PurchasePlansTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Target Baru' : 'Rencana Baru',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddGoalDialog(context, ref);
          } else {
            _showAddPlanDialog(context, ref);
          }
        },
      ),
    );
  }

  // ============================================================
  // DIALOGS: ADD GOAL
  // ============================================================

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    DateTime? selectedDate;
    bool isVirtual = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Target Tabungan Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tujuan Tabungan * (misal Dana Darurat)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Target Nominal (Rp) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: currentCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Dana Saat Ini (Rp)'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedDate == null
                        ? 'Pilih Target Tanggal (opsional)'
                        : 'Target: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alokasi Virtual',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'Hanya melacak target tanpa memindahkan uang secara fisik antar rekening',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  value: isVirtual,
                  onChanged: (val) => setState(() => isVirtual = val),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final target = int.tryParse(targetCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;
                final current = int.tryParse(currentCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;

                if (name.isEmpty || target <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Nama dan target nominal harus diisi')),
                  );
                  return;
                }

                await ref.read(savingsGoalRepositoryProvider).create(
                      name: name,
                      targetAmount: target,
                      currentAmount: current,
                      targetDate: selectedDate,
                      isVirtual: isVirtual,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS: ADD PURCHASE PLAN
  // ============================================================

  void _showAddPlanDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final allocCtrl = TextEditingController(text: '0');
    final catCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    PlanPriority priority = PlanPriority.medium;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rencana Pembelian Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nama Barang / Tujuan * (misal Laptop)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Harga / Target Nominal (Rp) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: allocCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Dana Teralokasi Saat Ini (Rp)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PlanPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Prioritas'),
                  items: const [
                    DropdownMenuItem(
                        value: PlanPriority.low, child: Text('Rendah (Low)')),
                    DropdownMenuItem(
                        value: PlanPriority.medium,
                        child: Text('Sedang (Medium)')),
                    DropdownMenuItem(
                        value: PlanPriority.high, child: Text('Tinggi (High)')),
                    DropdownMenuItem(
                        value: PlanPriority.urgent,
                        child: Text('Mendesak (Urgent)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => priority = val);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedDate == null
                        ? 'Tenggat Waktu Pembelian (opsional)'
                        : 'Tenggat: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Kategori Barang (misal Elektronik)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tautan / Link Produk (opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final target = int.tryParse(targetCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;
                final alloc = int.tryParse(allocCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;

                if (name.isEmpty || target <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Nama dan target nominal harus diisi')),
                  );
                  return;
                }

                await ref.read(purchasePlanRepositoryProvider).create(
                      name: name,
                      targetAmount: target,
                      allocatedAmount: alloc,
                      targetDate: selectedDate,
                      priority: priority,
                      category: catCtrl.text.trim().isEmpty
                          ? null
                          : catCtrl.text.trim(),
                      urlLink: urlCtrl.text.trim().isEmpty
                          ? null
                          : urlCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 1: SAVINGS GOALS
// ============================================================

class _SavingsGoalsTab extends ConsumerWidget {
  const _SavingsGoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryStream =
        ref.watch(savingsGoalRepositoryProvider).watchSummary();
    final goalsStream = ref.watch(savingsGoalRepositoryProvider).watchGoals();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<SavingsGoalSummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data ??
                  const SavingsGoalSummary(
                    totalTarget: 0,
                    totalSaved: 0,
                    activeGoalsCount: 0,
                    achievedGoalsCount: 0,
                  );

              final progressPct = summary.totalTarget > 0
                  ? (summary.totalSaved / summary.totalTarget * 100.0)
                  : 0.0;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Total Target Tabungan',
                          value: formatRupiah(summary.totalTarget),
                          color: Colors.white,
                        ),
                        _StatBox(
                          label: 'Total Terkumpul',
                          value: formatRupiah(summary.totalSaved),
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: (progressPct / 100.0).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: Colors.amberAccent,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Terkumpul ${progressPct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        Text(
                            '${summary.activeGoalsCount} Aktif • ${summary.achievedGoalsCount} Tercapai',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Daftar Target Tabungan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          StreamBuilder<List<SavingsGoal>>(
            stream: goalsStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                        'Belum ada target tabungan.\nTekan + untuk menambah target.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)),
                  ),
                );
              }

              final now = DateTime.now();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final g = list[index];
                  final progress = SavingsGoalRules.progress(
                    targetAmount: g.targetAmount,
                    currentAmount: g.currentAmount,
                  );
                  final remaining = SavingsGoalRules.remaining(
                    targetAmount: g.targetAmount,
                    currentAmount: g.currentAmount,
                  );
                  final monthly = SavingsGoalRules.monthlyRequired(
                    targetAmount: g.targetAmount,
                    currentAmount: g.currentAmount,
                    targetDate: g.targetDate,
                    today: now,
                  );
                  final isAchieved = g.status == SavingsGoalStatus.achieved;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAchieved
                            ? AppColors.income.withOpacity(0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(g.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'add_saving') {
                                  _showAddSavingsContributionDialog(
                                      context, ref, g);
                                } else if (val == 'delete') {
                                  ref
                                      .read(savingsGoalRepositoryProvider)
                                      .delete(g.id);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'add_saving',
                                    child: Text('Tambah Tabungan')),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Hapus Target')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (progress / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          color:
                              isAchieved ? AppColors.income : AppColors.primary,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Terkumpul: ${formatRupiah(g.currentAmount)} / ${formatRupiah(g.targetAmount)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                            Text('${progress.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAchieved
                                        ? AppColors.income
                                        : Colors.white)),
                          ],
                        ),
                        if (!isAchieved) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sisa: ${formatRupiah(remaining)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white54)),
                              if (monthly > 0)
                                Text('Perlu: ${formatRupiah(monthly)}/bln',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.income)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddSavingsContributionDialog(
      BuildContext context, WidgetRef ref, SavingsGoal goal) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tabung untuk: ${goal.name}'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Nominal Tambahan Tabungan (Rp)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text
                      .replaceAll('.', '')
                      .replaceAll(',', '')) ??
                  0;
              if (amount > 0) {
                await ref
                    .read(savingsGoalRepositoryProvider)
                    .addContribution(goal.id, amount);
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: PURCHASE PLANS
// ============================================================

class _PurchasePlansTab extends ConsumerWidget {
  const _PurchasePlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryStream =
        ref.watch(purchasePlanRepositoryProvider).watchSummary();
    final plansStream = ref.watch(purchasePlanRepositoryProvider).watchPlans();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<PurchasePlanSummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data ??
                  const PurchasePlanSummary(
                    totalActiveTarget: 0,
                    totalAllocated: 0,
                    totalHistoryTarget: 0,
                    activeCount: 0,
                    monthlyCommittedSavings: 0,
                  );

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF831843), Color(0xFF9D174D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Target Belanja Aktif',
                          value: formatRupiah(summary.totalActiveTarget),
                          color: Colors.white,
                        ),
                        _StatBox(
                          label: 'Alokasi Terkumpul',
                          value: formatRupiah(summary.totalAllocated),
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Komitmen Bulanan',
                          value: formatRupiah(summary.monthlyCommittedSavings),
                          color: AppColors.income,
                        ),
                        _StatBox(
                          label: 'Rencana Aktif',
                          value: '${summary.activeCount} Barang',
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Daftar Rencana Pembelian',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          StreamBuilder<List<PurchasePlan>>(
            stream: plansStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                        'Belum ada rencana pembelian.\nTekan + untuk menambah rencana belanja.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)),
                  ),
                );
              }

              final now = DateTime.now();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = list[index];
                  final progress = PurchasePlanRules.progress(
                    targetAmount: p.targetAmount,
                    currentSaving: p.allocatedAmount,
                  );
                  final monthly = PurchasePlanRules.monthlyRequired(
                    targetAmount: p.targetAmount,
                    currentSaving: p.allocatedAmount,
                    targetDate: p.targetDate,
                    today: now,
                  );
                  final isAchieved = p.status == PlanStatus.achieved;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAchieved
                            ? AppColors.income.withOpacity(0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(
                                  '${p.category ?? "Belanja"} • Prioritas: ${p.priority.name.toUpperCase()}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'add_saving') {
                                  _showAddPlanSavingDialog(context, ref, p);
                                } else if (val == 'complete') {
                                  _showCompletePlanDialog(context, ref, p);
                                } else if (val == 'delete') {
                                  ref
                                      .read(purchasePlanRepositoryProvider)
                                      .delete(p.id);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'add_saving',
                                    child: Text('Tambah Alokasi')),
                                if (!isAchieved)
                                  const PopupMenuItem(
                                      value: 'complete',
                                      child: Text('Realisasi / Beli Sekarang')),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Batalkan Rencana')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (progress / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          color:
                              isAchieved ? AppColors.income : AppColors.primary,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Alokasi: ${formatRupiah(p.allocatedAmount)} / ${formatRupiah(p.targetAmount)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                            Text('${progress.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAchieved
                                        ? AppColors.income
                                        : Colors.white)),
                          ],
                        ),
                        if (!isAchieved && monthly > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Perlu ditabung: ${formatRupiah(monthly)} / bulan',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.income)),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddPlanSavingDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Alokasi: ${plan.name}'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Nominal Tambahan Alokasi (Rp)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text
                      .replaceAll('.', '')
                      .replaceAll(',', '')) ??
                  0;
              if (amount > 0) {
                await ref
                    .read(purchasePlanRepositoryProvider)
                    .addSaving(plan.id, amount);
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCompletePlanDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            ref.read(accountRepositoryProvider).getActiveAccounts(),
            ref
                .read(categoryRepositoryProvider)
                .getByType(CategoryType.expense),
          ]),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return const AlertDialog(
                content: Center(child: CircularProgressIndicator()),
              );
            }

            final accounts = snapshot.data![0] as List<Account>;
            final categories = snapshot.data![1] as List<Category>;

            int? selectedAccId = accounts.isNotEmpty ? accounts.first.id : null;
            int? selectedCatId =
                categories.isNotEmpty ? categories.first.id : null;
            final amountCtrl =
                TextEditingController(text: plan.targetAmount.toString());

            return StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                title: Text('Realisasi Beli: ${plan.name}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Realisasi ini akan memotong saldo dompet Anda dan mencatat transaksi pengeluaran.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Nominal Belanja Aktual (Rp)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedAccId,
                      decoration: const InputDecoration(
                          labelText: 'Dompet Sumber Dana'),
                      items: accounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                    '${a.name} (${formatRupiah(a.balance)})'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedAccId = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedCatId,
                      decoration: const InputDecoration(
                          labelText: 'Kategori Pengeluaran'),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCatId = val);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal')),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedAccId == null || selectedCatId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Pilih dompet dan kategori')),
                        );
                        return;
                      }

                      final amount = int.tryParse(amountCtrl.text
                              .replaceAll('.', '')
                              .replaceAll(',', '')) ??
                          plan.targetAmount;

                      await ref
                          .read(purchasePlanRepositoryProvider)
                          .completePlan(
                            plan.id,
                            accountId: selectedAccId!,
                            categoryId: selectedCatId!,
                            amount: amount,
                          );

                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Beli & Selesaikan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }
}
