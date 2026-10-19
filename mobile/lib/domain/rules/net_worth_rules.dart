/// Aturan perhitungan net worth — porting dari backend Python.
///
/// Sumber: backend/app/routes/dashboard.py
///
/// total_assets = total_balance + total_investment_value + total_deposit + total_piutang
/// total_liabilities = total_hutang
/// net_worth = total_assets - total_liabilities
class NetWorthRules {
  const NetWorthRules._();

  /// Hitung total aset.
  ///
  /// Semua parameter dalam Rupiah (int).
  /// [totalBalance] = sum saldo akun aktif
  /// [totalInvestmentValue] = sum current_value investasi aktif
  /// [totalDeposit] = sum principal deposito aktif
  /// [totalPiutang] = sum remaining_amount piutang aktif
  static int totalAssets({
    required int totalBalance,
    int totalInvestmentValue = 0,
    int totalDeposit = 0,
    int totalPiutang = 0,
  }) {
    return totalBalance + totalInvestmentValue + totalDeposit + totalPiutang;
  }

  /// Hitung total kewajiban.
  ///
  /// [totalHutang] = sum remaining_amount hutang aktif
  static int totalLiabilities({
    int totalHutang = 0,
  }) {
    return totalHutang;
  }

  /// Hitung net worth.
  ///
  /// net_worth = total_assets - total_liabilities
  static int netWorth({
    required int totalBalance,
    int totalInvestmentValue = 0,
    int totalDeposit = 0,
    int totalPiutang = 0,
    int totalHutang = 0,
  }) {
    return totalAssets(
          totalBalance: totalBalance,
          totalInvestmentValue: totalInvestmentValue,
          totalDeposit: totalDeposit,
          totalPiutang: totalPiutang,
        ) -
        totalLiabilities(totalHutang: totalHutang);
  }

  /// Hitung cash flow bersih bulanan.
  ///
  /// Sumber: dashboard.py → net_flow = income + refund - expense
  static int monthlyCashFlow({
    required int income,
    required int expense,
    int refund = 0,
  }) {
    return income + refund - expense;
  }

  /// Hitung unrealized gain/loss dari investasi.
  ///
  /// Sumber: dashboard.py → unrealized_gain = total_value - total_cost
  static int unrealizedGain({
    required int totalInvestmentCost,
    required int totalInvestmentValue,
  }) {
    return totalInvestmentValue - totalInvestmentCost;
  }

  /// Hitung return persen dari investasi.
  ///
  /// Sumber: dashboard.py → return_pct = (value - cost) / cost * 100
  static double investmentReturnPercent({
    required int totalInvestmentCost,
    required int totalInvestmentValue,
  }) {
    if (totalInvestmentCost <= 0) return 0.0;
    return ((totalInvestmentValue - totalInvestmentCost) /
            totalInvestmentCost) *
        100.0;
  }
}
