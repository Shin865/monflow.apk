import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';

/// Layar Detail Hutang/Piutang & Jadwal Cicilan
class DebtDetailScreen extends ConsumerStatefulWidget {
  final int debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  void _showRecordPaymentDialog(BuildContext context, EnrichedDebt item) {
    final debtRepo = ref.read(debtRepositoryProvider);
    final accountRepo = ref.read(accountRepositoryProvider);

    final defaultAmt =
        item.debt.installmentAmount != null && item.debt.installmentAmount! > 0
            ? item.debt.installmentAmount!
            : item.debt.remainingAmount;

    final amountController = TextEditingController(text: defaultAmt.toString());
    final principalController =
        TextEditingController(text: defaultAmt.toString());
    final interestController = TextEditingController(text: '0');
    final feeController = TextEditingController(text: '0');
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
                  decoration: const InputDecoration(
                      labelText: 'Total Transaksi (Rp) *', prefixText: 'Rp '),
                  onChanged: (val) {
                    final total =
                        int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ??
                            0;
                    final interest = int.tryParse(interestController.text
                            .replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0;
                    final fee = int.tryParse(feeController.text
                            .replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0;
                    principalController.text =
                        (total - interest - fee).clamp(0, total).toString();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: principalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Alokasi Pokok (Rp)', prefixText: 'Rp '),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: interestController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Bunga (Rp)', prefixText: 'Rp '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Biaya / Denda (Rp)', prefixText: 'Rp '),
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
              onPressed: () async {
                final amount = int.tryParse(amountController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                final principal = int.tryParse(principalController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    amount;
                final interest = int.tryParse(interestController.text
                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                final fee = int.tryParse(
                        feeController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                    0;
                if (amount <= 0) return;

                await debtRepo.recordPayment(
                  debtId: item.debt.id,
                  amount: amount,
                  principalAmount: principal,
                  interestAmount: interest,
                  feeAmount: fee,
                  date: payDate,
                  accountId: selectedAccountId,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
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
    final debtRepo = ref.watch(debtRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Hutang & Cicilan'),
      ),
      body: FutureBuilder<EnrichedDebt?>(
        future: debtRepo.getDebtDetail(widget.debtId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Data tidak ditemukan.'));
          }

          final item = snapshot.data!;
          final debt = item.debt;
          final isHutang = item.isHutang;

          Color badgeColor;
          String badgeText;
          if (item.isPaid) {
            badgeColor = AppColors.income;
            badgeText = 'Lunas';
          } else if (item.isOverdue) {
            badgeColor = AppColors.expense;
            badgeText = 'Terlambat';
          } else {
            badgeColor = isHutang ? AppColors.expense : AppColors.income;
            badgeText = 'Aktif';
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
                            debt.name,
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
                      formatRupiah(debt.remainingAmount),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isHutang ? AppColors.expense : AppColors.income,
                      ),
                    ),
                    Text(
                      'Sisa pokok dari total ${formatRupiah(debt.totalAmount)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Tipe',
                      value: isHutang
                          ? 'Hutang Kita (Payable)'
                          : 'Piutang (Receivable)',
                    ),
                    if (debt.person != null && debt.person!.isNotEmpty)
                      _DetailRow(
                        label: isHutang ? 'Pemberi Pinjaman' : 'Peminjam',
                        value: debt.person!,
                      ),
                    if (debt.dueDate != null)
                      _DetailRow(
                        label: 'Jatuh Tempo',
                        value: formatDate(debt.dueDate!),
                      ),
                    if (debt.tenorMonths != null)
                      _DetailRow(
                        label: 'Tenor',
                        value: '${debt.tenorMonths} Bulan',
                      ),
                    if (debt.installmentAmount != null)
                      _DetailRow(
                        label: 'Cicilan per Bulan',
                        value: formatRupiah(debt.installmentAmount!),
                      ),
                    if (item.account != null)
                      _DetailRow(
                        label: 'Akun Terkait',
                        value: item.account!.name,
                      ),
                    if (debt.description != null &&
                        debt.description!.isNotEmpty)
                      _DetailRow(
                        label: 'Catatan',
                        value: debt.description!,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (!item.isPaid)
                FilledButton.icon(
                  onPressed: () => _showRecordPaymentDialog(context, item),
                  icon: Icon(isHutang
                      ? Icons.payment_rounded
                      : Icons.move_to_inbox_rounded),
                  label: Text(isHutang
                      ? 'Bayar Cicilan / Pelunasan'
                      : 'Terima Pembayaran Cicilan'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isHutang ? AppColors.expense : AppColors.income,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

              // Jadwal Cicilan (Jika ada)
              if (item.schedule.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jadwal Cicilan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${item.schedule.length} periode',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                ...item.schedule.map((sch) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: sch.isPaid
                            ? AppColors.income.withOpacity(0.15)
                            : AppColors.surfaceLight,
                        child: Icon(
                          sch.isPaid
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          color: sch.isPaid
                              ? AppColors.income
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      title: Text(
                          'Cicilan ke-${sch.installmentNumber} • ${formatRupiah(sch.expectedAmount)}'),
                      subtitle: Text(DateFormat('d MMMM yyyy', 'id_ID')
                          .format(sch.dueDate)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (sch.isPaid
                                  ? AppColors.income
                                  : AppColors.warning)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sch.isPaid ? 'Lunas' : 'Belum',
                          style: TextStyle(
                            color: sch.isPaid
                                ? AppColors.income
                                : AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],

              // Riwayat Pembayaran
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Riwayat Pembayaran & Penerimaan',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${item.payments.length} transaksi',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),

              if (item.payments.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Belum ada transaksi pembayaran.'),
                  ),
                )
              else
                ...item.payments.map((p) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.income.withOpacity(0.15),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.income, size: 20),
                      ),
                      title: Text(formatRupiah(p.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${formatDate(p.date)} • Pokok: ${formatRupiah(p.principalAmount)}${p.interestAmount > 0 ? ' • Bunga: ${formatRupiah(p.interestAmount)}' : ''}${p.notes != null ? ' (${p.notes})' : ''}',
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
