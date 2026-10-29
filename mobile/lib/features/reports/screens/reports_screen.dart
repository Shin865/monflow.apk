import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/services/report_service.dart';
import 'package:money_flow/data/services/export_service.dart';

enum ReportPeriod {
  thisMonth,
  lastMonth,
  last30Days,
  thisYear,
  custom,
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  DateTimeRange? _customDateRange;
  bool _isLoading = true;
  FinancialComprehensiveReport? _report;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  ({DateTime start, DateTime end}) _resolveDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.thisMonth:
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case ReportPeriod.lastMonth:
        return (
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
      case ReportPeriod.last30Days:
        return (
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case ReportPeriod.thisYear:
        return (
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case ReportPeriod.custom:
        if (_customDateRange != null) {
          return (
            start: _customDateRange!.start,
            end: DateTime(
              _customDateRange!.end.year,
              _customDateRange!.end.month,
              _customDateRange!.end.day,
              23,
              59,
              59,
            ),
          );
        }
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final range = _resolveDateRange();
      final service = ref.read(reportServiceProvider);
      final report = await service.getComprehensiveReport(
        startDate: range.start,
        endDate: range.end,
      );

      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat laporan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = ReportPeriod.custom;
        _customDateRange = picked;
      });
      _loadReport();
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Format Ekspor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.incomeBg,
                child: Icon(Icons.table_chart_rounded, color: AppColors.income),
              ),
              title: const Text('Ekspor Transaksi (CSV)'),
              subtitle: const Text(
                  'Format spreadsheet dengan proteksi formula injection'),
              onTap: () async {
                Navigator.pop(ctx);
                final range = _resolveDateRange();
                final exporter = ref.read(exportServiceProvider);
                final res = await exporter.exportTransactionsToCsv(
                  startDate: range.start,
                  endDate: range.end,
                );
                if (mounted) {
                  if (res.success && res.filePath != null) {
                    await exporter.shareFile(res.filePath!,
                        subject: 'Ekspor Transaksi Money Flow');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(res.message),
                          backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.brandTealWash,
                child:
                    Icon(Icons.table_view_rounded, color: AppColors.brandTeal),
              ),
              title: const Text('Ekspor Laporan Keuangan (Excel .xlsx)'),
              subtitle: const Text(
                  'Buku kerja 7 sheet lengkap: Ringkasan, Transaksi, Bulanan, Akun, Investasi, Deposito, Hutang/Tagihan'),
              onTap: () async {
                Navigator.pop(ctx);
                final range = _resolveDateRange();
                final exporter = ref.read(exportServiceProvider);
                final res = await exporter.exportFinancialReportToExcel(
                  startDate: range.start,
                  endDate: range.end,
                );
                if (mounted) {
                  if (res.success && res.filePath != null) {
                    await exporter.shareFile(res.filePath!,
                        subject: 'Laporan Keuangan Excel Money Flow');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(res.message),
                          backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.transferBg,
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.transfer),
              ),
              title: const Text('Ekspor Daftar Akun (CSV)'),
              subtitle: const Text('Daftar saldo dan posisi akun aktif'),
              onTap: () async {
                Navigator.pop(ctx);
                final exporter = ref.read(exportServiceProvider);
                final res = await exporter.exportAccountsToCsv();
                if (mounted) {
                  if (res.success && res.filePath != null) {
                    await exporter.shareFile(res.filePath!,
                        subject: 'Ekspor Akun Money Flow');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(res.message),
                          backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.expenseBg,
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.expense),
              ),
              title: const Text('Ekspor Laporan Keuangan (PDF)'),
              subtitle: const Text(
                  'Dokumen cetak resmi lengkap dengan rincian per kategori'),
              onTap: () async {
                Navigator.pop(ctx);
                final range = _resolveDateRange();
                final exporter = ref.read(exportServiceProvider);
                final res = await exporter.exportFinancialReportToPdf(
                  startDate: range.start,
                  endDate: range.end,
                );
                if (mounted) {
                  if (res.success && res.filePath != null) {
                    await exporter.shareFile(res.filePath!,
                        subject: 'Laporan Keuangan Money Flow');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(res.message),
                          backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Ekspor Laporan',
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: AppColors.expense),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadReport,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildReportContent(_report!),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPeriodChip('Bulan Ini', ReportPeriod.thisMonth),
            const SizedBox(width: 8),
            _buildPeriodChip('Bulan Lalu', ReportPeriod.lastMonth),
            const SizedBox(width: 8),
            _buildPeriodChip('30 Hari Terakhir', ReportPeriod.last30Days),
            const SizedBox(width: 8),
            _buildPeriodChip('Tahun Ini', ReportPeriod.thisYear),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.date_range,
                  size: 16, color: AppColors.textPrimary),
              label: Text(
                _selectedPeriod == ReportPeriod.custom &&
                        _customDateRange != null
                    ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                    : 'Kustom...',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: _selectedPeriod == ReportPeriod.custom
                  ? AppColors.brandTealWash
                  : AppColors.surface,
              side: BorderSide(
                color: _selectedPeriod == ReportPeriod.custom
                    ? AppColors.brandTeal
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.tokens.radiusChip),
              ),
              onPressed: _pickCustomDateRange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, ReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTealWash,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected ? AppColors.brandTeal : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.tokens.radiusChip),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.brandTeal : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPeriod = period);
          _loadReport();
        }
      },
    );
  }

  Widget _buildReportContent(FinancialComprehensiveReport r) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Executive Summary Cards
          _buildExecutiveSummary(r),
          const SizedBox(height: 16),

          // 2. Tren Cash Flow (fl_chart)
          _buildCashFlowChartCard(r),
          const SizedBox(height: 16),

          // 3. Pengeluaran per Kategori (fl_chart Pie)
          _buildCategoryPieCard(r),
          // 4. Posisi Akun & Kekayaan Bersih
          _buildNetWorthCard(r),
          const SizedBox(height: 16),

          // 5. Ringkasan Investasi & Deposito
          _buildInvestmentsDepositsCard(r),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummary(FinancialComprehensiveReport r) {
    final isPositive = r.cashFlow.netCashFlow >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Arus Kas Periode Ini',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppColors.income.withOpacity(0.12)
                        : AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPositive ? 'Surplus' : 'Defisit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryBox(
                    'Pemasukan',
                    formatRupiah(r.cashFlow.totalIncome),
                    AppColors.income,
                    Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryBox(
                    'Pengeluaran',
                    formatRupiah(r.cashFlow.totalExpense),
                    AppColors.expense,
                    Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(context.tokens.radiusControl),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Cash Flow:',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  Text(
                    formatRupiah(r.cashFlow.netCashFlow),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isPositive ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(context.tokens.radiusControl),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowChartCard(FinancialComprehensiveReport r) {
    final trends = r.cashFlow.monthlyTrends;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tren Pemasukan vs Pengeluaran',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            const Text(
              'Perbandingan pendapatan dan belanja per bulan',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (trends.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                      'Belum ada data transaksi pada rentang waktu ini.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    barGroups: trends.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: (item.income / 1000000).toDouble(),
                            color: AppColors.income,
                            width: 10,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: (item.expense / 1000000).toDouble(),
                            color: AppColors.expense,
                            width: 10,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < trends.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  trends[idx].monthLabel.split(' ').first,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Pemasukan (Juta Rp)', AppColors.income),
                const SizedBox(width: 16),
                _buildLegendItem('Pengeluaran (Juta Rp)', AppColors.expense),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieCard(FinancialComprehensiveReport r) {
    final categories = r.expenseCategories;

    // Achromatic-ledger palette: brand hue + neutral tones (SKILL.md §6.4 max 4 hues)
    final colors = [
      AppColors.brandTeal,
      ...AppColors.chartNeutrals,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengeluaran per Kategori',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            const Text(
              'Alokasi pos belanja dan persentase',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            if (categories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Tidak ada pengeluaran pada periode ini.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              )
            else ...[
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: categories
                        .take(6)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final idx = entry.key;
                      final c = entry.value;
                      final col = colors[idx % colors.length];
                      return PieChartSectionData(
                        value: c.totalAmount.toDouble(),
                        title: '${c.percentage.toStringAsFixed(0)}%',
                        color: col,
                        radius: 46,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children:
                    categories.take(5).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  final col = colors[idx % colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: col, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c.categoryName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary))),
                        Text(formatRupiah(c.totalAmount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.textPrimary)),
                        const SizedBox(width: 6),
                        Text('(${c.percentage.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(FinancialComprehensiveReport r) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kekayaan Bersih & Posisi Aset',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            _buildKvRow(
                'Total Saldo Dompet & Bank', formatRupiah(r.totalCashBalance)),
            _buildKvRow('Nilai Portofolio Investasi',
                formatRupiah(r.totalInvestmentsValue)),
            _buildKvRow(
                'Pokok Deposito Aktif', formatRupiah(r.totalDepositsPrincipal)),
            _buildKvRow(
                'Total Piutang Berjalan', formatRupiah(r.totalReceivables)),
            const Divider(height: 16),
            _buildKvRow('Total Seluruh Aset', formatRupiah(r.totalAssets),
                isBold: true),
            _buildKvRow('Total Hutang (Kewajiban)', formatRupiah(r.totalDebts),
                color: AppColors.expense),
            const Divider(height: 16),
            _buildKvRow('Net Worth', formatRupiah(r.netWorth),
                isBold: true, color: AppColors.brandTeal, fontSize: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentsDepositsCard(FinancialComprehensiveReport r) {
    final gain = r.totalInvestmentsValue - r.totalInvestmentsCost;
    final isPositive = gain >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Investasi & Deposito',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            _buildKvRow('Modal Akuisisi Investasi',
                formatRupiah(r.totalInvestmentsCost)),
            _buildKvRow(
                'Nilai Pasar Terkini', formatRupiah(r.totalInvestmentsValue)),
            _buildKvRow(
              'Keuntungan Belum Terealisasi',
              formatRupiah(gain),
              color: isPositive ? AppColors.income : AppColors.expense,
            ),
            const Divider(height: 16),
            _buildKvRow(
                'Total Pokok Deposito', formatRupiah(r.totalDepositsPrincipal)),
          ],
        ),
      ),
    );
  }

  Widget _buildKvRow(String label, String value,
      {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  color: AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
