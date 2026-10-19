import 'package:flutter/material.dart';
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
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(
                icon: Icon(Icons.trending_up_rounded),
                text: 'Portofolio Investasi'),
            Tab(
                icon: Icon(Icons.account_balance_rounded),
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
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Investasi Baru' : 'Deposito Baru',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddInvestmentDialog(context, ref);
          } else {
            _showAddDepositDialog(context, ref);
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
                  decoration:
                      const InputDecoration(labelText: 'Modal Awal (Rp) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Nilai Pasar Saat Ini (Rp) *'),
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

  // ============================================================
  // DIALOGS: ADD DEPOSIT
  // ============================================================

  void _showAddDepositDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final principalCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '6.25');
    final tenorCtrl = TextEditingController(text: '12');
    final taxCtrl = TextEditingController(text: '20');
    final feeCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    DepositInterestType interestType = DepositInterestType.simple;
    DateTime startDate = DateTime.now();

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
                    decoration: const InputDecoration(
                        labelText: 'Pokok Deposito (Rp) *'),
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
                              labelText: 'Bunga % / tahun (misal 6.25)'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: tenorCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Tenor (bulan)'),
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
                        child: Text('Bunga Majemuk (Compound Bulanan)'),
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
                          decoration: const InputDecoration(
                              labelText: 'Biaya Lain (Rp)'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
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
                              color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bunga Bersih:',
                                style: TextStyle(fontSize: 12)),
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
                                style: TextStyle(fontSize: 12)),
                            Text(
                              formatRupiah(previewCalc.maturityAmount),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
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
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty || principal <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Nama dan pokok deposito harus valid')),
                    );
                    return;
                  }

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
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );

                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
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

              final isPositive = summary.totalGain >= 0;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
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
                          label: 'Total Modal',
                          value: formatRupiah(summary.totalCost),
                          color: Colors.white70,
                        ),
                        _StatBox(
                          label: 'Nilai Sekarang',
                          value: formatRupiah(summary.totalValue),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Keuntungan (Rp)',
                          value:
                              '${isPositive ? '+' : ''}${formatRupiah(summary.totalGain)}',
                          color:
                              isPositive ? AppColors.income : AppColors.expense,
                        ),
                        _StatBox(
                          label: 'Imbal Hasil (%)',
                          value:
                              '${isPositive ? '+' : ''}${summary.returnPercent.toStringAsFixed(2)}%',
                          color:
                              isPositive ? AppColors.income : AppColors.expense,
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
                      style: TextStyle(color: Colors.white54),
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
                      borderRadius: BorderRadius.circular(14),
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
                                      fontSize: 16),
                                ),
                                Text(
                                  '${inv.type.name.toUpperCase()}${inv.platform != null ? " • ${inv.platform}" : ""}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54),
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
                                    fontSize: 12, color: Colors.white70)),
                            Text('Nilai: ${formatRupiah(inv.currentValue)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (inv.units != null)
                              Text('Unit: ${inv.units}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54))
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
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Nilai Pasar Baru (Rp)'),
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

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
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
                          label: 'Total Pokok Deposito',
                          value: formatRupiah(summary.totalPrincipal),
                          color: Colors.white,
                        ),
                        _StatBox(
                          label: 'Estimasi Bunga Bersih',
                          value:
                              formatRupiah(summary.totalEstimatedNetInterest),
                          color: AppColors.income,
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatBox(
                          label: 'Total Nilai Jatuh Tempo',
                          value: formatRupiah(summary.totalMaturityAmount),
                          color: AppColors.primary,
                        ),
                        _StatBox(
                          label: 'Deposito Aktif',
                          value: '${summary.count} Simpanan',
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
                      style: TextStyle(color: Colors.white54),
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

                  final ratePercent = dep.annualRateBps / 100.0;
                  final isMatured = dep.status == DepositStatus.matured;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMatured
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
                                Text(
                                  dep.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  '${dep.bankName ?? "Bank"} • Bunga ${ratePercent.toStringAsFixed(2)}% (${dep.interestType.name})',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'withdraw') {
                                  _showWithdrawDialog(context, ref, dep, calc);
                                } else if (val == 'rollover') {
                                  ref
                                      .read(depositRepositoryProvider)
                                      .rollover(dep.id);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'withdraw',
                                  child: Text('Cairkan Deposito (Withdraw)'),
                                ),
                                const PopupMenuItem(
                                  value: 'rollover',
                                  child: Text('Perpanjang (Rollover)'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pokok: ${formatRupiah(dep.principal)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                            Text(
                                'Jatuh Tempo: ${dep.maturityDate.year}-${dep.maturityDate.month.toString().padLeft(2, '0')}-${dep.maturityDate.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isMatured
                                        ? AppColors.income
                                        : Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Bunga Bersih: +${formatRupiah(calc.netInterest)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.income)),
                            Text('Hasil: ${formatRupiah(calc.maturityAmount)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
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

  void _showWithdrawDialog(
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
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
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
