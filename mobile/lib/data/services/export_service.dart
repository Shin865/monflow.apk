import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
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

  /// Bagikan file hasil ekspor ke aplikasi lain (WhatsApp, Drive, Email, dsb.).
  Future<void> shareFile(String filePath,
      {String subject = 'Ekspor Money Flow'}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: subject,
      ),
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
