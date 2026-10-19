import 'dart:math';

/// Aturan perhitungan bunga deposito — porting dari backend Python.
///
/// Sumber: backend/app/models/deposit.py
/// Semua rumus diambil langsung dari property methods di model Deposit.
///
/// Catatan: Rate dan tax dalam persen (misal 4.0 = 4%), principal dalam Rupiah (int).
/// Hasil perhitungan bunga bisa menghasilkan pecahan, sehingga menggunakan double
/// untuk intermediate calculation, lalu dibulatkan ke int saat final.
class DepositRules {
  const DepositRules._();

  /// Hitung bunga kotor (sebelum pajak).
  ///
  /// Simple: P × r × t
  /// Compound: P × ((1 + r/n)^(n×t) - 1)
  ///
  /// [principal] dalam Rupiah (int)
  /// [annualRatePercent] dalam persen, misal 4.0 = 4%
  /// [tenorMonths] dalam bulan
  /// [isCompound] true untuk bunga majemuk
  /// [compoundFrequency] frekuensi compounding per tahun (12=bulanan, 4=kuartalan)
  static double grossInterest({
    required int principal,
    required double annualRatePercent,
    required int tenorMonths,
    bool isCompound = false,
    int compoundFrequency = 12,
  }) {
    final p = principal.toDouble();
    final r = annualRatePercent / 100.0;
    final t = tenorMonths / 12.0;

    if (!isCompound) {
      // Simple interest: P × r × t
      return p * r * t;
    } else {
      // Compound interest: P × ((1 + r/n)^(n×t) - 1)
      final n = compoundFrequency.toDouble();
      return p * (pow(1 + r / n, n * t) - 1);
    }
  }

  /// Hitung pajak atas bunga.
  ///
  /// [grossInterestAmount] bunga kotor
  /// [taxRatePercent] tarif pajak dalam persen (default: 20%)
  static double taxAmount({
    required double grossInterestAmount,
    double taxRatePercent = 20.0,
  }) {
    return grossInterestAmount * (taxRatePercent / 100.0);
  }

  /// Hitung bunga bersih setelah pajak.
  static double netInterest({
    required double grossInterestAmount,
    double taxRatePercent = 20.0,
  }) {
    return grossInterestAmount -
        taxAmount(
          grossInterestAmount: grossInterestAmount,
          taxRatePercent: taxRatePercent,
        );
  }

  /// Hitung total yang diterima saat jatuh tempo.
  ///
  /// maturity = principal + net_interest
  static double maturityAmount({
    required int principal,
    required double annualRatePercent,
    required int tenorMonths,
    bool isCompound = false,
    int compoundFrequency = 12,
    double taxRatePercent = 20.0,
  }) {
    final gross = grossInterest(
      principal: principal,
      annualRatePercent: annualRatePercent,
      tenorMonths: tenorMonths,
      isCompound: isCompound,
      compoundFrequency: compoundFrequency,
    );

    final net = netInterest(
      grossInterestAmount: gross,
      taxRatePercent: taxRatePercent,
    );

    return principal + net;
  }

  /// Bulatkan hasil ke integer Rupiah terdekat menggunakan aturan Half-Up (away from zero).
  /// Menjamin tidak ada selisih floating point saat disimpan ke SQLite.
  static int roundHalfUp(num value) {
    if (value >= 0) {
      return (value + 0.5).floor();
    } else {
      return (value - 0.5).ceil();
    }
  }

  /// Bulatkan hasil ke integer Rupiah terdekat (backward-compatible).
  static int roundToRupiah(double amount) {
    return roundHalfUp(amount);
  }

  /// Hitung tanggal jatuh tempo kalender yang aman (mendukung kabisat dan pergantian tahun).
  static DateTime calculateMaturityDate(DateTime startDate, int tenorMonths) {
    var newYear = startDate.year + (startDate.month - 1 + tenorMonths) ~/ 12;
    var newMonth = (startDate.month - 1 + tenorMonths) % 12 + 1;
    // Cari jumlah hari maksimum di bulan target
    final daysInMonth = DateTime(newYear, newMonth + 1, 0).day;
    final day = startDate.day > daysInMonth ? daysInMonth : startDate.day;
    return DateTime(newYear, newMonth, day, startDate.hour, startDate.minute);
  }

  /// Perhitungan komprehensif deposito berbasis integer basis points (bps).
  ///
  /// [principal] pokok deposito dalam Rupiah (int)
  /// [rateBps] suku bunga tahunan dalam basis poin (misal 6.25% = 625 bps, 4% = 400 bps)
  /// [tenorMonths] tenor dalam bulan
  /// [isCompound] true untuk bunga majemuk
  /// [compoundFrequency] frekuensi compounding per tahun (12=bulanan, 4=kuartalan, 1=tahunan)
  /// [taxRateBps] tarif pajak dalam basis poin (default: 2000 bps = 20.00%)
  /// [feeAmount] biaya administrasi / pencairan dalam Rupiah (default: 0)
  static DepositCalculationResult calculateDeposit({
    required int principal,
    required int rateBps,
    required int tenorMonths,
    bool isCompound = false,
    int compoundFrequency = 12,
    int taxRateBps = 2000,
    int feeAmount = 0,
  }) {
    final annualRatePercent = rateBps / 100.0;
    final taxRatePercent = taxRateBps / 100.0;

    final gross = grossInterest(
      principal: principal,
      annualRatePercent: annualRatePercent,
      tenorMonths: tenorMonths,
      isCompound: isCompound,
      compoundFrequency: compoundFrequency,
    );

    final tax = taxAmount(
      grossInterestAmount: gross,
      taxRatePercent: taxRatePercent,
    );

    final netRaw = gross - tax - feeAmount;
    final maturityRaw = principal + netRaw;

    return DepositCalculationResult(
      principal: principal,
      grossInterest: roundHalfUp(gross),
      taxAmount: roundHalfUp(tax),
      feeAmount: feeAmount,
      netInterest: roundHalfUp(netRaw),
      maturityAmount: roundHalfUp(maturityRaw),
      grossInterestRaw: gross,
      taxAmountRaw: tax,
      netInterestRaw: netRaw,
    );
  }
}

/// Hasil perhitungan deposito dengan integer Rupiah final yang aman.
class DepositCalculationResult {
  final int principal;
  final int grossInterest;
  final int taxAmount;
  final int feeAmount;
  final int netInterest;
  final int maturityAmount;
  final double grossInterestRaw;
  final double taxAmountRaw;
  final double netInterestRaw;

  const DepositCalculationResult({
    required this.principal,
    required this.grossInterest,
    required this.taxAmount,
    required this.feeAmount,
    required this.netInterest,
    required this.maturityAmount,
    required this.grossInterestRaw,
    required this.taxAmountRaw,
    required this.netInterestRaw,
  });
}
