import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_flow/core/formatting/thousand_separator_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';

/// Layar Hutang (Payable) & Piutang (Receivable)
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen>
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

  void _showCreateDebtDialog(BuildContext context, DebtType type) {
    final debtRepo = ref.read(debtRepositoryProvider);
    final accountRepo = ref.read(accountRepositoryProvider);

    final nameController = TextEditingController();
    final personController = TextEditingController();
    final amountController = TextEditingController();
    final installmentController = TextEditingController();
    final descController = TextEditingController();
    DateTime? dueDate;
    int? tenorMonths;
    int? selectedAccountId;

    final isHutang = type == DebtType.hutang;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              isHutang ? 'Tambah Catatan Hutang' : 'Tambah Catatan Piutang'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama / Keterangan *',
                    hintText: isHutang
                        ? 'Misal: Pinjaman Motor'
                        : 'Misal: Pinjaman Teman',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: personController,
                  decoration: InputDecoration(
                    labelText: isHutang
                        ? 'Pemberi Pinjaman (Orang/Bank)'
                        : 'Peminjam (Orang/Pihak Lain)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandSeparatorInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Total Pokok (Rp) *',
                    hintText: 'Masukkan nominal',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: installmentController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandSeparatorInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cicilan/Bulan (Opsional)',
                          hintText: 'Masukkan nominal',
                          prefixText: 'Rp ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Tenor (Bulan)'),
                        onChanged: (val) => tenorMonths = int.tryParse(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Jatuh Tempo (Opsional)',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  subtitle: Text(
                    dueDate != null
                        ? DateFormat('d MMMM yyyy', 'id_ID').format(dueDate!)
                        : 'Belum diatur',
                    style: TextStyle(
                        fontWeight: dueDate != null
                            ? FontWeight.bold
                            : FontWeight.normal),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Account>>(
                  future: accountRepo.getActiveAccounts(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final accounts = snapshot.data!;
                    return DropdownButtonFormField<int>(
                      value: selectedAccountId,
                      dropdownColor: AppColors.surface,
                      items: [
                        const DropdownMenuItem<int>(
                            value: null,
                            child: Text('— Tanpa Rekening Terkait —')),
                        ...accounts.map((a) => DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(a.name),
                            )),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedAccountId = val),
                      decoration: const InputDecoration(
                          labelText: 'Akun Terkait (Opsional)'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Catatan Tambahan (Opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final totalAmount = int.tryParse(amountController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (name.isEmpty || totalAmount <= 0) return;

                final installmentAmount = int.tryParse(installmentController
                    .text
                    .replaceAll(RegExp(r'[^0-9]'), ''));

                await debtRepo.createDebt(
                  name: name,
                  type: type,
                  totalAmount: totalAmount,
                  person: personController.text.trim().isEmpty
                      ? null
                      : personController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  dueDate: dueDate,
                  tenorMonths: tenorMonths,
                  installmentAmount: installmentAmount,
                  installmentDay: dueDate?.day,
                  accountId: selectedAccountId,
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

  void _showPaymentDialog(BuildContext context, EnrichedDebt item) {
    final debtRepo = ref.read(debtRepositoryProvider);
    final accountRepo = ref.read(accountRepositoryProvider);

    final defaultAmt =
        item.debt.installmentAmount != null && item.debt.installmentAmount! > 0
            ? item.debt.installmentAmount!
            : item.debt.remainingAmount;

    final amountController = TextEditingController(text: defaultAmt.toString());
    final notesController = TextEditingController();
    DateTime payDate = DateTime.now();
    int? selectedAccountId = item.debt.accountId;

    final isHutang = item.isHutang;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              '${isHutang ? 'Bayar Hutang' : 'Terima Pembayaran'}: ${item.debt.name}'),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sisa Pokok:',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      Text(formatRupiah(item.debt.remainingAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    return DropdownButtonFormField<int>(
                      value: selectedAccountId,
                      dropdownColor: AppColors.surface,
                      items: [
                        const DropdownMenuItem<int>(
                            value: null,
                            child: Text('— Tunai / Tanpa Mutasi Akun —')),
                        ...accounts.map((a) => DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(
                                  '${a.name} (${formatRupiah(a.balance)})'),
                            )),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedAccountId = val),
                      decoration: InputDecoration(
                        labelText: isHutang
                            ? 'Sumber Dana Rekening'
                            : 'Rekening Penerima',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandSeparatorInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp) *',
                    hintText: 'Masukkan nominal',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Transaksi',
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
                  decoration:
                      const InputDecoration(labelText: 'Catatan (Opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isHutang ? AppColors.income : AppColors.primary,
              ),
              onPressed: () async {
                final amount = int.tryParse(amountController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (amount <= 0) return;

                await debtRepo.recordPayment(
                  debtId: item.debt.id,
                  amount: amount,
                  date: payDate,
                  accountId: selectedAccountId,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                );

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(() {});
              },
              child: Text(isHutang ? 'Bayar Hutang' : 'Terima Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtRepo = ref.watch(debtRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hutang & Piutang'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Hutang Kita', icon: Icon(Icons.arrow_downward_rounded)),
            Tab(
                text: 'Piutang (Uang di Orang)',
                icon: Icon(Icons.arrow_upward_rounded)),
          ],
        ),
      ),
      body: FutureBuilder<DebtSummary>(
        future: debtRepo.getDebtSummary(),
        builder: (context, summarySnap) {
          final summary = summarySnap.data ??
              const DebtSummary(totalHutang: 0, totalPiutang: 0, net: 0);

          return Column(
            children: [
              // Summary Cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryBox(
                        title: 'Total Hutang Kita',
                        amount: summary.totalHutang,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryBox(
                        title: 'Uang di Orang',
                        amount: summary.totalPiutang,
                        color: AppColors.income,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryBox(
                        title: 'Selisih Bersih',
                        amount: summary.net,
                        color: summary.net >= 0
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DebtListView(
                      type: DebtType.hutang,
                      onPay: (item) => _showPaymentDialog(context, item),
                      onDeleted: () => setState(() {}),
                    ),
                    _DebtListView(
                      type: DebtType.piutang,
                      onPay: (item) => _showPaymentDialog(context, item),
                      onDeleted: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currentType =
              _tabController.index == 0 ? DebtType.hutang : DebtType.piutang;
          _showCreateDebtDialog(context, currentType);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
            _tabController.index == 0 ? 'Tambah Hutang' : 'Tambah Piutang'),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final int amount;
  final Color color;

  const _SummaryBox({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 1),
          const SizedBox(height: 6),
          Text(
            formatRupiah(amount),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DebtListView extends ConsumerWidget {
  final DebtType type;
  final void Function(EnrichedDebt item) onPay;
  final VoidCallback onDeleted;

  const _DebtListView({
    required this.type,
    required this.onPay,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtRepo = ref.watch(debtRepositoryProvider);

    return FutureBuilder<List<EnrichedDebt>>(
      future: debtRepo.getEnrichedDebts(type: type, includePaid: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type == DebtType.hutang
                        ? Icons.credit_card_off_rounded
                        : Icons.money_off_rounded,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    type == DebtType.hutang
                        ? 'Hore! Tidak ada hutang saat ini.'
                        : 'Tidak ada piutang saat ini.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final debt = item.debt;

            String statusText;
            if (item.isPaid) {
              statusText = 'Lunas';
            } else if (item.isOverdue) {
              statusText = 'Terlambat';
            } else {
              statusText = 'Aktif';
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
                onTap: () {
                  context
                      .pushNamed('debt_detail', extra: debt.id)
                      .then((_) => onDeleted());
                },
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
                              color: (type == DebtType.hutang
                                      ? AppColors.expense
                                      : AppColors.income)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              type == DebtType.hutang
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: type == DebtType.hutang
                                  ? AppColors.expense
                                  : AppColors.income,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debt.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                Text(
                                  debt.person != null
                                      ? '${debt.person!} • $statusText'
                                      : statusText,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Sisa Pokok',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                              Text(
                                formatRupiah(debt.remainingAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: type == DebtType.hutang
                                      ? AppColors.expense
                                      : AppColors.income,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (item.progress / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            type == DebtType.hutang
                                ? AppColors.expense
                                : AppColors.income,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dibayar: ${formatRupiah(item.totalPaid)} (${item.progress.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                          Text(
                            'Total: ${formatRupiah(debt.totalAmount)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      if (!item.isPaid) ...[
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (debt.dueDate != null)
                              Text(
                                'Jatuh tempo: ${formatDate(debt.dueDate!)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              )
                            else
                              const SizedBox.shrink(),
                            FilledButton.tonal(
                              onPressed: () => onPay(item),
                              style: FilledButton.styleFrom(
                                backgroundColor: (type == DebtType.hutang
                                        ? AppColors.expense
                                        : AppColors.income)
                                    .withOpacity(0.15),
                                foregroundColor: type == DebtType.hutang
                                    ? AppColors.expense
                                    : AppColors.income,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                type == DebtType.hutang
                                    ? 'Bayar Cicilan'
                                    : 'Terima Pembayaran',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
