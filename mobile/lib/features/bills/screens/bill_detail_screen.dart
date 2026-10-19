import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/services/notification_service.dart';

/// Layar Detail Tagihan & Riwayat Pembayaran
class BillDetailScreen extends ConsumerStatefulWidget {
  final int billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  void _showPayDialog(BuildContext context, EnrichedBill item) {
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
                      decoration:
                          const InputDecoration(labelText: 'Sumber Rekening *'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Nominal Bayar (Rp) *', prefixText: 'Rp '),
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
              child: const Text('Bayar Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billRepo = ref.watch(billRepositoryProvider);
    final accountRepo = ref.watch(accountRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tagihan'),
      ),
      body: FutureBuilder<EnrichedBill?>(
        future: billRepo.getBillDetail(widget.billId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
                child: Text('Tagihan tidak ditemukan atau telah dihapus.'));
          }

          final item = snapshot.data!;
          final bill = item.bill;

          Color badgeColor;
          String badgeText;
          switch (bill.status) {
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            bill.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                    const SizedBox(height: 12),
                    Text(
                      formatRupiah(bill.amount),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Jatuh Tempo',
                      value: DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                          .format(bill.dueDate),
                    ),
                    _DetailRow(
                      label: 'Jenis Tagihan',
                      value: bill.isRecurring
                          ? 'Rutin (${bill.frequency.name})'
                          : 'Sekali Bayar',
                    ),
                    if (item.category != null)
                      _DetailRow(
                        label: 'Kategori',
                        value:
                            '${item.category!.icon ?? ''} ${item.category!.name}',
                      ),
                    if (bill.description != null &&
                        bill.description!.isNotEmpty)
                      _DetailRow(
                        label: 'Catatan',
                        value: bill.description!,
                      ),
                    _DetailRow(
                      label: 'Total Terbayar',
                      value: formatRupiah(item.totalPaid),
                      valueColor: AppColors.income,
                    ),
                    _DetailRow(
                      label: 'Sisa Tagihan',
                      value: formatRupiah(item.remaining),
                      valueColor:
                          item.isPaid ? AppColors.income : AppColors.expense,
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (!item.isPaid)
                FilledButton.icon(
                  onPressed: () => _showPayDialog(context, item),
                  icon: const Icon(Icons.payment_rounded),
                  label: const Text('Bayar Tagihan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.income,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Riwayat Pembayaran',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${item.payments.length} pembayaran',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),

              if (item.payments.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Belum ada catatan pembayaran.'),
                  ),
                )
              else
                ...item.payments.map((p) {
                  return FutureBuilder<Account?>(
                    future: accountRepo.getById(p.accountId),
                    builder: (context, accSnap) {
                      final accName =
                          accSnap.data?.name ?? 'Akun #${p.accountId}';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceLight,
                            child: Icon(Icons.check_rounded,
                                color: AppColors.income, size: 20),
                          ),
                          title: Text(formatRupiah(p.amount),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${formatDate(p.date)} • $accName${p.notes != null ? ' (${p.notes})' : ''}'),
                        ),
                      );
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
