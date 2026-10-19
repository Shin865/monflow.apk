import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/services/forecast_service.dart';
import 'package:money_flow/domain/rules/forecast_rules.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  String _selectedScenario = 'normal'; // 'conservative', 'normal', 'optimistic'
  int _projectionMonths = 6; // 3, 6, 12

  @override
  Widget build(BuildContext context) {
    final forecastFuture = ref
        .watch(forecastServiceProvider)
        .generateForecast(projectionMonths: _projectionMonths);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perkiraan Masa Depan (Forecast)'),
      ),
      body: FutureBuilder<ForecastReport>(
        future: forecastFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat perkiraan: ${snapshot.error}'),
            );
          }

          final report = snapshot.data!;
          final projections = report.scenarios[_selectedScenario] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Peringatan jika data kurang
                if (report.warningMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            report.warningMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Kartu Asumsi Dasar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Asumsi Dasar Proyeksi (Historis 3 Bulan)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MetricCol(
                            label: 'Saldo Awal Saat Ini',
                            value: formatRupiah(report.currentBalance),
                            color: AppColors.primary,
                          ),
                          _MetricCol(
                            label: 'Rata-rata Pemasukan',
                            value: formatRupiah(report.avgMonthlyIncome),
                            color: AppColors.income,
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MetricCol(
                            label: 'Rata-rata Pengeluaran',
                            value: formatRupiah(report.avgMonthlyExpense),
                            color: AppColors.expense,
                          ),
                          _MetricCol(
                            label: 'Tabungan Rencana',
                            value: formatRupiah(report.monthlyPurchaseSavings),
                            color: Colors.amberAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Selector Skenario
                const Text('Pilih Skenario Proyeksi:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScenarioButton(
                        label: 'Konservatif',
                        sublabel: 'Income ×0.9\nExpense ×1.1',
                        isSelected: _selectedScenario == 'conservative',
                        color: Colors.orangeAccent,
                        onTap: () =>
                            setState(() => _selectedScenario = 'conservative'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ScenarioButton(
                        label: 'Normal',
                        sublabel: 'Income ×1.0\nExpense ×1.0',
                        isSelected: _selectedScenario == 'normal',
                        color: AppColors.primary,
                        onTap: () =>
                            setState(() => _selectedScenario = 'normal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ScenarioButton(
                        label: 'Optimistis',
                        sublabel: 'Income ×1.1\nExpense ×0.9',
                        isSelected: _selectedScenario == 'optimistic',
                        color: AppColors.income,
                        onTap: () =>
                            setState(() => _selectedScenario = 'optimistic'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Durasi Proyeksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rentang Waktu:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [3, 6, 12].map((m) {
                        final isSel = _projectionMonths == m;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text('$m bln'),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            onSelected: (_) =>
                                setState(() => _projectionMonths = m),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tabel Proyeksi
                const Text(
                  'Tabel Proyeksi Saldo Masa Depan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: projections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = projections[index];
                    final isPositiveFlow = p.netFlow >= 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bulan ${p.date.month}/${p.date.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Saldo: ${formatRupiah(p.projectedBalance)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pemasukan: ${formatRupiah(p.income)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.income)),
                              Text('Pengeluaran: ${formatRupiah(p.expense)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.expense)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Tabungan: -${formatRupiah(p.purchaseSavings)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.amberAccent)),
                              Text(
                                'Arus Bersih: ${isPositiveFlow ? "+" : ""}${formatRupiah(p.netFlow)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPositiveFlow
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
                ),
                const SizedBox(height: 20),

                // Catatan Integritas Keuangan
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Colors.white54, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Catatan: Fitur Forecast adalah simulasi murni (read-only). Angka proyeksi tidak memodifikasi saldo akun, tidak mengubah transaksi historis, dan tidak menambah aset riil ke pembukuan.',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCol({
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
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ScenarioButton({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? color : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
