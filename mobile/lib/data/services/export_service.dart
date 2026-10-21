import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/data/services/report_service.dart';

class ExportResult {
  final bool success;
  final String message;
  final String? filePath;

  const ExportResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// Service untuk mengekspor data ke format CSV dan PDF.
///
/// Kebijakan Keamanan & Format:
/// - CSV dienkripsi dengan UTF-8 + BOM (\uFEFF) untuk kompatibilitas Excel.
/// - Perlindungan dari CSV Formula Injection: karakter diawali '=', '+', '-', '@' diawali dengan kutip tunggal (').
/// - PDF mencantumkan periode, tanggal cetak, format mata uang konsisten (Rupiah), dan ringkasan eksekutif.
/// - Menggunakan share_plus untuk berbagi file secara aman di Android / Desktop.
class ExportService {
  final AppDatabase _db;
  final ReportService _reportService;

  ExportService(this._db, this._reportService);

  /// Bersihkan teks dari potensi eksekusi formula jahat di aplikasi spreadsheet (Formula Injection).
  static String sanitizeForCsv(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.startsWith('=') ||
        trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('@')) {
      return "'$trimmed";
    }
    return value;
  }

  Future<Directory> _resolveDirectory(Directory? customDir) async {
    if (customDir != null) return customDir;
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Ekspor daftar transaksi ke file CSV.
  Future<ExportResult> exportTransactionsToCsv({
    DateTime? startDate,
    DateTime? endDate,
    Directory? outputDir,
  }) async {
    try {
      final query = _db.select(_db.transactions).join([
        leftOuterJoin(_db.accounts,
            _db.accounts.id.equalsExp(_db.transactions.accountId)),
        leftOuterJoin(_db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId)),
      ]);

      if (startDate != null && endDate != null) {
        query.where(
          _db.transactions.date.isBiggerOrEqualValue(startDate) &
              _db.transactions.date.isSmallerOrEqualValue(endDate),
        );
      }

      query.orderBy([
        OrderingTerm.desc(_db.transactions.date),
        OrderingTerm.desc(_db.transactions.id),
      ]);

      final rows = await query.get();

      final csvData = <List<dynamic>>[
        [
          'ID',
          'Tanggal',
          'Tipe',
          'Akun',
          'Kategori',
          'Nominal (Rp)',
          'Keterangan',
          'Catatan',
          'Status Aktual'
        ],
      ];

      for (final r in rows) {
        final t = r.readTable(_db.transactions);
        final a = r.readTableOrNull(_db.accounts);
        final c = r.readTableOrNull(_db.categories);

        final typeName = switch (t.type) {
          TransactionType.income => 'Pemasukan',
          TransactionType.expense => 'Pengeluaran',
          TransactionType.refund => 'Pengembalian Dana',
          TransactionType.adjustment => 'Penyesuaian',
        };

        csvData.add([
          t.id,
          t.date.toIso8601String().split('T').first,
          typeName,
          sanitizeForCsv(a?.name ?? '-'),
          sanitizeForCsv(c?.name ?? '-'),
          t.amount,
          sanitizeForCsv(t.description ?? ''),
          sanitizeForCsv(t.notes ?? ''),
          t.isActual ? 'Aktual' : 'Rencana',
        ]);
      }

      // Encode CSV dengan UTF-8 BOM
      final csvString = const ListToCsvConverter().convert(csvData);
      final bomCsv = '\uFEFF$csvString';

      final dir = await _resolveDirectory(outputDir);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'money_flow_transactions_$timestamp.csv';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(bomCsv);

      return ExportResult(
        success: true,
        message: 'Berhasil mengekspor ${rows.length} transaksi ke CSV',
        filePath: file.path,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Gagal mengekspor transaksi ke CSV: $e',
      );
    }
  }

