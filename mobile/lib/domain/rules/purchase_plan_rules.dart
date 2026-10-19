/// Aturan perhitungan rencana pembelian — porting dari backend Python.
///
/// Sumber: backend/app/models/purchase_plan.py
class PurchasePlanRules {
  const PurchasePlanRules._();

  /// Hitung sisa yang perlu dikumpulkan.
  /// remaining = max(0, target - current)
  static int remaining({
    required int targetAmount,
    required int currentSaving,
  }) {
    final diff = targetAmount - currentSaving;
    return diff > 0 ? diff : 0;
  }

  /// Hitung persentase progres (0-100).
  /// progress = min(100, (current / target) * 100)
  static double progress({
    required int targetAmount,
    required int currentSaving,
  }) {
    if (targetAmount <= 0) return 0.0;
    final pct = (currentSaving / targetAmount) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  /// Hitung berapa yang perlu ditabung per bulan untuk mencapai target.
  ///
  /// Jika target_date sudah lewat atau remaining == 0, return remaining.
  /// Jika ada bulan tersisa: monthly = remaining / months_left
  static int monthlyRequired({
    required int targetAmount,
    required int currentSaving,
    required DateTime? targetDate,
    DateTime? today,
  }) {
    final rem =
        remaining(targetAmount: targetAmount, currentSaving: currentSaving);
    if (rem <= 0) return 0;
    if (targetDate == null) return 0;

    final now = today ?? DateTime.now();
    if (!targetDate.isAfter(now)) return rem;

    final monthsLeft =
        (targetDate.year - now.year) * 12 + (targetDate.month - now.month);

    if (monthsLeft <= 0) return rem;
    return (rem / monthsLeft).ceil();
  }
}
