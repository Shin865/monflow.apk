import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';

/// Halaman Rencana Pembelian (Purchase Planning).
///
/// Memenuhi Ketentuan Master Prompt:
/// - Target Tabungan (Savings Goals) telah dihapus sepenuhnya dari perencanaan.
/// - Tidak ada konsep "nominal terkumpul" atau progres alokasi tabungan.
/// - Menampilkan nama barang, harga rencana, tanggal, kategori, prioritas, dan status.
/// - CRUD lengkap: Tambah, Lihat, Edit, Hapus dengan dialog konfirmasi.
/// - Realisasi langsung memotong saldo dompet yang dipilih dan mencatat pengeluaran secara atomik.
/// - Dilengkapi dialog riwayat audit per rencana (History Rencana Pembelian).
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  int _statusFilter = 0; // 0 = Semua, 1 = Aktif, 2 = Terealisasi

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summaryStream =
        ref.watch(purchasePlanRepositoryProvider).watchSummary();
    final plansStream = ref.watch(purchasePlanRepositoryProvider).watchPlans();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rencana Pembelian'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Ringkasan Rencana Pembelian
            StreamBuilder<PurchasePlanSummary>(
              stream: summaryStream,
              builder: (context, snapshot) {
                final summary = snapshot.data ??
                    const PurchasePlanSummary(
                      totalActiveTarget: 0,
                      totalHistoryTarget: 0,
                      activeCount: 0,
                      achievedCount: 0,
                    );

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF831843), Color(0xFFBE185D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF831843).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shopping_bag_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Total Kebutuhan Belanja Aktif',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatRupiah(summary.totalActiveTarget),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeaderStat(
                            label: 'Rencana Aktif',
                            value: '${summary.activeCount} Barang',
                          ),
                          _buildHeaderStat(
                            label: 'Terealisasi',
                            value: '${summary.achievedCount} Barang',
                          ),
                          _buildHeaderStat(
                            label: 'Total Terealisasi',
                            value: formatRupiah(summary.totalHistoryTarget),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 2. Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(0, 'Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'Aktif / Belum Terealisasi'),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, 'Sudah Terealisasi'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Daftar Rencana Pembelian
            StreamBuilder<List<PurchasePlan>>(
              stream: plansStream,
              builder: (context, snapshot) {
                var list = snapshot.data ?? [];
                if (_statusFilter == 1) {
                  list =
                      list.where((p) => p.status == PlanStatus.active).toList();
                } else if (_statusFilter == 2) {
                  list = list
                      .where((p) => p.status == PlanStatus.achieved)
                      .toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 56,
                              color: isDark ? Colors.white30 : Colors.black26),
                          const SizedBox(height: 12),
                          Text(
                            _statusFilter == 0
                                ? 'Belum ada rencana pembelian.\nTekan + untuk membuat rencana baru.'
                                : 'Tidak ada rencana pada kategori filter ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = list[index];
                    return _buildPlanCard(context, ref, plan, isDark);
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Rencana Baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddPlanDialog(context, ref),
      ),
    );
  }

  Widget _buildHeaderStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _statusFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = index);
      },
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    WidgetRef ref,
    PurchasePlan plan,
    bool isDark,
  ) {
    final isAchieved = plan.status == PlanStatus.achieved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAchieved
              ? AppColors.income.withOpacity(0.5)
              : (isDark ? AppColors.border : Colors.grey.shade300),
          width: isAchieved ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isDark ? Colors.white : Colors.black87,
                        decoration: isAchieved
                            ? TextDecoration.none
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (plan.category != null && plan.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plan.category!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                _priorityColor(plan.priority).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Prioritas ${_priorityName(plan.priority)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _priorityColor(plan.priority),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: isDark ? Colors.white70 : Colors.black54),
                onSelected: (val) {
                  if (val == 'history') {
                    _showHistoryDialog(context, ref, plan);
                  } else if (val == 'edit') {
                    _showEditPlanDialog(context, ref, plan);
                  } else if (val == 'unrealize') {
                    _showUnrealizeConfirmDialog(context, ref, plan);
                  } else if (val == 'delete') {
                    _showDeleteConfirmDialog(context, ref, plan);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Riwayat Perubahan'),
                      ],
                    ),
                  ),
                  if (!isAchieved)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Rencana'),
                        ],
                      ),
                    ),
                  if (isAchieved)
                    const PopupMenuItem(
                      value: 'unrealize',
                      child: Row(
                        children: [
                          Icon(Icons.undo_rounded,
                              size: 18, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text('Batalkan Realisasi'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.expense),
                        SizedBox(width: 8),
                        Text('Hapus Rencana'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Harga / Nominal Rencana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Harga Rencana',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(plan.targetAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (plan.targetDate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target Realisasi',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(plan.targetDate!),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.description!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          // Tombol status & Realisasi
          if (!isAchieved)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Realisasikan & Potong Saldo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showCompletePlanDialog(context, ref, plan),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.incomeBg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.income.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.income, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Telah Direalisasikan (Saldo telah dipotong)',
                      style: TextStyle(
                        color: AppColors.income,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _priorityColor(PlanPriority priority) {
    switch (priority) {
      case PlanPriority.low:
        return Colors.blue;
      case PlanPriority.medium:
        return Colors.amber.shade700;
      case PlanPriority.high:
        return Colors.orange.shade700;
      case PlanPriority.urgent:
        return Colors.red;
    }
  }

  String _priorityName(PlanPriority priority) {
    switch (priority) {
      case PlanPriority.low:
        return 'Rendah';
      case PlanPriority.medium:
        return 'Sedang';
      case PlanPriority.high:
        return 'Tinggi';
      case PlanPriority.urgent:
        return 'Mendesak';
    }
  }

  // ============================================================
  // DIALOG: TAMBAH RENCANA BARU
  // ============================================================

  void _showAddPlanDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? selectedDate;
    PlanPriority selectedPriority = PlanPriority.medium;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rencana Pembelian Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Barang *',
                    hintText: 'Misal: Laptop Baru, Sepatu',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga / Nominal Rencana (Rp) *',
                    hintText: 'Misal: 15.000.000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Barang',
                    hintText: 'Misal: Elektronik, Pakaian, Hobi',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlanPriority>(
                  value: selectedPriority,
                  decoration:
                      const InputDecoration(labelText: 'Tingkat Prioritas'),
                  items: PlanPriority.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(_priorityName(p)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedPriority = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedDate == null
                        ? 'Pilih Target Tanggal (opsional)'
                        : 'Target: ${formatDate(selectedDate!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 60)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tautan / Link Produk (opsional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Rencana',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = int.tryParse(priceCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;

                if (name.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Nama dan harga rencana harus diisi dengan benar.'),
                      backgroundColor: AppColors.expense,
                    ),
                  );
                  return;
                }

                await ref.read(purchasePlanRepositoryProvider).create(
                      name: name,
                      targetAmount: price,
                      targetDate: selectedDate,
                      priority: selectedPriority,
                      category: categoryCtrl.text.trim().isEmpty
                          ? null
                          : categoryCtrl.text.trim(),
                      urlLink: urlCtrl.text.trim().isEmpty
                          ? null
                          : urlCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan Rencana'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG: EDIT RENCANA
  // ============================================================

  void _showEditPlanDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) {
    final nameCtrl = TextEditingController(text: plan.name);
    final priceCtrl = TextEditingController(text: plan.targetAmount.toString());
    final categoryCtrl = TextEditingController(text: plan.category ?? '');
    final urlCtrl = TextEditingController(text: plan.urlLink ?? '');
    final descCtrl = TextEditingController(text: plan.description ?? '');
    DateTime? selectedDate = plan.targetDate;
    PlanPriority selectedPriority = plan.priority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Rencana Pembelian'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Barang *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga / Nominal Rencana (Rp) *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlanPriority>(
                  value: selectedPriority,
                  decoration:
                      const InputDecoration(labelText: 'Tingkat Prioritas'),
                  items: PlanPriority.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(_priorityName(p)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedPriority = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedDate == null
                        ? 'Pilih Target Tanggal (opsional)'
                        : 'Target: ${formatDate(selectedDate!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'Tautan Produk'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = int.tryParse(priceCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;

                if (name.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Nama dan harga rencana harus diisi dengan benar.'),
                      backgroundColor: AppColors.expense,
                    ),
                  );
                  return;
                }

                await ref.read(purchasePlanRepositoryProvider).update(
                      plan.id,
                      name: name,
                      targetAmount: price,
                      targetDate: selectedDate,
                      priority: selectedPriority,
                      category: categoryCtrl.text.trim().isEmpty
                          ? null
                          : categoryCtrl.text.trim(),
                      urlLink: urlCtrl.text.trim().isEmpty
                          ? null
                          : urlCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG: REALISASI RENCANA BELI (POTONG SALDO SECARA ATOMIK)
  // ============================================================

  void _showCompletePlanDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) async {
    final accounts =
        await ref.read(accountRepositoryProvider).getActiveAccounts();
    final expenseCategories = await ref
        .read(categoryRepositoryProvider)
        .getByType(CategoryType.expense);

    if (!context.mounted) return;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Belum ada akun dompet aktif. Tambahkan dompet terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final amountCtrl =
        TextEditingController(text: plan.targetAmount.toString());
    final notesCtrl = TextEditingController(text: 'Realisasi: ${plan.name}');
    int selectedAccountId = accounts.first.id;
    int selectedCategoryId =
        expenseCategories.isNotEmpty ? expenseCategories.first.id : 1;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.income, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Realisasikan: ${plan.name}'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo akun yang dipilih akan langsung dipotong dan transaksi pengeluaran aktual akan dicatat.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal Aktual Pengeluaran (Rp) *',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedAccountId,
                  decoration: const InputDecoration(
                      labelText: 'Sumber Dana (Dompet) *'),
                  items: accounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child:
                                Text('${a.name} (${formatRupiah(a.balance)})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedAccountId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (expenseCategories.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                        labelText: 'Kategori Pengeluaran'),
                    items: expenseCategories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.icon ?? "🛍️"} ${c.name}'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategoryId = val);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Tanggal Transaksi: ${formatDate(selectedDate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Catatan Pengeluaran'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.income),
              onPressed: () async {
                final amt = int.tryParse(amountCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;

                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nominal pembelian harus lebih dari 0.'),
                      backgroundColor: AppColors.expense,
                    ),
                  );
                  return;
                }

                try {
                  await ref.read(purchasePlanRepositoryProvider).completePlan(
                        plan.id,
                        accountId: selectedAccountId,
                        categoryId: selectedCategoryId,
                        amount: amt,
                        date: selectedDate,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Rencana "${plan.name}" berhasil direalisasikan. Saldo telah dipotong ${formatRupiah(amt)}.'),
                        backgroundColor: AppColors.income,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal merealisasikan: $e'),
                        backgroundColor: AppColors.expense,
                      ),
                    );
                  }
                }
              },
              child: const Text('Konfirmasi & Potong Saldo'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG: BATALKAN REALISASI (PEMBALIKAN TRANSAKSI)
  // ============================================================

  void _showUnrealizeConfirmDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Realisasi Rencana?'),
        content: Text(
          'Membatalkan realisasi akan menghapus transaksi pengeluaran terkait dan mengembalikan saldo dompet sebesar ${formatRupiah(plan.allocatedAmount)}. Status rencana akan dikembalikan ke Aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              try {
                await ref
                    .read(purchasePlanRepositoryProvider)
                    .cancelRealization(plan.id);

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Realisasi dibatalkan. Saldo dompet telah dipulihkan.'),
                      backgroundColor: AppColors.income,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membatalkan realisasi: $e'),
                      backgroundColor: AppColors.expense,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Batalkan & Pulihkan Saldo'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOG: HAPUS RENCANA
  // ============================================================

  void _showDeleteConfirmDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Rencana Pembelian?'),
        content: Text(
          plan.status == PlanStatus.achieved
              ? 'Rencana ini sudah terealisasi. Menghapus rencana TIDAK akan menghapus transaksi aktual yang sudah tercatat di pembukuan.'
              : 'Rencana pembelian "${plan.name}" akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              await ref.read(purchasePlanRepositoryProvider).delete(plan.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Rencana "${plan.name}" telah dihapus.')),
                );
              }
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOG: RIWAYAT AUDIT RENCANA
  // ============================================================

  void _showHistoryDialog(
      BuildContext context, WidgetRef ref, PurchasePlan plan) {
    final historiesStream =
        ref.read(purchasePlanRepositoryProvider).watchHistories(plan.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Riwayat Audit Rencana',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: StreamBuilder<List<PurchasePlanHistory>>(
                  stream: historiesStream,
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada catatan riwayat untuk rencana ini.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final h = list[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    h.action.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: h.action == 'realized'
                                          ? AppColors.income
                                          : (h.action == 'unrealized' ||
                                                  h.action == 'cancelled'
                                              ? AppColors.warning
                                              : AppColors.primary),
                                    ),
                                  ),
                                  Text(
                                    formatDateTime(h.timestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                              if (h.details != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  h.details!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (h.notes != null && h.notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Catatan: ${h.notes!}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white60),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
