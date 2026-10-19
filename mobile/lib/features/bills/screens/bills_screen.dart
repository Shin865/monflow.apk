import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/services/notification_service.dart';

enum BillFilter { all, unpaid, overdue, paid, recurring }

/// Layar Manajemen Tagihan (Bills) & Tagihan Berulang
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  BillFilter _currentFilter = BillFilter.unpaid;

  @override
  void initState() {
    super.initState();
    // Lazy sync tagihan rutin dan status jatuh tempo saat layar dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final billRepo = ref.read(billRepositoryProvider);
      final notifService = ref.read(notificationServiceProvider);
      await billRepo.generateRecurringInstances();
      await billRepo.refreshAllBillStatuses();
      final bills = await billRepo.getEnrichedBills(includePaid: false);
      await notifService
          .syncAllBillReminders(bills.map((e) => e.bill).toList());
      if (mounted) setState(() {});
    });
  }

  void _showCreateBillDialog(BuildContext context) {
    final billRepo = ref.read(billRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    bool isRecurring = false;
    BillFrequency frequency = BillFrequency.monthly;
    int? categoryId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Tagihan Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nama Tagihan *',
                      hintText: 'Misal: Listrik, Internet'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Nominal Tagihan (Rp) *', prefixText: 'Rp '),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Jatuh Tempo',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  subtitle: Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dueDate),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Category>>(
                  future: categoryRepo.getByType(CategoryType.expense),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final categories = snapshot.data!;
                    return DropdownButtonFormField<int>(
                      value: categoryId,
                      dropdownColor: AppColors.surface,
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('— Tanpa Kategori —')),
                        ...categories.map((c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Row(
                                children: [
                                  Text(c.icon ?? '📁',
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => categoryId = val),
                      decoration:
                          const InputDecoration(labelText: 'Kategori Tagihan'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tagihan Rutin / Berulang'),
                  subtitle: const Text('Otomatis dibuat tiap periode',
                      style: TextStyle(fontSize: 12)),
                  value: isRecurring,
                  onChanged: (val) => setDialogState(() => isRecurring = val),
                ),
                if (isRecurring) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<BillFrequency>(
                    value: frequency,
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(
                          value: BillFrequency.monthly,
                          child: Text('Bulanan (Setiap Bulan)')),
                      DropdownMenuItem(
                          value: BillFrequency.quarterly,
                          child: Text('3 Bulan (Kuartalan)')),
                      DropdownMenuItem(
                          value: BillFrequency.yearly,
                          child: Text('Tahunan (Setiap Tahun)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => frequency = val);
                    },
                    decoration: const InputDecoration(
                        labelText: 'Frekuensi Pengulangan'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Catatan / Deskripsi (Opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final amount = int.tryParse(amountController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (name.isEmpty || amount <= 0) return;

                final bill = await billRepo.createBill(
                  name: name,
                  amount: amount,
                  dueDate: dueDate,
                  isRecurring: isRecurring,
                  frequency: frequency,
                  categoryId: categoryId,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                );

                await notifService.scheduleBillReminder(bill);

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(() {});
              },
              child: const Text('Simpan Tagihan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayBillDialog(BuildContext context, EnrichedBill item) {
    final billRepo = ref.read(billRepositoryProvider);
    final accountRepo = ref.read(accountRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    final amountController =
        TextEditingController(text: item.remaining.toString());
    final notesController = TextEditingController();
    DateTime payDate = DateTime.now();
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Bayar Tagihan: ${item.bill.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Tagihan:',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                          Text(formatRupiah(item.bill.amount),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa yang Harus Dibayar:',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                          Text(formatRupiah(item.remaining),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.expense)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Account>>(
                  future: accountRepo.getActiveAccounts(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final accounts = snapshot.data!;
                    if (selectedAccountId == null && accounts.isNotEmpty) {
                      selectedAccountId = accounts.first.id;
                    }
                    return DropdownButtonFormField<int>(
                      value: selectedAccountId,
                      dropdownColor: AppColors.surface,
                      items: accounts.map((a) {
                        return DropdownMenuItem<int>(
                          value: a.id,
                          child: Text('${a.name} (${formatRupiah(a.balance)})'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedAccountId = val),
                      decoration: const InputDecoration(
                          labelText: 'Sumber Rekening / Dompet *'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Nominal Pembayaran (Rp) *',
                      prefixText: 'Rp '),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Pembayaran',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  subtitle: Text(
                      DateFormat('d MMMM yyyy', 'id_ID').format(payDate),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: payDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setDialogState(() => payDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                      labelText: 'Catatan Pembayaran (Opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.income),
              onPressed: () async {
                final amount = int.tryParse(amountController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (amount <= 0 || selectedAccountId == null) return;

                final updated = await billRepo.payBill(
                  billId: item.bill.id,
                  accountId: selectedAccountId!,
                  amount: amount,
                  date: payDate,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                );

                if (updated.isPaid) {
                  await notifService.cancelBillReminder(item.bill.id);
                }

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(() {});
              },
              child: const Text('Konfirmasi Bayar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billRepo = ref.watch(billRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tagihan (Bills)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Tagihan',
            onPressed: () => _showCreateBillDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Belum Lunas',
                  isSelected: _currentFilter == BillFilter.unpaid,
                  onSelected: () =>
                      setState(() => _currentFilter = BillFilter.unpaid),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Semua',
                  isSelected: _currentFilter == BillFilter.all,
                  onSelected: () =>
                      setState(() => _currentFilter = BillFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Terlambat',
                  isSelected: _currentFilter == BillFilter.overdue,
                  onSelected: () =>
                      setState(() => _currentFilter = BillFilter.overdue),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Lunas',
                  isSelected: _currentFilter == BillFilter.paid,
                  onSelected: () =>
                      setState(() => _currentFilter = BillFilter.paid),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Rutin',
                  isSelected: _currentFilter == BillFilter.recurring,
                  onSelected: () =>
                      setState(() => _currentFilter = BillFilter.recurring),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<EnrichedBill>>(
              future: billRepo.getEnrichedBills(includePaid: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Gagal memuat tagihan: ${snapshot.error}'));
                }

                var bills = snapshot.data ?? [];

                // Filter logic
                switch (_currentFilter) {
                  case BillFilter.unpaid:
                    bills = bills
                        .where((b) => b.bill.status != BillStatus.paid)
                        .toList();
                    break;
                  case BillFilter.overdue:
                    bills = bills
                        .where((b) => b.bill.status == BillStatus.overdue)
                        .toList();
                    break;
                  case BillFilter.paid:
                    bills = bills
                        .where((b) => b.bill.status == BillStatus.paid)
                        .toList();
                    break;
                  case BillFilter.recurring:
                    bills = bills
                        .where((b) =>
                            b.bill.isRecurring || b.bill.parentBillId != null)
                        .toList();
                    break;
                  case BillFilter.all:
                    break;
                }

                if (bills.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Tidak ada tagihan pada filter ini.',
                              style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final item = bills[index];
                    return _BillCard(
                      item: item,
                      onTap: () {
                        context
                            .pushNamed('bill_detail', extra: item.bill.id)
                            .then((_) => setState(() {}));
                      },
                      onPay: () => _showPayBillDialog(context, item),
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Tagihan'),
                            content: Text('Hapus tagihan "${item.bill.name}"?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal')),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.expense),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await billRepo.deleteBill(item.bill.id);
                          await ref
                              .read(notificationServiceProvider)
                              .cancelBillReminder(item.bill.id);
                          setState(() {});
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final EnrichedBill item;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  const _BillCard({
    required this.item,
    required this.onTap,
    required this.onPay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;
    switch (item.bill.status) {
      case BillStatus.upcoming:
        badgeColor = AppColors.primary;
        badgeText = 'Mendatang';
        break;
      case BillStatus.dueSoon:
        badgeColor = AppColors.warning;
        badgeText = 'Segera';
        break;
      case BillStatus.overdue:
        badgeColor = AppColors.expense;
        badgeText = 'Terlambat';
        break;
      case BillStatus.paid:
        badgeColor = AppColors.income;
        badgeText = 'Lunas';
        break;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        item.bill.dueDate.year, item.bill.dueDate.month, item.bill.dueDate.day);
    final diffDays = due.difference(today).inDays;

    String dueSubtext;
    if (item.isPaid) {
      dueSubtext = 'Lunas';
    } else if (diffDays == 0) {
      dueSubtext = 'Jatuh tempo HARI INI';
    } else if (diffDays > 0) {
      dueSubtext = 'Jatuh tempo dalam $diffDays hari';
    } else {
      dueSubtext = 'Terlambat ${diffDays.abs()} hari';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isOverdue
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
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.category?.icon ?? '📄',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.bill.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.bill.isRecurring ||
                                item.bill.parentBillId != null)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.transfer.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Rutin',
                                    style: TextStyle(
                                        color: AppColors.transfer,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dueSubtext,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.isOverdue
                                ? AppColors.expense
                                : AppColors.textMuted,
                            fontWeight: item.isOverdue
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatRupiah(item.bill.amount),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                    ],
                  ),
                ],
              ),
              if (!item.isPaid) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sisa: ${formatRupiah(item.remaining)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.textMuted),
                          onPressed: onDelete,
                          tooltip: 'Hapus Tagihan',
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonal(
                          onPressed: onPay,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.income.withOpacity(0.15),
                            foregroundColor: AppColors.income,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Bayar',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
