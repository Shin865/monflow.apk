import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_flow/core/formatting/thousand_separator_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/deposit_repository.dart';
import 'package:money_flow/data/repositories/investment_repository.dart';
import 'package:money_flow/domain/rules/deposit_rules.dart';
import 'package:money_flow/domain/rules/investment_rules.dart';

class InvestmentsDepositsScreen extends ConsumerStatefulWidget {
  const InvestmentsDepositsScreen({super.key});

  @override
  ConsumerState<InvestmentsDepositsScreen> createState() =>
      _InvestmentsDepositsScreenState();
}

class _InvestmentsDepositsScreenState
    extends ConsumerState<InvestmentsDepositsScreen>
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
        title: const Text('Investasi & Deposito'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brandTeal,
          labelColor: AppColors.brandTeal,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(
                icon: Icon(Icons.trending_up_rounded, size: 20),
                text: 'Portofolio Investasi'),
            Tab(
                icon: Icon(Icons.account_balance_rounded, size: 20),
                text: 'Simpanan Deposito'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _InvestmentsTab(),
          _DepositsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          _tabController.index == 0 ? 'Investasi Baru' : 'Deposito Baru',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddInvestmentDialog(context, ref);
          } else {
            DepositDialogHelper.showAdd(context, ref);
          }
        },
      ),
    );
  }

  // ============================================================
  // DIALOGS: ADD / EDIT INVESTMENT
  // ============================================================

  void _showAddInvestmentDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final platformCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final unitsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    InvestmentType selectedType = InvestmentType.saham;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Investasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nama Aset / Saham *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InvestmentType>(
                  value: selectedType,
                  decoration:
                      const InputDecoration(labelText: 'Tipe Instrumen'),
                  items: InvestmentType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: platformCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Platform / Sekuritas (opsional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandSeparatorInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal (Rp) *',
                    hintText: 'Masukkan nominal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandSeparatorInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nilai Pasar Saat Ini (Rp) *',
                    hintText: 'Masukkan nominal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Jumlah Unit / Lot / Gram (opsional)'),
                ),
                const SizedBox(height: 12),
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
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final cost = int.tryParse(costCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    0;
                final value = int.tryParse(valueCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    cost;
                final units =
                    double.tryParse(unitsCtrl.text.replaceAll(',', '.'));

                if (name.isEmpty || cost < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Nama dan modal harus diisi dengan benar')),
                  );
                  return;
                }

                await ref.read(investmentRepositoryProvider).create(
                      name: name,
                      type: selectedType,
                      platform: platformCtrl.text.trim().isEmpty
                          ? null
                          : platformCtrl.text.trim(),
                      initialCost: cost,
                      currentValue: value,
                      units: units,
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
}

// ============================================================
// DIALOGS: DEPOSIT HELPER (ADD, EDIT, DETAIL, DELETE, WITHDRAW)
// ============================================================
class DepositDialogHelper {
  static void showAdd(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final principalCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '6.25');
    final tenorCtrl = TextEditingController(text: '12');
    final taxCtrl = TextEditingController(text: '20');
    final feeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DepositInterestType interestType = DepositInterestType.simple;
    DateTime startDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final principal = int.tryParse(
                  principalCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
              0;
          final ratePercent =
              double.tryParse(rateCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final rateBps = (ratePercent * 100).round();
          final tenor = int.tryParse(tenorCtrl.text) ?? 12;
          final taxPercent =
              double.tryParse(taxCtrl.text.replaceAll(',', '.')) ?? 20.0;
          final taxBps = (taxPercent * 100).round();
          final fee = int.tryParse(
                  feeCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
              0;

          final previewMaturity =
              DepositRules.calculateMaturityDate(startDate, tenor);

          final previewCalc = DepositRules.calculateDeposit(
            principal: principal,
            rateBps: rateBps,
            tenorMonths: tenor,
            isCompound: interestType == DepositInterestType.compound,
            taxRateBps: taxBps,
            feeAmount: fee,
          );

          return AlertDialog(
            title: const Text('Tambah Deposito'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nama Produk / Deposito *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bankCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nama Bank (misal BCA, Mandiri)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: principalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Pokok Deposito (Rp) *',
                      hintText: 'Masukkan nominal',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Bunga % / tahun'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: tenorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Tenor (bulan) *'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DepositInterestType>(
                    value: interestType,
                    decoration:
                        const InputDecoration(labelText: 'Metode Bunga'),
                    items: const [
                      DropdownMenuItem(
                        value: DepositInterestType.simple,
                        child: Text('Bunga Sederhana (Simple)'),
                      ),
                      DropdownMenuItem(
                        value: DepositInterestType.compound,
                        child: Text('Bunga Majemuk (Compound)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => interestType = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Pajak Bunga % (default 20)'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ThousandSeparatorInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Biaya Lain (Rp)',
                            hintText: '0',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Date Picker: Tanggal Mulai
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText: 'Pilih Tanggal Mulai Deposito',
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Mulai *',
                        suffixIcon:
                            Icon(Icons.calendar_today_rounded, size: 20),
                      ),
                      child: Text(
                        formatDateIndo(startDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Informasi Tanggal Jatuh Tempo
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Tanggal Jatuh Tempo',
                      suffixIcon: Icon(Icons.event_available_rounded, size: 20),
                    ),
                    child: Text(
                      formatDateIndo(previewMaturity),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Catatan (opsional)'),
                  ),
                  const SizedBox(height: 12),

                  // Estimasi Kalkulasi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimasi Saat Jatuh Tempo:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bunga Bersih:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            Text(
                              formatRupiah(previewCalc.netInterest),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.income,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Diterima:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            Text(
                              formatRupiah(previewCalc.maturityAmount),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.brandTeal,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
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
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty || principal <= 0 || tenor <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Nama, pokok, dan tenor deposito harus diisi dengan benar')),
                          );
                          return;
                        }

                        final computedMaturity =
                            DepositRules.calculateMaturityDate(
                                startDate, tenor);
                        if (computedMaturity.isBefore(startDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Jatuh tempo tidak boleh lebih awal dari tanggal mulai')),
                          );
                          return;
                        }

                        setState(() => isSaving = true);
                        try {
                          await ref.read(depositRepositoryProvider).create(
                                name: name,
                                bankName: bankCtrl.text.trim().isEmpty
                                    ? null
                                    : bankCtrl.text.trim(),
                                principal: principal,
                                annualRateBps: rateBps,
                                tenorMonths: tenor,
                                interestType: interestType,
                                taxRateBps: taxBps,
                                feeAmount: fee,
                                startDate: startDate,
                                maturityDate: computedMaturity,
                                notes: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                              );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Deposito berhasil disimpan')),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showEdit(BuildContext context, WidgetRef ref, Deposit dep) {
    final nameCtrl = TextEditingController(text: dep.name);
    final bankCtrl = TextEditingController(text: dep.bankName ?? '');
    final principalCtrl = TextEditingController(
      text: ThousandSeparatorInputFormatter()
          .formatEditUpdate(
            const TextEditingValue(),
            TextEditingValue(text: dep.principal.toString()),
          )
          .text,
    );
    final rateCtrl =
        TextEditingController(text: (dep.annualRateBps / 100.0).toString());
    final tenorCtrl = TextEditingController(text: dep.tenorMonths.toString());
    final taxCtrl =
        TextEditingController(text: (dep.taxRateBps / 100.0).toString());
    final feeCtrl = TextEditingController(
      text: dep.feeAmount > 0
          ? ThousandSeparatorInputFormatter()
              .formatEditUpdate(
                const TextEditingValue(),
                TextEditingValue(text: dep.feeAmount.toString()),
              )
              .text
          : '',
    );
    final notesCtrl = TextEditingController(text: dep.notes ?? '');
    DepositInterestType interestType = dep.interestType;
    DateTime startDate = dep.startDate;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final principal = int.tryParse(
                  principalCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
              dep.principal;
          final ratePercent =
              double.tryParse(rateCtrl.text.replaceAll(',', '.')) ??
                  (dep.annualRateBps / 100.0);
          final rateBps = (ratePercent * 100).round();
          final tenor = int.tryParse(tenorCtrl.text) ?? dep.tenorMonths;
          final taxPercent =
              double.tryParse(taxCtrl.text.replaceAll(',', '.')) ?? 20.0;
          final taxBps = (taxPercent * 100).round();
          final fee = int.tryParse(
                  feeCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
              0;

          final previewMaturity =
              DepositRules.calculateMaturityDate(startDate, tenor);

          final previewCalc = DepositRules.calculateDeposit(
            principal: principal,
            rateBps: rateBps,
            tenorMonths: tenor,
            isCompound: interestType == DepositInterestType.compound,
            taxRateBps: taxBps,
            feeAmount: fee,
          );

          return AlertDialog(
            title: Text('Ubah Deposito: ${dep.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nama Produk / Deposito *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bankCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nama Bank (misal BCA, Mandiri)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: principalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Pokok Deposito (Rp) *',
                      hintText: 'Masukkan nominal',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Bunga % / tahun'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: tenorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Tenor (bulan) *'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DepositInterestType>(
                    value: interestType,
                    decoration:
                        const InputDecoration(labelText: 'Metode Bunga'),
                    items: const [
                      DropdownMenuItem(
                        value: DepositInterestType.simple,
                        child: Text('Bunga Sederhana (Simple)'),
                      ),
                      DropdownMenuItem(
                        value: DepositInterestType.compound,
                        child: Text('Bunga Majemuk (Compound)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => interestType = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Pajak Bunga % (default 20)'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ThousandSeparatorInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Biaya Lain (Rp)',
                            hintText: '0',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Date Picker: Tanggal Mulai
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText: 'Ubah Tanggal Mulai Deposito',
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Mulai *',
                        suffixIcon:
                            Icon(Icons.calendar_today_rounded, size: 20),
                      ),
                      child: Text(
                        formatDateIndo(startDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Estimasi Jatuh Tempo
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Tanggal Jatuh Tempo',
                      suffixIcon: Icon(Icons.event_available_rounded, size: 20),
                    ),
                    child: Text(
                      formatDateIndo(previewMaturity),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Catatan (opsional)'),
                  ),
                  const SizedBox(height: 12),

                  // Estimasi Hasil
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimasi Saat Jatuh Tempo Baru:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bunga Bersih:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            Text(
                              formatRupiah(previewCalc.netInterest),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.income,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Diterima:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            Text(
                              formatRupiah(previewCalc.maturityAmount),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.brandTeal,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
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
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty || principal <= 0 || tenor <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Nama, pokok, dan tenor deposito harus diisi dengan benar')),
                          );
                          return;
                        }

                        final computedMaturity =
                            DepositRules.calculateMaturityDate(
                                startDate, tenor);
                        if (computedMaturity.isBefore(startDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Jatuh tempo tidak boleh lebih awal dari tanggal mulai')),
                          );
                          return;
                        }

                        setState(() => isSaving = true);
                        try {
                          await ref.read(depositRepositoryProvider).update(
                                dep.id,
                                name: name,
                                bankName: bankCtrl.text.trim().isEmpty
                                    ? null
                                    : bankCtrl.text.trim(),
                                principal: principal,
                                annualRateBps: rateBps,
                                tenorMonths: tenor,
                                interestType: interestType,
                                taxRateBps: taxBps,
                                feeAmount: fee,
                                startDate: startDate,
                                maturityDate: computedMaturity,
                                notes: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                              );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Perubahan deposito disimpan')),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showDetail(
    BuildContext context,
    WidgetRef ref,
    Deposit dep,
  ) {
    final calc = DepositRules.calculateDeposit(
      principal: dep.principal,
      rateBps: dep.annualRateBps,
      tenorMonths: dep.tenorMonths,
      isCompound: dep.interestType == DepositInterestType.compound,
      compoundFrequency: dep.compoundFrequency,
      taxRateBps: dep.taxRateBps,
      feeAmount: dep.feeAmount,
    );
    final ratePercent = dep.annualRateBps / 100.0;
    final isMatured = dep.status == DepositStatus.matured;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance_rounded,
                color: AppColors.brandTeal, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dep.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dep.bankName != null && dep.bankName!.isNotEmpty) ...[
                Text(
                  'Bank: ${dep.bankName}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMatured
                      ? AppColors.income.withOpacity(0.15)
                      : AppColors.brandTealWash,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isMatured ? 'Status: Sudah Jatuh Tempo' : 'Status: Aktif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMatured ? AppColors.income : AppColors.brandTeal,
                  ),
                ),
              ),
              const Divider(height: 20),
              _detailRow('Pokok Deposito', formatRupiah(dep.principal)),
              _detailRow('Tanggal Mulai', formatDateIndo(dep.startDate)),
              _detailRow(
                  'Tanggal Jatuh Tempo', formatDateIndo(dep.maturityDate)),
              _detailRow('Tenor', '${dep.tenorMonths} Bulan'),
              _detailRow('Suku Bunga',
                  '${ratePercent.toStringAsFixed(2)}% / tahun (${dep.interestType == DepositInterestType.compound ? "Majemuk" : "Sederhana"})'),
              _detailRow('Pajak Bunga',
                  '${(dep.taxRateBps / 100).toStringAsFixed(1)}% (${formatRupiah(calc.taxAmount)})'),
              if (dep.feeAmount > 0)
                _detailRow('Biaya Lain', formatRupiah(dep.feeAmount)),
              const Divider(height: 16),
              _detailRow('Bunga Bersih', '+${formatRupiah(calc.netInterest)}',
                  valueColor: AppColors.income),
              _detailRow(
                  'Total Saat Jatuh Tempo', formatRupiah(calc.maturityAmount),
                  valueColor: AppColors.brandTeal, isBold: true),
              if (dep.notes != null && dep.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Catatan:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(dep.notes!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              confirmDelete(context, ref, dep);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showEdit(context, ref, dep);
            },
            child: const Text('Ubah'),
          ),
          if (dep.status != DepositStatus.withdrawn)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                showWithdraw(context, ref, dep, calc);
              },
              child: const Text('Cairkan'),
            ),
        ],
      ),
    );
  }

  static Future<void> confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Deposit dep,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Deposito'),
        content: Text(
          'Apakah Anda yakin ingin menghapus simpanan deposito "${dep.name}"?\n'
          'Tindakan ini akan menghapus catatan deposito dari portofolio Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(depositRepositoryProvider).delete(dep.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deposito "${dep.name}" berhasil dihapus')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus deposito: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  static void showWithdraw(
    BuildContext context,
    WidgetRef ref,
    Deposit dep,
    DepositCalculationResult calc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Account>>(
          future: ref.read(accountRepositoryProvider).getActiveAccounts(),
          builder: (ctx, snapshot) {
            final accounts = snapshot.data ?? [];
            int? selectedAccId = accounts.isNotEmpty ? accounts.first.id : null;

            return StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                title: Text('Cairkan: ${dep.name}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total dana cair (Pokok + Bunga Bersih): ${formatRupiah(calc.maturityAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('Pilih rekening tujuan pencairan:',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 8),
                    if (accounts.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedAccId,
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
                      )
                    else
                      const Text('Belum ada dompet aktif.'),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal')),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(depositRepositoryProvider).withdraw(
                            dep.id,
                            returnToAccountId: selectedAccId,
                          );
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Cairkan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _detailRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: INVESTMENTS
// ============================================================

class _InvestmentsTab extends ConsumerWidget {
  const _InvestmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryStream =
        ref.watch(investmentRepositoryProvider).watchPortfolioSummary();
    final investmentsStream =
        ref.watch(investmentRepositoryProvider).watchActiveInvestments();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<PortfolioSummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data ??
                  const PortfolioSummary(
                    totalCost: 0,
                    totalValue: 0,
                    totalGain: 0,
                    returnPercent: 0,
                    count: 0,
                  );

              final tokens = context.tokens;
              final isPositive = summary.totalGain >= 0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Total Modal',
                          value: formatRupiah(summary.totalCost),
                        ),
                        _StatBox(
                          label: 'Nilai Sekarang',
                          value: formatRupiah(summary.totalValue),
                          color: tokens.dataHue,
                        ),
                      ],
                    ),
                    Divider(height: 20, color: tokens.borderHairline),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Keuntungan (Rp)',
                          value:
                              '${isPositive ? '+' : ''}${formatRupiah(summary.totalGain)}',
                          color: isPositive ? tokens.income : tokens.expense,
                        ),
                        _StatBox(
                          label: 'Imbal Hasil (%)',
                          value:
                              '${isPositive ? '+' : ''}${summary.returnPercent.toStringAsFixed(2)}%',
                          color: isPositive ? tokens.income : tokens.expense,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Daftar Instrumen Portofolio',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Investment>>(
            stream: investmentsStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Belum ada portofolio investasi.\nTekan + untuk menambah instrumen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
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
                  final inv = list[index];
                  final gain = InvestmentRules.unrealizedGain(
                    initialCost: inv.initialCost,
                    currentValue: inv.currentValue,
                  );
                  final roi = InvestmentRules.returnPercent(
                    initialCost: inv.initialCost,
                    currentValue: inv.currentValue,
                  );
                  final isPositive = gain >= 0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(context.tokens.radiusCard),
                      border: Border.all(color: AppColors.border),
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
                                Text(
                                  inv.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${inv.type.name.toUpperCase()}${inv.platform != null ? " • ${inv.platform}" : ""}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'update_val') {
                                  _showUpdateValuationDialog(context, ref, inv);
                                } else if (val == 'delete') {
                                  ref
                                      .read(investmentRepositoryProvider)
                                      .delete(inv.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'update_val',
                                  child: Text('Update Nilai Pasar Manual'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Modal: ${formatRupiah(inv.initialCost)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            Text('Nilai: ${formatRupiah(inv.currentValue)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (inv.units != null)
                              Text('Unit: ${inv.units}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary))
                            else
                              const SizedBox(),
                            Text(
                              '${isPositive ? '+' : ''}${formatRupiah(gain)} (${isPositive ? '+' : ''}${roi.toStringAsFixed(2)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPositive
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                          ],
                        ),
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

  void _showUpdateValuationDialog(
      BuildContext context, WidgetRef ref, Investment inv) {
    final valCtrl = TextEditingController(text: inv.currentValue.toString());
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Nilai: ${inv.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aplikasi berjalan offline. Masukkan nilai pasar terkini dari portofolio Anda.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandSeparatorInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Nilai Pasar Baru (Rp)',
                hintText: 'Masukkan nominal',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                  labelText: 'Catatan Penilaian (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final newVal = int.tryParse(
                      valCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
                  inv.currentValue;
              await ref.read(investmentRepositoryProvider).updateValuation(
                    inv.id,
                    newValue: newVal,
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
    );
  }
}

// ============================================================
// TAB 2: DEPOSITS
// ============================================================

class _DepositsTab extends ConsumerWidget {
  const _DepositsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryStream = ref.watch(depositRepositoryProvider).watchSummary();
    final depositsStream = ref.watch(depositRepositoryProvider).watchDeposits();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DepositSummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data ??
                  const DepositSummary(
                    totalPrincipal: 0,
                    totalEstimatedNetInterest: 0,
                    totalMaturityAmount: 0,
                    count: 0,
                  );

              final tokens = context.tokens;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Total Pokok Deposito',
                          value: formatRupiah(summary.totalPrincipal),
                        ),
                        _StatBox(
                          label: 'Estimasi Bunga Bersih',
                          value:
                              formatRupiah(summary.totalEstimatedNetInterest),
                          color: tokens.income,
                        ),
                      ],
                    ),
                    Divider(height: 20, color: tokens.borderHairline),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Total Nilai Jatuh Tempo',
                          value: formatRupiah(summary.totalMaturityAmount),
                          color: tokens.dataHue,
                        ),
                        _StatBox(
                          label: 'Deposito Aktif',
                          value: '${summary.count} Simpanan',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Daftar Deposito Berjangka',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Deposit>>(
            stream: depositsStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Belum ada simpanan deposito.\nTekan + untuk menambah deposito.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
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
                  final dep = list[index];
                  final calc = DepositRules.calculateDeposit(
                    principal: dep.principal,
                    rateBps: dep.annualRateBps,
                    tenorMonths: dep.tenorMonths,
                    isCompound:
                        dep.interestType == DepositInterestType.compound,
                    compoundFrequency: dep.compoundFrequency,
                    taxRateBps: dep.taxRateBps,
                    feeAmount: dep.feeAmount,
                  );

                  final tokens = context.tokens;
                  final ratePercent = dep.annualRateBps / 100.0;
                  final isMatured = dep.status == DepositStatus.matured;

                  return InkWell(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    onTap: () =>
                        DepositDialogHelper.showDetail(context, ref, dep),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius:
                            BorderRadius.circular(context.tokens.radiusCard),
                        border: Border.all(
                          color:
                              isMatured ? tokens.income : tokens.borderHairline,
                        ),
                      ),
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
                                    Text(
                                      dep.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dep.bankName ?? "Bank"} • Bunga ${ratePercent.toStringAsFixed(2)}% (${dep.interestType.name})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'detail') {
                                    DepositDialogHelper.showDetail(
                                        context, ref, dep);
                                  } else if (val == 'edit') {
                                    DepositDialogHelper.showEdit(
                                        context, ref, dep);
                                  } else if (val == 'withdraw') {
                                    DepositDialogHelper.showWithdraw(
                                        context, ref, dep, calc);
                                  } else if (val == 'rollover') {
                                    ref
                                        .read(depositRepositoryProvider)
                                        .rollover(dep.id);
                                  } else if (val == 'delete') {
                                    DepositDialogHelper.confirmDelete(
                                        context, ref, dep);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'detail',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('Lihat Rincian Detail'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Ubah Deposito'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'withdraw',
                                    child: Row(
                                      children: [
                                        Icon(
                                            Icons
                                                .account_balance_wallet_outlined,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('Cairkan Deposito'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rollover',
                                    child: Row(
                                      children: [
                                        Icon(Icons.autorenew_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Perpanjang (Rollover)'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            size: 18, color: tokens.expense),
                                        const SizedBox(width: 8),
                                        Text('Hapus Deposito',
                                            style: TextStyle(
                                                color: tokens.expense)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Mulai: ${formatDateIndo(dep.startDate)}',
                                  style: TextStyle(
                                      fontSize: 11, color: tokens.textMuted)),
                              Text(
                                  'Jatuh Tempo: ${formatDateIndo(dep.maturityDate)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isMatured
                                          ? tokens.income
                                          : tokens.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pokok: ${formatRupiah(dep.principal)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              Text(
                                'Hasil: ${formatRupiah(calc.maturityAmount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.dataHue,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bunga Bersih: +${formatRupiah(calc.netInterest)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.income,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              Text(
                                isMatured
                                    ? 'Sudah Jatuh Tempo'
                                    : '${dep.tenorMonths} Bulan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMatured
                                      ? tokens.income
                                      : tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatBox({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: color ?? tokens.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
