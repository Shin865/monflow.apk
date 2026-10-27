import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/providers/balance_visibility_provider.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
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

/// Dashboard utama keuangan Money Flow — Achromatic Ledger Aesthetic.
///
/// Berorientasi data, bebas template AI slop/gradien ungu, angka tabular,
/// kontras tinggi dan tenang di kedua tema (terang dan gelap).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(tokens.radiusControl),
                border: Border.all(color: tokens.border),
              ),
              child: Icon(Icons.show_chart_rounded,
                  color: tokens.dataHue, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Money Flow',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: tokens.textPrimary,
        onRefresh: () async {
          ref.invalidate(accountRepositoryProvider);
          ref.invalidate(transactionRepositoryProvider);
          ref.invalidate(investmentRepositoryProvider);
          ref.invalidate(depositRepositoryProvider);
          ref.invalidate(purchasePlanRepositoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: tokens.pad, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NetWorthAndBalanceCard(),
              const SizedBox(height: 16),
              _PrimaryQuickActions(),
              const SizedBox(height: 10),
              _SecondaryShortcutsGrid(),
              const SizedBox(height: 14),
              _ReportsBanner(),
              const SizedBox(height: 16),
              const _PortfolioAndPlanCards(),
              const SizedBox(height: 16),
              _PeriodCashFlowSummary(),
              const SizedBox(height: 16),
              _AccountsList(),
              const SizedBox(height: 16),
              _RecentTransactions(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu Net Worth & Saldo Total Akun Aktif (Achromatic Ledger Hero Card).
///
/// Merujuk pada SKILL.md (references/app-screens.md §3 & §5):
/// - Flat surface raised, border 1px, 0 resting shadow.
/// - Tabular figures font feature untuk nominal.
/// - Polarity tenang: aset & net worth jelas tanpa dekorasi neon.
class _NetWorthAndBalanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final balanceStream =
        ref.watch(accountRepositoryProvider).watchTotalBalance();
    final invStream =
        ref.watch(investmentRepositoryProvider).watchPortfolioSummary();
    final depStream = ref.watch(depositRepositoryProvider).watchSummary();
    final debtStream = ref.watch(debtRepositoryProvider).watchDebts();

    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised,
                        borderRadius: BorderRadius.circular(tokens.radiusCard),
                        border: Border.all(color: tokens.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Label & Status SQLite + Visibility
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined,
                                      size: 16, color: tokens.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total Saldo Akun Aktif',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isBalanceHidden
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: tokens.textSecondary,
                                      size: 20,
                                    ),
                                    tooltip: isBalanceHidden
                                        ? 'Tampilkan Saldo'
                                        : 'Sembunyikan Saldo',
                                    onPressed: () => ref
                                        .read(
                                            balanceVisibilityProvider.notifier)
                                        .toggle(),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tokens.surface,
                                      borderRadius: BorderRadius.circular(
                                          tokens.radiusChip),
                                      border: Border.all(
                                          color: tokens.borderHairline),
                                    ),
                                    child: Text(
                                      'Lokal SQLite',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Hero KPI: Big Number with Tabular Figures
                          Text(
                            BalanceVisibilityNotifier.formatOrMask(
                              totalActiveBalance,
                              isHidden: isBalanceHidden,
                            ),
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Hairline divider
                          Container(
                            height: 1,
                            width: double.infinity,
                            color: tokens.borderHairline,
                          ),
                          const SizedBox(height: 12),

                          // Sub-metrics: Total Aset & Net Worth
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Aset',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      BalanceVisibilityNotifier.formatOrMask(
                                        totalAssets,
                                        isHidden: isBalanceHidden,
                                      ),
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: tokens.borderHairline,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Kekayaan Bersih (Net Worth)',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      BalanceVisibilityNotifier.formatOrMask(
                                        netWorth,
                                        isHidden: isBalanceHidden,
                                      ),
                                      style: TextStyle(
                                        color: netWorth >= 0
                                            ? tokens.income
                                            : tokens.expense,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

/// Aksi Utama Transaksi (Pemasukan, Pengeluaran, Transfer)
///
/// Hierarki primer yang jelas, bukan 9 kotak pelangi bersaing (SKILL.md §13 Tells).
class _PrimaryQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: _PrimaryActionButton(
            label: 'Pemasukan',
            icon: Icons.add_circle_outline_rounded,
            accentColor: tokens.income,
            onTap: () => context.pushNamed('create_transaction'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PrimaryActionButton(
            label: 'Pengeluaran',
            icon: Icons.remove_circle_outline_rounded,
            accentColor: tokens.expense,
            onTap: () => context.pushNamed('create_transaction'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PrimaryActionButton(
            label: 'Transfer',
            icon: Icons.swap_horiz_rounded,
            accentColor: tokens.dataHue,
            onTap: () => context.pushNamed('create_transfer'),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusControl),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          borderRadius: BorderRadius.circular(tokens.radiusControl),
          border: Border.all(color: tokens.border, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintasan Fitur Keuangan Sekunder (Dompet Baru, Kategori, Tagihan, Hutang, Investasi, Rencana)
///
/// Ditampilkan sebagai baris/grid tenang netral, tanpa background warna-warni kontras tinggi.
class _SecondaryShortcutsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final shortcuts = [
      (
        label: 'Dompet Baru',
        icon: Icons.account_balance_wallet_outlined,
        route: 'create_account'
      ),
      (label: 'Kategori', icon: Icons.category_outlined, route: 'categories'),
      (label: 'Tagihan', icon: Icons.receipt_long_outlined, route: 'bills'),
      (
        label: 'Hutang / Piutang',
        icon: Icons.handshake_outlined,
        route: 'debts'
      ),
      (
        label: 'Investasi',
        icon: Icons.trending_up_rounded,
        route: 'investments'
      ),
      (label: 'Rencana', icon: Icons.shopping_bag_outlined, route: 'planning'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: shortcuts.map((item) {
          return InkWell(
            onTap: () => context.pushNamed(item.route),
            borderRadius: BorderRadius.circular(tokens.radiusControl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 18, color: tokens.textSecondary),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Banner Laporan & Analisis Arus Kas.
///
/// Bersih dan tenang, menggantikan gradien ungu sci-fi dengan MfCard achromatic.
class _ReportsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MfCard(
      onTap: () => context.pushNamed('reports'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(tokens.radiusControl),
              border: Border.all(color: tokens.border),
            ),
            child:
                Icon(Icons.analytics_outlined, color: tokens.dataHue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan Keuangan & Analisis',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Grafik arus kas, alokasi kategori, dan ekspor CSV/PDF',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tokens.textMuted, size: 20),
        ],
      ),
    );
  }
}

/// Ringkasan Portofolio Investasi & Rencana Belanja (Milestone 5).
class _PortfolioAndPlanCards extends ConsumerWidget {
  const _PortfolioAndPlanCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final invSummaryStream =
        ref.watch(investmentRepositoryProvider).watchPortfolioSummary();
    final depSummaryStream =
        ref.watch(depositRepositoryProvider).watchSummary();
    final plansStream =
        ref.watch(purchasePlanRepositoryProvider).watchSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MfSectionHeader(
          title: 'Portofolio & Rencana Keuangan',
        ),
        const SizedBox(height: 6),

        // 1. Ringkasan Investasi & Deposito
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

                return MfCard(
                  onTap: () => context.pushNamed('investments'),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up_rounded,
                                  color: tokens.dataHue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Investasi & Deposito',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          MfPill.neutral(
                            context,
                            '${inv.count} Inv • ${dep.count} Dep',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nilai Pasar Investasi',
                                style: TextStyle(
                                    fontSize: 11, color: tokens.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatRupiah(inv.totalValue),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Pokok Deposito',
                                style: TextStyle(
                                    fontSize: 11, color: tokens.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatRupiah(dep.totalPrincipal),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 8),

        // 2. Ringkasan Rencana Pembelian
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

            return MfCard(
              onTap: () => context.pushNamed('planning'),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              color: tokens.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Rencana Pembelian',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      MfPill.neutral(
                        context,
                        '${plans.activeCount} Aktif • ${plans.achievedCount} Selesai',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Belanja Aktif',
                            style: TextStyle(
                                fontSize: 11, color: tokens.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRupiah(plans.totalActiveTarget),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Terealisasi',
                            style: TextStyle(
                                fontSize: 11, color: tokens.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRupiah(plans.totalHistoryTarget),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.income,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Ringkasan Arus Kas untuk Periode Terpilih.
///
/// Merujuk pada aturan akuntansi: Transfer netral dan tidak tercatat di pemasukan/pengeluaran.
class _PeriodCashFlowSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final period = ref.watch(selectedPeriodProvider);
    final summaryStream = ref
        .watch(transactionRepositoryProvider)
        .watchMonthlySummary(period.year, period.month);

    return MfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan Arus Kas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded,
                        size: 20, color: tokens.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(selectedPeriodProvider.notifier).state =
                          DateTime(period.year, period.month - 1);
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatMonthYear(period),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded,
                        size: 20, color: tokens.textSecondary),
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
          const SizedBox(height: 14),
          StreamBuilder<MonthlySummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data;
              final income = summary?.income ?? 0;
              final expense = summary?.expense ?? 0;
              final netFlow = summary?.netFlow ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(tokens.radiusControl),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CashFlowCell(
                        label: 'Pemasukan',
                        amount: income,
                        color: tokens.income,
                        sign: '+',
                      ),
                    ),
                    Container(
                        width: 1, height: 32, color: tokens.borderHairline),
                    Expanded(
                      child: _CashFlowCell(
                        label: 'Pengeluaran',
                        amount: expense,
                        color: tokens.expense,
                        sign: '-',
                      ),
                    ),
                    Container(
                        width: 1, height: 32, color: tokens.borderHairline),
                    Expanded(
                      child: _CashFlowCell(
                        label: 'Selisih Bersih',
                        amount: netFlow,
                        color: netFlow >= 0 ? tokens.income : tokens.expense,
                        sign: netFlow > 0 ? '+' : '',
                      ),
                    ),
                  ],
                ),
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

class _CashFlowCell extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final String sign;

  const _CashFlowCell({
    required this.label,
    required this.amount,
    required this.color,
    required this.sign,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$sign${formatRupiah(amount.abs())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Daftar akun ringkas (48px table rows per SKILL.md §8).
class _AccountsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final accountsStream =
        ref.watch(accountRepositoryProvider).watchActiveAccounts();

    return StreamBuilder<List<Account>>(
      stream: accountsStream,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MfSectionHeader(
              title: 'Dompet',
              trailing: TextButton(
                onPressed: () => context.goNamed('accounts'),
                child: Text('Lihat Semua',
                    style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            if (accounts.isEmpty)
              MfEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Belum ada dompet aktif',
                subtitle: 'Buat dompet pertamamu untuk mulai mencatat keuangan',
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

class _AccountTile extends ConsumerWidget {
  final Account account;

  const _AccountTile({required this.account});

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.bank:
        return Icons.account_balance_outlined;
      case AccountType.ewallet:
        return Icons.phone_android_outlined;
      case AccountType.savings:
        return Icons.savings_outlined;
      case AccountType.other:
        return Icons.wallet_outlined;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(tokens.radiusControl),
              border: Border.all(color: tokens.border),
            ),
            child: Icon(_getAccountIcon(account.type),
                color: tokens.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getAccountTypeLabel(account.type),
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            BalanceVisibilityNotifier.formatOrMask(
              account.balance,
              isHidden: isBalanceHidden,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Transaksi terakhir dengan alignment tabular angka.
class _RecentTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
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
            MfSectionHeader(
              title: 'Transaksi Terakhir',
              trailing: TextButton(
                onPressed: () => context.goNamed('transactions'),
                child: Text('Lihat Semua',
                    style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            if (transactions.isEmpty)
              MfEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada transaksi',
                subtitle: 'Mulai dengan mencatat pemasukan atau pengeluaran',
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
    final tokens = context.tokens;
    final txn = enriched.transaction;
    final isIncome = txn.type == TransactionType.income ||
        txn.type == TransactionType.refund;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(tokens.radiusControl),
              border: Border.all(color: tokens.border),
            ),
            child: Text(
              enriched.categoryIcon ?? (isIncome ? '📥' : '📤'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enriched.categoryName ?? txn.description ?? 'Transaksi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${enriched.accountName ?? ""} • ${formatDate(txn.date)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? "+" : "-"}${formatRupiah(txn.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isIncome ? tokens.income : tokens.expense,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
