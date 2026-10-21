import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';
import 'package:money_flow/data/repositories/deposit_repository.dart';
import 'package:money_flow/data/repositories/investment_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/domain/rules/investment_rules.dart';
import 'package:money_flow/domain/rules/net_worth_rules.dart';

/// State provider untuk bulan dan tahun yang dipilih pada dashboard.
final selectedPeriodProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Dashboard utama keuangan Money Flow — Milestone 5.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.show_chart_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Money Flow'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountRepositoryProvider);
          ref.invalidate(transactionRepositoryProvider);
          ref.invalidate(investmentRepositoryProvider);
          ref.invalidate(depositRepositoryProvider);
          ref.invalidate(purchasePlanRepositoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NetWorthAndBalanceCard(),
              const SizedBox(height: 16),
              _QuickActions(),
              const SizedBox(height: 10),
              const _FinancialFeaturesRow(),
              const SizedBox(height: 10),
              const _Milestone5FeaturesRow(),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.pushNamed('reports'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4338CA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.analytics_rounded,
                          color: Colors.cyanAccent, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Laporan Keuangan & Analisis',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Grafik arus kas, pengeluaran per kategori, dan ekspor CSV/PDF',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Milestone5OverviewCards(),
              const SizedBox(height: 16),
              _PeriodCashFlowSummary(),
              const SizedBox(height: 16),
              _AccountsList(),
              const SizedBox(height: 16),
              _RecentTransactions(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu Net Worth & Saldo Total Akun Aktif.
///
/// Net worth dihitung berdasarkan aturan domain audit `NetWorthRules.netWorth`
/// menggabungkan Saldo Dompet + Investasi + Deposito + Piutang - Hutang.
/// Tidak ada double counting aset maupun pengeluaran.
class _NetWorthAndBalanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceStream =
        ref.watch(accountRepositoryProvider).watchTotalBalance();
    final invStream =
        ref.watch(investmentRepositoryProvider).watchPortfolioSummary();
    final depStream = ref.watch(depositRepositoryProvider).watchSummary();
    final debtStream = ref.watch(debtRepositoryProvider).watchDebts();

    return StreamBuilder<int>(
      stream: balanceStream,
      builder: (context, balSnap) {
        return StreamBuilder<PortfolioSummary>(
          stream: invStream,
          builder: (context, invSnap) {
            return StreamBuilder<DepositSummary>(
              stream: depStream,
              builder: (context, depSnap) {
                return StreamBuilder<List<Debt>>(
                  stream: debtStream,
                  builder: (context, debtSnap) {
                    final totalActiveBalance = balSnap.data ?? 0;
                    final totalInvValue = invSnap.data?.totalValue ?? 0;
                    final totalDepositPrincipal =
                        depSnap.data?.totalPrincipal ?? 0;
                    final debts = debtSnap.data ?? [];

                    final totalPiutang = debts
                        .where((d) =>
                            d.type == DebtType.piutang &&
                            d.status != DebtStatus.paid)
                        .fold<int>(0, (sum, d) => sum + d.remainingAmount);

                    final totalHutang = debts
                        .where((d) =>
                            d.type == DebtType.hutang &&
                            d.status != DebtStatus.paid)
                        .fold<int>(0, (sum, d) => sum + d.remainingAmount);

                    final totalAssets = NetWorthRules.totalAssets(
                      totalBalance: totalActiveBalance,
                      totalInvestmentValue: totalInvValue,
                      totalDeposit: totalDepositPrincipal,
                      totalPiutang: totalPiutang,
                    );

                    final netWorth = NetWorthRules.netWorth(
                      totalBalance: totalActiveBalance,
                      totalInvestmentValue: totalInvValue,
                      totalDeposit: totalDepositPrincipal,
                      totalPiutang: totalPiutang,
                      totalHutang: totalHutang,
                    );

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3730A3),
                            Color(0xFF5B21B6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Total Saldo Akun Aktif',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Lokal SQLite',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            formatRupiah(totalActiveBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Aset',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatRupiah(totalAssets),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Colors.white24,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Kekayaan Bersih (Net Worth)',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatRupiah(netWorth),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Aksi cepat (Quick Actions) mencakup Pemasukan, Pengeluaran, Transfer, dan Dompet Baru.
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'Pemasukan',
            color: AppColors.income,
            onTap: () => context.pushNamed('create_transaction'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Pengeluaran',
            color: AppColors.expense,
            onTap: () => context.pushNamed('create_transaction'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer',
            color: AppColors.transfer,
            onTap: () => context.pushNamed('create_transfer'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Dompet Baru',
            color: AppColors.primary,
            onTap: () => context.pushNamed('create_account'),
          ),
        ),
      ],
    );
  }
}

class _FinancialFeaturesRow extends StatelessWidget {
  const _FinancialFeaturesRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.category_rounded,
            label: 'Kategori',
            color: AppColors.income,
            onTap: () => context.pushNamed('categories'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.receipt_long_rounded,
            label: 'Tagihan',
            color: AppColors.warning,
            onTap: () => context.pushNamed('bills'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.handshake_outlined,
            label: 'Hutang / Piutang',
            color: AppColors.transfer,
            onTap: () => context.pushNamed('debts'),
          ),
        ),
      ],
    );
  }
}

class _Milestone5FeaturesRow extends StatelessWidget {
  const _Milestone5FeaturesRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.trending_up_rounded,
            label: 'Investasi & Deposito',
            color: AppColors.primary,
            onTap: () => context.pushNamed('investments'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.shopping_bag_rounded,
            label: 'Rencana Pembelian',
            color: Colors.purpleAccent,
            onTap: () => context.pushNamed('planning'),
          ),
        ),
      ],
    );
  }
}

class _Milestone5OverviewCards extends ConsumerWidget {
  const _Milestone5OverviewCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invSummaryStream =
        ref.watch(investmentRepositoryProvider).watchPortfolioSummary();
    final depSummaryStream =
        ref.watch(depositRepositoryProvider).watchSummary();
    final plansStream =
        ref.watch(purchasePlanRepositoryProvider).watchSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Portofolio & Rencana Keuangan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        // 1. Kartu Ringkasan Investasi & Deposito
        StreamBuilder<PortfolioSummary>(
          stream: invSummaryStream,
          builder: (context, invSnap) {
            return StreamBuilder<DepositSummary>(
              stream: depSummaryStream,
              builder: (context, depSnap) {
                final inv = invSnap.data ??
                    const PortfolioSummary(
                      totalCost: 0,
                      totalValue: 0,
                      totalGain: 0,
                      returnPercent: 0,
                      count: 0,
                    );
                final dep = depSnap.data ??
                    const DepositSummary(
                      totalPrincipal: 0,
                      totalEstimatedNetInterest: 0,
                      totalMaturityAmount: 0,
                      count: 0,
                    );

                return InkWell(
                  onTap: () => context.pushNamed('investments'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up_rounded,
                                    color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Investasi & Deposito',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              '${inv.count} Inv • ${dep.count} Dep',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nilai Pasar Investasi',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white54)),
                                const SizedBox(height: 2),
                                Text(
                                  formatRupiah(inv.totalValue),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Pokok Deposito',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white54)),
                                const SizedBox(height: 2),
                                Text(
                                  formatRupiah(dep.totalPrincipal),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        // 2. Kartu Ringkasan Rencana Pembelian
        StreamBuilder<PurchasePlanSummary>(
          stream: plansStream,
          builder: (context, planSnap) {
            final plans = planSnap.data ??
                const PurchasePlanSummary(
                  totalActiveTarget: 0,
                  totalHistoryTarget: 0,
                  activeCount: 0,
                  achievedCount: 0,
                );

            return InkWell(
              onTap: () => context.pushNamed('planning'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shopping_bag_rounded,
                                color: Colors.purpleAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Rencana Pembelian',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Text(
                          '${plans.activeCount} Aktif • ${plans.achievedCount} Selesai',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Rencana Belanja Aktif',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                            const SizedBox(height: 2),
                            Text(
                              formatRupiah(plans.totalActiveTarget),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Terealisasi',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                            const SizedBox(height: 2),
                            Text(
                              formatRupiah(plans.totalHistoryTarget),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ringkasan Pemasukan & Pengeluaran untuk Periode Terpilih.
/// Transfer TIDAK dihitung sebagai pemasukan atau pengeluaran.
class _PeriodCashFlowSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final summaryStream = ref
        .watch(transactionRepositoryProvider)
        .watchMonthlySummary(period.year, period.month);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ringkasan Arus Kas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(selectedPeriodProvider.notifier).state =
                          DateTime(period.year, period.month - 1);
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatMonthYear(period),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(selectedPeriodProvider.notifier).state =
                          DateTime(period.year, period.month + 1);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<MonthlySummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data;
              final income = summary?.income ?? 0;
              final expense = summary?.expense ?? 0;
              final netFlow = summary?.netFlow ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: _CashFlowMetric(
                      title: 'Pemasukan',
                      amount: income,
                      color: AppColors.income,
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CashFlowMetric(
                      title: 'Pengeluaran',
                      amount: expense,
                      color: AppColors.expense,
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CashFlowMetric(
                      title: 'Selisih Bersih',
                      amount: netFlow,
                      color:
                          netFlow >= 0 ? AppColors.income : AppColors.expense,
                      icon: Icons.stacked_line_chart_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _CashFlowMetric extends StatelessWidget {
  final String title;
  final int amount;
  final Color color;
  final IconData icon;

  const _CashFlowMetric({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatRupiah(amount),
            style: TextStyle(
              fontSize: 12,
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
}

/// Daftar akun ringkas.
class _AccountsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsStream =
        ref.watch(accountRepositoryProvider).watchActiveAccounts();

    return StreamBuilder<List<Account>>(
      stream: accountsStream,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dompet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => context.goNamed('accounts'),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              _EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: 'Belum ada dompet aktif. Buat dompet pertamamu!',
                actionLabel: 'Buat Dompet',
                onAction: () => context.pushNamed('create_account'),
              )
            else
              ...accounts
                  .take(4)
                  .map((account) => _AccountTile(account: account)),
          ],
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;

  const _AccountTile({required this.account});

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.ewallet:
        return Icons.phone_android_rounded;
      case AccountType.savings:
        return Icons.savings_rounded;
      case AccountType.other:
        return Icons.wallet_rounded;
    }
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Tunai';
      case AccountType.bank:
        return 'Bank';
      case AccountType.ewallet:
        return 'E-Wallet';
      case AccountType.savings:
        return 'Tabungan';
      case AccountType.other:
        return 'Lainnya';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = account.color != null
        ? Color(int.parse(account.color!.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getAccountIcon(account.type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getAccountTypeLabel(account.type),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(account.balance),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color:
                  account.balance >= 0 ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

/// Transaksi terakhir.
class _RecentTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnStream = ref
        .watch(transactionRepositoryProvider)
        .watchRecentTransactions(limit: 5);

    return StreamBuilder<List<EnrichedTransaction>>(
      stream: txnStream,
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaksi Terakhir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => context.goNamed('transactions'),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              _EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Belum ada transaksi.',
                actionLabel: 'Catat Transaksi',
                onAction: () => context.pushNamed('create_transaction'),
              )
            else
              ...transactions.map((etxn) => _TransactionTile(enriched: etxn)),
          ],
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final EnrichedTransaction enriched;

  const _TransactionTile({required this.enriched});

  @override
  Widget build(BuildContext context) {
    final txn = enriched.transaction;
    final isIncome = txn.type == TransactionType.income ||
        txn.type == TransactionType.refund;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? AppColors.income : AppColors.expense)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              enriched.categoryIcon ?? (isIncome ? '📥' : '📤'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enriched.categoryName ?? txn.description ?? 'Transaksi',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${enriched.accountName ?? ""} • ${formatDate(txn.date)}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? "+" : "-"}${formatRupiah(txn.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
