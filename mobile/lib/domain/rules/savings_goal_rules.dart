/// Aturan perhitungan target tabungan (Savings Goals) — Milestone 5.
class SavingsGoalRules {
  const SavingsGoalRules._();

  /// Hitung sisa dana yang harus dikumpulkan.
  static int remaining({
    required int targetAmount,
    required int currentAmount,
  }) {
    final diff = targetAmount - currentAmount;
    return diff > 0 ? diff : 0;
  }

  /// Hitung persentase progres (0 - 100%).
  static double progress({
    required int targetAmount,
    required int currentAmount,
  }) {
    if (targetAmount <= 0) return 0.0;
    final pct = (currentAmount / targetAmount) * 100.0;
    return pct > 100.0 ? 100.0 : (pct < 0.0 ? 0.0 : pct);
  }

  /// Hitung kontribusi berkala (misal bulanan) yang diperlukan hingga tanggal target.
  static int monthlyRequired({
    required int targetAmount,
    required int currentAmount,
    required DateTime? targetDate,
    DateTime? today,
  }) {
    final rem =
        remaining(targetAmount: targetAmount, currentAmount: currentAmount);
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