  /// Ekspor daftar akun dan saldo ke file CSV.
  Future<ExportResult> exportAccountsToCsv({
    Directory? outputDir,
  }) async {
    try {
      final accounts = await (_db.select(_db.accounts)
            ..where((a) => a.isActive.equals(true)))
          .get();

      final csvData = <List<dynamic>>[
        ['ID', 'Nama Dompet / Akun', 'Tipe', 'Saldo (Rp)', 'Waktu Dibuat'],
      ];

      for (final a in accounts) {
        csvData.add([
          a.id,
          sanitizeForCsv(a.name),
          a.type.name,
          a.balance,
          a.createdAt.toIso8601String().split('T').first,
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final bomCsv = '\uFEFF$csvString';

      final dir = await _resolveDirectory(outputDir);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'money_flow_accounts_$timestamp.csv';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(bomCsv);

      return ExportResult(
        success: true,
        message: 'Berhasil mengekspor ${accounts.length} akun ke CSV',
        filePath: file.path,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Gagal mengekspor akun ke CSV: $e',
      );
    }
  }

  /// Ekspor Laporan Keuangan Komprehensif ke format PDF resmi.
  Future<ExportResult> exportFinancialReportToPdf({
    DateTime? startDate,
    DateTime? endDate,
    Directory? outputDir,
  }) async {
    try {
      final report = await _reportService.getComprehensiveReport(
        startDate: startDate,
        endDate: endDate,
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MONEY FLOW - LAPORAN KEUANGAN',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Periode: ${formatDate(report.startDate)} s/d ${formatDate(report.endDate)}',
                          style: const pw.TextStyle(
                              fontSize: 11, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Dicetak: ${formatDate(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Ringkasan Eksekutif (Cards)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfSummaryCol(
                        'Total Pemasukan',
                        formatRupiah(report.cashFlow.totalIncome),
                        PdfColors.green800),
                    _buildPdfSummaryCol(
                        'Total Pengeluaran',
                        formatRupiah(report.cashFlow.totalExpense),
                        PdfColors.red800),
                    _buildPdfSummaryCol(
                        'Arus Kas Bersih',
                        formatRupiah(report.cashFlow.netCashFlow),
                        PdfColors.blue800),
                    _buildPdfSummaryCol('Kekayaan Bersih',
                        formatRupiah(report.netWorth), PdfColors.purple800),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Rincian Pengeluaran per Kategori
              pw.Text(
                '1. Pengeluaran per Kategori',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              if (report.expenseCategories.isEmpty)
                pw.Text('Tidak ada pengeluaran pada periode ini.',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600))
              else
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Kategori',
                    'Jumlah Transaksi',
                    'Total (Rp)',
                    'Porsi (%)'
                  ],
                  data: report.expenseCategories
                      .map((c) => [
                            c.categoryName,
                            c.transactionCount.toString(),
                            formatRupiah(c.totalAmount),
                            '${c.percentage.toStringAsFixed(1)}%',
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              pw.SizedBox(height: 20),

              // Rincian Saldo Akun
              pw.Text(
                '2. Posisi Saldo Dompet & Rekening',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Nama Akun',
                  'Tipe',
                  'Saldo Saat Ini',
                  'Porsi dari Total Kas'
                ],
                data: report.accountBalances
                    .map((a) => [
                          a.accountName,
                          a.type.name.toUpperCase(),
                          formatRupiah(a.balance),
                          '${a.shareOfTotal.toStringAsFixed(1)}%',
                        ])
                    .toList(),
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
              ),
              pw.SizedBox(height: 20),

              // Ringkasan Aset & Kewajiban
              pw.Text(
                '3. Ringkasan Aset & Kewajiban (Net Worth)',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Komponen Keuangan', 'Nilai (Rp)'],
                data: [
                  [
                    'Total Saldo Kas & Bank',
                    formatRupiah(report.totalCashBalance)
                  ],
                  [
                    'Portofolio Investasi (Nilai Pasar)',
                    formatRupiah(report.totalInvestmentsValue)
                  ],
                  [
                    'Pokok Simpanan Deposito Aktif',
                    formatRupiah(report.totalDepositsPrincipal)
                  ],
                  [
                    'Total Piutang Berjalan',
                    formatRupiah(report.totalReceivables)
                  ],
                  ['Total Seluruh Aset', formatRupiah(report.totalAssets)],
                  ['Total Kewajiban (Hutang)', formatRupiah(report.totalDebts)],
                  ['Net Worth (Aset Bersih)', formatRupiah(report.netWorth)],
                ],
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
              ),

              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.Text(
                'Money Flow Android - Sistem Manajemen Finansial Pribadi Offline-First.',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ];
          },
        ),
      );

      final dir = await _resolveDirectory(outputDir);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'laporan_keuangan_money_flow_$timestamp.pdf';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(await pdf.save());

      return ExportResult(
        success: true,
        message: 'Laporan PDF berhasil dibuat',
        filePath: file.path,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Gagal membuat laporan PDF: $e',
      );
    }
  }

  /// Ekspor Laporan Keuangan Komprehensif ke format Excel (.xlsx) dengan 7 sheet terstruktur.
  Future<ExportResult> exportFinancialReportToExcel({
    required DateTime startDate,
    required DateTime endDate,
    Directory? outputDir,
  }) async {
    if (startDate.isAfter(endDate)) {
      return const ExportResult(
        success: false,
        message: 'Tanggal mulai tidak boleh lebih besar dari tanggal berakhir.',
      );
    }

    try {
      final report = await _reportService.getComprehensiveReport(
        startDate: startDate,
        endDate: endDate,
      );

      final excel = Excel.createExcel();

      // ----------------------------------------------------
      // SHEET 1: RINGKASAN KEUANGAN
      // ----------------------------------------------------
      final sSummary = excel['Ringkasan Keuangan'];
      excel.delete('Sheet1'); // Hapus sheet default

      sSummary.appendRow([TextCellValue('LAPORAN KEUANGAN MONEY FLOW')]);
      sSummary.appendRow([
        TextCellValue(
            'Periode: ${formatDate(startDate)} s/d ${formatDate(endDate)}')
      ]);
      sSummary.appendRow(
          [TextCellValue('Waktu Cetak: ${formatDateTime(DateTime.now())}')]);
      sSummary.appendRow([TextCellValue('')]);

      sSummary.appendRow([
        TextCellValue('1. ARUS KAS PERIODE BERJALAN'),
        TextCellValue('Nominal (Rp)')
      ]);
      sSummary.appendRow([
        TextCellValue('Total Pemasukan'),
        IntCellValue(report.cashFlow.totalIncome)
      ]);
      sSummary.appendRow([
        TextCellValue('Total Pengeluaran'),
        IntCellValue(report.cashFlow.totalExpense)
      ]);
      sSummary.appendRow([
        TextCellValue('Arus Kas Bersih (Net Cash Flow)'),
        IntCellValue(report.cashFlow.netCashFlow)
      ]);
      sSummary.appendRow([
        TextCellValue('Jumlah Transaksi Tercatat'),
        IntCellValue(report.cashFlow.transactionCount)
      ]);
      sSummary.appendRow([TextCellValue('')]);

      sSummary.appendRow([
        TextCellValue('2. POSISI KEKAYAAN BERSIH (NET WORTH)'),
        TextCellValue('Nominal (Rp)')
      ]);
      sSummary.appendRow([
        TextCellValue('Total Saldo Kas & Bank'),
        IntCellValue(report.totalCashBalance)
      ]);
      sSummary.appendRow([
        TextCellValue('Total Portofolio Investasi'),
        IntCellValue(report.totalInvestmentsValue)
      ]);
      sSummary.appendRow([
        TextCellValue('Total Pokok Deposito'),
        IntCellValue(report.totalDepositsPrincipal)
      ]);
      sSummary.appendRow([
        TextCellValue('Total Piutang Berjalan'),
        IntCellValue(report.totalReceivables)
      ]);
      sSummary.appendRow([
        TextCellValue('Total Seluruh Aset'),
        IntCellValue(report.totalAssets)
      ]);
      sSummary.appendRow([
        TextCellValue('Total Kewajiban (Hutang)'),
        IntCellValue(report.totalDebts)
      ]);
      sSummary.appendRow([
        TextCellValue('Kekayaan Bersih (Net Worth)'),
        IntCellValue(report.netWorth)
      ]);

      // ----------------------------------------------------
      // SHEET 2: RIWAYAT TRANSAKSI
      // ----------------------------------------------------
      final sTxns = excel['Riwayat Transaksi'];
      sTxns.appendRow([
        TextCellValue('ID'),
        TextCellValue('Tanggal'),
        TextCellValue('Tipe Transaksi'),
        TextCellValue('Akun / Dompet'),
        TextCellValue('Kategori'),
        TextCellValue('Nominal (Rp)'),
        TextCellValue('Keterangan'),
        TextCellValue('Catatan'),
      ]);

      final txQuery = _db.select(_db.transactions).join([
        leftOuterJoin(_db.accounts,
            _db.accounts.id.equalsExp(_db.transactions.accountId)),
        leftOuterJoin(_db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId)),
      ])
        ..where(_db.transactions.date.isBiggerOrEqualValue(startDate) &
            _db.transactions.date.isSmallerOrEqualValue(endDate) &
            _db.transactions.isActual.equals(true))
        ..orderBy([OrderingTerm.desc(_db.transactions.date)]);

      final txRows = await txQuery.get();
      for (final r in txRows) {
        final t = r.readTable(_db.transactions);
        final a = r.readTableOrNull(_db.accounts);
        final c = r.readTableOrNull(_db.categories);

        sTxns.appendRow([
          IntCellValue(t.id),
          TextCellValue(formatDate(t.date)),
          TextCellValue(t.type == TransactionType.income
              ? 'Pemasukan'
              : (t.type == TransactionType.expense
                  ? 'Pengeluaran'
                  : (t.type == TransactionType.refund
                      ? 'Pengembalian'
                      : 'Penyesuaian'))),
          TextCellValue(a?.name ?? '-'),
          TextCellValue(c?.name ?? '-'),
          IntCellValue(t.amount),
          TextCellValue(sanitizeForCsv(t.description)),
          TextCellValue(sanitizeForCsv(t.notes)),
        ]);
      }

      // ----------------------------------------------------
      // SHEET 3: RINGKASAN BULANAN
      // ----------------------------------------------------
      final sMonthly = excel['Ringkasan Bulanan'];
      sMonthly.appendRow([
        TextCellValue('Bulan'),
        TextCellValue('Total Pemasukan (Rp)'),
        TextCellValue('Total Pengeluaran (Rp)'),
        TextCellValue('Arus Kas Bersih (Rp)'),
      ]);

      for (final m in report.cashFlow.monthlyTrends) {
        sMonthly.appendRow([
          TextCellValue(m.monthLabel),
          IntCellValue(m.income),
          IntCellValue(m.expense),
          IntCellValue(m.netFlow),
        ]);
      }

      // ----------------------------------------------------
      // SHEET 4: AKUN DAN SALDO
      // ----------------------------------------------------
      final sAccounts = excel['Akun dan Saldo'];
      sAccounts.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nama Akun / Dompet'),
        TextCellValue('Tipe Akun'),
        TextCellValue('Saldo Saat Ini (Rp)'),
        TextCellValue('Status'),
      ]);

      final allAccounts = await (_db.select(_db.accounts)
            ..orderBy([(a) => OrderingTerm.asc(a.id)]))
          .get();

      for (final a in allAccounts) {
        sAccounts.appendRow([
          IntCellValue(a.id),
          TextCellValue(a.name),
          TextCellValue(a.type.name.toUpperCase()),
          IntCellValue(a.balance),
          TextCellValue(a.isActive ? 'Aktif' : 'Diarsipkan'),
        ]);
      }

      // ----------------------------------------------------
      // SHEET 5: INVESTASI
      // ----------------------------------------------------
      final sInvs = excel['Tabungan dan Investasi'];
      sInvs.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nama Instrumen'),
        TextCellValue('Tipe Investasi'),
        TextCellValue('Platform / Broker'),
        TextCellValue('Modal Awal (Rp)'),
        TextCellValue('Nilai Pasar Terkini (Rp)'),
        TextCellValue('Unit / Lot'),
        TextCellValue('Tanggal Beli'),
        TextCellValue('Status'),
      ]);

      final allInvs = await (_db.select(_db.investments)
            ..orderBy([(i) => OrderingTerm.asc(i.id)]))
          .get();

      for (final inv in allInvs) {
        sInvs.appendRow([
          IntCellValue(inv.id),
          TextCellValue(inv.name),
          TextCellValue(inv.type.name.toUpperCase()),
          TextCellValue(inv.platform ?? '-'),
          IntCellValue(inv.initialCost),
          IntCellValue(inv.currentValue),
          DoubleCellValue(inv.units ?? 0.0),
          TextCellValue(
              inv.purchaseDate != null ? formatDate(inv.purchaseDate!) : '-'),
          TextCellValue(inv.isActive ? 'Aktif' : 'Nonaktif'),
        ]);
      }

      // ----------------------------------------------------
      // SHEET 6: DEPOSITO
      // ----------------------------------------------------
      final sDeps = excel['Deposito'];
      sDeps.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nama Deposito'),
        TextCellValue('Bank / Institusi'),
        TextCellValue('Nominal Pokok (Rp)'),
        TextCellValue('Suku Bunga (% p.a.)'),
        TextCellValue('Tenor (Bulan)'),
        TextCellValue('Pajak Bunga (%)'),
        TextCellValue('Tanggal Mulai'),
        TextCellValue('Jatuh Tempo'),
        TextCellValue('Status'),
      ]);

      final allDeps = await (_db.select(_db.deposits)
            ..orderBy([(d) => OrderingTerm.asc(d.id)]))
          .get();

      for (final dep in allDeps) {
        sDeps.appendRow([
          IntCellValue(dep.id),
          TextCellValue(dep.name),
          TextCellValue(dep.bankName ?? '-'),
          IntCellValue(dep.principal),
          DoubleCellValue(dep.annualRateBps / 100.0),
          IntCellValue(dep.tenorMonths),
          DoubleCellValue(dep.taxRateBps / 100.0),
          TextCellValue(formatDate(dep.startDate)),
          TextCellValue(formatDate(dep.maturityDate)),
          TextCellValue(dep.status.name.toUpperCase()),
        ]);
      }

      // ----------------------------------------------------
      // SHEET 7: UTANG PIUTANG DAN TAGIHAN
      // ----------------------------------------------------
      final sDebts = excel['Utang Piutang & Tagihan'];
      sDebts.appendRow([TextCellValue('A. DAFTAR HUTANG & PIUTANG')]);
      sDebts.appendRow([
        TextCellValue('ID'),
        TextCellValue('Jenis'),
        TextCellValue('Nama / Keperluan'),
        TextCellValue('Pihak Terkait'),
        TextCellValue('Pokok Awal (Rp)'),
        TextCellValue('Sisa Saldo (Rp)'),
        TextCellValue('Jatuh Tempo'),
        TextCellValue('Status'),
      ]);

      final allDebts = await (_db.select(_db.debts)
            ..orderBy([(d) => OrderingTerm.asc(d.id)]))
          .get();

      for (final d in allDebts) {
        sDebts.appendRow([
          IntCellValue(d.id),
          TextCellValue(d.type == DebtType.hutang
              ? 'Hutang (Kewajiban)'
              : 'Piutang (Hak)'),
          TextCellValue(d.name),
          TextCellValue(d.person ?? '-'),
          IntCellValue(d.totalAmount),
          IntCellValue(d.remainingAmount),
          TextCellValue(d.dueDate != null ? formatDate(d.dueDate!) : '-'),
          TextCellValue(d.status.name.toUpperCase()),
        ]);
      }

      sDebts.appendRow([TextCellValue('')]);
      sDebts.appendRow([TextCellValue('B. DAFTAR TAGIHAN (BILLS)')]);
      sDebts.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nama Tagihan'),
        TextCellValue('Nominal (Rp)'),
        TextCellValue('Jatuh Tempo'),
        TextCellValue('Frekuensi'),
        TextCellValue('Status'),
      ]);

      final allBills = await (_db.select(_db.bills)
            ..orderBy([(b) => OrderingTerm.asc(b.id)]))
          .get();

      for (final b in allBills) {
        sDebts.appendRow([
          IntCellValue(b.id),
          TextCellValue(b.name),
          IntCellValue(b.amount),
          TextCellValue(formatDate(b.dueDate)),
          TextCellValue(b.frequency.name.toUpperCase()),
          TextCellValue(b.status.name.toUpperCase()),
        ]);
      }

      final dir = await _resolveDirectory(outputDir);
      final sStr =
          '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
      final eStr =
          '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
      final fileName = 'Laporan_Keuangan_MoneyFlow_${sStr}_sd_$eStr.xlsx';
      final file = File(p.join(dir.path, fileName));

      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
      } else {
        throw StateError('Gagal melakukan encoding file Excel');
      }

      return ExportResult(
        success: true,
        message: 'Laporan keuangan Excel berhasil dibuat: $fileName',
        filePath: file.path,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Gagal membuat laporan Excel: $e',
      );
    }
  }

  /// Bagikan file hasil ekspor ke aplikasi lain (WhatsApp, Drive, Email, dsb.).
  Future<void> shareFile(String filePath,
      {String subject = 'Ekspor Money Flow'}) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: subject,
    );
  }

  static pw.Widget _buildPdfSummaryCol(
      String label, String value, PdfColor valueColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: valueColor)),
      ],
    );
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  final db = ref.watch(databaseProvider);
  final report = ref.watch(reportServiceProvider);
  return ExportService(db, report);
});
