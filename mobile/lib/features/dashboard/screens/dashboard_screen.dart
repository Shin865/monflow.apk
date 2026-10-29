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

/// Dashboard utama keuangan Money Flow — Finsave Reference & Taste-Skill.
///
/// Karakteristik Finsave:
/// - Header sapaan + "Available balance" besar dengan ikon mata hide/show
/// - Dua tombol aksi berdampingan (primer charcoal + sekunder outline)
/// - Bar statistik pemasukan vs pengeluaran proporsional dari data nyata
/// - Baris daftar transaksi polos dengan avatar kecil dan nominal tabular +/-
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.ground,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Money Flow',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Manajemen Keuangan Mandiri',
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: tokens.brand,
        onRefresh: () async {
          ref.invalidate(accountRepositoryProvider);
          ref.invalidate(transactionRepositoryProvider);
          ref.invalidate(investmentRepositoryProvider);
          ref.invalidate(depositRepositoryProvider);
          ref.invalidate(purchasePlanRepositoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: tokens.pad, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvailableBalanceCard(),
              const SizedBox(height: 12),
              _FinsaveActionButtons(),
              const SizedBox(height: 12),
              _SecondaryShortcutsRow(),
              const SizedBox(height: 16),
              _FinsaveCashFlowCard(),
              const SizedBox(height: 16),
              const _PortfolioAndPlanCards(),
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

/// Kartu Saldo Tersedia (Available Balance) gaya Finsave:
/// Sapaan + Available balance besar dengan ikon mata + Sub-metrik Net Worth.
class _AvailableBalanceCard extends ConsumerWidget {
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(tokens.radiusCard),
                        border: Border.all(color: tokens.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sapaan & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available balance',
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Total Saldo Akun Aktif',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  isBalanceHidden
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: tokens.textSecondary,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: isBalanceHidden
                                    ? 'Tampilkan Saldo'
                                    : 'Sembunyikan Saldo',
                                onPressed: () => ref
                                    .read(balanceVisibilityProvider.notifier)
                                    .toggle(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Nominal Saldo Besar (Tabular Figures)
                          Text(
                            BalanceVisibilityNotifier.formatOrMask(
                              totalActiveBalance,
                              isHidden: isBalanceHidden,
                            ),
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Hairline divider
                          Container(
                            height: 1,
                            width: double.infinity,
                            color: tokens.rule,
                          ),
                          const SizedBox(height: 10),

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
                                        color: tokens.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      BalanceVisibilityNotifier.formatOrMask(
                                        totalAssets,
                                        isHidden: isBalanceHidden,
                                      ),
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 13,
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
                                height: 24,
                                color: tokens.rule,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Kekayaan Bersih (Net Worth)',
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      BalanceVisibilityNotifier.formatOrMask(
                                        netWorth,
                                        isHidden: isBalanceHidden,
                                      ),
                                      style: TextStyle(
                                        color: netWorth >= 0
                                            ? tokens.income
                                            : tokens.expense,
                                        fontSize: 13,
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

/// Dua Tombol Aksi Berdampingan (Finsave pattern):
/// - Tombol Primer Gelap: Catat Transaksi
/// - Tombol Sekunder Outline: Transfer Antar Akun
class _FinsaveActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MfButton.primary(
            label: 'Catat Transaksi',
            icon: Icons.add_rounded,
            height: 46,
            onPressed: () => context.pushNamed('create_transaction'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MfButton.secondary(
            label: 'Transfer',
            icon: Icons.swap_horiz_rounded,
            height: 46,
            onPressed: () => context.pushNamed('create_transfer'),
          ),
        ),
      ],
    );
  }
}

/// Baris Pintasan Fitur Keuangan Sekunder (Finsave clean row)
class _SecondaryShortcutsRow extends StatelessWidget {
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
      (label: 'Hutang', icon: Icons.handshake_outlined, route: 'debts'),
      (
        label: 'Investasi',
        icon: Icons.trending_up_rounded,
        route: 'investments'
      ),
      (label: 'Rencana', icon: Icons.shopping_bag_outlined, route: 'planning'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: shortcuts.map((item) {
          return InkWell(
            onTap: () => context.pushNamed(item.route),
            borderRadius: BorderRadius.circular(tokens.radiusControl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 18, color: tokens.textPrimary),
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

/// Kartu Ringkasan Arus Kas dengan Bar Statistik Pemasukan vs Pengeluaran Proporsional (Finsave Pattern)
class _FinsaveCashFlowCard extends ConsumerWidget {
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
                  fontSize: 14,
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
                  const SizedBox(width: 6),
                  Text(
                    _formatMonthYear(period),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
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
          const SizedBox(height: 12),
          StreamBuilder<MonthlySummary>(
            stream: summaryStream,
            builder: (context, snapshot) {
              final summary = snapshot.data;
              final income = summary?.income ?? 0;
              final expense = summary?.expense ?? 0;
              final totalFlow = income + expense;
              final net = income - expense;

              double incomeRatio = 0.5;
              if (totalFlow > 0) {
                incomeRatio = (income / totalFlow).clamp(0.05, 0.95);
              }

              return Column(
                children: [
                  // Angka Pemasukan & Pengeluaran
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tokens.income,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Pemasukan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '+${formatRupiah(income)}',
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tokens.expense,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Pengeluaran',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '-${formatRupiah(expense)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.expense,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bar Statistik Proporsional Realistis
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (incomeRatio * 100).toInt(),
                            child: Container(color: tokens.income),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            flex: ((1 - incomeRatio) * 100).toInt(),
                            child: Container(color: tokens.expense),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selisih Bersih',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textSecondary,
                        ),
                      ),
                      Text(
                        '${net >= 0 ? "+" : ""}${formatRupiah(net)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: net >= 0 ? tokens.income : tokens.expense,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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

/// Ringkasan Portofolio & Rencana
class _PortfolioAndPlanCards extends ConsumerWidget {
  const _PortfolioAndPlanCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final invSummaryStream =
        ref.watch(investmentRepositoryProvider).watchPortfolioSummary();
    final depSummaryStream =
        ref.watch(depositRepositoryProvider).watchSummary();

    return StreamBuilder<PortfolioSummary>(
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
                              color: tokens.brand, size: 18),
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nilai Investasi',
                            style: TextStyle(
                                fontSize: 11, color: tokens.textSecondary),
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
                                fontSize: 11, color: tokens.textSecondary),
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
    );
  }
}

/// Daftar Akun / Dompet
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
            MfSectionHeader(
              title: 'Dompet & Rekening',
              onViewAll: () => context.goNamed('accounts'),
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
                  .take(3)
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
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getAccountIcon(account.type),
                color: tokens.textPrimary, size: 18),
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
                    color: tokens.textSecondary,
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

/// Daftar Transaksi Terakhir (Finsave Baris-Polos)
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
            MfSectionHeader(
              title: 'Transaksi Terakhir',
              onViewAll: () => context.goNamed('transactions'),
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
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Text(
              enriched.categoryIcon ?? (isIncome ? '📥' : '📤'),
              style: const TextStyle(fontSize: 15),
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
                    color: tokens.textSecondary,
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
