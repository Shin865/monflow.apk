import 'package:money_flow/domain/rules/deposit_rules.dart';

/// Aturan perhitungan portofolio dan transaksi investasi — Milestone 5.
/// Sesuai model desktop backend/app/models/investment.py dan routes/investments.py
class InvestmentRules {
  const InvestmentRules._();

  /// Hitung keuntungan/kerugian belum terealisasi (unrealized gain/loss).
  ///
  /// unrealized_gain = current_value - initial_cost
  static int unrealizedGain({
    required int initialCost,
    required int currentValue,
  }) {
    return currentValue - initialCost;
  }

  /// Hitung persentase return investasi (ROI).
  ///
  /// return_pct = ((current_value - initial_cost) / initial_cost) * 100
  static double returnPercent({
    required int initialCost,
    required int currentValue,
  }) {
    if (initialCost <= 0) return 0.0;
    return ((currentValue - initialCost) / initialCost) * 100.0;
  }

  /// Hitung metrik penjualan unit investasi (realized gain/loss).
  static RealizedSellResult calculateSale({
    required int totalCost,
    required double totalUnits,
    required double unitsSold,
    required int sellPricePerUnit,
    int sellFee = 0,
  }) {
    final grossProceeds = (unitsSold * sellPricePerUnit).round();
    final netProceeds = grossProceeds - sellFee;
    final costBasisSold = totalUnits > 0
        ? DepositRules.roundHalfUp((unitsSold / totalUnits) * totalCost)
        : 0;
    final realizedGain = netProceeds - costBasisSold;
    final remainingCost =
        totalCost - costBasisSold > 0 ? totalCost - costBasisSold : 0;
    final remainingUnits =
        totalUnits - unitsSold > 0 ? totalUnits - unitsSold : 0.0;

    return RealizedSellResult(
      grossProceeds: grossProceeds,
      sellFee: sellFee,
      netProceeds: netProceeds,
      costBasisSold: costBasisSold,
      realizedGain: realizedGain,
      remainingCost: remainingCost,
      remainingUnits: remainingUnits,
    );
  }

  /// Hitung ringkasan agregat portofolio investasi.
  static PortfolioSummary summarize(List<InvestmentItemSummary> items) {
    var totalCost = 0;
    var totalValue = 0;

    for (final item in items) {
      if (item.isActive) {
        totalCost += item.initialCost;
        totalValue += item.currentValue;
      }
    }

    final totalGain = totalValue - totalCost;
    final totalReturnPct =
        totalCost > 0 ? (totalGain / totalCost) * 100.0 : 0.0;

    return PortfolioSummary(
      totalCost: totalCost,
      totalValue: totalValue,
      totalGain: totalGain,
      returnPercent: totalReturnPct,
      count: items.where((i) => i.isActive).length,
    );
  }
}

class RealizedSellResult {
  final int grossProceeds;
  final int sellFee;
  final int netProceeds;
  final int costBasisSold;
  final int realizedGain;
  final int remainingCost;
  final double remainingUnits;

  const RealizedSellResult({
    required this.grossProceeds,
    required this.sellFee,
    required this.netProceeds,
    required this.costBasisSold,
    required this.realizedGain,
    required this.remainingCost,
    required this.remainingUnits,
  });
}

class InvestmentItemSummary {
  final int initialCost;
  final int currentValue;
  final bool isActive;

  const InvestmentItemSummary({
    required this.initialCost,
    required this.currentValue,
    this.isActive = true,
  });
}

class PortfolioSummary {
  final int totalCost;
  final int totalValue;
  final int totalGain;
  final double returnPercent;
  final int count;

  const PortfolioSummary({
    required this.totalCost,
    required this.totalValue,
    required this.totalGain,
    required this.returnPercent,
    required this.count,
  });
}
